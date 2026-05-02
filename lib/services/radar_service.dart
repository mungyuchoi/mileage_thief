import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/deal_model.dart';
import '../models/radar_item_model.dart';

class RadarService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final NumberFormat _wonFormat = NumberFormat('#,###');

  static Future<RadarTravelProfile> getTravelProfile() async {
    final user = _auth.currentUser;
    if (user == null) return RadarTravelProfile.defaults();

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('travel_profile')
        .doc('default')
        .get();
    return RadarTravelProfile.fromMap(doc.data());
  }

  static Future<void> saveTravelProfile(RadarTravelProfile profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('travel_profile')
        .doc('default')
        .set({
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<RadarItem>> loadRadarItems({
    RadarTravelProfile? profile,
    int limit = 12,
  }) async {
    final resolvedProfile = profile ?? await getTravelProfile();
    final averageCost = await loadAverageCostPerMile();

    final groups = await Future.wait<List<RadarItem>>([
      _safeItems(() => _loadServerRadarItems(limit: limit)),
      _safeItems(() => _loadFlightDealItems(resolvedProfile)),
      if (resolvedProfile.giftcardEnabled)
        _safeItems(_loadGiftcardItems)
      else
        Future.value(const <RadarItem>[]),
      _safeItems(_loadPopularCancellationItems),
      _safeItems(_loadNewsItems),
    ]);

    final items = <RadarItem>[
      _buildValueCalculatorItem(resolvedProfile, averageCost),
      for (final group in groups) ...group,
    ];

    final seen = <String>{};
    final deduped = <RadarItem>[];
    for (final item in items) {
      final key = '${item.itemType}:${item.id}';
      if (seen.add(key)) deduped.add(item);
    }

    deduped.sort((a, b) => b.score.compareTo(a.score));
    return deduped.take(limit).toList();
  }

  static Future<double?> loadAverageCostPerMile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sales')
          .orderBy('sellDate', descending: true)
          .limit(80)
          .get();
      final values = snap.docs
          .map((doc) => (doc.data()['costPerMile'] as num?)?.toDouble())
          .whereType<double>()
          .where((value) => value > 0)
          .toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRadarSubscription(RadarItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final id =
        '${_sanitizeId(item.itemType)}_${_sanitizeId(item.id)}_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('radar_subscriptions')
        .doc(id)
        .set({
      'type': item.itemType,
      'conditions': {
        'title': item.title,
        'route': item.route,
        'dateRange': item.dateRange,
        'price': item.price,
        'miles': item.miles,
        'source': item.source,
        'payload': item.payload,
      },
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'isActive': true,
      'pushEnabled': true,
      'peanutUsed': 0,
      'lastMatchedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchRadarSubscriptions(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('radar_subscriptions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchRadarNotifications(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('radar_notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  static Future<void> deleteRadarSubscription(String subscriptionId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('radar_subscriptions')
        .doc(subscriptionId)
        .delete();
  }

  static Future<void> updateRadarSubscriptionPush({
    required String subscriptionId,
    required bool pushEnabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('radar_subscriptions')
        .doc(subscriptionId)
        .set({
      'pushEnabled': pushEnabled,
      'isActive': pushEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> extendRadarSubscription({
    required String subscriptionId,
    int days = 30,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('radar_subscriptions')
        .doc(subscriptionId);
    final doc = await ref.get();
    final data = doc.data();
    final currentExpiresAt = (data?['expiresAt'] as Timestamp?)?.toDate();
    final base =
        currentExpiresAt != null && currentExpiresAt.isAfter(DateTime.now())
            ? currentExpiresAt
            : DateTime.now();
    await ref.set({
      'expiresAt': Timestamp.fromDate(base.add(Duration(days: days))),
      'isActive': true,
      'pushEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markRadarNotificationRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('radar_notifications')
        .doc(notificationId)
        .set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<RadarItem>> _safeItems(
    Future<List<RadarItem>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const <RadarItem>[];
    }
  }

  static Future<List<RadarItem>> _loadServerRadarItems({
    required int limit,
  }) async {
    final snap = await _firestore
        .collection('radar_items')
        .orderBy('score', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map(RadarItem.fromFirestore)
        .where((item) => item.itemType != RadarItemType.hotelDeal)
        .toList();
  }

  static Future<List<RadarItem>> _loadFlightDealItems(
    RadarTravelProfile profile,
  ) async {
    final snap =
        await _firestore.collection('deals').orderBy('price').limit(14).get();
    final homeAirports = profile.homeAirports.map((e) => e.toUpperCase());

    final items = <RadarItem>[];
    for (final doc in snap.docs) {
      final deal = DealModel.fromFirestore(doc);
      if (deal.price <= 0) continue;
      if (profile.maxCashBudget != null &&
          deal.price > profile.maxCashBudget!) {
        continue;
      }

      final startsFromHome = homeAirports.contains(deal.originAirport);
      final score = 70.0 +
          (startsFromHome ? 8 : 0) +
          (deal.discountPercent ?? 0).clamp(0, 12) +
          (deal.isDirect ? 3 : 0);
      items.add(
        RadarItem(
          id: 'flight_${deal.dealId}',
          itemType: RadarItemType.flightDeal,
          title:
              '${deal.originAirport}-${deal.destAirport} ${deal.priceDisplay.isNotEmpty ? deal.priceDisplay : '${_wonFormat.format(deal.price)}원'}',
          subtitle: [
            if (deal.destCity.isNotEmpty) deal.destCity,
            if (deal.airlineName.isNotEmpty) deal.airlineName,
            if (deal.travelDays > 0) '${deal.travelDays}일 여정',
          ].join(' · '),
          reason: startsFromHome
              ? '선호 출발 공항에서 바로 볼 수 있는 항공권 특가입니다.'
              : '가격순 상위 특가라 유연 여행자에게 먼저 보여줍니다.',
          source: deal.agency.isNotEmpty ? deal.agency : '항공권 특가',
          route: '${deal.originAirport}-${deal.destAirport}',
          dateRange: _dealDateRange(deal),
          price: deal.price,
          miles: null,
          cashValue: deal.price,
          costPerMile: null,
          urgency: _flightUrgency(deal),
          score: score,
          deepLink: deal.bookingUrl,
          updatedAt: deal.lastUpdated?.toDate() ?? DateTime.now(),
          payload: {
            'dealId': deal.dealId,
            'originAirport': deal.originAirport,
            'destAirport': deal.destAirport,
            'bookingUrl': deal.bookingUrl,
          },
        ),
      );
    }
    return items;
  }

  static Future<List<RadarItem>> _loadGiftcardItems() async {
    final snap = await _firestore
        .collection('giftcards')
        .orderBy('bestSellPrice', descending: true)
        .limit(4)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      final name = (data['name'] as String?) ?? doc.id;
      final bestSellPrice = (data['bestSellPrice'] as num?)?.toInt();
      final branch = (data['bestSellBranchName'] as String?) ??
          (data['bestSellBranchId'] as String?) ??
          '시세표';
      return RadarItem(
        id: 'giftcard_${doc.id}',
        itemType: RadarItemType.giftcard,
        title: '$name 매입가 체크',
        subtitle: bestSellPrice == null
            ? '상품권 시세 갱신 대기'
            : '최고 ${_wonFormat.format(bestSellPrice)}원 · $branch',
        reason: '상품권 원가를 낮춰 마일리지 발권 기준 원가에 바로 반영할 수 있습니다.',
        source: branch,
        route: '',
        dateRange: '',
        price: bestSellPrice,
        miles: null,
        cashValue: null,
        costPerMile: null,
        urgency: '시세 변동',
        score: bestSellPrice == null ? 58 : 68,
        deepLink: '',
        updatedAt: DateTime.now(),
        payload: {
          'giftcardId': doc.id,
          'giftcardName': name,
        },
      );
    }).toList();
  }

  static Future<List<RadarItem>> _loadPopularCancellationItems() async {
    final snap = await _firestore
        .collection('popular_subscriptions')
        .orderBy('count', descending: true)
        .limit(4)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      final parsed = _parseRouteKey(doc.id);
      final count = (data['count'] as num?)?.toInt() ?? 0;
      final route = parsed.route.isEmpty ? doc.id : parsed.route;
      return RadarItem(
        id: 'cancel_${doc.id}',
        itemType: RadarItemType.cancelAlert,
        title: '$route 취소표 관심 급상승',
        subtitle: parsed.cabins.isEmpty ? '$count명 구독 중' : parsed.cabins,
        reason: '커뮤니티에서 많이 등록한 구간입니다. 내 일정과 맞으면 알림을 먼저 걸어두세요.',
        source: '취소표 알림',
        route: route,
        dateRange: '',
        price: null,
        miles: null,
        cashValue: null,
        costPerMile: null,
        urgency: count >= 10 ? '높음' : '관심 증가',
        score: 65 + count.clamp(0, 20).toDouble(),
        deepLink: '',
        updatedAt:
            (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
        payload: {
          'routeKey': doc.id,
          'count': count,
        },
      );
    }).toList();
  }

  static Future<List<RadarItem>> _loadNewsItems() async {
    final snap = await _firestore
        .collectionGroup('posts')
        .where('boardId', whereIn: [
          'deal',
          'news',
          'seats',
          'seat_share',
          'aeroroute_news',
          'secretflying_news',
        ])
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      final boardId = (data['boardId'] as String?) ?? 'news';
      final title = (data['title'] as String?) ?? '커뮤니티 소식';
      final dateString = doc.reference.parent.parent?.id ?? '';
      return RadarItem(
        id: 'post_${doc.id}',
        itemType: RadarItemType.benefitNews,
        title: title,
        subtitle: _plainText(data['contentHtml'] as String? ?? ''),
        reason: '${_boardLabel(boardId)} 게시판에서 방금 확인된 정보입니다.',
        source: _boardLabel(boardId),
        route: '',
        dateRange: '',
        price: null,
        miles: null,
        cashValue: null,
        costPerMile: null,
        urgency: '새 글',
        score: boardId == 'seats' || boardId == 'seat_share' ? 74 : 63,
        deepLink: '',
        updatedAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        payload: {
          'postId': (data['postId'] as String?) ?? doc.id,
          'boardId': boardId,
          'boardName': _boardLabel(boardId),
          'dateString': dateString,
        },
      );
    }).toList();
  }

  static RadarItem _buildValueCalculatorItem(
    RadarTravelProfile profile,
    double? averageCost,
  ) {
    final totalMiles = profile.mileageBalances.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    return RadarItem(
      id: 'value_calculator',
      itemType: RadarItemType.valueCalculator,
      title: '발권 가치 계산기',
      subtitle: totalMiles > 0
          ? '보유 ${_wonFormat.format(totalMiles)}마일 기준'
          : '현금가와 마일리지 발권 비교',
      reason: averageCost == null
          ? '필요 마일, 세금, 현금가를 넣어 원/마일 가치를 계산합니다.'
          : '내 상품권 평균 원가 ${averageCost.toStringAsFixed(1)}원/마일로 손익을 비교합니다.',
      source: '마일캐치',
      route: '',
      dateRange: '',
      price: null,
      miles: totalMiles > 0 ? totalMiles : null,
      cashValue: null,
      costPerMile: averageCost,
      urgency: '바로 계산',
      score: 92,
      deepLink: '',
      updatedAt: DateTime.now(),
      payload: {'averageCostPerMile': averageCost},
    );
  }

  static String _dealDateRange(DealModel deal) {
    if (deal.availableDates.isNotEmpty) {
      final date = deal.availableDates.first;
      final departure = date.departureDate ?? date.departure;
      final arrival = date.returnDateStr ?? date.returnDate;
      if (departure.isNotEmpty && arrival.isNotEmpty) {
        return '$departure~$arrival';
      }
      if (departure.isNotEmpty) return departure;
    }
    if (deal.dateRanges.isNotEmpty) {
      final range = deal.dateRanges.first;
      if (range.start.isNotEmpty && range.end.isNotEmpty) {
        return '${range.start}~${range.end}';
      }
    }
    final start = _formatSupplyDate(deal.supplyStartDate);
    final end = _formatSupplyDate(deal.supplyEndDate);
    if (start.isNotEmpty && end.isNotEmpty) return '$start~$end';
    return start;
  }

  static String _formatSupplyDate(String value) {
    if (value.length != 8) return value;
    return '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}';
  }

  static String _flightUrgency(DealModel deal) {
    final discount = deal.discountPercent;
    if (discount != null && discount >= 10) {
      return '${discount.toStringAsFixed(0)}% 하락';
    }
    if (deal.isDirect) return '직항';
    return '가격순 상위';
  }

  static ({String route, String cabins}) _parseRouteKey(String routeKey) {
    final parts = routeKey.split('_');
    if (parts.length != 2) return (route: '', cabins: '');
    final classes = parts[1].split('').map((cls) {
      switch (cls) {
        case 'E':
          return '이코노미';
        case 'B':
          return '비즈니스';
        case 'F':
          return '퍼스트';
        default:
          return cls;
      }
    }).join('/');
    return (route: parts[0], cabins: classes);
  }

  static String _boardLabel(String boardId) {
    const labels = {
      'deal': '적립/카드 혜택',
      'news': '오늘의 뉴스',
      'seats': '오늘의 좌석',
      'seat_share': '좌석 공유',
      'aeroroute_news': 'AeroRoutes',
      'secretflying_news': 'SecretFlying',
    };
    return labels[boardId] ?? boardId;
  }

  static String _plainText(String html) {
    final text = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length <= 64) return text;
    return '${text.substring(0, 64)}...';
  }

  static String _sanitizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
