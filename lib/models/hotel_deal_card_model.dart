import 'package:cloud_firestore/cloud_firestore.dart';

class HotelDealCardModel {
  final String dealId;
  final String hotelId;
  final String regionKey;
  final String windowKey; // TODAY | TOMORROW | THIS_WEEKEND | NEXT_WEEKEND
  final String name;
  final String imageUrl;
  final double starRating;
  final double reviewScore;
  final int reviewCount;
  final int price;
  final int totalPrice;
  final int discountPct;
  final bool hasFreeCancellation;
  final int? remainingRooms;
  final double dealScore;
  final String bookingUrl;
  final String checkInDate; // YYYY-MM-DD
  final String expiresAt; // ISO string

  const HotelDealCardModel({
    required this.dealId,
    required this.hotelId,
    required this.regionKey,
    required this.windowKey,
    required this.name,
    required this.imageUrl,
    required this.starRating,
    required this.reviewScore,
    required this.reviewCount,
    required this.price,
    required this.totalPrice,
    required this.discountPct,
    required this.hasFreeCancellation,
    required this.remainingRooms,
    required this.dealScore,
    required this.bookingUrl,
    required this.checkInDate,
    required this.expiresAt,
  });

  factory HotelDealCardModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HotelDealCardModel(
      dealId: (data['dealId'] as String?) ?? doc.id,
      hotelId: (data['hotelId'] as String?) ?? '',
      regionKey: (data['regionKey'] as String?) ?? '',
      windowKey: (data['windowKey'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      starRating: (data['starRating'] as num?)?.toDouble() ?? 0.0,
      reviewScore: (data['reviewScore'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toInt() ?? (data['price'] as num?)?.toInt() ?? 0,
      discountPct: (data['discountPct'] as num?)?.toInt() ?? 0,
      hasFreeCancellation: (data['hasFreeCancellation'] as bool?) ?? false,
      remainingRooms: (data['remainingRooms'] as num?)?.toInt(),
      dealScore: (data['dealScore'] as num?)?.toDouble() ?? 0.0,
      bookingUrl: (data['bookingUrl'] as String?) ?? '',
      checkInDate: (data['checkInDate'] as String?) ?? '',
      expiresAt: (data['expiresAt'] as String?) ?? '',
    );
  }
}


