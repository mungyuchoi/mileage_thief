import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screen/community_detail_screen.dart';

class PeanutHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 땅콩 히스토리 추가
  static Future<void> addHistory({
    required String userId,
    required String type,
    required int amount,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final historyRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('peanut_history')
          .doc();

      final baseData = {
        'type': type,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 추가 데이터가 있으면 병합
      final finalData = additionalData != null 
          ? {...baseData, ...additionalData}
          : baseData;

      await historyRef.set(finalData);
    } catch (e) {
      print('땅콩 히스토리 추가 오류: $e');
    }
  }

  /// 땅콩 히스토리 조회
  static Future<List<Map<String, dynamic>>> getHistory(
    String userId, {
    String? filterType,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('peanut_history')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (filterType != null && filterType != 'all') {
        query = query.where('type', isEqualTo: filterType);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('땅콩 히스토리 조회 오류: $e');
      return [];
    }
  }

  /// 콘텐츠로 이동 (딥링크)
  static Future<void> navigateToContent(
    BuildContext context, 
    Map<String, dynamic> historyData,
  ) async {
    final type = historyData['type'] as String;
    
    if (type == 'admin_gift') {
      // 운영자 선물은 이동하지 않음
      return;
    }

    try {
      final postId = historyData['postId'] as String?;
      final dateString = historyData['dateString'] as String?;
      final boardId = historyData['boardId'] as String?;
      final postTitle = historyData['postTitle'] as String?;

      if (postId != null && dateString != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityDetailScreen(
              postId: postId,
              boardId: boardId ?? '',
              boardName: _getBoardName(boardId ?? ''),
              dateString: dateString,
            ),
          ),
        );
      }
    } catch (e) {
      print('딥링크 이동 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해당 게시글을 찾을 수 없습니다.')),
      );
    }
  }

  /// 게시판 이름 가져오기 (임시)
  static String _getBoardName(String boardId) {
    // TODO: 실제 게시판 정보 조회 로직 구현
    switch (boardId) {
      case 'general': return '자유게시판';
      case 'seats': return '오늘의 좌석';
      case 'questions': return 'Q&A';
      default: return '게시판';
    }
  }

  /// 표시용 제목 생성
  static String getDisplayTitle(String type) {
    switch (type) {
      case 'post_create': return '게시글 작성';
      case 'comment_create': return '댓글 작성';
      case 'post_like': return '게시글 좋아요';
      case 'admin_gift': return '운영자 선물';
      default: return '땅콩 획득';
    }
  }

  /// 표시용 부제목 생성
  static String getDisplaySubtitle(Map<String, dynamic> data) {
    final type = data['type'] as String;
    
    switch (type) {
      case 'post_create':
      case 'comment_create':
      case 'post_like':
        return data['postTitle'] as String? ?? '제목 없음';
      case 'admin_gift':
        final reason = data['reason'] as String?;
        final adminName = data['adminName'] as String? ?? '마일캐치';
        return reason != null ? '$adminName: $reason' : adminName;
      default:
        return '';
    }
  }

  /// 아이콘 데이터 가져오기
  static IconData getIcon(String type) {
    switch (type) {
      case 'post_create': return Icons.edit;
      case 'comment_create': return Icons.comment;
      case 'post_like': return Icons.favorite;
      case 'admin_gift': return Icons.card_giftcard;
      default: return Icons.star;
    }
  }

  /// 아이콘 색상 가져오기
  static Color getIconColor(String type) {
    switch (type) {
      case 'post_create': return Colors.blue;
      case 'comment_create': return Colors.green;
      case 'post_like': return Colors.red;
      case 'admin_gift': return Colors.orange;
      default: return Colors.grey;
    }
  }
} 