import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/giftcard_deal_model.dart';

class GiftcardDealService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _maxDealsLimit = 80;
  static const int _maxSourcesLimit = 120;
  static const Duration _cacheTtl = Duration(minutes: 3);
  static final Map<int, Stream<List<GiftcardDeal>>> _dealStreams = {};
  static final Map<int, List<GiftcardDeal>> _dealCache = {};
  static final Map<int, _CacheEntry<List<GiftcardDeal>>> _topDealsCache = {};
  static final _CacheEntry<List<GiftcardDealSource>> _sourcesCache =
      _CacheEntry<List<GiftcardDealSource>>();

  static List<GiftcardDeal>? peekDeals({int limit = _maxDealsLimit}) {
    final deals = _cachedDealsForLimit(_effectiveDealsLimit(limit));
    if (deals == null) return null;
    return List<GiftcardDeal>.unmodifiable(deals);
  }

  static Stream<List<GiftcardDeal>> watchDeals({int limit = _maxDealsLimit}) {
    final effectiveLimit = _effectiveDealsLimit(limit);
    return _dealStreams.putIfAbsent(
      effectiveLimit,
      () => _firestore
          .collection('giftcardDeals')
          .orderBy('discountRate', descending: true)
          .limit(effectiveLimit)
          .snapshots()
          .map((snapshot) {
        final deals = snapshot.docs
            .map(GiftcardDeal.fromDoc)
            .where((deal) => deal.status != 'disabled')
            .toList(growable: false);
        _dealCache[effectiveLimit] = deals;
        return deals;
      }).asBroadcastStream(),
    );
  }

  static Stream<GiftcardDeal?> watchDeal(String dealId) {
    return _firestore
        .collection('giftcardDeals')
        .doc(dealId)
        .snapshots()
        .map((doc) => doc.exists ? GiftcardDeal.fromDoc(doc) : null);
  }

  static Future<GiftcardDeal?> loadDeal(String dealId) async {
    final doc = await _firestore.collection('giftcardDeals').doc(dealId).get();
    return doc.exists ? GiftcardDeal.fromDoc(doc) : null;
  }

  static Future<List<GiftcardDeal>> loadTopDeals({
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    final effectiveLimit = _effectiveDealsLimit(limit);
    final cachedDeals = _cachedDealsForLimit(effectiveLimit);
    if (!forceRefresh && cachedDeals != null) {
      return cachedDeals.take(effectiveLimit).toList(growable: false);
    }

    final entry = _topDealsCache.putIfAbsent(
      effectiveLimit,
      () => _CacheEntry<List<GiftcardDeal>>(),
    );
    return _cached(
      entry: entry,
      force: forceRefresh,
      copy: (data) => List<GiftcardDeal>.unmodifiable(data),
      loader: () async {
        final snapshot = await _firestore
            .collection('giftcardDeals')
            .orderBy('discountRate', descending: true)
            .limit(effectiveLimit)
            .get();
        final deals = snapshot.docs
            .map(GiftcardDeal.fromDoc)
            .where((deal) => deal.status != 'disabled')
            .toList(growable: false);
        _dealCache[effectiveLimit] = deals;
        return deals;
      },
    );
  }

  static Stream<List<Map<String, dynamic>>> watchPriceHistory(
    String dealId, {
    int limit = 30,
  }) {
    return _firestore
        .collection('giftcardDeals')
        .doc(dealId)
        .collection('priceHistory')
        .orderBy('crawledAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  static Stream<List<GiftcardDealSource>> watchSources() {
    return _firestore
        .collection('giftcardDealSources')
        .orderBy('updatedAt', descending: true)
        .limit(_maxSourcesLimit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(GiftcardDealSource.fromDoc).toList());
  }

  static Future<List<GiftcardDealSource>> loadSources({
    int limit = _maxSourcesLimit,
    bool forceRefresh = false,
  }) {
    final effectiveLimit = limit.clamp(1, _maxSourcesLimit).toInt();
    return _cached(
      entry: _sourcesCache,
      force: forceRefresh,
      copy: (data) => List<GiftcardDealSource>.unmodifiable(data),
      loader: () async {
        final snapshot = await _firestore
            .collection('giftcardDealSources')
            .orderBy('updatedAt', descending: true)
            .limit(effectiveLimit)
            .get();
        return snapshot.docs
            .map(GiftcardDealSource.fromDoc)
            .toList(growable: false);
      },
    );
  }

  static Stream<GiftcardDealSource?> watchSource(String sourceId) {
    return _firestore
        .collection('giftcardDealSources')
        .doc(sourceId)
        .snapshots()
        .map((doc) => doc.exists ? GiftcardDealSource.fromDoc(doc) : null);
  }

  static Stream<List<GiftcardDealSourceRequest>> watchSourceRequests({
    String status = 'pending',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('giftcardDealSourceRequests');
    if (status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }
    return query.limit(100).snapshots().map((snapshot) {
      final requests =
          snapshot.docs.map(GiftcardDealSourceRequest.fromDoc).toList();
      requests.sort((a, b) {
        final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMillis.compareTo(aMillis);
      });
      return requests;
    });
  }

  static Stream<List<GiftcardDealAlert>> watchAlerts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream<List<GiftcardDealAlert>>.empty();
    }
    return watchAlertsForUser(currentUser.uid);
  }

  static Stream<List<GiftcardDealAlert>> watchAlertsForUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('giftcardDealAlerts')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(GiftcardDealAlert.fromDoc).toList());
  }

  static Future<String> saveSource({
    String? existingId,
    required String url,
    required String merchantName,
    required String brandName,
    required int denominationKRW,
    required int faceValueKRW,
    required String displayName,
    required bool enabled,
    required String memo,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('URL을 입력해주세요.');
    }
    final normalizedMerchant = _slug(merchantName);
    final normalizedBrand = _slug(brandName);
    if (normalizedMerchant.isEmpty || normalizedBrand.isEmpty) {
      throw ArgumentError('상점과 브랜드를 입력해주세요.');
    }
    final amount = faceValueKRW > 0 ? faceValueKRW : denominationKRW;
    if (amount <= 0) {
      throw ArgumentError('액면가를 입력해주세요.');
    }

    String dealId = existingId?.trim() ?? '';
    final duplicate = await _firestore
        .collection('giftcardDealSources')
        .where('normalizedUrl', isEqualTo: normalizedUrl)
        .limit(1)
        .get();
    if (duplicate.docs.isNotEmpty) {
      dealId = duplicate.docs.first.id;
    } else if (dealId.isEmpty) {
      dealId = buildDealId(
        merchantName: merchantName,
        brandName: brandName,
        denominationKRW: amount,
        normalizedUrl: normalizedUrl,
      );
    }

    final ref = _firestore.collection('giftcardDealSources').doc(dealId);
    final existing = await ref.get();
    await ref.set({
      'url': url.trim(),
      'normalizedUrl': normalizedUrl,
      'merchantId': normalizedMerchant,
      'merchantName': merchantName.trim(),
      'brandId': normalizedBrand,
      'brandName': brandName.trim(),
      'denominationKRW': amount,
      'faceValueKRW': amount,
      'displayName': displayName.trim(),
      'enabled': enabled,
      'memo': memo.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': currentUser.uid,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdByUid': currentUser.uid,
    }, SetOptions(merge: true));

    return dealId;
  }

  static Future<String> createSourceRequest({
    required String url,
    required String merchantName,
    required String brandName,
    required int denominationKRW,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final submittedUrl = _coerceUrl(url);
    final normalizedUrl = normalizeUrl(submittedUrl);
    if (!_isValidUrl(normalizedUrl)) {
      throw ArgumentError('올바른 URL을 입력해주세요.');
    }

    final duplicateSource = await _firestore
        .collection('giftcardDealSources')
        .where('normalizedUrl', isEqualTo: normalizedUrl)
        .limit(1)
        .get();
    if (duplicateSource.docs.isNotEmpty) {
      throw StateError('이미 등록된 URL입니다.');
    }

    final duplicateRequest = await _firestore
        .collection('giftcardDealSourceRequests')
        .where('normalizedUrl', isEqualTo: normalizedUrl)
        .limit(10)
        .get();
    final hasPending = duplicateRequest.docs.any((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim();
      return status.isEmpty || status == 'pending';
    });
    if (hasPending) {
      throw StateError('이미 요청된 URL입니다.');
    }

    final merchant = merchantName.trim();
    final brand = brandName.trim();
    final amount = denominationKRW > 0 ? denominationKRW : 0;
    final requestRef =
        _firestore.collection('giftcardDealSourceRequests').doc();
    await requestRef.set({
      'url': submittedUrl,
      'normalizedUrl': normalizedUrl,
      'merchantId': merchant.isEmpty ? '' : _slug(merchant),
      'merchantName': merchant,
      'brandId': brand.isEmpty ? '' : _slug(brand),
      'brandName': brand,
      'denominationKRW': amount,
      'faceValueKRW': amount,
      'status': 'pending',
      'requesterUid': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return requestRef.id;
  }

  static Future<String> approveSourceRequest({
    required String requestId,
    required String url,
    required String merchantName,
    required String brandName,
    required int denominationKRW,
    required int faceValueKRW,
    String displayName = '',
    String memo = '',
    String reviewNote = '',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final trimmedRequestId = requestId.trim();
    if (trimmedRequestId.isEmpty) {
      throw ArgumentError('요청 정보가 없습니다.');
    }

    final requestRef = _firestore
        .collection('giftcardDealSourceRequests')
        .doc(trimmedRequestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw StateError('URL 요청을 찾을 수 없습니다.');
    }

    final sourceId = await saveSource(
      url: _coerceUrl(url),
      merchantName: merchantName,
      brandName: brandName,
      denominationKRW: denominationKRW,
      faceValueKRW: faceValueKRW,
      displayName: displayName,
      enabled: true,
      memo: memo,
    );

    await requestRef.set({
      'status': 'approved',
      'sourceId': sourceId,
      'reviewNote': reviewNote.trim(),
      'reviewedByUid': currentUser.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return sourceId;
  }

  static Future<void> rejectSourceRequest(
    String requestId, {
    String note = '',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final trimmedRequestId = requestId.trim();
    if (trimmedRequestId.isEmpty) {
      throw ArgumentError('요청 정보가 없습니다.');
    }

    await _firestore
        .collection('giftcardDealSourceRequests')
        .doc(trimmedRequestId)
        .set({
      'status': 'rejected',
      'reviewNote': note.trim(),
      'reviewedByUid': currentUser.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveAlert({
    required GiftcardDeal deal,
    required double minDiscountRate,
    required int maxPriceKRW,
  }) async {
    await saveCustomAlert(
      alertId: deal.id,
      name: '${deal.displayTitle} 알림',
      scopeType: 'deal',
      dealIds: [deal.id],
      brandIds: deal.brandId.isEmpty ? const <String>[] : [deal.brandId],
      merchantIds:
          deal.merchantId.isEmpty ? const <String>[] : [deal.merchantId],
      denominationsKRW: deal.faceValueKRW > 0
          ? [deal.faceValueKRW]
          : deal.denominationKRW > 0
              ? [deal.denominationKRW]
              : const <int>[],
      minDiscountRate: minDiscountRate,
      maxPriceKRW: maxPriceKRW,
      dealTitle: deal.displayTitle,
      merchantName: deal.merchantName,
      brandName: deal.brandName,
    );
  }

  static Future<void> saveCustomAlert({
    String? alertId,
    required String name,
    required String scopeType,
    required List<String> dealIds,
    required List<String> brandIds,
    required List<String> merchantIds,
    required List<int> denominationsKRW,
    required double minDiscountRate,
    required int maxPriceKRW,
    bool enabled = true,
    String? dealTitle,
    String? merchantName,
    String? brandName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final alerts = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('giftcardDealAlerts');
    final docRef = alertId == null || alertId.trim().isEmpty
        ? alerts.doc()
        : alerts.doc(alertId);
    final existing = await docRef.get();
    await docRef.set({
      'name': name.trim().isEmpty ? '상품권 맞춤 알림' : name.trim(),
      'scopeType': scopeType.trim().isEmpty ? 'custom' : scopeType.trim(),
      'dealIds': _cleanStringList(dealIds),
      'brandIds': _cleanStringList(brandIds),
      'merchantIds': _cleanStringList(merchantIds),
      'denominationsKRW': _cleanIntList(denominationsKRW),
      'minDiscountRate': minDiscountRate,
      'maxPriceKRW': maxPriceKRW,
      'enabled': enabled,
      'notifyMode': 'improved_only',
      if (dealTitle != null) 'dealTitle': dealTitle.trim(),
      if (merchantName != null) 'merchantName': merchantName.trim(),
      if (brandName != null) 'brandName': brandName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setAlertEnabled(String alertId, bool enabled) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('giftcardDealAlerts')
        .doc(alertId)
        .set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteAlert(String alertId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('giftcardDealAlerts')
        .doc(alertId)
        .delete();
  }

  static String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed;
    final ignoredPrefixes = ['utm_'];
    const ignoredKeys = {
      'fbclid',
      'gclid',
      'igshid',
      'NaPm',
      'n_media',
      'n_query',
      'n_rank',
      'n_ad_group',
      'n_ad',
    };
    final entries = uri.queryParameters.entries
        .where((entry) =>
            !ignoredKeys.contains(entry.key) &&
            !ignoredPrefixes.any((prefix) => entry.key.startsWith(prefix)))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final normalized = uri.replace(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      fragment: '',
      queryParameters: entries.isEmpty
          ? null
          : {
              for (final entry in entries) entry.key: entry.value,
            },
    );
    return normalized.toString();
  }

  static String _coerceUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;
    return 'https://$trimmed';
  }

  static bool _isValidUrl(String input) {
    final uri = Uri.tryParse(input);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String buildDealId({
    required String merchantName,
    required String brandName,
    required int denominationKRW,
    required String normalizedUrl,
  }) {
    final digest =
        sha1.convert(utf8.encode(normalizedUrl)).toString().substring(0, 10);
    return '${_slug(merchantName)}_${_slug(brandName)}_${denominationKRW}_$digest';
  }

  static String _slug(String input) {
    final text = input.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isAsciiLetter = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      if (isAsciiLetter || isDigit) {
        buffer.write(char);
      } else if (rune >= 0xAC00 && rune <= 0xD7A3) {
        buffer.write(char);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('_')) {
        buffer.write('_');
      }
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static List<String> _cleanStringList(List<String> values) {
    final seen = <String>{};
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList();
  }

  static List<int> _cleanIntList(List<int> values) {
    final seen = <int>{};
    return values.where((value) => value > 0 && seen.add(value)).toList();
  }

  static int _effectiveDealsLimit(int limit) {
    return limit.clamp(1, _maxDealsLimit).toInt();
  }

  static List<GiftcardDeal>? _cachedDealsForLimit(int limit) {
    final candidates = _dealCache.entries
        .where((entry) => entry.key >= limit)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (candidates.isEmpty) return null;
    return candidates.first.value.take(limit).toList(growable: false);
  }

  static Future<T> _cached<T>({
    required _CacheEntry<T> entry,
    required Future<T> Function() loader,
    required T Function(T data) copy,
    bool force = false,
  }) async {
    final cachedData = entry.data;
    final fetchedAt = entry.fetchedAt;
    final isFresh =
        fetchedAt != null && DateTime.now().difference(fetchedAt) < _cacheTtl;
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
}

class _CacheEntry<T> {
  T? data;
  DateTime? fetchedAt;
  Future<T>? inFlight;
}
