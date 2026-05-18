import 'package:cloud_firestore/cloud_firestore.dart';

enum MarriottStayType {
  paid('paid', '유상'),
  points('points', '포인트 숙박'),
  freeNightAward('freeNightAward', '무료숙박권');

  final String value;
  final String label;

  const MarriottStayType(this.value, this.label);

  static MarriottStayType fromValue(Object? value) {
    final text = value?.toString();
    for (final type in MarriottStayType.values) {
      if (type.value == text) return type;
    }
    return MarriottStayType.paid;
  }
}

class MarriottEliteTierOption {
  final String name;
  final double multiplier;

  const MarriottEliteTierOption({
    required this.name,
    required this.multiplier,
  });

  static const options = <MarriottEliteTierOption>[
    MarriottEliteTierOption(name: '멤버', multiplier: 1),
    MarriottEliteTierOption(name: '실버', multiplier: 1.1),
    MarriottEliteTierOption(name: '골드', multiplier: 1.25),
    MarriottEliteTierOption(name: '플래티넘', multiplier: 1.5),
    MarriottEliteTierOption(name: '티타늄', multiplier: 1.75),
    MarriottEliteTierOption(name: '앰배서더', multiplier: 1.75),
  ];

  static MarriottEliteTierOption get defaultOption => options[3];

  static MarriottEliteTierOption fromStored({
    Object? name,
    Object? multiplier,
  }) {
    final storedMultiplier = _asDouble(multiplier, fallback: 0);
    final storedName = _asString(name);
    for (final option in options) {
      if (option.name == storedName) return option;
      if (storedMultiplier > 0 &&
          (option.multiplier - storedMultiplier).abs() < 0.0001) {
        return option;
      }
    }
    if (storedName.isNotEmpty || storedMultiplier > 0) {
      return MarriottEliteTierOption(
        name: storedName.isEmpty ? '직접 입력' : storedName,
        multiplier: storedMultiplier > 0 ? storedMultiplier : 1,
      );
    }
    return defaultOption;
  }
}

class MarriottStayRecord {
  final String id;
  final MarriottStayType stayType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final String hotelName;
  final int totalAmount;
  final int roomRate;
  final int taxAmount;
  final int serviceCharge;
  final int earnedPoints;
  final double returnRate;
  final String bookingNumber;
  final String memo;
  final double pointValueKrw;
  final double exchangeRateKrwPerUsd;
  final String eliteTierName;
  final double eliteMultiplier;
  final int welcomePoints;
  final int promoPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MarriottStayRecord({
    required this.id,
    required this.stayType,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.hotelName,
    required this.totalAmount,
    required this.roomRate,
    required this.taxAmount,
    required this.serviceCharge,
    required this.earnedPoints,
    required this.returnRate,
    required this.bookingNumber,
    required this.memo,
    required this.pointValueKrw,
    required this.exchangeRateKrwPerUsd,
    required this.eliteTierName,
    required this.eliteMultiplier,
    required this.welcomePoints,
    required this.promoPoints,
    this.createdAt,
    this.updatedAt,
  });

  factory MarriottStayRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MarriottStayRecord(
      id: _asString(data['id'], fallback: doc.id),
      stayType: MarriottStayType.fromValue(data['stayType']),
      checkIn: _asDate(data['checkIn']),
      checkOut: _asDate(data['checkOut']),
      nights: _asInt(data['nights'], fallback: 1),
      hotelName: _asString(data['hotelName']),
      totalAmount: _asInt(data['totalAmount']),
      roomRate: _asInt(data['roomRate']),
      taxAmount: _asInt(data['taxAmount']),
      serviceCharge: _asInt(data['serviceCharge']),
      earnedPoints: _asInt(data['earnedPoints']),
      returnRate: _asDouble(data['returnRate']),
      bookingNumber: _asString(data['bookingNumber']),
      memo: _asString(data['memo']),
      pointValueKrw: _asDouble(data['pointValueKrw'], fallback: 10),
      exchangeRateKrwPerUsd:
          _asDouble(data['exchangeRateKrwPerUsd'], fallback: 1200),
      eliteTierName: _asString(
        data['eliteTierName'],
        fallback: MarriottEliteTierOption.defaultOption.name,
      ),
      eliteMultiplier: _asDouble(
        data['eliteMultiplier'],
        fallback: MarriottEliteTierOption.defaultOption.multiplier,
      ),
      welcomePoints: _asInt(data['welcomePoints']),
      promoPoints: _asInt(data['promoPoints']),
      createdAt: _asNullableDate(data['createdAt']),
      updatedAt: _asNullableDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({required String documentId}) {
    return {
      'id': documentId,
      'stayType': stayType.value,
      'checkIn': Timestamp.fromDate(_dateOnly(checkIn)),
      'checkOut': Timestamp.fromDate(_dateOnly(checkOut)),
      'nights': nights,
      'hotelName': hotelName.trim(),
      'totalAmount': totalAmount,
      'roomRate': roomRate,
      'taxAmount': taxAmount,
      'serviceCharge': serviceCharge,
      'earnedPoints': earnedPoints,
      'returnRate': returnRate,
      'bookingNumber': bookingNumber.trim(),
      'memo': memo.trim(),
      'pointValueKrw': pointValueKrw,
      'exchangeRateKrwPerUsd': exchangeRateKrwPerUsd,
      'eliteTierName': eliteTierName,
      'eliteMultiplier': eliteMultiplier,
      'welcomePoints': welcomePoints,
      'promoPoints': promoPoints,
    };
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
  }
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

DateTime _asDate(Object? value) {
  return _asNullableDate(value) ?? DateTime.now();
}

DateTime? _asNullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
