import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/giftcard_info_data.dart';
import '../model/giftcard_period.dart';
import 'firestore_page_loader.dart';

class GiftcardService {
  static const Duration _infoTtl = Duration(minutes: 2);
  static const Duration _referenceTtl = Duration(minutes: 10);
  static const int _pageSize = 200;

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
    return _cached(
      entry: entry,
      ttl: _infoTtl,
      force: forceRefresh,
      copy: (data) => data.copy(),
      loader: () => _fetchInfoData(
        uid: uid,
        periodType: periodType,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
        forceReferenceRefresh: forceRefresh,
      ),
    );
  }

  static void invalidateUser(String uid) {
    _infoCache.removeWhere((key, _) => key.startsWith('$uid|'));
    _cardsCache.remove(uid);
    _whereToBuyCache.remove(uid);
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
        // Firestore whereIn 은 최대 10개까지만 지원하므로 10개 단위로 나누어 조회
        for (int i = 0; i < lotIds.length; i += 10) {
          final int endIndex =
              (i + 10 < lotIds.length) ? i + 10 : lotIds.length;
          final List<String> chunk = lotIds.sublist(i, endIndex);
          final docs = await FirestorePageLoader.load(
            query: salesRef.where('lotId', whereIn: chunk),
            pageSize: _pageSize,
          );
          for (final d in docs) {
            saleById[d.id] = d;
          }
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
