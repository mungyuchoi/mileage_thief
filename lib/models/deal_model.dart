import 'package:cloud_firestore/cloud_firestore.dart';

class DealModel {
  final String dealId;
  final String originCity;
  final String originAirport;
  final String destCity;
  final String destAirport;
  final String countryCode;
  final String airlineCode;
  final String airlineName;
  final bool isDirect;
  final int viaCount;
  final String flightDuration;
  final int price;
  final String priceDisplay;
  final String supplyStartDate;
  final String supplyEndDate;
  final List<DateRange> dateRanges;
  final List<AvailableDate> availableDates;
  final int minimumPassengers;
  final String tripType;
  final String masterId;
  final String agency;
  final String agencyCode;
  final int scheduleCount;
  final FlightInfo? outbound;
  final FlightInfo? inbound;
  final String bookingUrl;
  final Map<String, dynamic>? bookingData;
  final Timestamp? lastUpdated;
  
  // 가격 변동 정보 (price_history에서 계산)
  double? priceChangePercent;
  int? previousPrice;

  DealModel({
    required this.dealId,
    required this.originCity,
    required this.originAirport,
    required this.destCity,
    required this.destAirport,
    required this.countryCode,
    required this.airlineCode,
    required this.airlineName,
    required this.isDirect,
    required this.viaCount,
    required this.flightDuration,
    required this.price,
    required this.priceDisplay,
    required this.supplyStartDate,
    required this.supplyEndDate,
    required this.dateRanges,
    required this.availableDates,
    required this.minimumPassengers,
    required this.tripType,
    required this.masterId,
    required this.agency,
    required this.agencyCode,
    required this.scheduleCount,
    this.outbound,
    this.inbound,
    required this.bookingUrl,
    this.bookingData,
    this.lastUpdated,
    this.priceChangePercent,
    this.previousPrice,
  });

