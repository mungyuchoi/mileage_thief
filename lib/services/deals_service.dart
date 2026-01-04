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
    List<String>? airlines,
    List<String>? agencies,
    String? sortBy, // 'price', 'price_change', 'price_desc'
    int limit = 50, // 초기 로딩 속도 개선을 위해 limit 감소
    bool loadPriceHistory = true, // 가격 이력 로드 여부 (초기 로딩 시 false로 설정 가능)
  }) {
    // 쿼리 파라미터 로깅
    print('=== DealsService.getDealsStream 쿼리 파라미터 ===');
    print('originAirport: $originAirport');
    print('destAirports: $destAirports');
    print('selectedMonths: $selectedMonths');
    print('travelDurations: $travelDurations');
    print('airlines: $airlines');
    print('agencies: $agencies');
    print('sortBy: $sortBy');
    print('limit: $limit');
    print('==========================================');

    Query query = _firestore.collection('deals');

    // 출발 공항 필터 (Firestore 쿼리 레벨)
    if (originAirport != null && originAirport.isNotEmpty) {
      query = query.where('origin_airport', isEqualTo: originAirport);
      print('[쿼리] origin_airport 필터 추가: $originAirport');
    }

    // 도착 공항 필터 (Firestore 쿼리 레벨로 이동)
    if (destAirports != null && destAirports.isNotEmpty) {
      if (destAirports.length == 1) {
        query = query.where('dest_airport', isEqualTo: destAirports.first);
        print('[쿼리] dest_airport 필터 추가 (단일): ${destAirports.first}');
      } else if (destAirports.length <= 10) {
        // Firestore whereIn은 최대 10개까지만 지원
        query = query.where('dest_airport', whereIn: destAirports);
        print('[쿼리] dest_airport 필터 추가 (whereIn): $destAirports');
      } else {
        // 10개 초과 시 처음 10개만 사용
        query = query.where('dest_airport', whereIn: destAirports.take(10).toList());
        print('[쿼리] dest_airport 필터 추가 (whereIn, 10개 제한): ${destAirports.take(10).toList()}');
      }
    }

    // 여행사 필터 (Firestore 쿼리 레벨에서 먼저 적용)
    if (agencies != null && agencies.isNotEmpty) {
      if (agencies.length == 1) {
        query = query.where('agency_code', isEqualTo: agencies.first);
        print('[쿼리] agency_code 필터 추가 (단일): ${agencies.first}');
      } else if (agencies.length <= 10) {
        // Firestore whereIn은 최대 10개까지만 지원
        query = query.where('agency_code', whereIn: agencies);
        print('[쿼리] agency_code 필터 추가 (whereIn): $agencies');
      } else {
        // 10개 초과 시 처음 10개만 사용
        query = query.where('agency_code', whereIn: agencies.take(10).toList());
        print('[쿼리] agency_code 필터 추가 (whereIn, 10개 제한): ${agencies.take(10).toList()}');
      }
    }

    // 항공사 필터 (Firestore 쿼리 레벨에서 먼저 적용)
    if (airlines != null && airlines.isNotEmpty) {
      if (airlines.length == 1) {
        query = query.where('airline_code', isEqualTo: airlines.first);
        print('[쿼리] airline_code 필터 추가 (단일): ${airlines.first}');
      } else if (airlines.length <= 10) {
        query = query.where('airline_code', whereIn: airlines);
        print('[쿼리] airline_code 필터 추가 (whereIn): $airlines');
      } else {
        query = query.where('airline_code', whereIn: airlines.take(10).toList());
        print('[쿼리] airline_code 필터 추가 (whereIn, 10개 제한): ${airlines.take(10).toList()}');
      }
    }

    // sortBy에 따라 정렬 방향 결정
    bool isDescending = (sortBy == 'price_desc');
    
    // 필터가 적용되면 더 많은 데이터를 가져와서 각 여행사/항공사의 최저가/최고가를 포함하도록 함
    // 여행사나 항공사 필터가 있으면 limit을 늘려서 각각의 최저가/최고가를 찾을 수 있게 함
    int effectiveLimit = limit;
    if (agencies != null && agencies.isNotEmpty) {
      // 여행사 필터가 있으면 각 여행사에서 최저가/최고가를 찾기 위해 limit 증가
      // 예: 여행사 2개면 최소 40개, 3개면 최소 60개 등
      effectiveLimit = (limit * agencies.length).clamp(limit, 200);
      print('[쿼리] 여행사 필터 적용으로 limit 증가: $limit -> $effectiveLimit (여행사 수: ${agencies.length})');
    }
    if (airlines != null && airlines.isNotEmpty) {
      // 항공사 필터가 있으면 각 항공사에서 최저가/최고가를 찾기 위해 limit 증가
      effectiveLimit = (effectiveLimit * airlines.length).clamp(effectiveLimit, 200);
      print('[쿼리] 항공사 필터 적용으로 limit 증가: $effectiveLimit (항공사 수: ${airlines.length})');
    }
    
    // sortBy에 따라 정렬 방향 적용
    query = query.orderBy('price', descending: isDescending).limit(effectiveLimit);
    print('[쿼리] Firestore 쿼리 실행: orderBy(price, ${isDescending ? "desc" : "asc"}), limit($effectiveLimit)');

    return query.snapshots().asyncMap((snapshot) async {
      print('[쿼리 결과] Firestore에서 가져온 문서 수: ${snapshot.docs.length}');
      
      List<DealModel> deals = [];
      int filteredOutByDestAirport = 0;
      int filteredOutByMonth = 0;
      int filteredOutByTravelDuration = 0;
      int filteredOutByAirline = 0;
      int filteredOutByAgency = 0;

      // 먼저 모든 deal 파싱 (빠른 필터링을 위해)
      for (var doc in snapshot.docs) {
        try {
          final deal = DealModel.fromFirestore(doc);

          // 도착 공항 필터링 (Firestore 쿼리에서 이미 필터링되었지만, 10개 초과 시 클라이언트에서 추가 필터링)
          if (destAirports != null && destAirports.isNotEmpty && destAirports.length > 10) {
            if (!destAirports.contains(deal.destAirport)) {
              filteredOutByDestAirport++;
              continue;
            }
          }

          // 출발 월 필터링
          if (selectedMonths != null && selectedMonths.isNotEmpty) {
            final dealMonth = _extractMonthFromSupplyDate(deal.supplyStartDate);
            if (dealMonth == 0 || !selectedMonths.contains(dealMonth)) {
              filteredOutByMonth++;
              continue;
            }
          }

          // 여행 기간 필터링
          if (travelDurations != null && travelDurations.isNotEmpty) {
            final days = deal.travelDays;
            if (days == 0 || !travelDurations.contains(days)) {
              filteredOutByTravelDuration++;
              continue;
            }
          }

          // 항공사 필터링 (Firestore 쿼리에서 이미 필터링되었지만, 10개 초과 시 클라이언트에서 추가 필터링)
          if (airlines != null && airlines.isNotEmpty && airlines.length > 10) {
            if (!airlines.contains(deal.airlineCode)) {
              filteredOutByAirline++;
              continue;
            }
          }

          // 여행사 필터링 (Firestore 쿼리에서 이미 필터링되었지만, 10개 초과 시 클라이언트에서 추가 필터링)
          if (agencies != null && agencies.isNotEmpty && agencies.length > 10) {
            if (!agencies.contains(deal.agencyCode)) {
              filteredOutByAgency++;
              continue;
            }
          }

          deals.add(deal);
        } catch (e) {
          print('Deal 파싱 오류: ${doc.id} - $e');
        }
      }

      print('[쿼리 결과] 필터링 후 최종 결과: ${deals.length}개');
      if (filteredOutByDestAirport > 0) {
        print('  - 도착 공항 필터로 제외: $filteredOutByDestAirport개');
      }
      if (filteredOutByMonth > 0) {
        print('  - 출발 월 필터로 제외: $filteredOutByMonth개');
      }
      if (filteredOutByTravelDuration > 0) {
        print('  - 여행 기간 필터로 제외: $filteredOutByTravelDuration개');
      }
      if (filteredOutByAirline > 0) {
        print('  - 항공사 필터로 제외: $filteredOutByAirline개');
      }
      if (filteredOutByAgency > 0) {
        print('  - 여행사 필터로 제외: $filteredOutByAgency개');
      }
      
      // 여행사 필터가 있을 때 실제 여행사 코드 분포 확인
      if (agencies != null && agencies.isNotEmpty) {
        final agencyCounts = <String, int>{};
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final agencyCode = data['agency_code'] as String? ?? '';
            agencyCounts[agencyCode] = (agencyCounts[agencyCode] ?? 0) + 1;
          } catch (e) {
            // 무시
          }
        }
        print('[쿼리 결과] Firestore 결과의 여행사 분포: $agencyCounts');
        print('[쿼리 결과] 요청한 여행사: $agencies');
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

