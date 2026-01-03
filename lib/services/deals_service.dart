import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deal_model.dart';

class DealsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// deals 컬렉션에서 특가 항공권 조회
  static Stream<List<DealModel>> getDealsStream({
    String? originAirport,
    List<String>? destAirports,
    List<int>? selectedMonths,
    List<int>? travelDurations,
    String? sortBy, // 'price', 'price_change', 'price_asc'
    int limit = 50, // 초기 로딩 속도 개선을 위해 limit 감소
    bool loadPriceHistory = true, // 가격 이력 로드 여부 (초기 로딩 시 false로 설정 가능)
  }) {
    Query query = _firestore.collection('deals');

    // 출발 공항 필터
    if (originAirport != null && originAirport.isNotEmpty) {
      query = query.where('origin_airport', isEqualTo: originAirport);
    }

    // 기본 정렬 (필터링 전)
    query = query.orderBy('price', descending: false).limit(limit);

    return query.snapshots().asyncMap((snapshot) async {
      List<DealModel> deals = [];

      // 먼저 모든 deal 파싱 (빠른 필터링을 위해)
      for (var doc in snapshot.docs) {
        try {
          final deal = DealModel.fromFirestore(doc);

          // 도착 공항 필터링
          if (destAirports != null && destAirports.isNotEmpty) {
            if (!destAirports.contains(deal.destAirport)) {
              continue;
            }
          }

          // 출발 월 필터링
          if (selectedMonths != null && selectedMonths.isNotEmpty) {
            final dealMonth = _extractMonthFromSupplyDate(deal.supplyStartDate);
            if (dealMonth == 0 || !selectedMonths.contains(dealMonth)) {
              continue;
            }
          }

          // 여행 기간 필터링
          if (travelDurations != null && travelDurations.isNotEmpty) {
            final days = deal.travelDays;
            if (days == 0 || !travelDurations.contains(days)) {
              continue;
            }
          }

          deals.add(deal);
        } catch (e) {
          print('Deal 파싱 오류: ${doc.id} - $e');
        }
      }

      // 가격 이력 조회를 병렬로 처리 (성능 개선)
      // 초기 로딩 속도 개선: 가격 이력은 선택적으로 로드
      if (deals.isNotEmpty && loadPriceHistory) {
        final priceHistoryMap = await _getPriceHistoriesBatch(
          deals.map((d) => d.dealId).toList(),
        );

        // 가격 변동 정보 적용
        for (var deal in deals) {
          final priceHistory = priceHistoryMap[deal.dealId];
          if (priceHistory != null) {
            final changePercent = priceHistory['price_change_percent'];
            final prevPrice = priceHistory['previous_price'];
            if (changePercent != null) {
              deal.priceChangePercent = (changePercent is double)
                  ? changePercent
                  : (changePercent as num).toDouble();
            }
            if (prevPrice != null) {
              deal.previousPrice = (prevPrice is int)
                  ? prevPrice
                  : (prevPrice as num).toInt();
            }
          }
        }
      }

      // 정렬
      if (sortBy == 'price') {
        deals.sort((a, b) => a.price.compareTo(b.price));
      } else if (sortBy == 'price_desc') {
        deals.sort((a, b) => b.price.compareTo(a.price));
      } else {
        // 기본: 가격 변동순 (할인율 큰 순서)
        deals.sort((a, b) {
          final aChange = a.priceChangePercent ?? 0;
          final bChange = b.priceChangePercent ?? 0;
          return bChange.compareTo(aChange); // 내림차순 (큰 할인율이 위로)
        });
      }

      return deals;
    });
  }

  /// 최신 가격 이력 조회 (단일)
  static Future<Map<String, dynamic>?> _getLatestPriceHistory(String dealId) async {
    try {
      final historyRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('price_history')
          .orderBy('recorded_at', descending: true)
          .limit(1);

      final snapshot = await historyRef.get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (e) {
      print('가격 이력 조회 오류: $e');
    }
    return null;
  }

  /// 여러 deal의 가격 이력을 병렬로 조회 (성능 개선)
  static Future<Map<String, Map<String, dynamic>>> _getPriceHistoriesBatch(
    List<String> dealIds,
  ) async {
    final Map<String, Map<String, dynamic>> result = {};

    if (dealIds.isEmpty) return result;

    // 병렬로 모든 가격 이력 조회
    final futures = dealIds.map((dealId) async {
      try {
        final historyRef = _firestore
            .collection('deals')
            .doc(dealId)
            .collection('price_history')
            .orderBy('recorded_at', descending: true)
            .limit(1);

        final snapshot = await historyRef.get();
        if (snapshot.docs.isNotEmpty) {
          return MapEntry(dealId, snapshot.docs.first.data());
        }
      } catch (e) {
        print('가격 이력 조회 오류 ($dealId): $e');
      }
      return null;
    });

    final results = await Future.wait(futures);
    for (var entry in results) {
      if (entry != null) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// 공급 시작일에서 월 추출 (1-12)
  static int _extractMonthFromSupplyDate(String supplyStartDate) {
    try {
      if (supplyStartDate.length >= 6) {
        final monthStr = supplyStartDate.substring(4, 6);
        return int.parse(monthStr);
      }
    } catch (e) {
      print('월 추출 오류: $e');
    }
    return 0;
  }

  /// 특정 딜 상세 정보 조회
  static Future<DealModel?> getDealById(String dealId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).get();
      if (doc.exists) {
        return DealModel.fromFirestore(doc);
      }
    } catch (e) {
      print('딜 조회 오류: $e');
    }
    return null;
  }

  /// 가격 이력 조회
  static Stream<List<Map<String, dynamic>>> getPriceHistory(String dealId, {int limit = 30}) {
    return _firestore
        .collection('deals')
        .doc(dealId)
        .collection('price_history')
        .orderBy('recorded_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}

