import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/marriott_stay_record.dart';

class MarriottStayService {
  const MarriottStayService._();

  static CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('marriottStays');
  }

  static Stream<List<MarriottStayRecord>> watchUserStays(String uid) {
    return _collection(uid)
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(MarriottStayRecord.fromDoc)
          .toList(growable: false);
    });
  }

  static Future<void> saveStay({
    required String uid,
    required MarriottStayRecord record,
  }) async {
    final collection = _collection(uid);
    final bool isCreate = record.id.trim().isEmpty;
    final ref = isCreate
        ? collection.doc('stay_${DateTime.now().millisecondsSinceEpoch}')
        : collection.doc(record.id);

    final data = record.toFirestoreMap(documentId: ref.id);
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (isCreate) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  static Future<void> deleteStay({
    required String uid,
    required String stayId,
  }) async {
    await _collection(uid).doc(stayId).delete();
  }
}
