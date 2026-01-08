import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/hotel_deal_card_model.dart';
import '../models/hotel_region_model.dart';
import '../models/hotel_static_model.dart';
import 'hotel_debug.dart';

class HotelDealsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<HotelRegionModel>> getRegionsStream() {
    hotelLog('getRegionsStream subscribe: collection=hotel_regions where isActive=true orderBy sortOrder');
    return _firestore
        .collection('hotel_regions')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .handleError((e, st) {
          hotelLog('getRegionsStream ERROR: $e');
        })
        .map(
          (snapshot) {
            hotelLog('getRegionsStream snapshot: docs=${snapshot.docs.length}');
            final regions = snapshot.docs
                .map((doc) => HotelRegionModel.fromFirestore(doc))
                .toList();
            if (regions.isNotEmpty) {
              hotelLog('getRegionsStream first=${regions.first.regionKey} name=${regions.first.name}');
            }
            return regions;
          },
        );
  }

  static Stream<List<HotelDealCardModel>> getDealCardsStream({
    required String regionKey,
    required String windowKey,
    int limit = 12,
  }) {
    hotelLog('getDealCardsStream subscribe: regionKey=$regionKey windowKey=$windowKey limit=$limit');
    return _firestore
        .collection('hotel_deal_cards')
        .where('regionKey', isEqualTo: regionKey)
        .where('windowKey', isEqualTo: windowKey)
        .orderBy('dealScore', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((e, st) {
          hotelLog('getDealCardsStream ERROR: regionKey=$regionKey windowKey=$windowKey err=$e');
        })
        .map(
          (snapshot) {
            hotelLog('getDealCardsStream snapshot: regionKey=$regionKey windowKey=$windowKey docs=${snapshot.docs.length}');
            return snapshot.docs
                .map((doc) => HotelDealCardModel.fromFirestore(doc))
                .toList();
          },
        );
  }

  static Stream<HotelDealCardModel?> getDealCardStream(String dealId) {
    return _firestore
        .collection('hotel_deal_cards')
        .doc(dealId)
        .snapshots()
        .map((doc) => doc.exists ? HotelDealCardModel.fromFirestore(doc) : null);
  }

  static Future<HotelStaticModel?> getHotelStatic(String hotelId) async {
    final doc = await _firestore.collection('hotel_static').doc(hotelId).get();
    if (!doc.exists) return null;
    return HotelStaticModel.fromFirestore(doc);
  }

  static Stream<List<Map<String, dynamic>>> getPriceHistoryStream(
    String hotelId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('hotel_static')
        .doc(hotelId)
        .collection('price_history')
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  static Future<void> incrementVisitCount(String hotelId) async {
    try {
      await _firestore
          .collection('hotel_static')
          .doc(hotelId)
          .update({'visitCount': FieldValue.increment(1)});
    } catch (_) {
      // 무시: 문서가 없거나 권한 문제 등
    }
  }

  static Stream<Set<String>> getSavedHotelIdsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(<String>{});

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_hotels')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
  }

  static Future<void> toggleSavedHotel({
    required String hotelId,
    required String name,
    required String imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_hotels')
        .doc(hotelId);

    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      return;
    }

    await ref.set({
      'hotelId': hotelId,
      'name': name,
      'imageUrl': imageUrl,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> upsertHotelHistory({
    required String hotelId,
    required String name,
    required String imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final historyRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('hotel_history');

    await historyRef.doc(hotelId).set({
      'hotelId': hotelId,
      'name': name,
      'imageUrl': imageUrl,
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 최대 20개 유지 (정책)
    try {
      final snap = await historyRef
          .orderBy('viewedAt', descending: true)
          .limit(30)
          .get();
      if (snap.docs.length <= 20) return;

      final toDelete = snap.docs.sublist(20);
      final batch = _firestore.batch();
      for (final d in toDelete) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {
      // 인덱스/필드 없음 등으로 실패할 수 있어 무시
    }
  }
}


