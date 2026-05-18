import 'package:cloud_firestore/cloud_firestore.dart';

enum HotelAwardProgram {
  marriott(
    id: 'marriott',
    label: 'Marriott Bonvoy',
    shortLabel: '메리어트',
    baselineCentsPerPoint: 0.75,
  ),
  hilton(
    id: 'hilton',
    label: 'Hilton Honors',
    shortLabel: '힐튼',
    baselineCentsPerPoint: 0.40,
  ),
  hyatt(
    id: 'hyatt',
    label: 'World of Hyatt',
    shortLabel: '하얏트',
    baselineCentsPerPoint: 1.70,
  ),
  ihg(
    id: 'ihg',
    label: 'IHG One Rewards',
    shortLabel: 'IHG',
    baselineCentsPerPoint: 0.60,
  );

  final String id;
  final String label;
  final String shortLabel;
  final double baselineCentsPerPoint;

  const HotelAwardProgram({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.baselineCentsPerPoint,
  });

  static HotelAwardProgram fromId(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    for (final program in values) {
      if (program.id == normalized) return program;
    }
    return HotelAwardProgram.marriott;
  }
}

enum HotelAwardSort {
  value,
  points,
  cash,
  recent,
}

class HotelAwardSearchQuery {
  final String locationText;
  final DateTime checkIn;
  final int nights;
  final Set<HotelAwardProgram> programs;
  final int? maxPoints;
  final double? minKrwPerPoint;
  final int? maxCashKrw;
  final HotelAwardSort sort;

  const HotelAwardSearchQuery({
    required this.locationText,
    required this.checkIn,
    required this.nights,
    required this.programs,
    required this.maxPoints,
    required this.minKrwPerPoint,
    required this.maxCashKrw,
    required this.sort,
  });

  String get checkInKey => HotelAwardSnapshot.dateKey(checkIn);

  bool matches(HotelAwardSnapshot snapshot) {
    if (programs.isNotEmpty && !programs.contains(snapshot.program)) {
      return false;
    }
    if (snapshot.checkInKey != checkInKey) return false;
    if (snapshot.nights != nights) return false;
    if (maxPoints != null && snapshot.pointsTotal > maxPoints!) return false;
    final krwPerPoint = snapshot.krwPerPoint;
    if (minKrwPerPoint != null &&
        (krwPerPoint == null || krwPerPoint < minKrwPerPoint!)) {
      return false;
    }
    final cashTotalKrw = snapshot.cashTotalKrw;
    if (maxCashKrw != null &&
        (cashTotalKrw == null || cashTotalKrw > maxCashKrw!)) {
      return false;
    }
    final needle = locationText.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return snapshot.searchText.contains(needle);
  }

  List<HotelAwardSnapshot> sortSnapshots(List<HotelAwardSnapshot> snapshots) {
    final sorted = snapshots.toList(growable: false);
    sorted.sort((a, b) {
      switch (sort) {
        case HotelAwardSort.points:
          return a.pointsTotal.compareTo(b.pointsTotal);
        case HotelAwardSort.cash:
          return (a.cashTotalKrw ?? 1 << 30).compareTo(
            b.cashTotalKrw ?? 1 << 30,
          );
        case HotelAwardSort.recent:
          return b.fetchedAt.compareTo(a.fetchedAt);
        case HotelAwardSort.value:
          final valueCompare = (b.krwPerPoint ?? 0).compareTo(
            a.krwPerPoint ?? 0,
          );
          if (valueCompare != 0) return valueCompare;
          return b.valueRatio.compareTo(a.valueRatio);
      }
    });
    return sorted;
  }
}

class HotelAwardProperty {
  final String id;
  final HotelAwardProgram program;
  final String chainPropertyId;
  final String name;
  final String brand;
  final String subBrand;
  final String regionKey;
  final String countryCode;
  final String cityName;
  final String address;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final String officialUrl;
  final DateTime updatedAt;

  const HotelAwardProperty({
    required this.id,
    required this.program,
    required this.chainPropertyId,
    required this.name,
    required this.brand,
    required this.subBrand,
    required this.regionKey,
    required this.countryCode,
    required this.cityName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.officialUrl,
    required this.updatedAt,
  });

