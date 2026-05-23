import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/point_hotel_model.dart';

class PointHotelService {
  PointHotelService._();

  static final PointHotelService instance = PointHotelService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<PointHotel>> watchHotels() {
    return _firestore
        .collection('pointHotels')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final hotels = snapshot.docs
          .map(PointHotel.fromFirestore)
          .where((hotel) => hotel.name.isNotEmpty)
          .toList(growable: false);
      final sorted = [...hotels]..sort((a, b) {
          final score = b.sortScore.compareTo(a.sortScore);
          if (score != 0) return score;
          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;
          return a.name.compareTo(b.name);
        });
      debugPrint(
        '[PointHotelService] pointHotels snapshot docs=${snapshot.docs.length} '
        'hotels=${sorted.length}',
      );
      return List<PointHotel>.unmodifiable(sorted);
    }).handleError((Object error, StackTrace stackTrace) {
      debugPrint('[PointHotelService] pointHotels error: $error');
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<PointHotel?> fetchHotel(String hotelId) async {
    if (hotelId.trim().isEmpty) return null;
    final doc = await _firestore.collection('pointHotels').doc(hotelId).get();
    if (!doc.exists) return null;
    final hotel = PointHotel.fromFirestore(doc);
    return hotel.name.isEmpty ? null : hotel;
  }
}
