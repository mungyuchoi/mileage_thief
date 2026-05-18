import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/hotel_award_model.dart';
import '../models/radar_item_model.dart';

class HotelAwardService {
  const HotelAwardService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<List<HotelAwardSnapshot>> watchAwardSnapshots(
    HotelAwardSearchQuery query, {
    int limit = 240,
  }) {
    return _firestore
        .collection('hotel_award_snapshots')
        .orderBy('fetchedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map(HotelAwardSnapshot.fromFirestore)
          .where(query.matches)
          .toList(growable: false);
      return query.sortSnapshots(matches).take(80).toList(growable: false);
    });
  }

  static Stream<List<HotelAwardSnapshot>> watchPropertySnapshots({
    required String propertyId,
    int limit = 120,
  }) {
    return _firestore
        .collection('hotel_award_snapshots')
        .where('propertyId', isEqualTo: propertyId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final snapshots =
          snapshot.docs.map(HotelAwardSnapshot.fromFirestore).toList();
      snapshots.sort((a, b) {
        final date = a.checkIn.compareTo(b.checkIn);
        if (date != 0) return date;
        return b.fetchedAt.compareTo(a.fetchedAt);
      });
      return snapshots;
    });
  }

  static Stream<Set<String>> watchSavedAwardHotelIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(<String>{});
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_award_hotels')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  static Future<void> toggleSavedAwardHotel(
    HotelAwardSnapshot snapshot,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_award_hotels')
        .doc(snapshot.propertyId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      return;
    }

    await ref.set({
      'propertyId': snapshot.propertyId,
      'programId': snapshot.program.id,
      'hotelName': snapshot.hotelName,
      'brand': snapshot.displayBrand,
      'cityName': snapshot.cityName,
      'countryCode': snapshot.countryCode,
      'imageUrl': snapshot.imageUrl,
      'officialUrl': snapshot.officialUrl,
      'lastSnapshotId': snapshot.id,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveAwardAlert({
    required HotelAwardSnapshot snapshot,
    int? maxPoints,
    double? minKrwPerPoint,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final alertId = _alertId(snapshot);
    final conditions = {
      'propertyId': snapshot.propertyId,
      'programId': snapshot.program.id,
      'hotelName': snapshot.hotelName,
      'brand': snapshot.displayBrand,
      'checkInDate': snapshot.checkInKey,
      'checkOutDate': snapshot.checkOutKey,
      'nights': snapshot.nights,
      'maxPoints': maxPoints ?? snapshot.pointsTotal,
      'minKrwPerPoint': minKrwPerPoint ?? snapshot.krwPerPoint,
      'sourceSnapshotId': snapshot.id,
      'officialUrl': snapshot.officialUrl,
    };

    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.collection('hotel_award_alerts').doc(alertId).set({
      'type': RadarItemType.hotelAward,
      'conditions': conditions,
      'isActive': true,
      'pushEnabled': true,
      'lastMatchedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await userRef.collection('radar_subscriptions').doc(alertId).set({
      'type': RadarItemType.hotelAward,
      'conditions': {
        ...conditions,
        'title': '${snapshot.hotelName} 포숙 알림',
        'route': snapshot.displayLocation,
        'dateRange': '${snapshot.checkInKey} · ${snapshot.nights}박',
        'price': snapshot.cashTotalKrw,
        'miles': snapshot.pointsTotal,
        'source': snapshot.program.shortLabel,
        'payload': {
          'hotelAwardAlertId': alertId,
          'propertyId': snapshot.propertyId,
          'programId': snapshot.program.id,
          'officialUrl': snapshot.officialUrl,
        },
      },
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'isActive': true,
      'pushEnabled': true,
      'peanutUsed': 0,
      'lastMatchedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _alertId(HotelAwardSnapshot snapshot) {
    final raw = [
      'hotelAward',
      snapshot.program.id,
      snapshot.propertyId,
      snapshot.checkInKey,
      snapshot.nights.toString(),
    ].join('_');
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