  String get primaryImageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  factory HotelAwardProperty.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return HotelAwardProperty.fromMap(doc.id, doc.data() ?? const {});
  }

  factory HotelAwardProperty.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return HotelAwardProperty(
      id: _stringValue(data['propertyId'], fallback: id),
      program: HotelAwardProgram.fromId(_stringValue(data['programId'])),
      chainPropertyId: _stringValue(data['chainPropertyId']),
      name: _stringValue(data['name'], fallback: '호텔명 미정'),
      brand: _stringValue(data['brand']),
      subBrand: _stringValue(data['subBrand']),
      regionKey: _stringValue(data['regionKey']),
      countryCode: _stringValue(data['countryCode']),
      cityName: _stringValue(data['cityName']),
      address: _stringValue(data['address']),
      latitude: _doubleValue(data['lat'] ?? data['latitude']),
      longitude: _doubleValue(data['lng'] ?? data['longitude']),
      imageUrls: _stringList(data['imageUrls']),
      officialUrl: _stringValue(data['officialUrl']),
      updatedAt: _dateValue(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'programId': program.id,
      'chainPropertyId': chainPropertyId,
      'name': name,
      'brand': brand,
      'subBrand': subBrand,
      'regionKey': regionKey,
      'countryCode': countryCode,
      'cityName': cityName,
      'address': address,
      'lat': latitude,
      'lng': longitude,
      'imageUrls': imageUrls,
      'officialUrl': officialUrl,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class HotelAwardSnapshot {
  final String id;
  final String propertyId;
  final HotelAwardProgram program;
  final String hotelName;
  final String brand;
  final String subBrand;
  final String regionKey;
  final String countryCode;
  final String cityName;
  final String address;
  final String imageUrl;
  final String officialUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int pointsTotal;
  final int pointsPerNight;
  final int? cashTotalKrw;
  final double? cashTotalUsd;
  final double? centsPerPoint;
  final double? krwPerPoint;
  final String roomType;
  final String availabilityStatus;
  final String source;
  final String sourceUrl;
  final double confidence;
  final double score;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  const HotelAwardSnapshot({
    required this.id,
    required this.propertyId,
    required this.program,
    required this.hotelName,
    required this.brand,
    required this.subBrand,
    required this.regionKey,
    required this.countryCode,
    required this.cityName,
    required this.address,
    required this.imageUrl,
    required this.officialUrl,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.pointsTotal,
    required this.pointsPerNight,
    required this.cashTotalKrw,
    required this.cashTotalUsd,
    required this.centsPerPoint,
    required this.krwPerPoint,
    required this.roomType,
    required this.availabilityStatus,
    required this.source,
    required this.sourceUrl,
    required this.confidence,
    required this.score,
    required this.fetchedAt,
    required this.expiresAt,
  });

  String get checkInKey => dateKey(checkIn);

  String get checkOutKey => dateKey(checkOut);

  String get displayBrand {
    if (subBrand.isNotEmpty) return subBrand;
    if (brand.isNotEmpty) return brand;
    return program.shortLabel;
  }

  String get displayLocation {
    final parts = <String>[
      if (cityName.isNotEmpty) cityName,
      if (countryCode.isNotEmpty) countryCode,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return address;
  }

  bool get isBookable {
    final value = availabilityStatus.toLowerCase();
    return value == 'bookable' ||
        value == 'available' ||
        value == 'open' ||
        value == '확인됨';
  }

  bool get isFresh {
    return fetchedAt
        .isAfter(DateTime.now().subtract(const Duration(hours: 24)));
  }

  double get valueRatio {
    final cpp = centsPerPoint;
    if (cpp == null || cpp <= 0) return 0;
    return cpp / program.baselineCentsPerPoint;
  }

  String get searchText {
    return [
      hotelName,
      brand,
      subBrand,
      regionKey,
      countryCode,
      cityName,
      address,
      program.label,
      program.shortLabel,
    ].join(' ').toLowerCase();
  }

  factory HotelAwardSnapshot.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return HotelAwardSnapshot.fromMap(doc.id, doc.data() ?? const {});
  }

  factory HotelAwardSnapshot.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final property = data['property'] is Map
        ? Map<String, dynamic>.from(data['property'] as Map)
        : const <String, dynamic>{};
    final program = HotelAwardProgram.fromId(
      _stringValue(data['programId'],
          fallback: _stringValue(property['programId'])),
    );
    final checkIn =
        _dateValue(data['checkIn'] ?? data['checkInDate']) ?? DateTime.now();
    final nights = _intValue(data['nights'], fallback: 1).clamp(1, 30).toInt();
    final checkOut = _dateValue(data['checkOut'] ?? data['checkOutDate']) ??
        checkIn.add(Duration(days: nights));
    final pointsTotal = _intValue(
      data['pointsTotal'] ?? data['pointsRequired'] ?? data['points'],
    );
    final pointsPerNight = _intValue(
      data['pointsPerNight'],
      fallback: pointsTotal > 0 ? (pointsTotal / nights).round() : 0,
    );
    final cashTotalKrw =
        _nullableIntValue(data['cashTotalKRW'] ?? data['cashTotalKrw']);
    final cashTotalUsd =
        _doubleValue(data['cashTotalUSD'] ?? data['cashTotalUsd']);
    final explicitKrwPerPoint =
        _doubleValue(data['krwPerPoint'] ?? data['valueKrwPerPoint']);
    final explicitCpp =
        _doubleValue(data['cpp'] ?? data['centsPerPoint'] ?? data['cppUsd']);
    final calculatedKrw = explicitKrwPerPoint ??
        HotelPointValueCalculator.krwPerPoint(
          cashTotalKrw: cashTotalKrw,
          pointsTotal: pointsTotal,
        );
    final calculatedCpp = explicitCpp ??
        HotelPointValueCalculator.centsPerPoint(
          cashTotalUsd: cashTotalUsd,
          cashTotalKrw: cashTotalKrw,
          pointsTotal: pointsTotal,
        );

    return HotelAwardSnapshot(
      id: id,
      propertyId: _stringValue(
        data['propertyId'],
        fallback: _stringValue(property['propertyId'], fallback: id),
      ),
      program: program,
      hotelName: _stringValue(
        data['hotelName'] ?? data['name'],
        fallback: _stringValue(property['name'], fallback: '호텔명 미정'),
      ),
      brand: _stringValue(data['brand'],
          fallback: _stringValue(property['brand'])),
      subBrand: _stringValue(
        data['subBrand'],
        fallback: _stringValue(property['subBrand']),
      ),
      regionKey: _stringValue(
        data['regionKey'],
        fallback: _stringValue(property['regionKey']),
      ),
      countryCode: _stringValue(
        data['countryCode'],
        fallback: _stringValue(property['countryCode']),
      ),
      cityName: _stringValue(
        data['cityName'],
        fallback: _stringValue(property['cityName']),
      ),
      address: _stringValue(
        data['address'],
        fallback: _stringValue(property['address']),
      ),
      imageUrl: _stringValue(
        data['imageUrl'],
        fallback: _stringList(property['imageUrls']).firstOrNull ?? '',
      ),
      officialUrl: _stringValue(
        data['officialUrl'],
        fallback: _stringValue(property['officialUrl']),
      ),
      checkIn: checkIn,
      checkOut: checkOut,
      nights: nights,
      pointsTotal: pointsTotal,
      pointsPerNight: pointsPerNight,
      cashTotalKrw: cashTotalKrw,
      cashTotalUsd: cashTotalUsd,
      centsPerPoint: calculatedCpp,
      krwPerPoint: calculatedKrw,
      roomType: _stringValue(data['roomType'], fallback: 'Standard award'),
      availabilityStatus:
          _stringValue(data['availabilityStatus'], fallback: 'unknown'),
      source: _stringValue(data['source'], fallback: 'milecatch'),
      sourceUrl: _stringValue(data['sourceUrl']),
      confidence:
          (_doubleValue(data['confidence']) ?? 0.5).clamp(0, 1).toDouble(),
      score:
          _doubleValue(data['score']) ?? calculatedKrw ?? calculatedCpp ?? 0.0,
      fetchedAt: _dateValue(data['fetchedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: _dateValue(data['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class HotelPointValueCalculator {
  const HotelPointValueCalculator._();

  static int effectivePointsTotal({
    required HotelAwardProgram program,
    required int pointsPerNight,
    required int nights,
    bool hiltonEliteOrCardholder = true,
    bool ihgFourthNightFree = false,
  }) {
    if (pointsPerNight <= 0 || nights <= 0) return 0;
    var paidNights = nights;
    if (program == HotelAwardProgram.marriott && nights >= 5) {
      paidNights = nights - (nights ~/ 5);
    }
    if (program == HotelAwardProgram.hilton &&
        hiltonEliteOrCardholder &&
        nights >= 5) {
      paidNights = nights - (nights ~/ 5);
    }
    if (program == HotelAwardProgram.ihg && ihgFourthNightFree && nights >= 4) {
      paidNights = nights - (nights ~/ 4);
    }
    return pointsPerNight * paidNights;
  }

  static double? krwPerPoint({
    required int? cashTotalKrw,
    required int pointsTotal,
  }) {
    if (cashTotalKrw == null || cashTotalKrw <= 0 || pointsTotal <= 0) {
      return null;
    }
    return _round(cashTotalKrw / pointsTotal, digits: 2);
  }

  static double? centsPerPoint({
    required double? cashTotalUsd,
    required int? cashTotalKrw,
    required int pointsTotal,
    double krwPerUsd = 1350,
  }) {
    if (pointsTotal <= 0) return null;
    final usd = cashTotalUsd ??
        (cashTotalKrw == null || cashTotalKrw <= 0 || krwPerUsd <= 0
            ? null
            : cashTotalKrw / krwPerUsd);
    if (usd == null || usd <= 0) return null;
    return _round(usd / pointsTotal * 100, digits: 2);
  }

  static double _round(num value, {required int digits}) {
    final factor = List.filled(digits, 10).fold<int>(1, (a, b) => a * b);
    return (value * factor).round() / factor;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  final parsed = int.tryParse(_stringValue(value).replaceAll(',', ''));
  return parsed ?? fallback;
}

int? _nullableIntValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(_stringValue(value).replaceAll(',', ''));
}

double? _doubleValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(_stringValue(value).replaceAll(',', ''));
}

DateTime? _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}
