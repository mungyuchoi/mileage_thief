import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RadarItemType {
  static const String mileageSeat = 'mileageSeat';
  static const String cancelAlert = 'cancelAlert';
  static const String flightDeal = 'flightDeal';
  static const String hotelDeal = 'hotelDeal';
  static const String giftcard = 'giftcard';
  static const String benefitNews = 'benefitNews';
  static const String valueCalculator = 'valueCalculator';
}

class RadarTravelProfile {
  final List<String> homeAirports;
  final List<String> preferredCabins;
  final List<String> targetRegions;
  final int dateFlexibility;
  final Map<String, int> mileageBalances;
  final int? maxCashBudget;
  final bool giftcardEnabled;

  const RadarTravelProfile({
    required this.homeAirports,
    required this.preferredCabins,
    required this.targetRegions,
    required this.dateFlexibility,
    required this.mileageBalances,
    required this.maxCashBudget,
    required this.giftcardEnabled,
  });

  factory RadarTravelProfile.defaults() {
    return const RadarTravelProfile(
      homeAirports: ['ICN'],
      preferredCabins: ['비즈니스'],
      targetRegions: ['미주', '유럽', '일본'],
      dateFlexibility: 90,
      mileageBalances: {
        '대한항공': 0,
        '아시아나': 0,
      },
      maxCashBudget: null,
      giftcardEnabled: true,
    );
  }

  factory RadarTravelProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return RadarTravelProfile.defaults();
    return RadarTravelProfile(
      homeAirports: _stringList(data['homeAirports'], fallback: ['ICN']),
      preferredCabins: _stringList(data['preferredCabins'], fallback: ['비즈니스']),
      targetRegions: _stringList(
        data['targetRegions'],
        fallback: ['미주', '유럽', '일본'],
      ),
      dateFlexibility: (data['dateFlexibility'] as num?)?.toInt() ?? 90,
      mileageBalances: _intMap(data['mileageBalances']),
      maxCashBudget: (data['maxCashBudget'] as num?)?.toInt(),
      giftcardEnabled: (data['giftcardEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'homeAirports': homeAirports,
      'preferredCabins': preferredCabins,
      'targetRegions': targetRegions,
      'dateFlexibility': dateFlexibility,
      'mileageBalances': mileageBalances,
      'maxCashBudget': maxCashBudget,
      'giftcardEnabled': giftcardEnabled,
    };
  }

  String get summary {
    final airports = homeAirports.isEmpty ? 'ICN' : homeAirports.join('/');
    final cabins =
        preferredCabins.isEmpty ? '좌석 전체' : preferredCabins.join('/');
    return '$airports 출발 · $cabins · $dateFlexibility일 유연';
  }
}

class RadarItem {
  final String id;
  final String itemType;
  final String title;
  final String subtitle;
  final String reason;
  final String source;
  final String route;
  final String dateRange;
  final int? price;
  final int? miles;
  final int? cashValue;
  final double? costPerMile;
  final String urgency;
  final double score;
  final String deepLink;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;

  const RadarItem({
    required this.id,
    required this.itemType,
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.source,
    required this.route,
    required this.dateRange,
    required this.price,
    required this.miles,
    required this.cashValue,
    required this.costPerMile,
    required this.urgency,
    required this.score,
    required this.deepLink,
    required this.updatedAt,
    this.payload = const {},
  });

  factory RadarItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return RadarItem(
      id: doc.id,
      itemType: (data['itemType'] as String?) ?? RadarItemType.benefitNews,
      title: (data['title'] as String?) ?? '레이더 추천',
      subtitle: (data['subtitle'] as String?) ?? '',
      reason: (data['reason'] as String?) ?? '오늘 확인하면 좋은 항목입니다.',
      source: (data['source'] as String?) ?? '마일캐치',
      route: _stringValue(data['route']),
      dateRange: _stringValue(data['dateRange']),
      price: (data['price'] as num?)?.toInt(),
      miles: (data['miles'] as num?)?.toInt(),
      cashValue: (data['cashValue'] as num?)?.toInt(),
      costPerMile: (data['costPerMile'] as num?)?.toDouble(),
      urgency: (data['urgency'] as String?) ?? '보통',
      score: (data['score'] as num?)?.toDouble() ?? 0,
      deepLink: (data['deepLink'] as String?) ?? '',
      updatedAt: _dateValue(data['updatedAt']) ?? DateTime.now(),
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemType': itemType,
      'title': title,
      'subtitle': subtitle,
      'reason': reason,
      'source': source,
      'route': route,
      'dateRange': dateRange,
      'price': price,
      'miles': miles,
      'cashValue': cashValue,
      'costPerMile': costPerMile,
      'urgency': urgency,
      'score': score,
      'deepLink': deepLink,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'payload': payload,
    };
  }

  String get typeLabel {
    switch (itemType) {
      case RadarItemType.mileageSeat:
        return '마일리지 좌석';
      case RadarItemType.cancelAlert:
        return '취소표';
      case RadarItemType.flightDeal:
        return '항공 특가';
      case RadarItemType.hotelDeal:
        return '호텔 특가';
      case RadarItemType.giftcard:
        return '상품권';
      case RadarItemType.valueCalculator:
        return '계산기';
      case RadarItemType.benefitNews:
      default:
        return '뉴스/혜택';
    }
  }

  String get updatedAtLabel {
    return DateFormat('MM.dd HH:mm').format(updatedAt);
  }

  String? get priceLabel {
    final value = price;
    if (value == null || value <= 0) return null;
    return '${_wonFormat.format(value)}원';
  }

  String? get milesLabel {
    final value = miles;
    if (value == null || value <= 0) return null;
    return '${_countFormat.format(value)}마일';
  }

  String? get cashValueLabel {
    final value = cashValue;
    if (value == null || value <= 0) return null;
    return '현금가 ${_wonFormat.format(value)}원';
  }

  String? get costPerMileLabel {
    final value = costPerMile;
    if (value == null || value <= 0) return null;
    return '${value.toStringAsFixed(1)}원/마일';
  }

  String get shareText {
    final lines = <String>[
      '[마일캐치 레이더] $title',
      if (route.isNotEmpty) '노선: $route',
      if (dateRange.isNotEmpty) '일정: $dateRange',
      if (milesLabel != null) '필요 마일: $milesLabel',
      if (priceLabel != null) '가격: $priceLabel',
      if (cashValueLabel != null) cashValueLabel!,
      if (costPerMileLabel != null) '기준 원가: $costPerMileLabel',
      '출처: $source · 갱신: $updatedAtLabel',
    ];
    return lines.join('\n');
  }

  static final NumberFormat _wonFormat = NumberFormat('#,###');
  static final NumberFormat _countFormat = NumberFormat('#,###');
}

List<String> _stringList(dynamic value, {required List<String> fallback}) {
  if (value is Iterable) {
    final list = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (list.isNotEmpty) return list;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return fallback;
}

Map<String, int> _intMap(dynamic value) {
  final defaults = RadarTravelProfile.defaults().mileageBalances;
  if (value is! Map) return defaults;
  return {
    ...defaults,
    for (final entry in value.entries)
      entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
  };
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) {
    final from = value['from']?.toString();
    final to = value['to']?.toString();
    if ((from ?? '').isNotEmpty && (to ?? '').isNotEmpty) {
      return '$from-$to';
    }
  }
  return value.toString();
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
