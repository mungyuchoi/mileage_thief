import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/point_hotel_model.dart';

class PointHotelLikeService {
  PointHotelLikeService._();

  static final PointHotelLikeService instance = PointHotelLikeService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'liked_hotels';

  DocumentReference<Map<String, dynamic>> _hotelLikeRef(
    String uid,
    String hotelId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(hotelId);
  }

  Stream<bool> watchLiked({
    required String uid,
    required String hotelId,
  }) {
    if (hotelId.isEmpty) return Stream<bool>.value(false);
    return _hotelLikeRef(uid, hotelId).snapshots().map((doc) => doc.exists);
  }

  Future<void> setLiked({
    required String uid,
    required PointHotel hotel,
    required bool liked,
  }) async {
    if (hotel.id.isEmpty) return;

    final ref = _hotelLikeRef(uid, hotel.id);
    if (!liked) {
      await ref.delete();
      return;
    }

    await ref.set({
      'hotelId': hotel.id,
      'hotelPath': 'pointHotels/${hotel.id}',
      'name': hotel.name,
      'brand': hotel.brand,
      'locationText': hotel.locationText,
      'address': hotel.address,
      'imageUrl': hotel.imageUrl,
      'loyaltyProgram': hotel.loyaltyProgram,
      'propertyCode': hotel.propertyCode,
      'rating': hotel.rating,
      'pointsPerNight': hotel.pointsPerNight,
      'cashPerNightKrw': hotel.cashPerNightKrw,
      'likedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
