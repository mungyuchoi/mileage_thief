import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/giftcard_info_data.dart';
import '../model/giftcard_period.dart';
import 'firestore_page_loader.dart';

class GiftcardService {
  static const Duration _infoTtl = Duration(minutes: 2);
  static const Duration _diskInfoTtl = Duration(hours: 24);
  static const Duration _referenceTtl = Duration(minutes: 10);
  static const int _pageSize = 200;
  static const int _diskCacheSchemaVersion = 1;
  static const int _whereInChunkSize = 10;
  static const int _whereInConcurrency = 4;

  static final Map<String, _CacheEntry<GiftcardInfoData>> _infoCache = {};
  static final Map<String, _CacheEntry<Map<String, Map<String, dynamic>>>>
      _cardsCache = {};
  static final Map<String, _CacheEntry<Map<String, String>>> _whereToBuyCache =
      {};
  static final _CacheEntry<Map<String, String>> _giftcardNamesCache =
      _CacheEntry<Map<String, String>>();
  static final _CacheEntry<Map<String, String>> _branchNamesCache =
      _CacheEntry<Map<String, String>>();

  static Future<GiftcardInfoData> loadInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _freshCachedInfoData(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
      );
      if (cached != null) return cached;
    }

    try {
      return await refreshInfoData(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
        forceReferenceRefresh: forceRefresh,
      );
    } catch (_) {
      final diskCache = !forceRefresh
          ? await loadInfoDataFromDiskCache(
              uid: uid,
              periodType: periodType,
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
            )
          : null;
      if (diskCache != null) return diskCache;
      rethrow;
    }
  }

  static GiftcardInfoData? peekCachedInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) {
    final key = _infoCacheKey(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    return _infoCache[key]?.data?.copy();
  }

  static Future<GiftcardInfoData?> loadInfoDataFromDiskCache({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) async {
    try {
      final file = await _diskCacheFile(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
      );
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final data = debugDecodeInfoDataCachePayload(decoded);
      if (data == null) return null;

      final key = _infoCacheKey(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
      );
      final entry = _infoCache.putIfAbsent(
        key,
        () => _CacheEntry<GiftcardInfoData>(),
      );
      entry
        ..data = data.copy()
        ..fetchedAt = DateTime.now();
      return data.copy();
    } catch (_) {
      return null;
    }
  }

  static Future<GiftcardInfoData> refreshInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
    bool forceReferenceRefresh = false,
  }) async {
    final key = _infoCacheKey(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    final entry = _infoCache.putIfAbsent(
      key,
      () => _CacheEntry<GiftcardInfoData>(),
    );
    if (entry.inFlight != null) {
      return (await entry.inFlight!).copy();
    }

    final future = _fetchInfoData(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
      forceReferenceRefresh: forceReferenceRefresh,
    );
    entry.inFlight = future;
    try {
      final data = await future;
      entry
        ..data = data.copy()
        ..fetchedAt = DateTime.now();
      unawaited(_writeInfoDataToDiskCache(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
        data: data,
      ));
      return data.copy();
    } finally {
      if (identical(entry.inFlight, future)) {
        entry.inFlight = null;
      }
    }
  }

  static GiftcardInfoData? _freshCachedInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) {
    final key = _infoCacheKey(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    final entry = _infoCache[key];
    final cachedData = entry?.data;
    final fetchedAt = entry?.fetchedAt;
    if (cachedData == null || fetchedAt == null) return null;
    if (DateTime.now().difference(fetchedAt) >= _infoTtl) return null;
    return cachedData.copy();
  }

  static void invalidateUser(String uid) {
    _infoCache.removeWhere((key, _) => key.startsWith('$uid|'));
    _cardsCache.remove(uid);
    _whereToBuyCache.remove(uid);
    unawaited(_deleteUserDiskCaches(uid));
  }

  static Future<GiftcardInfoData> _fetchInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
    required bool forceReferenceRefresh,
  }) async {
    final range = getGiftcardPeriodRange(
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    final DateTime? start = range.start;
    final DateTime? end = range.end;
    final referencesFuture = _loadReferenceData(
      uid: uid,
      forceRefresh: forceReferenceRefresh,
    );

    // lots는 항상 buyDate 기준으로 기간 필터
    final CollectionReference<Map<String, dynamic>> lotsRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('lots');

    Query<Map<String, dynamic>> lotsQuery = lotsRef;
    if (start != null && end != null) {
      lotsQuery = lotsQuery
          .where('buyDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('buyDate', isLessThan: Timestamp.fromDate(end))
          .orderBy('buyDate');
    } else {
      lotsQuery = lotsQuery.orderBy('buyDate');
    }

    final lotsDocs = await FirestorePageLoader.load(
      query: lotsQuery,
      pageSize: _pageSize,
    );

    // 매입월 기준 대시보드를 위해:
    // - 선택한 기간에 매입한 lot 들만 lots 에 포함
    // - sales 는 "그 lotId 들과 연결된 판매" + "선택한 기간에 판매된 판매" 모두 포함
    //   (일간 탭에서 판매일 기준으로도 표시하기 위해)
    final CollectionReference<Map<String, dynamic>> salesRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('sales');

    List<QueryDocumentSnapshot<Map<String, dynamic>>> saleDocs = [];
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> saleById =
        {};

    if (periodType == DashboardPeriodType.all) {
      saleDocs = await FirestorePageLoader.load(
        query: salesRef.orderBy('sellDate'),
        pageSize: _pageSize,
      );
    } else {
      // 1) lotId 기준으로 연결된 판매 조회 (대시보드/내역용)
      final lotIds = lotsDocs.map((d) => d.id).toList();
      if (lotIds.isNotEmpty) {
        final docs = await _loadSalesForLotIds(
          salesRef: salesRef,
          lotIds: lotIds,
        );
        for (final d in docs) {
          saleById[d.id] = d;
        }
      }

      // 2) 판매일 기준으로도 판매 조회 (일간/내역용)
      final salesByDateDocs = await FirestorePageLoader.load(
        query: salesRef
            .where('sellDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start!))
            .where('sellDate', isLessThan: Timestamp.fromDate(end!))
            .orderBy('sellDate'),
        pageSize: _pageSize,
      );
      for (final d in salesByDateDocs) {
        saleById[d.id] = d;
      }

      saleDocs = saleById.values.toList();
    }

    final references = await referencesFuture;
    final lots = lotsDocs
        .map<Map<String, dynamic>>(
          (d) => <String, dynamic>{'id': d.id, ...d.data()},
        )
        .toList();
    final sales = saleDocs
        .map<Map<String, dynamic>>(
          (d) => <String, dynamic>{'id': d.id, ...d.data()},
        )
        .toList();

    return GiftcardInfoData(
      lots: lots,
      sales: sales,
      cards: references.cards,
      giftcardNames: references.giftcardNames,
      branchNames: references.branchNames,
      whereToBuyNames: references.whereToBuyNames,
    );
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadSalesForLotIds({
    required CollectionReference<Map<String, dynamic>> salesRef,
    required List<String> lotIds,
  }) async {
    final chunks = <List<String>>[];
    for (int i = 0; i < lotIds.length; i += _whereInChunkSize) {
      final int end = (i + _whereInChunkSize < lotIds.length)
          ? i + _whereInChunkSize
          : lotIds.length;
      chunks.add(lotIds.sublist(i, end));
    }

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (int i = 0; i < chunks.length; i += _whereInConcurrency) {
      final int end = (i + _whereInConcurrency < chunks.length)
          ? i + _whereInConcurrency
          : chunks.length;
      final batch = chunks.sublist(i, end);
      final batchDocs = await Future.wait(
        batch.map(
          (chunk) => FirestorePageLoader.load(
            query: salesRef.where('lotId', whereIn: chunk),
            pageSize: _pageSize,
          ),
        ),
      );
      for (final pageDocs in batchDocs) {
        docs.addAll(pageDocs);
      }
    }
    return docs;
  }

  static Future<_GiftcardReferenceData> _loadReferenceData({
    required String uid,
    required bool forceRefresh,
  }) async {
    final cardsFuture = _loadCards(uid, forceRefresh: forceRefresh);
    final giftcardNamesFuture = _loadGiftcardNames(forceRefresh: forceRefresh);
    final branchNamesFuture = _loadBranchNames(forceRefresh: forceRefresh);
    final whereToBuyNamesFuture =
        _loadWhereToBuyNames(uid, forceRefresh: forceRefresh);

    return _GiftcardReferenceData(
      cards: await cardsFuture,
      giftcardNames: await giftcardNamesFuture,
      branchNames: await branchNamesFuture,
      whereToBuyNames: await whereToBuyNamesFuture,
    );
  }

  static Future<Map<String, Map<String, dynamic>>> _loadCards(
    String uid, {
    required bool forceRefresh,
  }) {
    final entry = _cardsCache.putIfAbsent(
      uid,
      () => _CacheEntry<Map<String, Map<String, dynamic>>>(),
    );
    return _cached(
      entry: entry,
      ttl: _referenceTtl,
      force: forceRefresh,
      copy: _copyCardMap,
      loader: () async {
        final docs = await FirestorePageLoader.load(
          query: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('cards'),
          pageSize: _pageSize,
        );
        return {
          for (final d in docs)
            d.id: {
              'name': d.data()['name'],
              'credit': ((d.data()['creditPerMileKRW'] as num?)?.toInt()) ?? 0,
              'check': ((d.data()['checkPerMileKRW'] as num?)?.toInt()) ?? 0,
            }
        };
      },
    );
  }

  static Future<Map<String, String>> _loadGiftcardNames({
    required bool forceRefresh,
  }) {
    return _cached(
      entry: _giftcardNamesCache,
      ttl: _referenceTtl,
      force: forceRefresh,
      copy: (data) => Map<String, String>.from(data),
      loader: () async {
        final docs = await FirestorePageLoader.load(
          query: FirebaseFirestore.instance.collection('giftcards'),
          pageSize: _pageSize,
        );
        return {
          for (final d in docs) d.id: (d.data()['name'] as String?) ?? d.id
        };
      },
    );
  }

  static Future<Map<String, String>> _loadBranchNames({
    required bool forceRefresh,
  }) {
    return _cached(
      entry: _branchNamesCache,
      ttl: _referenceTtl,
      force: forceRefresh,
      copy: (data) => Map<String, String>.from(data),
      loader: () async {
        final docs = await FirestorePageLoader.load(
          query: FirebaseFirestore.instance.collection('branches'),
          pageSize: _pageSize,
        );
        return {
          for (final d in docs) d.id: (d.data()['name'] as String?) ?? d.id
        };
      },
    );
  }

  static Future<Map<String, String>> _loadWhereToBuyNames(
    String uid, {
    required bool forceRefresh,
  }) {
    final entry = _whereToBuyCache.putIfAbsent(
      uid,
      () => _CacheEntry<Map<String, String>>(),
    );
    return _cached(
      entry: entry,
      ttl: _referenceTtl,
      force: forceRefresh,
      copy: (data) => Map<String, String>.from(data),
      loader: () async {
        final docs = await FirestorePageLoader.load(
          query: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('where_to_buy'),
          pageSize: _pageSize,
        );
        return {
          for (final d in docs) d.id: (d.data()['name'] as String?) ?? d.id
        };
      },
    );
  }

  static Future<T> _cached<T>({
    required _CacheEntry<T> entry,
    required Duration ttl,
    required Future<T> Function() loader,
    required T Function(T data) copy,
    bool force = false,
  }) async {
    final cachedData = entry.data;
    final fetchedAt = entry.fetchedAt;
    final isFresh =
        fetchedAt != null && DateTime.now().difference(fetchedAt) < ttl;
    if (!force && cachedData != null && isFresh) {
      return copy(cachedData);
    }

    if (!force && entry.inFlight != null) {
      return copy(await entry.inFlight!);
    }

    final future = loader();
    entry.inFlight = future;
    try {
      final data = await future;
      entry
        ..data = copy(data)
        ..fetchedAt = DateTime.now();
      return copy(data);
    } finally {
      if (identical(entry.inFlight, future)) {
        entry.inFlight = null;
      }
    }
  }

  static Map<String, Map<String, dynamic>> _copyCardMap(
    Map<String, Map<String, dynamic>> data,
  ) {
    return data.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
  }

  static String _infoCacheKey({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) {
    final monthKey =
        '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    return '$uid|${periodType.name}|$monthKey|$selectedYear';
  }

  @visibleForTesting
  static String debugInfoCacheKey({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) {
    return _infoCacheKey(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
  }

  static Future<File> _diskCacheFile({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/giftcard_info_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final key = _infoCacheKey(
      uid: uid,
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    final fileName = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File('${cacheDir.path}/$fileName.json');
  }

  static Future<void> _writeInfoDataToDiskCache({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
    required GiftcardInfoData data,
  }) async {
    try {
      final file = await _diskCacheFile(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
      );
      final payload = debugEncodeInfoDataCachePayload(data);
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {}
  }

  static Future<void> _deleteUserDiskCaches(String uid) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}/giftcard_info_cache');
      if (!await cacheDir.exists()) return;
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final name =
            entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
        if (!name.endsWith('.json')) continue;
        try {
          final rawName = name.replaceAll('.json', '');
          final padding = '=' * ((4 - rawName.length % 4) % 4);
          final decoded = utf8.decode(
            base64Url.decode('$rawName$padding'),
            allowMalformed: true,
          );
          if (decoded.startsWith('$uid|')) {
            await entity.delete();
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
  }

  @visibleForTesting
  static Map<String, dynamic> debugEncodeInfoDataCachePayload(
    GiftcardInfoData data, {
    DateTime? fetchedAt,
  }) {
    return {
      'schemaVersion': _diskCacheSchemaVersion,
      'fetchedAtMillis': (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
      'data': {
        'lots': _encodeCacheValue(data.lots),
        'sales': _encodeCacheValue(data.sales),
        'cards': _encodeCacheValue(data.cards),
        'giftcardNames': _encodeCacheValue(data.giftcardNames),
        'branchNames': _encodeCacheValue(data.branchNames),
        'whereToBuyNames': _encodeCacheValue(data.whereToBuyNames),
      },
    };
  }

  @visibleForTesting
  static GiftcardInfoData? debugDecodeInfoDataCachePayload(
    Map<String, dynamic> payload, {
    DateTime? now,
  }) {
    try {
      if (payload['schemaVersion'] != _diskCacheSchemaVersion) return null;
      final fetchedAtMillis = payload['fetchedAtMillis'];
      if (fetchedAtMillis is! int) return null;
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMillis);
      if ((now ?? DateTime.now()).difference(fetchedAt) > _diskInfoTtl) {
        return null;
      }
      final data = payload['data'];
      if (data is! Map<String, dynamic>) return null;
      return GiftcardInfoData(
        lots: _decodeListOfMaps(data['lots']),
        sales: _decodeListOfMaps(data['sales']),
        cards: _decodeCards(data['cards']),
        giftcardNames: _decodeStringMap(data['giftcardNames']),
        branchNames: _decodeStringMap(data['branchNames']),
        whereToBuyNames: _decodeStringMap(data['whereToBuyNames']),
      );
    } catch (_) {
      return null;
    }
  }

  static dynamic _encodeCacheValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__cacheType': 'timestamp',
        'millis': value.millisecondsSinceEpoch,
      };
    }
    if (value is DateTime) {
      return {
        '__cacheType': 'datetime',
        'millis': value.millisecondsSinceEpoch,
      };
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, child) => MapEntry(key.toString(), _encodeCacheValue(child)),
      );
    }
    if (value is Iterable) {
      return value.map(_encodeCacheValue).toList(growable: false);
    }
    return value;
  }

  static dynamic _decodeCacheValue(dynamic value) {
    if (value is Map) {
      final type = value['__cacheType'];
      if (type == 'timestamp') {
        final millis = value['millis'];
        if (millis is int) {
          return Timestamp.fromMillisecondsSinceEpoch(millis);
        }
      }
      if (type == 'datetime') {
        final millis = value['millis'];
        if (millis is int) {
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      return value.map<String, dynamic>(
        (key, child) => MapEntry(key.toString(), _decodeCacheValue(child)),
      );
    }
    if (value is List) {
      return value.map(_decodeCacheValue).toList(growable: false);
    }
    return value;
  }

  static List<Map<String, dynamic>> _decodeListOfMaps(dynamic value) {
    final decoded = _decodeCacheValue(value);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Map<String, String> _decodeStringMap(dynamic value) {
    final decoded = _decodeCacheValue(value);
    if (decoded is! Map) return <String, String>{};
    return decoded.map<String, String>(
      (key, child) => MapEntry(key.toString(), child?.toString() ?? ''),
    );
  }

  static Map<String, Map<String, dynamic>> _decodeCards(dynamic value) {
    final decoded = _decodeCacheValue(value);
    if (decoded is! Map) return <String, Map<String, dynamic>>{};
    return decoded.map<String, Map<String, dynamic>>((key, child) {
      if (child is Map) {
        return MapEntry(key.toString(), Map<String, dynamic>.from(child));
      }
      return MapEntry(key.toString(), <String, dynamic>{});
    });
  }
}

class _CacheEntry<T> {
  T? data;
  DateTime? fetchedAt;
  Future<T>? inFlight;
}

class _GiftcardReferenceData {
  final Map<String, Map<String, dynamic>> cards;
  final Map<String, String> giftcardNames;
  final Map<String, String> branchNames;
  final Map<String, String> whereToBuyNames;

  const _GiftcardReferenceData({
    required this.cards,
    required this.giftcardNames,
    required this.branchNames,
    required this.whereToBuyNames,
  });
}
