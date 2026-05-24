import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/point_hotel_model.dart';
import '../models/point_hotel_review_model.dart';

class PointHotelReviewService {
  PointHotelReviewService._();

  static final PointHotelReviewService instance = PointHotelReviewService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String collectionName = 'reviews';
  static const String userCollectionName = 'hotel_reviews';

  CollectionReference<Map<String, dynamic>> _reviewsRef(String hotelId) {
    return _firestore
        .collection('pointHotels')
        .doc(hotelId)
        .collection(collectionName);
  }

  DocumentReference<Map<String, dynamic>> _userReviewRef(
    String uid,
    String reviewId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(userCollectionName)
        .doc(reviewId);
  }

  Stream<List<PointHotelReview>> watchRecentReviews({
    required String hotelId,
    int limit = 2,
  }) {
    if (hotelId.isEmpty) {
      return Stream<List<PointHotelReview>>.value(const []);
    }
    return _reviewsRef(hotelId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(PointHotelReview.fromFirestore)
            .where((review) => !review.isDeleted)
            .toList(growable: false));
  }

  Future<PointHotelReviewPage> fetchReviews({
    required String hotelId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    if (hotelId.isEmpty) {
      return const PointHotelReviewPage(
        reviews: [],
        lastDocument: null,
        hasMore: false,
      );
    }

    Query<Map<String, dynamic>> query = _reviewsRef(hotelId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final reviews = snapshot.docs
        .map(PointHotelReview.fromFirestore)
        .where((review) => !review.isDeleted)
        .toList(growable: false);
    return PointHotelReviewPage(
      reviews: reviews,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<void> addReview({
    required PointHotel hotel,
    required int rating,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('login-required');
    }
    final trimmed = content.trim();
    if (hotel.id.isEmpty || trimmed.isEmpty) {
      throw ArgumentError('invalid-review');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final displayName = _firstNonEmpty([
      userData['displayName'],
      user.displayName,
      '익명',
    ]);
    final photoURL = _firstNonEmpty([
      userData['photoURL'],
      user.photoURL,
      '',
    ]);
    final reviewRef = _reviewsRef(hotel.id).doc();
    final userReviewRef = _userReviewRef(user.uid, reviewRef.id);
    final now = FieldValue.serverTimestamp();
    final safeRating = rating.clamp(1, 5).toInt();

    final sourceData = <String, dynamic>{
      'reviewId': reviewRef.id,
      'hotelId': hotel.id,
      'authorId': user.uid,
      'authorDisplayName': displayName,
      'authorPhotoURL': photoURL,
      'rating': safeRating,
      'content': trimmed,
      'hotelName': hotel.name,
      'brand': hotel.brand,
      'locationText': hotel.locationText,
      'imageUrl': hotel.imageUrl,
      'createdAt': now,
      'updatedAt': now,
      'isDeleted': false,
    };

    final mirrorData = <String, dynamic>{
      'reviewPath': 'pointHotels/${hotel.id}/reviews/${reviewRef.id}',
      'hotelId': hotel.id,
      'hotelName': hotel.name,
      'brand': hotel.brand,
      'locationText': hotel.locationText,
      'imageUrl': hotel.imageUrl,
      'rating': safeRating,
      'content': trimmed,
      'createdAt': now,
    };

    final batch = _firestore.batch();
    batch.set(reviewRef, sourceData);
    batch.set(userReviewRef, mirrorData);
    await batch.commit();
  }

  Future<void> deleteReview(PointHotelReview review) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != review.authorId) {
      throw StateError('permission-denied');
    }
    final batch = _firestore.batch();
    batch.delete(_reviewsRef(review.hotelId).doc(review.id));
    batch.delete(_userReviewRef(user.uid, review.id));
    await batch.commit();
  }
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
