import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'user_service.dart';

class DealNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'deal_subscriptions';

  /// 특가 알림 구독 저장
  static Future<String> saveDealSubscription({
    required String uid,
    required String? originAirport,
    required List<String> airports,
    required List<String> countries,
    required String region,
    required int maxPrice,
    required int days,
    required int peanutUsed,
  }) async {
    try {
      final subscriptionId = const Uuid().v4();
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: days)),
      );

      final subscriptionData = {
        'region': region,
        'countries': countries,
        'airports': airports,
        'maxPrice': maxPrice,
        'originAirport': originAirport,
        'expiresAt': expiresAt,
        'createdAt': now,
        'peanutUsed': peanutUsed,
        'autoRenew': false,
        'notifiedDeals': [],
        'isActive': true,
      };

      await _firestore
          .collection(_collection)
          .doc(uid)
          .collection('items')
          .doc(subscriptionId)
          .set(subscriptionData);

      // 땅콩 차감
      final userData = await UserService.getUserFromFirestoreWithLimit(uid);
      final currentPeanutCount = userData?['peanutCount'] ?? 0;
      final newPeanutCount = currentPeanutCount - peanutUsed;
      await UserService.updatePeanutCount(uid, newPeanutCount);

      return subscriptionId;
    } catch (e) {
      print('특가 알림 구독 저장 오류: $e');
      rethrow;
    }
  }

  /// 특가 알림 구독 삭제
  static Future<void> deleteDealSubscription(String uid, String subscriptionId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(uid)
          .collection('items')
          .doc(subscriptionId)
          .delete();
    } catch (e) {
      print('특가 알림 구독 삭제 오류: $e');
      rethrow;
    }
  }

  /// 특가 알림 구독 연장
  static Future<void> extendDealSubscription({
    required String uid,
    required String subscriptionId,
    required int days,
    required int peanutUsed,
  }) async {
    try {
      final subscriptionRef = _firestore
          .collection(_collection)
          .doc(uid)
          .collection('items')
          .doc(subscriptionId);

      final subscriptionDoc = await subscriptionRef.get();
      if (!subscriptionDoc.exists) {
        throw Exception('구독을 찾을 수 없습니다.');
      }

      final data = subscriptionDoc.data()!;
      final currentExpiresAt = (data['expiresAt'] as Timestamp).toDate();
      final newExpiresAt = currentExpiresAt.add(Duration(days: days));

      await subscriptionRef.update({
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'peanutUsed': FieldValue.increment(peanutUsed),
      });

      // 땅콩 차감
      final userData = await UserService.getUserFromFirestoreWithLimit(uid);
      final currentPeanutCount = userData?['peanutCount'] ?? 0;
      final newPeanutCount = currentPeanutCount - peanutUsed;
      await UserService.updatePeanutCount(uid, newPeanutCount);
    } catch (e) {
      print('특가 알림 구독 연장 오류: $e');
      rethrow;
    }
  }

  /// 특가 알림 구독 목록 가져오기
  static Stream<QuerySnapshot> getDealSubscriptionsStream(String uid) {
    return _firestore
        .collection(_collection)
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// 땅콩 계산
  static int calculatePeanuts({
    required int airportCount,
    required int days,
    bool hasOriginAirport = false,
  }) {
    int peanuts = 0;

    // 1. 선택한 도시 개수에 따른 땅콩
    if (airportCount <= 3) {
      peanuts += 2;
    } else if (airportCount <= 5) {
      peanuts += 3;
    } else {
      peanuts += 5;
    }

    // 2. 알림 기간에 따른 땅콩
    if (days == 7) {
      peanuts += 2;
    } else if (days == 14) {
      peanuts += 3;
    } else {
      peanuts += 5;
    }

    // 3. 출발지 선택 시 추가 땅콩
    if (hasOriginAirport) {
      peanuts += 1;
    }

    return peanuts;
  }

  /// 공항 코드로 지역 찾기
  static String? getRegionByAirport(String airportCode, Map<String, List<Map<String, dynamic>>> citiesByRegion) {
    for (final entry in citiesByRegion.entries) {
      for (final city in entry.value) {
        if (city['airport'] == airportCode) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 선택된 공항들로 대표 지역 찾기 (가장 많은 공항이 있는 지역)
  static String getMainRegion(List<String> airports, Map<String, List<Map<String, dynamic>>> citiesByRegion) {
    final regionCounts = <String, int>{};
    
    for (final airport in airports) {
      final region = getRegionByAirport(airport, citiesByRegion);
      if (region != null) {
        regionCounts[region] = (regionCounts[region] ?? 0) + 1;
      }
    }

    if (regionCounts.isEmpty) {
      return '기타';
    }

    // 가장 많은 공항이 있는 지역 반환
    return regionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

