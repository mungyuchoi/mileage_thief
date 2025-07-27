import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screen/community_detail_screen.dart';
import '../screen/user_profile_screen.dart';
import '../screen/my_page_screen.dart';

class CommunityNotificationHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 사용자의 알림 히스토리 실시간 조회
  static Stream<List<Map<String, dynamic>>> getNotificationHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('receivedAt', descending: true)
        .limit(50) // 최대 50개까지만 조회
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id, // 문서 ID 포함
            }).toList());
  }

  /// 읽지 않은 알림 개수 실시간 조회
  static Stream<int> getUnreadCount(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 특정 알림을 읽음 처리
  static Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('알림 읽음 처리 오류: $e');
    }
  }

  /// 모든 알림을 읽음 처리
  static Future<void> markAllAsRead(String uid) async {
    try {
      final unreadNotifications = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('전체 읽음 처리 오류: $e');
    }
  }

  /// 일주일 지난 오래된 알림들 삭제 (로그인 시 호출)
  static Future<void> cleanupOldNotifications(String uid) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      final oldNotifications = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('receivedAt', isLessThan: oneWeekAgo)
          .get();

      final batch = _firestore.batch();
      for (var doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('오래된 알림 ${oldNotifications.docs.length}개 삭제 완료');
    } catch (e) {
      print('오래된 알림 삭제 오류: $e');
    }
  }

  /// 알림 클릭 시 읽음 처리 + 딥링크 네비게이션
  static Future<void> handleNotificationTap(
    BuildContext context,
    String uid,
    Map<String, dynamic> notification,
  ) async {
    // 1. 읽음 처리 (읽지 않은 상태인 경우만)
    if (notification['isRead'] == false) {
      await markAsRead(uid, notification['id']);
    }

    // 2. 딥링크 네비게이션
    navigateFromNotification(context, notification['data']);
  }

  /// 알림 데이터에 따른 네비게이션 처리
  static void navigateFromNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    try {
      final deepLinkType = data['deepLinkType'] as String?;

      switch (deepLinkType) {
        case 'post_detail':
          // 게시글 상세 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(
                postId: data['postId'] ?? '',
                boardId: data['boardId'] ?? '',
                boardName: data['boardName'] ?? '',
                dateString: data['dateString'] ?? '',
                scrollToCommentId: data['scrollToCommentId'], // 댓글로 스크롤
              ),
            ),
          );
          break;

        case 'user_profile':
          // 사용자 프로필 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userUid: data['authorUid'] ?? '',
              ),
            ),
          );
          break;

        case 'my_page':
          // 마이페이지로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyPageScreen(),
            ),
          );
          break;

        default:
          print('알 수 없는 딥링크 타입: $deepLinkType');
          break;
      }
    } catch (e) {
      print('알림 네비게이션 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('페이지를 열 수 없습니다.')),
      );
    }
  }

  /// 알림 타입에 따른 아이콘 반환
  static IconData getNotificationIcon(String type) {
    switch (type) {
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      case 'mention':
        return Icons.reply;
      case 'follow':
        return Icons.person_add;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  /// 알림 타입에 따른 아이콘 색상 반환
  static Color getNotificationIconColor(String type) {
    switch (type) {
      case 'comment':
        return Colors.blue;
      case 'like':
        return Colors.red;
      case 'mention':
        return Colors.green;
      case 'follow':
        return Colors.purple;
      case 'system':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// 시간 포맷팅 (오늘, 어제, MM.dd)
  static String formatNotificationTime(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final notificationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (notificationDate == today) {
        // 오늘: HH:mm 형식
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (notificationDate == today.subtract(const Duration(days: 1))) {
        // 어제
        return '어제';
      } else {
        // 그 외: MM.dd 형식
        return '${dateTime.month}.${dateTime.day}';
      }
    } catch (e) {
      print('시간 포맷팅 오류: $e');
      return '';
    }
  }
} 