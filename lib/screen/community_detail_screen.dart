import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../services/user_service.dart';
import '../services/branch_service.dart';
import '../services/category_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'community_post_create_screen.dart';
import 'user_profile_screen.dart';
import 'my_page_screen.dart';
import '../helper/AdHelper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/image_compressor.dart';

// 무지개 그라데이션 텍스트 위젯
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(this.text, {required this.style, required this.gradient, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class CommunityDetailScreen extends StatefulWidget {
  final String postId;
  final String boardId;
  final String boardName;
  final String dateString;
  final String? scrollToCommentId; // 딥링크용 댓글 스크롤 ID

  const CommunityDetailScreen({
    Key? key,
    required this.postId,
    required this.boardId,
    required this.boardName,
    required this.dateString,
    this.scrollToCommentId, // 딥링크용 댓글 스크롤 ID
  }) : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = true; // 댓글 로딩 상태 추가
  bool _isLiked = false;
  bool _isFollowing = false;
  Map<String, bool> _commentLikes = {}; // 댓글 좋아요 상태 저장
  Set<String> _processingCommentLikes = {}; // 좋아요 처리 중인 댓글 ID들
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();
  String _commentSortOrder = '등록순';
  
  // 답글 관련 상태
  String? _replyingToCommentId; // 답글을 달고 있는 댓글 ID
  Map<String, dynamic>? _replyingToComment; // 답글 대상 댓글 정보
  final GlobalKey _replySectionKey = GlobalKey(); // 답글 섹션으로 스크롤용
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _isAddingComment = false;

  // 딥링크 스크롤용 키들
  final Map<String, GlobalKey> _commentKeys = {};
  final ScrollController _scrollController = ScrollController();

  // 댓글 수정 상태 관리 변수 추가
  String? _editingCommentId;
  String? _editingOriginalContent;

  // 내가 신고한 댓글 ID 목록
  Set<String> _reportedCommentIds = {};
  // 게시글 신고여부 상태
  bool _alreadyReportedPost = false;

  Map<String, dynamic>? _myUserProfile;

  // 광고 위젯 생성 함수
  Widget _buildBannerAd(String adUnitId) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Text(
          '광고 영역 ($adUnitId)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  BannerAd? _profileBannerAd;
  bool _isProfileBannerAdLoaded = false;
  BannerAd? _contentBannerAd;
  bool _isContentBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPostDetail();
    _loadComments();
    _checkUserStatus();
    _loadMyReportedComments();
    _loadMyUserProfile(); // 내 userProfile 불러오기
    _checkIfReportedPost(); // 게시글 신고여부 확인
    _loadProfileBannerAd();
    _loadContentBannerAd();
  }

  void _loadProfileBannerAd() {
    _profileBannerAd = BannerAd(
      adUnitId: AdHelper.postDetailProfileBannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isProfileBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadContentBannerAd() {
    _contentBannerAd = BannerAd(
      adUnitId: AdHelper.postDetailContentBannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isContentBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _profileBannerAd?.dispose();
    _contentBannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadMyUserProfile() async {
    if (_currentUser == null) return;
    final data = await UserService.getUserFromFirestore(_currentUser!.uid);
    setState(() {
      _myUserProfile = data;
    });
  }

  // 내가 신고한 댓글 ID 목록 불러오기
  Future<void> _loadMyReportedComments() async {
    final myUid = _currentUser?.uid;
    if (myUid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .doc('comments')
          .collection('comments')
          .where('reporterUid', isEqualTo: myUid)
          .get();
      setState(() {
        _reportedCommentIds = snapshot.docs.map((doc) => doc['commentId'] as String).toSet();
      });
    } catch (e) {
      print('내가 신고한 댓글 목록 로드 오류: $e');
    }
  }

  Future<void> _loadPostDetail() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final docSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (docSnapshot.exists) {
        final postData = docSnapshot.data() as Map<String, dynamic>;
        
        // 신고 수가 5건 이상이면 자동으로 숨김처리
        final reportsCount = postData['reportsCount'] ?? 0;
        if (reportsCount >= 5 && postData['isHidden'] != true) {
          await docSnapshot.reference.update({
            'isHidden': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          postData['isHidden'] = true;
        }
        
        // 숨김처리된 게시글인 경우 접근 차단
        if (postData['isHidden'] == true) {
          setState(() {
            _isLoading = false;
          });
          _showErrorAndGoBack('해당 게시글은 숨김처리되었습니다.');
          return;
        }

        // 조회수 증가
        await docSnapshot.reference.update({
          'viewsCount': FieldValue.increment(1),
        });

        setState(() {
          _post = postData;
          _post!['viewsCount'] = (_post!['viewsCount'] ?? 0) + 1;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorAndGoBack('게시글을 찾을 수 없습니다.');
      }
    } catch (e) {
      print('게시글 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorAndGoBack('게시글을 불러오는 중 오류가 발생했습니다.');
    }
  }

  Future<void> _refreshData() async {
    try {
      // 게시글과 댓글을 동시에 새로고침
      await Future.wait([
        _loadPostDetailForRefresh(), // 조회수 증가 없이 로드
        _loadComments(),
        _checkUserStatus(),
      ]);
    } catch (e) {
      print('새로고침 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새로고침 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _loadPostDetailForRefresh() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _post = docSnapshot.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print('게시글 새로고침 오류: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoadingComments = true;
      });

      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: _commentSortOrder == '최신순')
          .get();

      final allComments = commentsSnapshot.docs
          .map((doc) => {
                'commentId': doc.id,
                ...doc.data() as Map<String, dynamic>
              })
          .toList();

      // 댓글을 계층 구조로 정렬 (부모 댓글 → 답글 순서)
      final sortedComments = _sortCommentsHierarchically(allComments);

      // 각 댓글의 좋아요 상태 확인
      if (_currentUser != null) {
        final Map<String, bool> commentLikes = {};
        for (final comment in sortedComments) {
          final commentId = comment['commentId'];
          final likeDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.dateString)
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .doc(commentId)
              .collection('likes')
              .doc(_currentUser!.uid)
              .get();

          commentLikes[commentId] = likeDoc.exists;
        }

        setState(() {
          _comments = sortedComments;
          _commentLikes = commentLikes;
          _isLoadingComments = false;
        });
      } else {
        setState(() {
          _comments = sortedComments;
          _isLoadingComments = false;
        });
      }

      // 딥링크로 전달된 댓글로 스크롤
      if (widget.scrollToCommentId != null) {
        _scrollToComment(widget.scrollToCommentId!);
      }
    } catch (e) {
      print('댓글 로드 오류: $e');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  List<Map<String, dynamic>> _sortCommentsHierarchically(List<Map<String, dynamic>> comments) {
    final List<Map<String, dynamic>> parentComments = [];
    final Map<String, List<Map<String, dynamic>>> repliesByParent = {};

    // 댓글을 부모 댓글과 답글로 분류
    for (final comment in comments) {
      final parentId = comment['parentCommentId'];
      
      if (parentId == null) {
        // 원댓글
        parentComments.add(comment);
      } else {
        // 답글 (모든 레벨의 답글 포함)
        if (!repliesByParent.containsKey(parentId)) {
          repliesByParent[parentId] = [];
        }
        repliesByParent[parentId]!.add(comment);
      }
    }
    
    // 부모 댓글들을 선택된 순서로 정렬
    parentComments.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      if (_commentSortOrder == '최신순') {
        return bTime.compareTo(aTime); // 최신순: 내림차순
      } else {
        return aTime.compareTo(bTime); // 등록순: 오름차순
      }
    });

    // 재귀적으로 댓글과 답글들을 추가
    final List<Map<String, dynamic>> finalComments = [];
    for (final parentComment in parentComments) {
      _addCommentAndReplies(parentComment, repliesByParent, finalComments);
    }

    return finalComments;
  }

  void _addCommentAndReplies(
    Map<String, dynamic> comment,
    Map<String, List<Map<String, dynamic>>> repliesByParent,
    List<Map<String, dynamic>> result,
  ) {
    // 현재 댓글 추가
    result.add(comment);
    
    final commentId = comment['commentId'];
    
    if (repliesByParent.containsKey(commentId)) {
      final replies = repliesByParent[commentId]!;
      
      // 답글들을 선택된 순서로 정렬
      replies.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (_commentSortOrder == '최신순') {
          return bTime.compareTo(aTime); // 최신순: 내림차순
        } else {
          return aTime.compareTo(bTime); // 등록순: 오름차순
        }
      });
      
      // 각 답글을 재귀적으로 처리 (답글의 답글도 포함)
      for (final reply in replies) {
        _addCommentAndReplies(reply, repliesByParent, result);
      }
    }
  }

  Future<void> _checkUserStatus() async {
    if (_currentUser == null) return;

    try {
      // 좋아요 상태 확인
      final likeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(_currentUser!.uid)
          .get();

      setState(() {
        _isLiked = likeDoc.exists;
      });
    } catch (e) {
      print('사용자 상태 확인 오류: $e');
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 이미 처리 중인 댓글이면 중복 클릭 방지
    if (_processingCommentLikes.contains(commentId)) {
      return;
    }

    try {
      // 처리 중 상태로 설정
      setState(() {
        _processingCommentLikes.add(commentId);
      });

      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(_currentUser!.uid);
      final isCurrentlyLiked = _commentLikes[commentId] ?? false;

      if (isCurrentlyLiked) {
        // 좋아요 취소
        await likeRef.delete();
        await commentRef.update({
          'likesCount': FieldValue.increment(-1),
        });

        setState(() {
          _commentLikes[commentId] = false;
          // 댓글 목록에서도 업데이트
          final commentIndex = _comments.indexWhere((c) => c['commentId'] == commentId);
          if (commentIndex != -1) {
            _comments[commentIndex]['likesCount'] = (_comments[commentIndex]['likesCount'] ?? 0) - 1;
          }
        });
      } else {
        // 좋아요 추가
        await likeRef.set({
          'uid': _currentUser!.uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await commentRef.update({
          'likesCount': FieldValue.increment(1),
        });

        setState(() {
          _commentLikes[commentId] = true;
          // 댓글 목록에서도 업데이트
          final commentIndex = _comments.indexWhere((c) => c['commentId'] == commentId);
          if (commentIndex != -1) {
            _comments[commentIndex]['likesCount'] = (_comments[commentIndex]['likesCount'] ?? 0) + 1;
          }
        });
      }
    } catch (e) {
      print('댓글 좋아요 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다.')),
      );
    } finally {
      // 처리 완료 후 처리 중 상태 해제
      setState(() {
        _processingCommentLikes.remove(commentId);
      });
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    setState(() {
      _replyingToCommentId = comment['commentId'];
      _replyingToComment = comment;
    });

    // 답글 입력창으로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox = _replySectionKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        Scrollable.ensureVisible(
          _replySectionKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToComment = null;
    });
  }

  void _showErrorAndGoBack(String message) {
    // 토스트 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // 잠시 후 홈화면으로 이동
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // 모든 화면을 pop하고 홈화면으로 이동
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (Route<dynamic> route) => false,
        );
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId);

      final likeRef = postRef.collection('likes').doc(_currentUser!.uid);
      
      // 사용자 문서 참조
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);
      
      // 사용자의 liked_posts 서브컬렉션 참조
      final userLikedPostRef = userRef
          .collection('liked_posts')
          .doc(widget.postId);

      if (_isLiked) {
        // 좋아요 취소
        batch.delete(likeRef);
        batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
        
        // 사용자의 likesCount 감소
        batch.update(userRef, {'likesCount': FieldValue.increment(-1)});
        
        // 사용자의 liked_posts에서 제거
        batch.delete(userLikedPostRef);
        
        setState(() {
          _isLiked = false;
          if (_post != null) {
            _post!['likesCount'] = (_post!['likesCount'] ?? 0) - 1;
          }
        });
      } else {
        // 좋아요 추가
        batch.set(likeRef, {
          'uid': _currentUser!.uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'likesCount': FieldValue.increment(1)});
        
        // 사용자의 likesCount 증가
        batch.update(userRef, {'likesCount': FieldValue.increment(1)});
        
        // 사용자의 liked_posts에 추가
        batch.set(userLikedPostRef, {
          'postPath': 'posts/${widget.dateString}/posts/${widget.postId}',
          'title': _post?['title'] ?? '제목 없음',
          'likedAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _isLiked = true;
          if (_post != null) {
            _post!['likesCount'] = (_post!['likesCount'] ?? 0) + 1;
          }
        });
        // 땅콩 1개 지급
        final userData = await UserService.getUserFromFirestore(_currentUser!.uid);
        if (userData != null) {
          final currentPeanut = userData['peanutCount'] ?? 0;
          final newPeanut = currentPeanut + 1;
          await UserService.updatePeanutCount(_currentUser!.uid, newPeanut);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('땅콩 1개가 추가되었습니다.'),
              backgroundColor: Colors.black38,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      await batch.commit();
    } catch (e) {
      print('좋아요 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUser == null || _post == null) return;

    try {
      final authorId = _post!['author']['uid'];
      if (authorId == _currentUser!.uid) return; // 자기 자신은 팔로우할 수 없음

      setState(() {
        _isFollowing = !_isFollowing;
      });

      // 실제 팔로우 로직은 나중에 구현
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? '팔로우했습니다.' : '팔로우를 취소했습니다.'),
        ),
      );
    } catch (e) {
      print('팔로우 처리 오류: $e');
    }
  }

  void _sharePost() async {
    if (_post != null) {
      final title = _post!['title'] ?? '제목 없음';
      final content = _getPlainTextFromHtml(_post!['contentHtml'] ?? '');
      
      try {
        // Branch.io 딥링크 생성
        await BranchService().showShareSheet(
          postId: widget.postId,
          dateString: widget.dateString,
          boardId: widget.boardId,
          boardName: widget.boardName,
          scrollToCommentId: null, // 게시글 공유이므로 댓글 ID는 null
          title: title,
          description: content.length > 100 ? '${content.substring(0, 100)}...' : content,
        );
      } catch (e) {
        print('Branch 공유 오류: $e');
        // Branch 실패 시 기본 공유로 폴백
        final shareText = '$title\n\n$content\n\n마일캐치 커뮤니티에서 공유';
        Share.share(shareText);
      }
    }
  }



  Widget _buildMoreOptionsMenu() {
    // 프로필 정보가 아직 로드되지 않았다면 ... 메뉴 숨김
    if (_myUserProfile == null) {
      return const SizedBox.shrink();
    }
    // 본인 게시글인지 확인
    final isMyPost = _currentUser?.uid == _post?['author']?['uid'];
    // 내가 이미 신고한 게시글이면 ... 버튼 자체를 숨김
    if (_alreadyReportedPost) {
      return const SizedBox.shrink();
    }
    // 관리자 권한 체크
    final isAdmin = (_myUserProfile?['roles'] ?? []).contains('admin');
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
      color: Colors.white,
      onSelected: (String value) {
        switch (value) {
          case 'edit':
            _editPost();
            break;
          case 'delete':
            _deletePost();
            break;
          case 'report':
            _reportPost();
            break;
          case 'block':
            _blockUser();
            break;
          case 'move':
            _showMoveCategoryDialog();
            break;
          case 'hide':
            _hidePost();
            break;
          case 'unhide':
            _unhidePost();
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];
        if (isMyPost) {
          items.addAll([
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('수정하기'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('삭제하기', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ]);
        } else {
          items.add(
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('신고하기'),
                ],
              ),
            ),
          );
        }
        // 관리자라면 이동하기 옵션 추가 (본인/남의 게시글 상관없이)
        if (isAdmin) {
          items.addAll([
            const PopupMenuItem<String>(
              value: 'move',
              child: Row(
                children: [
                  Icon(Icons.drive_file_move_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('이동하기', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: _post?['isHidden'] == true ? 'unhide' : 'hide',
              child: Row(
                children: [
                  Icon(
                    _post?['isHidden'] == true ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                    color: _post?['isHidden'] == true ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _post?['isHidden'] == true ? '숨김 해제' : '숨김처리',
                    style: TextStyle(
                      color: _post?['isHidden'] == true ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ]);
        }
        return items;
      },
    );
  }

  // 카테고리 이동 다이얼로그
  void _showMoveCategoryDialog() async {
    final CategoryService categoryService = CategoryService();
    final List<Map<String, dynamic>> boards = await categoryService.getBoards();
    String selectedBoardId = _post?['boardId'] ?? widget.boardId;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('카테고리 이동', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 카테고리: ${_getBoardDisplayName(_post?['boardId'] ?? widget.boardId)}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 16),
                  const Text('변경할 카테고리를 선택하세요:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  ...boards.map((board) => RadioListTile<String>(
                        title: Text(board['name']!),
                        value: board['id']!,
                        groupValue: selectedBoardId,
                        onChanged: (value) {
                          setState(() {
                            selectedBoardId = value!;
                          });
                        },
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedBoardId == (_post?['boardId'] ?? widget.boardId)) {
                      Navigator.pop(context);
                      return;
                    }
                    // Firestore 업데이트
                    await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.dateString)
                        .collection('posts')
                        .doc(widget.postId)
                        .update({
                          'boardId': selectedBoardId,
                        });
                    // 화면 갱신
                    await _loadPostDetail();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('카테고리가 변경되었습니다.')),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  child: const Text('이동'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editPost() {
    if (_post == null) return;
    
    // 수정 모드로 게시글 작성 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPostCreateScreen(
          isEditMode: true,
          postId: widget.postId,
          dateString: widget.dateString,
          initialBoardId: widget.boardId,
          initialBoardName: widget.boardName,
          editTitle: _post!['title'] ?? '',
          editContentHtml: _post!['contentHtml'] ?? '',
        ),
      ),
    ).then((result) {
      // 수정 완료 후 돌아왔을 때 게시글 새로고침
      if (result == true) {
        _loadPostDetail();
        // 상위 화면(커뮤니티 목록)에도 변경사항 알림
        Navigator.pop(context, true);
      }
    });
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('게시글 삭제'),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeletePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost() async {
    try {
      // 소프트 삭제: isDeleted 필드를 true로 변경
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .update({
            'isDeleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 관리자용 삭제된 게시글 백업 생성
      if (_post != null) {
        await FirebaseFirestore.instance
            .collection('admin')
            .doc('deleted_posts')
            .collection('posts')
            .doc(widget.postId)
            .set({
              'originalPath': 'posts/${widget.dateString}/posts/${widget.postId}',
              'postId': widget.postId,
              'dateString': widget.dateString,
              'boardId': _post!['boardId'],
              'title': _post!['title'],
              'contentHtml': _post!['contentHtml'],
              'author': _post!['author'],
              'viewsCount': _post!['viewsCount'] ?? 0,
              'likesCount': _post!['likesCount'] ?? 0,
              'commentCount': _post!['commentCount'] ?? 0,
              'createdAt': _post!['createdAt'],
              'deletedAt': FieldValue.serverTimestamp(),
              'deletedBy': _currentUser!.uid,
              'deletionType': 'user_self_delete', // 사용자 스스로 삭제
            });
      }

      // 사용자 게시글 수 감소
      if (_currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'postsCount': FieldValue.increment(-1)});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었습니다.')),
      );

      // SnackBar가 표시된 후 잠시 대기한 다음 화면 나가기
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          // 상위 화면으로 돌아가기 (변경사항 알림)
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      print('게시글 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  void _blockUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사용자를 차단했습니다.')),
    );
  }

  // 게시글 숨김처리
  void _hidePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('게시글 숨김처리'),
        content: const Text('이 게시글을 숨김처리하시겠습니까?\n숨김처리된 게시글은 목록에서 보이지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmHidePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('숨김처리'),
          ),
        ],
      ),
    );
  }

  // 게시글 숨김 해제
  void _unhidePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('게시글 숨김 해제'),
        content: const Text('이 게시글의 숨김을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmUnhidePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('숨김 해제'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmHidePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .update({
            'isHidden': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 게시글 데이터 새로고침
      await _loadPostDetail();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 숨김처리되었습니다.')),
      );
    } catch (e) {
      print('게시글 숨김처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 숨김처리 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _confirmUnhidePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .update({
            'isHidden': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 게시글 데이터 새로고침
      await _loadPostDetail();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 숨김이 해제되었습니다.')),
      );
    } catch (e) {
      print('게시글 숨김 해제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 숨김 해제 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      // URL이 http:// 또는 https://로 시작하지 않으면 https:// 추가
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final Uri uri = Uri.parse(formattedUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 외부 브라우저에서 열기
        );
      } else {
        throw Exception('URL을 열 수 없습니다');
      }
    } catch (e) {
      print('URL 실행 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('링크를 열 수 없습니다: $url')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      // iOS에서 권한 확인 및 요청
      if (Platform.isIOS) {
        final permission = Permission.photos;
        final status = await permission.status;
        
        if (status.isDenied) {
          final result = await permission.request();
          
          if (result.isDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('사진 라이브러리 접근 권한이 필요합니다.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('설정에서 사진 접근 권한을 허용해주세요.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '설정',
                textColor: Colors.white,
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
          return;
        }
      }
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        final originalFile = File(image.path);
        
        // 이미지 정보 출력 (디버깅용)
        await ImageCompressor.printImageInfo(originalFile);
        
        // 이미지 압축
        final compressedFile = await ImageCompressor.compressImage(originalFile);
        
        setState(() {
          _selectedImage = compressedFile;
        });
        
        // 압축된 이미지 정보 출력 (디버깅용)
        await ImageCompressor.printImageInfo(compressedFile);
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 선택이 취소되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<String?> _uploadImage(File imageFile, String commentId) async {
    try {
      // iOS에서는 올바른 bucket 사용
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }
      
      if (!await imageFile.exists()) {
        return null;
      }
      
      final fileName = '${commentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'posts/${widget.dateString}/posts/${widget.postId}/comments/${commentId}/images/$fileName';
      
      final storageRef = storage.ref().child(storagePath);
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _addComment() async {
    if (_currentUser == null ||
        (_commentController.text.trim().isEmpty && _selectedImage == null)) {
      return;
    }

    if (_isUploadingImage || _isAddingComment) {
      return;
    }

    try {
      setState(() {
        _isAddingComment = true;
      });

      // 먼저 댓글 문서를 생성해서 commentId를 얻음
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      String contentHtml = _commentController.text.trim();
      List<Map<String, dynamic>> attachments = [];

      // 답글인 경우 멘션 추가
      final bool isReply = _replyingToCommentId != null;
      String? parentCommentId;
      int depth = 0;
      String? replyToUserId;
      String? replyToUserName;
      
      if (isReply) {
        parentCommentId = _replyingToCommentId;
        depth = 1;
        if (_replyingToComment != null) {
          replyToUserId = _replyingToComment!['uid'] as String?;
          replyToUserName = _replyingToComment!['displayName'] as String?;
        }
      }
      
      final List<String> mentionedUsers = [];
      
      if (isReply && replyToUserId != null && replyToUserName != null) {
        // 답글인 경우 멘션 추가
        contentHtml = '@$replyToUserName $contentHtml';
        mentionedUsers.add(replyToUserId);
      }

      // 이미지가 있으면 업로드
      if (_selectedImage != null) {
        final imageUrl = await _uploadImage(_selectedImage!, commentRef.id);
        
        if (imageUrl != null) {
          // HTML에 이미지 태그 추가
          contentHtml += '<br><img src="$imageUrl" alt="첨부이미지" style="max-width: 100%; border-radius: 8px;" />';

          // 첨부파일 목록에 추가
          attachments.add({
            'type': 'image',
            'url': imageUrl,
            'filename': 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          });
        }
      }

      // UserService를 통해 사용자 정보 가져오기
      final userData = await UserService.getUserFromFirestore(_currentUser!.uid);

      final profileImageUrl = userData?['photoURL'] ?? '';
      final displayName = userData?['displayName'] ?? '익명';
      final displayGrade = userData?['displayGrade'] ?? '이코노미 Lv.1';
      final currentSkyEffect = userData?['currentSkyEffect'] ?? '';

      // 마지막 로그인 시간 업데이트
      await UserService.updateLastLogin(_currentUser!.uid);

      final commentData = {
        'commentId': commentRef.id,
        'uid': _currentUser!.uid,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'displayGrade': displayGrade,
        'currentSkyEffect': currentSkyEffect,
        'contentHtml': contentHtml.isEmpty ? '<p>이미지</p>' : '<p>$contentHtml</p>',
        'contentType': 'html',
        'attachments': attachments,
        'parentCommentId': parentCommentId,
        'depth': depth,
        'replyToUserId': replyToUserId,
        'mentionedUsers': mentionedUsers,
        'hasMention': mentionedUsers.isNotEmpty,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isHidden': false,
        'reportsCount': 0,
        'likesCount': 0,
      };

      await commentRef.set(commentData);

      // 사용자의 my_comments에 추가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('my_comments')
          .doc(commentRef.id)
          .set({
            'commentPath': 'posts/${widget.dateString}/posts/${widget.postId}/comments/${commentRef.id}',
            'postPath': 'posts/${widget.dateString}/posts/${widget.postId}',
            'contentHtml': commentData['contentHtml'],
            'contentType': commentData['contentType'],
            'attachments': commentData['attachments'],
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 게시글의 댓글 수 증가
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .update({'commentCount': FieldValue.increment(1)});

      // 사용자의 댓글 수 증가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'commentCount': FieldValue.increment(1)});

      // 땅콩 2개 지급 로직 추가
      if (userData != null) {
        final currentPeanut = userData['peanutCount'] ?? 0;
        final newPeanut = currentPeanut + 2;
        await UserService.updatePeanutCount(_currentUser!.uid, newPeanut);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('땅콩 2개가 추가되었습니다.'),
            backgroundColor: Colors.black38,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _commentController.clear();
      _removeSelectedImage();
      _cancelReply(); // 답글 모드 해제

      // 새 댓글의 좋아요 상태 초기화
      _commentLikes[commentRef.id] = false;

      _loadComments();

      setState(() {
        if (_post != null) {
          _post!['commentCount'] = (_post!['commentCount'] ?? 0) + 1;
        }
        _isAddingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 등록되었습니다.')),
      );
    } catch (e) {
      setState(() {
        _isAddingComment = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('댓글 등록 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getPlainTextFromHtml(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n') // <br> 태그를 줄바꿈으로
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '') // <img> 태그 제거
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '') // <p> 태그 제거
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n') // </p> 태그를 줄바꿈으로
        .replaceAll(RegExp(r'<[^>]*>'), '') // 나머지 HTML 태그 제거
        .replaceAll(RegExp(r'&[^;]+;'), '') // HTML 엔티티 제거
        .replaceAll(RegExp(r'\n+'), '\n') // 연속된 줄바꿈을 하나로
        .trim();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays < 1) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (diff.inDays < 365) {
      return DateFormat('MM.dd').format(dateTime);
    }
    return DateFormat('yy.MM.dd').format(dateTime);
  }

  String _getGradeDisplay(String? grade, int? level) {
    if (grade == null) return '';
    final gradeMap = {
      'economy': '이코노미',
      'business': '비즈니스',
      'first': '퍼스트',
      'hidden': '히든',
    };
    final gradeName = gradeMap[grade] ?? grade;
    return level != null ? '$gradeName Lv.$level' : gradeName;
  }

  String _getBoardDisplayName(String boardId) {
    final boardMap = {
      'question': '마일리지',
      'deal': '적립/카드 혜택',
      'seat_share': '좌석 공유',
      'review': '항공 리뷰',
      'error_report': '오류 신고',
      'suggestion': '건의사항',
      'free': '자유게시판',
      'notice': '운영 공지사항',
    };
    return boardMap[boardId] ?? boardId;
  }

  Color _getGradeColor(String? grade) {
    switch (grade) {
      case 'economy':
        return Colors.grey;
      case 'business':
        return Colors.purple;
      case 'first':
        return Colors.amber;
      case 'hidden':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: null,
        actions: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.grey[600],
            ),
            onPressed: _toggleLike,
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
            onPressed: _sharePost,
          ),
          _buildMoreOptionsMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF74512D),
              ),
            )
          : _post == null
              ? const Center(
                  child: Text(
                    '게시글을 찾을 수 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshData,
                        color: const Color(0xFF74512D),
                        backgroundColor: Colors.white,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                            // 게시글 내용 카드
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. 카테고리명 (boardId) - 작게
                                  Text(
                                    _getBoardDisplayName(_post?['boardId'] ?? widget.boardId),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF74512D),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // 2. 게시글 제목 (title) - 크고 굵게
                                  Text(
                                    _post!['title'] ?? '제목 없음',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // 3. 시간 | 조회수 - 작은 글자, 적당한 색상
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime((_post!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        ' | 조회 ${_post!['viewsCount'] ?? 0}회',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // 4. 프로필 정보 + 댓글/좋아요 - 한줄로 짧게
                                  Row(
                                    children: [
                                      // 프로필 + skyEffect + 닉네임 (클릭 가능)
                                      GestureDetector(
                                        onTap: () {
                                          final currentUser = FirebaseAuth.instance.currentUser;
                                          final authorUid = _post!['author']?['uid'];
                                          if (currentUser != null && authorUid == currentUser.uid) {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPageScreen()));
                                          } else if (authorUid != null) {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userUid: authorUid)));
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.grey,
                                              backgroundImage: (_post!['author']?['photoURL'] ?? _post!['author']?['profileImageUrl'] ?? '').isNotEmpty
                                                  ? NetworkImage(_post!['author']['photoURL'] ?? _post!['author']['profileImageUrl'])
                                                  : null,
                                              child: (_post!['author']?['photoURL'] ?? _post!['author']?['profileImageUrl'] ?? '').isEmpty
                                                  ? Text(
                                                      (_post!['author']?['displayName'] ?? '익명')[0],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            SizedBox(width: _post!['author']?['currentSkyEffect'] != null && 
                                                            (_post!['author']['currentSkyEffect'] as String).isNotEmpty ? 4 : 8),
                                            if (_post!['author']?['currentSkyEffect'] != null && 
                                                (_post!['author']['currentSkyEffect'] as String).isNotEmpty)
                                              SizedBox(
                                                width: 32,
                                                height: 20,
                                                child: _buildSkyEffectPreview(_post!['author']['currentSkyEffect']),
                                              ),
                                            if (_post!['author']?['currentSkyEffect'] != null && 
                                                (_post!['author']['currentSkyEffect'] as String).isNotEmpty)
                                              const SizedBox(width: 4),
                                            Text(
                                              _post!['author']?['displayName'] ?? '익명',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (_post!['author']?['displayGrade'] != null &&
                                                (_post!['author']['displayGrade'] as String).isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 6.0),
                                                child: _post!['author']['displayGrade'] == '★★★'
                                                    ? GradientText(
                                                        '★★★',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        gradient: const LinearGradient(
                                                          colors: [
                                                            Colors.red,
                                                            Colors.orange,
                                                            Colors.yellow,
                                                            Colors.green,
                                                            Colors.blue,
                                                            Colors.indigo,
                                                            Colors.purple,
                                                          ],
                                                        ),
                                                      )
                                                    : Text(
                                                        _post!['author']['displayGrade'],
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                          fontWeight: FontWeight.normal,
                                                        ),
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // 광고 영역 1: 프로필/스카이이펙트/닉네임 아래
                                  _buildProfileBannerAd(),
                                  const SizedBox(height: 16),

                                  // 5. 게시글 내용 (contentHtml) 또는 숨김처리 메시지
                                  if (_post!['isHidden'] == true)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.visibility_off,
                                            size: 48,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            '관리자에 의해 숨김처리되었습니다.',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '이 게시글은 커뮤니티 운영 정책에 따라 숨김처리되었습니다.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Html(
                                      data: _post!['contentHtml'] ?? '',
                                      style: {
                                        "body": Style(
                                          fontSize: FontSize(15),
                                          color: Colors.black87,
                                          lineHeight: LineHeight(1.5),
                                          margin: Margins.zero,
                                        ),
                                        "p": Style(
                                          margin: Margins.zero,
                                          padding: HtmlPaddings.zero,
                                          whiteSpace: WhiteSpace.pre,
                                        ),
                                        "br": Style(
                                          margin: Margins.only(bottom: 8),
                                          display: Display.block,
                                        ),
                                        "img": Style(
                                          margin: Margins.zero,
                                          display: Display.block,
                                        ),
                                        "u": Style(
                                          margin: Margins.zero,
                                        ),
                                        "a": Style(
                                          color: Colors.blue,
                                          textDecoration: TextDecoration.underline,
                                        ),
                                      },
                                      onLinkTap: (url, _, __) {
                                        if (url != null) {
                                          _launchUrl(url);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),

                          // 광고 영역 2: 게시글과 댓글 사이
                          _buildContentBannerAd(),
                              const SizedBox(height: 16),
                          // 댓글 섹션
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isLoadingComments
                                ? // 댓글 로딩 중 UI
                                Container(
                                    padding: const EdgeInsets.all(40),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF74512D),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _comments.isEmpty
                                    ? // 댓글이 없을 때 UI
                                    Container(
                                        padding: const EdgeInsets.all(40),
                                        child: Center(
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.comment,
                                                size: 48,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                '첫 번째 댓글을 작성해보세요!',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : // 댓글이 있을 때 UI
                                    Column(
                                        children: [
                                          // 댓글 헤더
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '댓글 ${_comments.length}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const Spacer(),
                                                DropdownButton<String>(
                                                  value: _commentSortOrder,
                                                  underline: const SizedBox(),
                                                  dropdownColor: Colors.white,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  items: ['등록순', '최신순'].map((String value) {
                                                    return DropdownMenuItem<String>(
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newValue) {
                                                    if (newValue != null) {
                                                      setState(() {
                                                        _commentSortOrder = newValue;
                                                      });
                                                      _loadComments(); // 댓글 다시 로드
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),

                                          // 댓글 목록
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _comments.length,
                                            separatorBuilder: (context, index) => Divider(
                                              height: 1,
                                              color: Colors.grey[200],
                                            ),
                                            itemBuilder: (context, index) {
                                              final comment = _comments[index];
                                              return _buildCommentItem(comment);
                                            },
                                          ),
                                        ],
                                      ),
                          ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 댓글 입력창
                    Container(
                      key: _replySectionKey,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 답글 모드 표시
                              if (_replyingToCommentId != null && _replyingToComment != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.reply,
                                        size: 16,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_replyingToComment!['displayName']}님에게 답글 작성 중',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _cancelReply,
                                        icon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.blue[600],
                                        ),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              // 선택된 이미지 미리보기
                              if (_selectedImage != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _selectedImage!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          '이미지 선택됨',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _removeSelectedImage,
                                        icon: Icon(
                                          Icons.close,
                                          color: Colors.grey[600],
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 입력창과 버튼들
                              Row(
                                children: [
                                  // 이미지 첨부 버튼
                                  IconButton(
                                    onPressed: (_myUserProfile?['isBanned'] == true) ? null : _pickImage,
                                    icon: Icon(
                                      Icons.image_outlined,
                                      color: (_myUserProfile?['isBanned'] == true) ? Colors.grey[300] : Colors.grey[600],
                                      size: 24, // 기존 24 → 22
                                    ),
                                    padding: EdgeInsets.zero, // 여백 최소화
                                    constraints: BoxConstraints(minWidth: 32, minHeight: 32), // 최소 크기
                                    tooltip: '이미지 첨부',
                                  ),

                                  // 텍스트 입력 필드
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      enabled: !(_myUserProfile?['isBanned'] == true || _isAddingComment), // 업로드 중엔 비활성화
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: _myUserProfile?['isBanned'] == true
                                            ? '정지된 계정은 댓글을 작성할 수 없습니다'
                                            : (_editingCommentId != null ? '댓글 수정' : '댓글을 입력하세요'),
                                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: const BorderSide(color: Color(0xFF74512D)),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      maxLines: null, // 여러 줄 입력 가능
                                      textInputAction: TextInputAction.newline, // 엔터키로 줄바꿈
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  if (_editingCommentId != null) ...[
                                    ElevatedButton(
                                      onPressed: (_myUserProfile?['isBanned'] == true || _isAddingComment) ? null : _updateComment,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF74512D),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      child: const Text('수정 완료', style: TextStyle(color: Colors.white)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: (_myUserProfile?['isBanned'] == true || _isAddingComment) ? null : _cancelEditComment,
                                      child: const Text('취소', style: TextStyle(color: Colors.grey)),
                                    ),
                                  ] else ...[
                                    _isAddingComment
                                      ? SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF74512D)),
                                        )
                                      : ElevatedButton(
                                          onPressed: (_myUserProfile?['isBanned'] == true || _isAddingComment) ? null : _addComment,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF74512D),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                          child: const Text('등록', style: TextStyle(color: Colors.white)),
                                        ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final createdAt = (comment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final depth = comment['depth'] ?? 0;
    final isHighlighted = _replyingToCommentId == comment['commentId'];
    final commentId = comment['commentId'];
    
    // 딥링크 스크롤용 GlobalKey 생성
    if (!_commentKeys.containsKey(commentId)) {
      _commentKeys[commentId] = GlobalKey();
    }
    
    return Container(
      key: _commentKeys[commentId], // 딥링크 스크롤용 키
      color: isHighlighted ? Colors.blue.withOpacity(0.1) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0 + (depth * 24.0), // depth에 따른 들여쓰기
          16.0, 
          16.0, 
          16.0
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 댓글 작성자 프로필
            GestureDetector(
              onTap: () {
                final currentUser = FirebaseAuth.instance.currentUser;
                final commentUid = comment['uid'];
                if (currentUser != null && commentUid == currentUser.uid) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPageScreen()));
                } else if (commentUid != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userUid: commentUid)));
                }
              },
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.purple,
                        backgroundImage: (comment['profileImageUrl'] ?? '').isNotEmpty
                            ? NetworkImage(comment['profileImageUrl'])
                            : null,
                        child: (comment['profileImageUrl'] ?? '').isEmpty
                            ? Text(
                                (comment['displayName'] ?? '익명')[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                      // currentSkyEffect 표시 (댓글에서는 제거)
                      // if (comment['currentSkyEffect'] != null && 
                      //     (comment['currentSkyEffect'] as String).isNotEmpty)
                      //   Positioned(
                      //     right: -2,
                      //     bottom: -2,
                      //     child: Container(
                      //       width: 20,
                      //       height: 20,
                      //       child: _buildSkyEffectPreview(comment['currentSkyEffect']),
                      //     ),
                      //   ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: comment['currentSkyEffect'] != null && 
                            (comment['currentSkyEffect'] as String).isNotEmpty ? 4 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment['displayName'] ?? '익명',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment['displayGrade'] ?? '이코노미 Lv.1',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildCommentContent(comment),
                  
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _processingCommentLikes.contains(comment['commentId'])
                            ? null // 처리 중일 때는 클릭 비활성화
                            : () => _toggleCommentLike(comment['commentId']),
                        child: Row(
                          children: [
                            Icon(
                              (_commentLikes[comment['commentId']] ?? false)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: (_processingCommentLikes.contains(comment['commentId']))
                                  ? Colors.grey[400] // 처리 중일 때는 회색으로 표시
                                  : (_commentLikes[comment['commentId']] ?? false)
                                      ? Colors.red
                                      : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${comment['likesCount'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (_processingCommentLikes.contains(comment['commentId']))
                                    ? Colors.grey[400] // 처리 중일 때는 회색으로 표시
                                    : (_commentLikes[comment['commentId']] ?? false)
                                        ? Colors.red
                                        : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: Text(
                          '답글',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                      const Spacer(),
                      // 댓글 더보기 버튼
                      _buildCommentMoreOptions(comment),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentContent(Map<String, dynamic> comment) {
    final reportsCount = comment['reportsCount'] ?? 0;

    // 관리자에 의해 숨김처리된 댓글인 경우
    if (comment['isHidden'] == true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_off,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            const Text(
              '관리자에 의해 숨김처리되었습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    
    // 신고 누적으로 일시적으로 감춰진 댓글 (3건 이상)
    if (reportsCount >= 3 && reportsCount < 6) {
      return GestureDetector(
        onTap: () => _showHiddenCommentDialog(comment),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber,
                size: 16,
                color: Colors.orange[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '신고건 누적으로 일시적으로 감춰진 댓글입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 신고 누적으로 완전히 감춰진 댓글 (6건 이상)
    if (reportsCount >= 6) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.block,
              size: 16,
              color: Colors.red[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '신고건 누적으로 완전히 감춰진 댓글입니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final contentHtml = comment['contentHtml'] ?? comment['content'] ?? '';
    final hasMention = comment['hasMention'] == true;
    
    // @사용자명 패턴을 파란색으로 스타일링
    final processedHtml = contentHtml.replaceAllMapped(
      RegExp(r'@([a-zA-Z0-9가-힣_]+[!]?)', multiLine: true),
      (match) => '<span style="color: #1976D2; font-weight: 600;">${match.group(0)}</span>',
    );
    
    return Html(
      data: processedHtml,
      style: {
        "body": Style(
          fontSize: FontSize(14),
          color: Colors.black87,
          lineHeight: LineHeight(1.4),
          margin: Margins.zero,
        ),
        "p": Style(
          margin: Margins.only(bottom: 2),
          whiteSpace: WhiteSpace.pre,
        ),
        "br": Style(
          margin: Margins.zero,
        ),
        "img": Style(
          margin: Margins.zero,
        ),
        "u": Style(
          margin: Margins.zero,
        ),
        "a": Style(
          color: Colors.blue,
          textDecoration: TextDecoration.underline,
        ),
        // 멘션 스타일링
        "span[data-mention]": Style(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null) {
          _launchUrl(url);
        }
      },
    );
  }

  /// 딥링크로 특정 댓글로 스크롤
  void _scrollToComment(String commentId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commentKey = _commentKeys[commentId];
      if (commentKey?.currentContext != null) {
        Scrollable.ensureVisible(
          commentKey!.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          alignment: 0.3, // 화면 상단 30% 지점에 위치
        );
        
        // 댓글 하이라이트 효과 (선택사항)
        _highlightComment(commentId);
      } else {
        // 존재하지 않는 댓글인 경우
        print('존재하지 않는 댓글: $commentId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('유효하지 않은 댓글입니다.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// 댓글 하이라이트 효과
  void _highlightComment(String commentId) {
    // 잠시 후 하이라이트 제거
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          // 하이라이트 상태를 관리하는 변수가 있다면 여기서 제거
        });
      }
    });
  }

  // 댓글 더보기 옵션 위젯
  Widget _buildCommentMoreOptions(Map<String, dynamic> comment) {
    // 프로필 정보가 아직 로드되지 않았다면 ... 메뉴 숨김
    if (_myUserProfile == null) {
      return const SizedBox.shrink();
    }
    // 본인 댓글인지 확인
    final isMyComment = _currentUser?.uid == comment['uid'];
    // 관리자 권한 체크
    final isAdmin = (_myUserProfile?['roles'] ?? []).contains('admin');
    // 내가 이미 신고한 댓글이면 ... 버튼 숨김
    if (_reportedCommentIds.contains(comment['commentId'])) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[500]),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 둥근 팝업
      ),
      onSelected: (String value) {
        switch (value) {
          case 'edit':
            _editComment(comment);
            break;
          case 'delete':
            _deleteComment(comment);
            break;
          case 'report':
            _reportComment(comment);
            break;
          case 'hide':
            _hideComment(comment);
            break;
          case 'unhide':
            _unhideComment(comment);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        // 관리자라면 무조건 수정/삭제/숨김처리 옵션 노출
        if (isAdmin) {
          return [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('수정하기'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('삭제하기', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: comment['isHidden'] == true ? 'unhide' : 'hide',
              child: Row(
                children: [
                  Icon(
                    comment['isHidden'] == true ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                    color: comment['isHidden'] == true ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    comment['isHidden'] == true ? '숨김 해제' : '숨김처리',
                    style: TextStyle(
                      color: comment['isHidden'] == true ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }
        // 본인 댓글일 때
        if (isMyComment) {
          return [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('수정하기'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('삭제하기', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ];
        } else {
          // 다른 사람 댓글일 때
          return [
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('신고하기'),
                ],
              ),
            ),
          ];
        }
      },
    );
  }

  // 댓글 수정
  void _editComment(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['commentId'];
      _editingOriginalContent = _getPlainTextFromHtml(comment['contentHtml'] ?? '');
      _commentController.text = _editingOriginalContent ?? '';
    });
    FocusScope.of(context).requestFocus(FocusNode()); // 입력창 포커스
  }

  // 댓글 수정 취소
  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _editingOriginalContent = null;
      _commentController.clear();
    });
  }

  // 댓글 수정 완료
  Future<void> _updateComment() async {
    if (_editingCommentId == null || _commentController.text.trim().isEmpty) return;
    try {
      final newContent = _commentController.text.trim();
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(_editingCommentId)
          .update({
        'contentHtml': '<p>$newContent</p>',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _editingCommentId = null;
        _editingOriginalContent = null;
        _commentController.clear();
      });
      _loadComments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 수정되었습니다.')),
      );
    } catch (e) {
      print('댓글 수정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 수정 중 오류가 발생했습니다.')),
      );
    }
  }

  // 댓글 삭제
  void _deleteComment(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('댓글 삭제'),
        content: const Text('정말로 이 댓글을 삭제하시겠습니까?\n삭제된 댓글은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeleteComment(comment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteComment(Map<String, dynamic> comment) async {
    try {
      setState(() {
        _isLoadingComments = true;
      });
      final commentId = comment['commentId'];
      // 댓글 삭제 (posts의 서브컬렉션)
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // 게시글 댓글 수 감소
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .update({
            'commentCount': FieldValue.increment(-1),
          });

      // my_comments에서도 삭제
      if (_currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('my_comments')
            .doc(commentId)
            .delete();

        // 사용자 댓글 수 감소
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'commentCount': FieldValue.increment(-1)});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 삭제되었습니다.')),
      );

      // 잠시 후 댓글 목록 새로고침 및 로딩 해제
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _loadComments();
          setState(() {
            _isLoadingComments = false;
          });
        }
      });
    } catch (e) {
      print('댓글 삭제 오류: $e');
      setState(() {
        _isLoadingComments = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  // 댓글 신고
  void _reportComment(Map<String, dynamic> comment) {
    _showReportDialog('comment', comment);
  }

  // 게시글 신고
  void _reportPost() {
    _showReportDialog('post', null);
  }

  // 신고 다이얼로그
  void _showReportDialog(String type, Map<String, dynamic>? comment) {
    String? selectedReason;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${type == 'post' ? '게시글' : '댓글'} 신고'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('신고 이유를 선택해주세요:'),
                const SizedBox(height: 16),
                // 신고 이유 선택
                RadioListTile<String>(
                  title: const Text('비방/욕설'),
                  value: 'abuse',
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('저작권'),
                  value: 'copyright',
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('광고'),
                  value: 'advertisement',
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('기타'),
                  value: 'other',
                  groupValue: selectedReason,
                  activeColor: Colors.black,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                if (selectedReason == 'other') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: '신고 이유를 입력해주세요',
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              if (selectedReason != null) {
                Navigator.pop(context);
                await _submitReport(type, comment, selectedReason!, reasonController.text);
              }
            },
            child: const Text('신고', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(String type, Map<String, dynamic>? comment, String reason, String detail) async {
    try {
      final reportData = {
        'type': type,
        'reason': reason,
        'detail': detail,
        'reporterUid': _currentUser!.uid,
        'reporterName': _currentUser!.displayName ?? '익명',
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, resolved
      };

      if (type == 'post') {
        reportData['postId'] = widget.postId;
        reportData['dateString'] = widget.dateString;
        reportData['boardId'] = widget.boardId;
        reportData['postTitle'] = _post!['title'];
        reportData['postAuthor'] = _post!['author'];
        reportData['detailPath'] = 'posts/${widget.dateString}/posts/${widget.postId}';
        // 1. posts/{dateString}/posts/{postId}/reports/{내uid}에 저장
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.dateString)
            .collection('posts')
            .doc(widget.postId)
            .collection('reports')
            .doc(_currentUser!.uid)
            .set(reportData);
        // 2. reports/posts/posts에도 저장
        await FirebaseFirestore.instance
            .collection('reports')
            .doc('posts')
            .collection('posts')
            .add(reportData);
        // 3. 게시글 신고 수 증가
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.dateString)
            .collection('posts')
            .doc(widget.postId)
            .update({
              'reportsCount': FieldValue.increment(1),
            });
        // 신고 성공 시 상태 갱신
        setState(() {
          _alreadyReportedPost = true;
        });
      } else {
        reportData['commentId'] = comment!['commentId'];
        reportData['postId'] = widget.postId;
        reportData['dateString'] = widget.dateString;
        reportData['commentAuthor'] = comment['displayName'];
        reportData['commentContent'] = comment['contentHtml'] ?? comment['content'];
        reportData['detailPath'] = 'posts/${widget.dateString}/posts/${widget.postId}/comments/${comment['commentId']}';
        await FirebaseFirestore.instance
            .collection('reports')
            .doc('comments')
            .collection('comments')
            .add(reportData);
        // 댓글 신고 수 증가
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.dateString)
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(comment['commentId'])
            .update({
              'reportsCount': FieldValue.increment(1),
            });
      }

      // 신고 성공 시 SnackBar가 항상 뜨도록 context 타이밍 보장
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고가 접수되었습니다. 검토 후 처리하겠습니다.')),
          );
        }
      });

      // 신고 완료 후 내가 신고한 댓글 목록 즉시 갱신
      if (type == 'comment') {
        await _loadMyReportedComments();
      }
    } catch (e) {
      print('신고 제출 오류: $e');
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고 제출 중 오류가 발생했습니다.')),
          );
        }
      });
    }
  }

  // 스카이 이펙트 미리보기 위젯
  Widget _buildSkyEffectPreview(String? effectId) {
    if (effectId == null || effectId.isEmpty) return const SizedBox.shrink();
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('effects').doc(effectId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lottieUrl = data['lottieUrl'] as String?;
        
        if (lottieUrl != null && lottieUrl.isNotEmpty) {
          return Lottie.network(
            lottieUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            repeat: true,
            animate: true,
          );
        } else {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
      },
    );
  }

  Widget _buildCommentAuthorRow(Map<String, dynamic> comment) {
    final photoURL = comment['profileImageUrl'] ?? '';
    final hasSkyEffect = comment['currentSkyEffect'] != null && 
                        (comment['currentSkyEffect'] as String).isNotEmpty;
    
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          child: photoURL.isEmpty
              ? Text(
                  (comment['displayName'] ?? '익명')[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                )
              : null,
        ),
        SizedBox(width: hasSkyEffect ? 4 : 8),
        if (hasSkyEffect)
          SizedBox(
            width: 32,
            height: 20,
            child: _buildSkyEffectPreview(comment['currentSkyEffect']),
          ),
        if (hasSkyEffect) const SizedBox(width: 4),
        Text(
          comment['displayName'] ?? '익명',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          comment['displayGrade'] ?? '이코노미 Lv.1',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        // 시간 등 추가 가능
      ],
    );
  }

  // 게시글 신고여부 확인 (posts/{dateString}/posts/{postId}/reports/{내uid} 존재 여부)
  Future<void> _checkIfReportedPost() async {
    final myUid = _currentUser?.uid;
    if (myUid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('reports')
          .doc(myUid)
          .get();
      setState(() {
        _alreadyReportedPost = doc.exists;
      });
    } catch (e) {
      print('게시글 신고여부 확인 오류: $e');
    }
  }

  Widget _buildProfileBannerAd() {
    if (_isProfileBannerAdLoaded && _profileBannerAd != null) {
      return Container(
        width: MediaQuery.of(context).size.width, // 화면 전체 너비로 설정
        height: _profileBannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _profileBannerAd!),
      );
    } else {
      return const SizedBox(height: 50);
    }
  }

  Widget _buildContentBannerAd() {
    if (_isContentBannerAdLoaded && _contentBannerAd != null) {
      return Container(
        width: MediaQuery.of(context).size.width, // 화면 전체 너비로 설정
        height: _contentBannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: _contentBannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _contentBannerAd!),
          ),
        ),
      );
    } else {
      return const SizedBox(height: 50);
    }
  }

  // 댓글 숨김처리
  void _hideComment(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('댓글 숨김처리'),
        content: const Text('이 댓글을 숨김처리하시겠습니까?\n숨김처리된 댓글은 "관리자에 의해 숨김처리되었습니다."로 표시됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmHideComment(comment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('숨김처리'),
          ),
        ],
      ),
    );
  }

  // 댓글 숨김 해제
  void _unhideComment(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('댓글 숨김 해제'),
        content: const Text('이 댓글의 숨김을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmUnhideComment(comment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('숨김 해제'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmHideComment(Map<String, dynamic> comment) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment['commentId'])
          .update({
            'isHidden': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 댓글 목록 새로고침
      await _loadComments();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 숨김처리되었습니다.')),
      );
    } catch (e) {
      print('댓글 숨김처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 숨김처리 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _confirmUnhideComment(Map<String, dynamic> comment) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment['commentId'])
          .update({
            'isHidden': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 댓글 목록 새로고침
      await _loadComments();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 숨김이 해제되었습니다.')),
      );
    } catch (e) {
      print('댓글 숨김 해제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 숨김 해제 중 오류가 발생했습니다.')),
      );
    }
  }

  // 숨겨진 댓글 보기 다이얼로그
  void _showHiddenCommentDialog(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('숨겨진 댓글'),
        content: const Text('비공개 처리된 댓글을 보시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showHiddenCommentContent(comment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('예'),
          ),
        ],
      ),
    );
  }

  // 숨겨진 댓글 내용 보기
  void _showHiddenCommentContent(Map<String, dynamic> comment) {
    final contentHtml = comment['contentHtml'] ?? comment['content'] ?? '';
    final hasMention = comment['hasMention'] == true;
    
    // @사용자명 패턴을 파란색으로 스타일링
    final processedHtml = contentHtml.replaceAllMapped(
      RegExp(r'@([a-zA-Z0-9가-힣_]+[!]?)', multiLine: true),
      (match) => '<span style="color: #1976D2; font-weight: 600;">${match.group(0)}</span>',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('숨겨진 댓글 내용'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Html(
            data: processedHtml,
            style: {
              "body": Style(
                fontSize: FontSize(14),
                color: Colors.black87,
                lineHeight: LineHeight(1.4),
                margin: Margins.zero,
              ),
              "p": Style(
                margin: Margins.only(bottom: 2),
                whiteSpace: WhiteSpace.pre,
              ),
              "br": Style(
                margin: Margins.zero,
              ),
              "img": Style(
                margin: Margins.zero,
              ),
              "u": Style(
                margin: Margins.zero,
              ),
              "a": Style(
                color: Colors.blue,
                textDecoration: TextDecoration.underline,
              ),
              "span[data-mention]": Style(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            },
            onLinkTap: (url, _, __) {
              if (url != null) {
                _launchUrl(url);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
} 