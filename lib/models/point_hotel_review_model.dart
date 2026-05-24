import 'package:cloud_firestore/cloud_firestore.dart';

class PointHotelReview {
  final String id;
  final String hotelId;
  final String authorId;
  final String authorDisplayName;
  final String authorPhotoURL;
  final int rating;
  final String content;
  final String hotelName;
  final String brand;
  final String locationText;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  const PointHotelReview({
    required this.id,
    required this.hotelId,
    required this.authorId,
    required this.authorDisplayName,
    required this.authorPhotoURL,
    required this.rating,
    required this.content,
    required this.hotelName,
    required this.brand,
    required this.locationText,
    required this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory PointHotelReview.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PointHotelReview(
      id: _asString(data['reviewId'], fallback: doc.id),
      hotelId: _asString(data['hotelId']),
      authorId: _asString(data['authorId']),
      authorDisplayName: _asString(data['authorDisplayName'], fallback: '익명'),
      authorPhotoURL: _asString(data['authorPhotoURL']),
      rating: _asRating(data['rating']),
      content: _asString(data['content']),
      hotelName: _asString(data['hotelName']),
      brand: _asString(data['brand']),
      locationText: _asString(data['locationText']),
      imageUrl: _asString(data['imageUrl']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class PointHotelReviewPage {
  final List<PointHotelReview> reviews;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PointHotelReviewPage({
    required this.reviews,
    required this.lastDocument,
    required this.hasMore,
  });
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asRating(dynamic value) {
  final parsed = value is num ? value.round() : int.tryParse('$value') ?? 0;
  return parsed.clamp(1, 5);
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
