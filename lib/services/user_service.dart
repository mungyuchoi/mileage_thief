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
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'postsCount': 0,
      'commentCount': 0,
      'likesReceived': 0,
      'likesCount': 0,
      'reportedCount': 0,
      'reportSubmittedCount': 0,
      'grade': '이코노미',
      'gradeLevel': 1,
      'displayGrade': '이코노미 Lv.1',
      'title': '',
      'gradeUpdatedAt': FieldValue.serverTimestamp(),
      'peanutCount': peanutCount,
      'peanutCountLimit': 3,
      'adBonusPercent': 0,
      'badgeVisible': true,
      'roles': ['user'],
      'isBanned': false,
      'warnCount': 0,
      'fcmToken': fcmToken ?? '',
      'followingCount': 0,
      'followerCount': 0,
      'photoURLChangeCount': 0,
      'displayNameChangeCount': 0,
      'photoURLEnable': true,
      'displayNameEnable': true,
      'ownedEffects': [],
      'currentSkyEffect': null,
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

  // peanutCountLimit 필드 추가/업데이트 (기존 사용자용)
  static Future<void> ensurePeanutCountLimit(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'peanutCountLimit': 3,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('peanutCountLimit 필드 추가 완료: $uid');
    } catch (e) {
      print('peanutCountLimit 필드 추가 오류: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기 + peanutCountLimit 자동 추가
  static Future<Map<String, dynamic>?> getUserFromFirestoreWithLimit(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        
        // peanutCountLimit 필드가 없으면 추가
        if (!data.containsKey('peanutCountLimit')) {
          await ensurePeanutCountLimit(uid);
          // 업데이트된 데이터 다시 가져오기
          final updatedDoc = await _firestore.collection(_usersCollection).doc(uid).get();
          return updatedDoc.data();
        }
        
        return data;
      }
      return null;
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      rethrow;
    }
  }

  // 회원 탈퇴 시 모든 데이터 삭제 (cancel_subscriptions, notification_history 포함)
  static Future<void> deleteUserFromFirestore(String uid) async {
    final batch = _firestore.batch();
    // 1. users/{uid} 삭제
    batch.delete(_firestore.collection(_usersCollection).doc(uid));

    // 2. cancel_subscriptions/{uid}/items 전체 삭제
    final cancelSubsItems = await _firestore.collection('cancel_subscriptions').doc(uid).collection('items').get();
    for (final doc in cancelSubsItems.docs) {
      batch.delete(doc.reference);
    }
    // 2-1. cancel_subscriptions/{uid} 문서도 삭제
    batch.delete(_firestore.collection('cancel_subscriptions').doc(uid));

    // 3. notification_history/{uid}/items 전체 삭제
    final notifHistoryItems = await _firestore.collection('notification_history').doc(uid).collection('items').get();
    for (final doc in notifHistoryItems.docs) {
      batch.delete(doc.reference);
    }
    // 3-1. notification_history/{uid} 문서도 삭제
    batch.delete(_firestore.collection('notification_history').doc(uid));

    // 일괄 커밋
    await batch.commit();
    print('회원 탈퇴 관련 모든 데이터 삭제 완료: $uid');
  }

  // 변경권 관련 메서드들
  // 프로필 이미지 변경 가능 여부 확인
  static Future<bool> canChangePhotoURL(String uid) async {
    try {
      final userData = await getUserFromFirestore(uid);
      if (userData == null) return false;
      
      final changeCount = userData['photoURLChangeCount'] ?? 0;
      final peanutCount = userData['peanutCount'] ?? 0;
      
      // 1회 무료 변경 가능하거나 땅콩이 50개 이상 있으면 변경 가능
      return changeCount < 1 || peanutCount >= 50;
    } catch (e) {
      print('프로필 이미지 변경 가능 여부 확인 오류: $e');
      return false;
    }
  }

  // 닉네임 변경 가능 여부 확인
  static Future<bool> canChangeDisplayName(String uid) async {
    try {
      final userData = await getUserFromFirestore(uid);
      if (userData == null) return false;
      
      final changeCount = userData['displayNameChangeCount'] ?? 0;
      final peanutCount = userData['peanutCount'] ?? 0;
      
      // 1회 무료 변경 가능하거나 땅콩이 30개 이상 있으면 변경 가능
      return changeCount < 1 || peanutCount >= 30;
    } catch (e) {
      print('닉네임 변경 가능 여부 확인 오류: $e');
      return false;
    }
  }

  // 프로필 이미지 변경 처리 (땅콩 차감 포함)
  static Future<void> changePhotoURL(String uid, String newPhotoURL) async {
    try {
      final userData = await getUserFromFirestore(uid);
      if (userData == null) throw Exception('사용자 정보를 찾을 수 없습니다.');
      
      final changeCount = userData['photoURLChangeCount'] ?? 0;
      final currentPeanutCount = userData['peanutCount'] ?? 0;
      
      // 변경 횟수 증가
      final newChangeCount = changeCount + 1;
      
      // 땅콩 차감 (무료 변경이 아닌 경우)
      int newPeanutCount = currentPeanutCount;
      if (changeCount >= 1) {
        if (currentPeanutCount < 50) {
          throw Exception('땅콩이 부족합니다. (필요: 50개, 보유: $currentPeanutCount개)');
        }
        newPeanutCount = currentPeanutCount - 50;
      }
      
      // Firestore 업데이트
      await _firestore.collection(_usersCollection).doc(uid).update({
        'photoURL': newPhotoURL,
        'photoURLChangeCount': newChangeCount,
        'photoURLEnable': false, // 변경 후 비활성화
        'peanutCount': newPeanutCount,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('프로필 이미지 변경 완료: $uid, 변경 횟수: $newChangeCount, 땅콩 차감: ${changeCount >= 1 ? 50 : 0}');
    } catch (e) {
      print('프로필 이미지 변경 오류: $e');
      rethrow;
    }
  }

  // 닉네임 변경 처리 (땅콩 차감 포함)
  static Future<void> changeDisplayName(String uid, String newDisplayName) async {
    try {
      final userData = await getUserFromFirestore(uid);
      if (userData == null) throw Exception('사용자 정보를 찾을 수 없습니다.');
      
      final changeCount = userData['displayNameChangeCount'] ?? 0;
      final currentPeanutCount = userData['peanutCount'] ?? 0;
      
      // 변경 횟수 증가
      final newChangeCount = changeCount + 1;
      
      // 땅콩 차감 (무료 변경이 아닌 경우)
      int newPeanutCount = currentPeanutCount;
      if (changeCount >= 1) {
        if (currentPeanutCount < 30) {
          throw Exception('땅콩이 부족합니다. (필요: 30개, 보유: $currentPeanutCount개)');
        }
        newPeanutCount = currentPeanutCount - 30;
      }
      
      // Firestore 업데이트
      await _firestore.collection(_usersCollection).doc(uid).update({
        'displayName': newDisplayName,
        'displayNameChangeCount': newChangeCount,
        'displayNameEnable': false, // 변경 후 비활성화
        'peanutCount': newPeanutCount,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('닉네임 변경 완료: $uid, 변경 횟수: $newChangeCount, 땅콩 차감: ${changeCount >= 1 ? 30 : 0}');
    } catch (e) {
      print('닉네임 변경 오류: $e');
      rethrow;
    }
  }

  // 변경권 구매 가격 조회
  static Map<String, int> getChangePrices() {
    return {
      'photoURL': 50,
      'displayName': 30,
    };
  }
}

Future<void> migrateAllUsersToCommunitySchema() async {
  final users = await FirebaseFirestore.instance.collection('users').get();
  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    // md 기준 누락 필드 모두 추가
    if (!data.containsKey('joinedAt')) updates['joinedAt'] = FieldValue.serverTimestamp();
    if (!data.containsKey('postCount')) updates['postCount'] = 0;
    if (!data.containsKey('commentCount')) updates['commentCount'] = 0;
    if (!data.containsKey('likesReceived')) updates['likesReceived'] = 0;
    if (!data.containsKey('reportedCount')) updates['reportedCount'] = 0;
    if (!data.containsKey('reportSubmittedCount')) updates['reportSubmittedCount'] = 0;
    if (!data.containsKey('grade')) updates['grade'] = '이코노미';
    if (!data.containsKey('gradeLevel')) updates['gradeLevel'] = 1;
    if (!data.containsKey('displayGrade')) updates['displayGrade'] = '이코노미 Lv.1';
    if (!data.containsKey('title')) updates['title'] = '';
    if (!data.containsKey('gradeUpdatedAt')) updates['gradeUpdatedAt'] = FieldValue.serverTimestamp();
    if (!data.containsKey('adBonusPercent')) updates['adBonusPercent'] = 0;
    if (!data.containsKey('badgeVisible')) updates['badgeVisible'] = true;
    if (!data.containsKey('roles')) updates['roles'] = ['user'];
    if (!data.containsKey('isBanned')) updates['isBanned'] = false;
    if (!data.containsKey('warnCount')) updates['warnCount'] = 0;
    if (!data.containsKey('followingCount')) updates['followingCount'] = 0;
    if (!data.containsKey('followerCount')) updates['followerCount'] = 0;

    // 이미 있는 필드는 건드리지 않음
    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
    }
  }
  print('모든 기존 사용자 문서가 커뮤니티 스키마로 마이그레이션 완료!');
}

// 변경권 시스템 필드 마이그레이션
Future<void> migrateUsersToChangeSystem() async {
  final users = await FirebaseFirestore.instance.collection('users').get();
  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    // 변경권 시스템 필드 추가
    if (!data.containsKey('photoURLChangeCount')) updates['photoURLChangeCount'] = 0;
    if (!data.containsKey('displayNameChangeCount')) updates['displayNameChangeCount'] = 0;
    if (!data.containsKey('photoURLEnable')) updates['photoURLEnable'] = true;
    if (!data.containsKey('displayNameEnable')) updates['displayNameEnable'] = true;

    // 이미 있는 필드는 건드리지 않음
    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      print('사용자 ${doc.id}의 변경권 시스템 필드 추가 완료');
    }
  }
  print('모든 기존 사용자 문서에 변경권 시스템 필드 마이그레이션 완료!');
}

// 스카이 이펙트 시스템 필드 마이그레이션
Future<void> migrateUsersToSkyEffectSystem() async {
  final users = await FirebaseFirestore.instance.collection('users').get();
  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    // 스카이 이펙트 시스템 필드 추가
    if (!data.containsKey('ownedEffects')) updates['ownedEffects'] = [];
    if (!data.containsKey('currentSkyEffect')) updates['currentSkyEffect'] = null;

    // 업데이트가 필요한 경우만 실행
    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      print('사용자 ${doc.id}의 스카이 이펙트 시스템 필드 추가 완료');
    }
  }
  print('모든 기존 사용자 문서에 스카이 이펙트 시스템 필드 마이그레이션 완료!');
}