  factory DealModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DealModel(
      dealId: data['deal_id'] ?? doc.id,
      originCity: data['origin_city'] ?? '',
      originAirport: data['origin_airport'] ?? '',
      destCity: data['dest_city'] ?? '',
      destAirport: data['dest_airport'] ?? '',
      countryCode: data['country_code'] ?? '',
      airlineCode: data['airline_code'] ?? '',
      airlineName: data['airline_name'] ?? '',
      isDirect: data['is_direct'] ?? true,
      viaCount: data['via_count'] ?? 0,
      flightDuration: data['flight_duration'] ?? '',
      price: (data['price'] ?? 0) as int,
      priceDisplay: data['price_display'] ?? '',
      supplyStartDate: data['supply_start_date'] ?? '',
      supplyEndDate: data['supply_end_date'] ?? '',
      dateRanges: (data['date_ranges'] as List<dynamic>?)
          ?.map((e) => DateRange.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      availableDates: (data['available_dates'] as List<dynamic>?)
          ?.map((e) => AvailableDate.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      minimumPassengers: data['minimum_passengers'] ?? 1,
      tripType: data['trip_type'] ?? 'VV',
      masterId: data['master_id'] ?? '',
      agency: data['agency'] ?? '',
      agencyCode: data['agency_code'] ?? '',
      scheduleCount: data['schedule_count'] ?? 1,
      outbound: data['outbound'] != null
          ? FlightInfo.fromMap(data['outbound'] as Map<String, dynamic>)
          : null,
      inbound: data['inbound'] != null
          ? FlightInfo.fromMap(data['inbound'] as Map<String, dynamic>)
          : null,
      bookingUrl: data['booking_url'] ?? '',
      bookingData: data['booking_data'] as Map<String, dynamic>?,
      lastUpdated: data['last_updated'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deal_id': dealId,
      'origin_city': originCity,
      'origin_airport': originAirport,
      'dest_city': destCity,
      'dest_airport': destAirport,
      'country_code': countryCode,
      'airline_code': airlineCode,
      'airline_name': airlineName,
      'is_direct': isDirect,
      'via_count': viaCount,
      'flight_duration': flightDuration,
      'price': price,
      'price_display': priceDisplay,
      'supply_start_date': supplyStartDate,
      'supply_end_date': supplyEndDate,
      'date_ranges': dateRanges.map((e) => e.toMap()).toList(),
      'available_dates': availableDates.map((e) => e.toMap()).toList(),
      'minimum_passengers': minimumPassengers,
      'trip_type': tripType,
      'master_id': masterId,
      'agency': agency,
      'agency_code': agencyCode,
      'schedule_count': scheduleCount,
      'outbound': outbound?.toMap(),
      'inbound': inbound?.toMap(),
      'booking_url': bookingUrl,
      'booking_data': bookingData,
      'last_updated': lastUpdated,
    };
  }

  // 여행 기간 계산 (일수)
  int get travelDays {
    // 1. availableDates 우선 확인
    if (availableDates.isNotEmpty) {
      final firstDate = availableDates.first;
      
      // ISO 형식 날짜 문자열 사용 (departureDate, returnDateStr)
      if (firstDate.departureDate != null && firstDate.returnDateStr != null) {
        try {
          final departure = DateTime.parse(firstDate.departureDate!);
          final returnDate = DateTime.parse(firstDate.returnDateStr!);
          final days = returnDate.difference(departure).inDays;
          // 최소 0일 (같은 날 출발/귀국) 반환
          return days >= 0 ? days : 0;
        } catch (e) {
          // 파싱 실패 시 다음 방법 시도
        }
      }
    }
    
    // 2. date_ranges 확인
    if (dateRanges.isNotEmpty) {
      final dateRange = dateRanges.first;
      try {
        final startDate = DateTime.parse(dateRange.start);
        final endDate = DateTime.parse(dateRange.end);
        final days = endDate.difference(startDate).inDays;
        // 최소 0일 (같은 날 출발/귀국) 반환
        return days >= 0 ? days : 0;
      } catch (e) {
        // 파싱 실패 시 다음 방법 시도
      }
    }
    
    // 3. supply_start_date와 supply_end_date로 계산 시도
    if (supplyStartDate.isNotEmpty && supplyEndDate.isNotEmpty) {
      try {
        final start = _parseSupplyDate(supplyStartDate);
        final end = _parseSupplyDate(supplyEndDate);
        if (start != null && end != null) {
          final days = end.difference(start).inDays;
          // 최소 0일 (같은 날 출발/귀국) 반환
          return days >= 0 ? days : 0;
        }
      } catch (e) {
        // 파싱 실패 시 0 반환
      }
    }
    
    return 0;
  }

  // YYYYMMDD 형식의 날짜를 DateTime으로 변환
  DateTime? _parseSupplyDate(String dateStr) {
    try {
      if (dateStr.length == 8) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // 할인율 계산 (이전 가격 대비)
  double? get discountPercent {
    if (previousPrice == null || previousPrice == 0) return null;
    return ((previousPrice! - price) / previousPrice!) * 100;
  }
}

class DateRange {
  final String start;
  final String end;

  DateRange({required this.start, required this.end});

  factory DateRange.fromMap(Map<String, dynamic> map) {
    return DateRange(
      start: map['start'] ?? '',
      end: map['end'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }
}

class AvailableDate {
  final String departure;
  final String returnDate;
  final String? departureDate;
  final String? returnDateStr;
  final int? price;

  AvailableDate({
    required this.departure,
    required this.returnDate,
    this.departureDate,
    this.returnDateStr,
    this.price,
  });

  factory AvailableDate.fromMap(Map<String, dynamic> map) {
    return AvailableDate(
      departure: map['departure'] ?? '',
      returnDate: map['return'] ?? '',
      departureDate: map['departure_date'] as String?,
      returnDateStr: map['return_date'] as String?,
      price: map['price'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departure': departure,
      'return': returnDate,
      'departure_date': departureDate,
      'return_date': returnDateStr,
      'price': price,
    };
  }
}

class FlightInfo {
  final String? departureTime;
  final String? arrivalTime;
  final String originAirport;
  final String destAirport;
  final String airlineCode;
  final String airlineName;
  final String? flightNo;
  final String? durationText;

  FlightInfo({
    this.departureTime,
    this.arrivalTime,
    required this.originAirport,
    required this.destAirport,
    required this.airlineCode,
    required this.airlineName,
    this.flightNo,
    this.durationText,
  });

  factory FlightInfo.fromMap(Map<String, dynamic> map) {
    return FlightInfo(
      departureTime: map['departure_time'] as String?,
      arrivalTime: map['arrival_time'] as String?,
      originAirport: map['origin_airport'] ?? '',
      destAirport: map['dest_airport'] ?? '',
      airlineCode: map['airline_code'] ?? '',
      airlineName: map['airline_name'] ?? '',
      flightNo: map['flight_no'] as String?,
      durationText: map['duration_text'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'origin_airport': originAirport,
      'dest_airport': destAirport,
      'airline_code': airlineCode,
      'airline_name': airlineName,
      'flight_no': flightNo,
      'duration_text': durationText,
    };
  }
}

