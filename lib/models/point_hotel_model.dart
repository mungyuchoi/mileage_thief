import 'package:cloud_firestore/cloud_firestore.dart';

class PointHotelAmenity {
  final String title;
  final String subtitle;
  final bool included;

  const PointHotelAmenity({
    required this.title,
    this.subtitle = '',
    this.included = true,
  });

  factory PointHotelAmenity.fromMap(Map<String, dynamic> data) {
    return PointHotelAmenity(
      title: _asString(data['title']),
      subtitle: _asString(data['subtitle']),
      included: data['included'] is bool ? data['included'] as bool : true,
    );
  }
}

class PointHotelInfoItem {
  final String title;
  final String body;

  const PointHotelInfoItem({
    required this.title,
    required this.body,
  });

  factory PointHotelInfoItem.fromMap(Map<String, dynamic> data) {
    return PointHotelInfoItem(
      title: _asString(data['title']),
      body: _asString(data['body']),
    );
  }
}

class PointHotelInfoSection {
  final String title;
  final List<PointHotelInfoItem> items;

  const PointHotelInfoSection({
    required this.title,
    required this.items,
  });

  factory PointHotelInfoSection.fromMap(Map<String, dynamic> data) {
    return PointHotelInfoSection(
      title: _asString(data['title']),
      items: _asMapList(data['items'])
          .map(PointHotelInfoItem.fromMap)
          .where((item) => item.title.isNotEmpty || item.body.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class PointHotelCalendarEntry {
  final String date;
  final int points;
  final int? cashKrw;

  const PointHotelCalendarEntry({
    required this.date,
    required this.points,
    this.cashKrw,
  });

  factory PointHotelCalendarEntry.fromMap(Map<String, dynamic> data) {
    return PointHotelCalendarEntry(
      date: _asString(data['dateKey'] ?? data['date']),
      points: _asInt(data['pointsPerNight'] ?? data['points'] ?? data['p']),
      cashKrw: _asNullableInt(
        data['cashPerNightKrw'] ?? data['cashKrw'] ?? data['c'],
      ),
    );
  }
}

class PointHotel {
  final String id;
  final String name;
  final String city;
  final String country;
  final String address;
  final String brand;
  final String imageUrl;
  final List<String> galleryUrls;
  final double rating;
  final int pointsPerNight;
  final int cashPerNightKrw;
  final bool guestFavorite;
  final String description;
  final List<String> amenities;
  final List<int> calendarPoints;
  final String loyaltyProgram;
  final String propertyCode;
  final String officialUrl;
  final String phone;
  final String checkInTime;
  final String checkOutTime;
  final int? reviewCount;
  final String mapUrl;
  final double? latitude;
  final double? longitude;
  final String pointCalendarNote;
  final List<PointHotelAmenity> amenityDetails;
  final List<PointHotelInfoSection> detailSections;
  final List<PointHotelCalendarEntry> calendarEntries;
  final int sortScore;
  final double? milecatchRatingAverage;
  final int milecatchRatingCount;
  final int milecatchRatingSum;

  const PointHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.address,
    required this.brand,
    required this.imageUrl,
    required this.galleryUrls,
    required this.rating,
    required this.pointsPerNight,
    required this.cashPerNightKrw,
    required this.guestFavorite,
    required this.description,
    required this.amenities,
    required this.calendarPoints,
    this.loyaltyProgram = '',
    this.propertyCode = '',
    this.officialUrl = '',
    this.phone = '',
    this.checkInTime = '',
    this.checkOutTime = '',
    this.reviewCount,
    this.mapUrl = '',
    this.latitude,
    this.longitude,
    this.pointCalendarNote = '',
    this.amenityDetails = const [],
    this.detailSections = const [],
    this.calendarEntries = const [],
    this.sortScore = 0,
    this.milecatchRatingAverage,
    this.milecatchRatingCount = 0,
    this.milecatchRatingSum = 0,
  });

  factory PointHotel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final currentAward = _asMap(data['currentAward']);
    final calendarEntries =
        _calendarEntriesFromPreview(data['calendarPreview']);
    PointHotelCalendarEntry? firstCalendarRate;
    for (final entry in calendarEntries) {
      if (entry.points > 0 || (entry.cashKrw ?? 0) > 0) {
        firstCalendarRate = entry;
        break;
      }
    }
    final galleryUrls = _asStringList(data['galleryUrls']);
    final imageUrl = _asString(data['imageUrl']);
    final geo = _asMap(data['geo']);
    final latitude = _asNullableDouble(
      geo['lat'] ?? data['latitude'] ?? data['lat'],
    );
    final longitude = _asNullableDouble(
      geo['lng'] ?? data['longitude'] ?? data['lng'],
    );
    final pointsPerNight = _asInt(currentAward['pointsPerNight']) > 0
        ? _asInt(currentAward['pointsPerNight'])
        : firstCalendarRate?.points ?? 0;
    final cashPerNightKrw = _asInt(currentAward['cashPerNightKrw']) > 0
        ? _asInt(currentAward['cashPerNightKrw'])
        : firstCalendarRate?.cashKrw ?? 0;
    final amenities = _asStringList(data['amenities']);
    final amenityDetails = _asMapList(data['amenityDetails'])
        .map(PointHotelAmenity.fromMap)
        .where((amenity) => amenity.title.isNotEmpty)
        .toList(growable: false);
    final detailSections = _asMapList(data['detailSections'])
        .map(PointHotelInfoSection.fromMap)
        .where(
            (section) => section.title.isNotEmpty && section.items.isNotEmpty)
        .toList(growable: false);
    final rating = _asDouble(data['rating']);

    return PointHotel(
      id: _asString(data['hotelId'], fallback: doc.id),
      name: _asString(data['name']),
      city: _asString(data['city']),
      country: _asString(data['country']),
      address: _asString(data['address']),
      brand: _asString(data['brand']),
      imageUrl: imageUrl.isNotEmpty
          ? imageUrl
          : galleryUrls.isNotEmpty
              ? galleryUrls.first
              : '',
      galleryUrls: galleryUrls,
      rating: rating,
      pointsPerNight: pointsPerNight,
      cashPerNightKrw: cashPerNightKrw,
      guestFavorite: data['guestFavorite'] is bool
          ? data['guestFavorite'] as bool
          : rating >= 4.5,
      description: _asString(data['description']),
      amenities: amenities,
      calendarPoints: calendarEntries
          .map((entry) => entry.points)
          .where((points) => points > 0)
          .toList(growable: false),
      loyaltyProgram: _asString(data['loyaltyProgram']),
      propertyCode: _asString(data['propertyCode']),
      officialUrl: _asString(data['officialUrl']),
      phone: _asString(data['phone']),
      checkInTime: _asString(data['checkInTime']),
      checkOutTime: _asString(data['checkOutTime']),
      reviewCount: _asNullableInt(data['reviewCount']),
      mapUrl: _asString(data['mapUrl']),
      latitude: latitude,
      longitude: longitude,
      pointCalendarNote: _calendarNote(currentAward, calendarEntries),
      amenityDetails: amenityDetails,
      detailSections: detailSections,
      calendarEntries: calendarEntries,
      sortScore: _asInt(data['sortScore']),
      milecatchRatingAverage: _asNullableDouble(data['milecatchRatingAverage']),
      milecatchRatingCount: _asInt(data['milecatchRatingCount']),
      milecatchRatingSum: _asInt(data['milecatchRatingSum']),
    );
  }

  String get locationText {
    final parts = [city, country].where((part) => part.isNotEmpty);
    return parts.isEmpty ? address : parts.join(', ');
  }

  String get hostText => brand.isEmpty ? programText : '$brand이(가) 호스팅';

  String get programText => loyaltyProgram.isEmpty ? brand : loyaltyProgram;

  bool get isMarriottBonvoy {
    final haystack = [
      loyaltyProgram,
      officialUrl,
      propertyCode,
    ].join(' ').toLowerCase();
    return haystack.contains('marriott') ||
        officialUrl.contains('marriott.com');
  }

  bool get hasAwardRate => pointsPerNight > 0;

  bool get hasCashRate => cashPerNightKrw > 0;

  bool get hasMilecatchReviews =>
      milecatchRatingCount > 0 && milecatchRatingAverage != null;

  String get milecatchRatingText {
    if (!hasMilecatchReviews) return '아직 마일캐치 리뷰 없음';
    return '${milecatchRatingAverage!.toStringAsFixed(1)} · 마일캐치 리뷰 $milecatchRatingCount개';
  }

  double get krwPerPoint {
    if (!hasAwardRate || !hasCashRate) return 0;
    return cashPerNightKrw / pointsPerNight;
  }

  int awardPointsForNights(int nights) {
    if (nights <= 0 || !hasAwardRate) return 0;
    if ((isMarriottBonvoy || brand.toLowerCase().contains('hilton')) &&
        nights >= 5) {
      return pointsPerNight * (nights - (nights ~/ 5));
    }
    return pointsPerNight * nights;
  }

  List<PointHotelAmenity> get displayAmenities {
    if (amenityDetails.isNotEmpty) return amenityDetails;
    return amenities
        .map((title) => PointHotelAmenity(title: title))
        .toList(growable: false);
  }

  String get searchableText {
    return [
      name,
      city,
      country,
      address,
      brand,
      loyaltyProgram,
      propertyCode,
    ].join(' ').toLowerCase();
  }
}

List<PointHotelCalendarEntry> _calendarEntriesFromPreview(dynamic value) {
  return _asMapList(value)
      .where((data) => data['available'] != false)
      .map(PointHotelCalendarEntry.fromMap)
      .where((entry) => entry.date.isNotEmpty)
      .toList(growable: false);
}

String _calendarNote(
  Map<String, dynamic> currentAward,
  List<PointHotelCalendarEntry> entries,
) {
  if (_asInt(currentAward['pointsPerNight']) > 0 || entries.isNotEmpty) {
    return '';
  }
  return '포인트/현금가 캘린더는 아직 수집 전입니다.';
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _asInt(value);
  return parsed == 0 ? null : parsed;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _asStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => _asString(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! Iterable) return const <Map<String, dynamic>>[];
  return value
      .map(_asMap)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
