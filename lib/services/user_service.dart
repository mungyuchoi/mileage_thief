import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  // 사용자 데이터 모델
  static Map<String, dynamic> _createUserData(User user, int peanutCount, {String? fcmToken}) {
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'peanutCount': peanutCount,
      'peanutCountLimit': 3,
      'fcmToken': fcmToken ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }

  // 사용자 정보 Firestore에 저장
  static Future<void> saveUserToFirestore(User user, int peanutCount, {String? fcmToken}) async {
    try {
      final userData = _createUserData(user, peanutCount, fcmToken: fcmToken);

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      print('사용자 정보 저장 완료: ${user.uid}');
    } catch (e) {
      print('사용자 정보 저장 오류: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기
  static Future<Map<String, dynamic>?> getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      rethrow;
    }
  }

  // 땅콩 개수 업데이트
  static Future<void> updatePeanutCount(String uid, int newCount) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'peanutCount': newCount,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('땅콩 개수 업데이트 완료: $newCount');
    } catch (e) {
      print('땅콩 개수 업데이트 오류: $e');
      rethrow;
    }
  }

  // 마지막 로그인 시간 업데이트
  static Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('마지막 로그인 시간 업데이트 오류: $e');
      rethrow;
    }
  }

  // 사용자 데이터 삭제
  static Future<void> deleteUserData(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
      print('사용자 데이터 삭제 완료: $uid');
    } catch (e) {
      print('사용자 데이터 삭제 오류: $e');
      rethrow;
    }
  }

  // 사용자가 이미 존재하는지 확인
  static Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('사용자 존재 확인 오류: $e');
      return false;
    }
  }

  // DisplayName만 업데이트
  static Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'displayName': displayName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('DisplayName 업데이트 완료: $displayName');
    } catch (e) {
      print('DisplayName 업데이트 오류: $e');
      rethrow;
    }
  }

  // FCM 토큰 업데이트
  static Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'fcmToken': token,
        'lastFcmUpdate': FieldValue.serverTimestamp(),
      });
      
      print('FCM 토큰 업데이트 완료: $token');
    } catch (e) {
      print('FCM 토큰 업데이트 오류: $e');
      rethrow;
    }
  }
}