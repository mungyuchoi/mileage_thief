import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CommunityNotificationTestHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 테스트용 더미 알림 데이터 생성
  static Future<void> generateDummyNotifications(String uid) async {
    try {
      print('테스트용 더미 알림 생성 시작...');

      // 다양한 알림 타입별 더미 데이터
      final dummyNotifications = [
        // 댓글 알림 (읽지 않음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_1',
          'type': 'comment',
          'title': '새 댓글이 달렸습니다',
          'body': 'vory!님이 회원님의 게시글에 댓글을 남겼습니다',
          'data': {
            'postId': 'test_post_123',
            'dateString': '20250109',
            'boardId': 'deal',
            'boardName': '적립/카드 혜택',
            'commentId': 'test_comment_456',
            'authorUid': 'test_user_789',
            'authorName': 'vory!',
            'authorPhotoURL': 'https://via.placeholder.com/50',
            'deepLinkType': 'post_detail',
            'scrollToCommentId': 'test_comment_456'
          },
          'isRead': false,
          'receivedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        
        // 좋아요 알림 (읽지 않음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_2',
          'type': 'like',
          'title': '좋아요를 받았습니다',
          'body': '마일리지킹님이 회원님의 게시글을 좋아합니다',
          'data': {
            'postId': 'test_post_456',
            'dateString': '20250108',
            'boardId': 'question',
            'boardName': '마일리지',
            'authorUid': 'test_user_888',
            'authorName': '마일리지킹',
            'authorPhotoURL': 'https://via.placeholder.com/50',
            'deepLinkType': 'post_detail'
          },
          'isRead': false,
          'receivedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
        },

        // 답글 알림 (읽음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_3',
          'type': 'mention',
          'title': '답글이 달렸습니다',
          'body': '항공덕후님이 회원님께 답글을 남겼습니다',
          'data': {
            'postId': 'test_post_789',
            'dateString': '20250107',
            'boardId': 'review',
            'boardName': '항공 리뷰',
            'commentId': 'test_comment_789',
            'parentCommentId': 'test_comment_123',
            'authorUid': 'test_user_999',
            'authorName': '항공덕후',
            'authorPhotoURL': 'https://via.placeholder.com/50',
            'deepLinkType': 'post_detail',
            'scrollToCommentId': 'test_comment_789'
          },
          'isRead': true,
          'receivedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
        },

        // 시스템 알림 (읽지 않음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_4',
          'type': 'system',
          'title': '등급 업그레이드',
          'body': '축하합니다! 비즈니스 등급으로 승급하셨습니다',
          'data': {
            'deepLinkType': 'my_page',
            'systemType': 'grade_upgrade',
            'newGrade': 'business',
            'newLevel': 1
          },
          'isRead': false,
          'receivedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 5))),
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 5))),
        },

        // 댓글 알림 2 (읽음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_5',
          'type': 'comment',
          'title': '새 댓글이 달렸습니다',
          'body': '마일캐처님이 회원님의 게시글에 댓글을 남겼습니다',
          'data': {
            'postId': 'test_post_111',
            'dateString': '20250106',
            'boardId': 'free',
            'boardName': '자유게시판',
            'commentId': 'test_comment_111',
            'authorUid': 'test_user_111',
            'authorName': '마일캐처',
            'authorPhotoURL': 'https://via.placeholder.com/50',
            'deepLinkType': 'post_detail',
            'scrollToCommentId': 'test_comment_111'
          },
          'isRead': true,
          'receivedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
        },

        // 좋아요 알림 2 (읽지 않음)
        {
          'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}_6',
          'type': 'like',
          'title': '좋아요를 받았습니다',
          'body': '상테크전문가님이 회원님의 게시글을 좋아합니다',
          'data': {
            'postId': 'test_post_222',
            'dateString': '20250105',
            'boardId': 'deal',
            'boardName': '적립/카드 혜택',
            'authorUid': 'test_user_222',
            'authorName': '상테크전문가',
            'authorPhotoURL': 'https://via.placeholder.com/50',
            'deepLinkType': 'post_detail'
          },
          'isRead': false,
          'receivedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))),
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 3))),
        },
      ];

      // Firestore에 배치로 저장
      final batch = _firestore.batch();
      
      for (final notificationData in dummyNotifications) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notificationData['notificationId'] as String);
        
        batch.set(docRef, notificationData);
      }

      await batch.commit();
      
      print('테스트용 더미 알림 ${dummyNotifications.length}개 생성 완료!');
      print('읽지 않은 알림: 4개, 읽은 알림: 2개');
      
    } catch (e) {
      print('더미 알림 생성 오류: $e');
      rethrow;
    }
  }

  /// 테스트용 더미 알림 모두 삭제
  static Future<void> clearAllTestNotifications(String uid) async {
    try {
      print('테스트 알림 삭제 시작...');
      
      final notifications = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('notificationId', isGreaterThan: 'test_')
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('테스트 알림 ${notifications.docs.length}개 삭제 완료!');
      
    } catch (e) {
      print('테스트 알림 삭제 오류: $e');
      rethrow;
    }
  }

  /// 랜덤 더미 알림 1개 추가 (개발 중 테스트용)
  static Future<void> addRandomNotification(String uid) async {
    try {
      final random = Random();
      final types = ['comment', 'like', 'mention', 'system'];
      final type = types[random.nextInt(types.length)];
      final isRead = random.nextBool();
      
      final notificationData = {
        'notificationId': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'title': _getRandomTitle(type),
        'body': _getRandomBody(type),
        'data': _getRandomData(type),
        'isRead': isRead,
        'receivedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationData['notificationId'] as String)
          .set(notificationData);
          
      print('랜덤 알림 생성 완료: $type (읽음: $isRead)');
      
    } catch (e) {
      print('랜덤 알림 생성 오류: $e');
      rethrow;
    }
  }

  static String _getRandomTitle(String type) {
    switch (type) {
      case 'comment':
        return '새 댓글이 달렸습니다';
      case 'like':
        return '좋아요를 받았습니다';
      case 'mention':
        return '답글이 달렸습니다';
      case 'system':
        return '시스템 알림';
      default:
        return '알림';
    }
  }

  static String _getRandomBody(String type) {
    final names = ['테스터1', '테스터2', '마일킹', '항공덕후', '상테크마스터'];
    final randomName = names[Random().nextInt(names.length)];
    
    switch (type) {
      case 'comment':
        return '$randomName님이 회원님의 게시글에 댓글을 남겼습니다';
      case 'like':
        return '$randomName님이 회원님의 게시글을 좋아합니다';
      case 'mention':
        return '$randomName님이 회원님께 답글을 남겼습니다';
      case 'system':
        return '새로운 업데이트가 있습니다';
      default:
        return '알림 내용';
    }
  }

  static Map<String, dynamic> _getRandomData(String type) {
    final random = Random();
    
    switch (type) {
      case 'comment':
      case 'mention':
        return {
          'postId': 'test_post_${random.nextInt(1000)}',
          'dateString': '20250109',
          'boardId': 'deal',
          'boardName': '적립/카드 혜택',
          'commentId': 'test_comment_${random.nextInt(1000)}',
          'authorUid': 'test_user_${random.nextInt(1000)}',
          'authorName': '랜덤유저',
          'authorPhotoURL': 'https://via.placeholder.com/50',
          'deepLinkType': 'post_detail',
          'scrollToCommentId': 'test_comment_${random.nextInt(1000)}'
        };
      case 'like':
        return {
          'postId': 'test_post_${random.nextInt(1000)}',
          'dateString': '20250109',
          'boardId': 'deal',
          'boardName': '적립/카드 혜택',
          'authorUid': 'test_user_${random.nextInt(1000)}',
          'authorName': '랜덤유저',
          'authorPhotoURL': 'https://via.placeholder.com/50',
          'deepLinkType': 'post_detail'
        };
      case 'system':
        return {
          'deepLinkType': 'my_page',
          'systemType': 'general',
        };
      default:
        return {};
    }
  }
} 