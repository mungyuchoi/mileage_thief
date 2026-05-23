import 'package:cloud_firestore/cloud_firestore.dart';

import 'point_hotel_model.dart';

enum PointAwardIndexSort { value, points, recent }

class PointAwardIndexItem {
  final String id;
  final String candidateId;
  final String hotelId;
  final String programId;
  final String brand;
  final String name;
  final String city;
  final String country;
  final String address;
  final String imageUrl;
  final String loyaltyProgram;
  final String propertyCode;
  final String officialUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int pointsTotal;
  final int cashTotalKrw;
  final int pointsPerNight;
  final int cashPerNightKrw;
  final double krwPerPoint;
  final int valueScore;
  final double rating;
  final bool guestFavorite;
  final double confidence;
  final DateTime? updatedAt;

  const PointAwardIndexItem({
    required this.id,
    required this.candidateId,
    required this.hotelId,
    required this.programId,
    required this.brand,
    required this.name,
    required this.city,
    required this.country,
    required this.address,
    required this.imageUrl,
    required this.loyaltyProgram,
    required this.propertyCode,
    required this.officialUrl,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.pointsTotal,
    required this.cashTotalKrw,
    required this.pointsPerNight,
    required this.cashPerNightKrw,
    required this.krwPerPoint,
    required this.valueScore,
    required this.rating,
    required this.guestFavorite,
    required this.confidence,
    this.updatedAt,
  });

  factory PointAwardIndexItem.fromMap(
    Map<String, dynamic> data, {
    DateTime? indexUpdatedAt,
  }) {
    final checkIn = _asDate(data['checkInDate']);
    final nights = _asInt(data['nights']);
    final checkOut = _asDate(
      data['checkOutDate'],
      fallback: checkIn.add(Duration(days: nights > 0 ? nights : 1)),
    );
    final candidateId = _asString(data['candidateId']);

    return PointAwardIndexItem(
      id: candidateId,
      candidateId: candidateId,
      hotelId: _asString(data['hotelId']),
      programId: _asString(data['programId']),
      brand: _asString(data['brand']),
      name: _asString(data['name']),
      city: _asString(data['city']),
      country: _asString(data['country']),
      address: _asString(data['address']),
      imageUrl: _asString(data['imageUrl']),
      loyaltyProgram: _asString(data['loyaltyProgram']),
      propertyCode: _asString(data['propertyCode']),
      officialUrl: _asString(data['officialUrl']),
      checkIn: checkIn,
      checkOut: checkOut,
      nights: nights,
      pointsTotal: _asInt(data['pointsTotal']),
      cashTotalKrw: _asInt(data['cashTotalKrw']),
      pointsPerNight: _asInt(data['pointsPerNight']),
      cashPerNightKrw: _asInt(data['cashPerNightKrw']),
      krwPerPoint: _asDouble(data['krwPerPoint']),
      valueScore: _asInt(data['valueScore']),
      rating: _asDouble(data['rating']),
      guestFavorite: data['guestFavorite'] is bool
          ? data['guestFavorite'] as bool
          : _asDouble(data['rating']) >= 4.5,
      confidence: _asDouble(data['confidence']),
      updatedAt: _asDateTime(data['updatedAt']) ?? indexUpdatedAt,
    );
  }

  String get locationText {
    final parts = [city, country].where((part) => part.isNotEmpty);
    return parts.isEmpty ? address : parts.join(', ');
  }

  double get usdTotal => cashTotalKrw / 1350;

  String updatedLabel({DateTime? now}) {
    final checkedAt = updatedAt;
    if (checkedAt == null) return '최근 확인';
    final diff = (now ?? DateTime.now()).difference(checkedAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  PointHotel toPointHotel() {
    return PointHotel(
      id: hotelId,
      name: name,
      city: city,
      country: country,
      address: address,
      brand: brand,
      imageUrl: imageUrl,
      galleryUrls: imageUrl.isEmpty ? const [] : [imageUrl],
      rating: rating,
      pointsPerNight: pointsPerNight > 0
          ? pointsPerNight
          : nights > 0
              ? (pointsTotal / nights).round()
              : pointsTotal,
      cashPerNightKrw: cashPerNightKrw > 0
          ? cashPerNightKrw
          : nights > 0
              ? (cashTotalKrw / nights).round()
              : cashTotalKrw,
      guestFavorite: guestFavorite,
      description: '',
      amenities: const [],
      calendarPoints: const [],
      loyaltyProgram: loyaltyProgram,
      propertyCode: propertyCode,
      officialUrl: officialUrl,
    );
  }
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

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ??
      fallback ??
      DateTime.now();
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

List<Map<String, dynamic>> asPointAwardIndexItemMaps(dynamic value) {
  if (value is! Iterable) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}
