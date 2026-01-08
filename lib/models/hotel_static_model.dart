import 'package:cloud_firestore/cloud_firestore.dart';

class HotelStaticModel {
  final String hotelId;
  final String name;
  final String cityId;
  final String regionKey;
  final String areaName;
  final bool isLocal;
  final double starRating;
  final List<String> imageUrls;
  final List<String> amenityTags;
  final int visitCount;
  final String source;
  final String updatedAt;
  final double? reviewScoreInternal; // _reviewScore
  final int? reviewCountInternal; // _reviewCount

  const HotelStaticModel({
    required this.hotelId,
    required this.name,
    required this.cityId,
    required this.regionKey,
    required this.areaName,
    required this.isLocal,
    required this.starRating,
    required this.imageUrls,
    required this.amenityTags,
    required this.visitCount,
    required this.source,
    required this.updatedAt,
    required this.reviewScoreInternal,
    required this.reviewCountInternal,
  });

  factory HotelStaticModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final urls = (data['imageUrls'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final tags = (data['amenityTags'] as List?)?.whereType<String>().toList() ?? const <String>[];
    return HotelStaticModel(
      hotelId: (data['hotelId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      cityId: (data['cityId'] as String?) ?? '',
      regionKey: (data['regionKey'] as String?) ?? '',
      areaName: (data['areaName'] as String?) ?? '',
      isLocal: (data['isLocal'] as bool?) ?? false,
      starRating: (data['starRating'] as num?)?.toDouble() ?? 0.0,
      imageUrls: urls,
      amenityTags: tags,
      visitCount: (data['visitCount'] as num?)?.toInt() ?? 0,
      source: (data['source'] as String?) ?? '',
      updatedAt: (data['updatedAt'] as String?) ?? '',
      reviewScoreInternal: (data['_reviewScore'] as num?)?.toDouble(),
      reviewCountInternal: (data['_reviewCount'] as num?)?.toInt(),
    );
  }
}


