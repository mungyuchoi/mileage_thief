import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'branch_service.dart';
import 'user_service.dart';
import '../utils/community_access_level.dart';

/// 세계지도(딱칵) 기록을 커뮤니티 글로 만들고 Branch 공유 시트를 띄운다.
///
/// 웹(milecatch)에서 JS 브리지 `share.openSheet` 로 호출된다.
/// 글 생성 흐름은 community_post_create_screen_v3 의 스키마를 그대로 따른다
/// (posts/{yyyyMMdd}/posts/{postId} + meta/postNumber 트랜잭션 + my_posts).
class WorldShareService {
  static const _uuid = Uuid();

  /// 기록을 커뮤니티 글로 발행하고 공유 시트를 연다.
  /// 반환: 생성된 postId (실패 시 null).
  static Future<String?> shareRecordToCommunity({
    required String title,
    required String description,
    String boardId = 'review',
    String boardName = '항공 리뷰',
    String imageUrl = '',
    String countryNameKo = '',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[WorldShare] 로그인 필요');
      return null;
    }

    try {
      final userProfile =
          await UserService.getUserFromFirestore(currentUser.uid);
      if (userProfile == null) {
        debugPrint('[WorldShare] 사용자 프로필 없음');
        return null;
      }

      final now = DateTime.now();
      final dateString = DateFormat('yyyyMMdd').format(now);
      final postId = _uuid.v4();

      // postNumber 트랜잭션 +1
      final int allocatedPostNumber =
          await FirebaseFirestore.instance.runTransaction((transaction) async {
        final metaRef =
            FirebaseFirestore.instance.collection('meta').doc('postNumber');
        final snap = await transaction.get(metaRef);
        final int current = (snap.exists
            ? ((snap.data() as Map<String, dynamic>?)?['number'] ?? 0)
            : 0) as int;
        final int next = current + 1;
        transaction.set(metaRef, {'number': next}, SetOptions(merge: true));
        return next;
      });

      final safeTitle = title.trim().isEmpty
          ? '${countryNameKo.isEmpty ? '세계' : countryNameKo} 여행 기록'
          : title.trim();
      final imageHtml = imageUrl.isNotEmpty
          ? '<p><img src="$imageUrl" alt="여행 기록"/></p>'
          : '';
      final contentHtml =
          '$imageHtml<p>${_escapeHtml(description.trim())}</p>'
          '<p>🌍 마일캐치 세계지도에서 남긴 기록</p>';

      final isAdmin = userProfile['roles'] != null &&
          (userProfile['roles'] as List).contains('admin');

      final postData = <String, dynamic>{
        'postId': postId,
        'postNumber': allocatedPostNumber.toString(),
        'boardId': boardId,
        'title': safeTitle,
        'contentHtml': contentHtml,
        'author': {
          'uid': currentUser.uid,
          'displayName': userProfile['displayName'] ?? '익명',
          'photoURL': userProfile['photoURL'] ?? '',
          'displayGrade': isAdmin
              ? '★★★'
              : (userProfile['displayGrade'] ?? '이코노미 Lv.1'),
          'currentSkyEffect': userProfile['currentSkyEffect'] ?? '',
        },
        'viewsCount': 0,
        'likesCount': 0,
        'commentCount': 0,
        'reportsCount': 0,
        'isDeleted': false,
        'isHidden': false,
        'hiddenByReport': false,
        'readRestriction': CommunityAccessLevel.unrestrictedMap(),
        'labels': const <dynamic>[],
        'labelKeys': const <dynamic>[],
        'source': 'world_map',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(dateString)
          .collection('posts')
          .doc(postId);
      final myPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('my_posts')
          .doc(postId);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      final batch = FirebaseFirestore.instance.batch();
      batch.set(postRef, postData);
      batch.set(myPostRef, {
        'postPath': 'posts/$dateString/posts/$postId',
        'title': safeTitle,
        'boardId': boardId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {'postsCount': FieldValue.increment(1)});
      await batch.commit();

      // 검증된 네이티브 Branch 공유 시트 재사용
      await BranchService().showShareSheet(
        postId: postId,
        dateString: dateString,
        boardId: boardId,
        boardName: boardName,
        title: safeTitle,
        description: description.trim(),
      );

      return postId;
    } catch (e, st) {
      debugPrint('[WorldShare] 공유 실패: $e\n$st');
      return null;
    }
  }

  static String _escapeHtml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
