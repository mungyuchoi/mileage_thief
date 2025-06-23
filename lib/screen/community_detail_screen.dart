import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/user_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'community_post_create_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String postId;
  final String boardId;
  final String boardName;
  final String dateString;

  const CommunityDetailScreen({
    Key? key,
    required this.postId,
    required this.boardId,
    required this.boardName,
    required this.dateString,
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

  @override
  void initState() {
    super.initState();
    _loadPostDetail();
    _loadComments();
    _checkUserStatus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
        // 조회수 증가
        await docSnapshot.reference.update({
          'viewsCount': FieldValue.increment(1),
        });

        setState(() {
          _post = docSnapshot.data() as Map<String, dynamic>;
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
          .orderBy('createdAt', descending: false)
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
    
    // 부모 댓글들을 시간순으로 정렬
    parentComments.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aTime.compareTo(bTime);
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
      
      // 답글들을 시간순으로 정렬
      replies.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return aTime.compareTo(bTime);
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

    try {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.pop(context);
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

      if (_isLiked) {
        // 좋아요 취소
        batch.delete(likeRef);
        batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
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
        setState(() {
          _isLiked = true;
          if (_post != null) {
            _post!['likesCount'] = (_post!['likesCount'] ?? 0) + 1;
          }
        });
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

  void _sharePost() {
    if (_post != null) {
      final title = _post!['title'] ?? '제목 없음';
      final content = _getPlainTextFromHtml(_post!['contentHtml'] ?? '');
      final shareText = '$title\n\n$content\n\n마일리지도둑 커뮤니티에서 공유';
      Share.share(shareText);
    }
  }

  Widget _buildMoreOptionsMenu() {
    // 본인 게시글인지 확인
    final isMyPost = _currentUser?.uid == _post?['author']?['uid'];
    
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
        }
      },
      itemBuilder: (BuildContext context) {
        if (isMyPost) {
          // 본인 게시글일 때
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
          // 다른 사람 게시글일 때
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
            const PopupMenuItem<String>(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('차단하기'),
                ],
              ),
            ),
          ];
        }
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
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeletePost();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            .update({'postCount': FieldValue.increment(-1)});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었습니다.')),
      );

      // 상위 화면으로 돌아가기
      Navigator.pop(context);
    } catch (e) {
      print('게시글 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  void _reportPost() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었습니다.')),
    );
  }

  void _blockUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사용자를 차단했습니다.')),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다.')),
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
      setState(() {
        _isUploadingImage = true;
      });

      final String fileName = '${commentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String storagePath = 'posts/${widget.dateString}/posts/${widget.postId}/comments/$commentId/images/$fileName';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(storagePath);

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isUploadingImage = false;
      });

      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      setState(() {
        _isUploadingImage = false;
      });
      return null;
    }
  }

  Future<void> _addComment() async {
    if (_currentUser == null ||
        (_commentController.text.trim().isEmpty && _selectedImage == null)) return;

    if (_isUploadingImage || _isAddingComment) return; // 이미지 업로드 중이거나 댓글 등록 중일 때는 중복 방지

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

      // 마지막 로그인 시간 업데이트
      await UserService.updateLastLogin(_currentUser!.uid);

      final commentData = {
        'commentId': commentRef.id,
        'uid': _currentUser!.uid,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'displayGrade': displayGrade,
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
      print('댓글 등록 오류: $e');
      setState(() {
        _isAddingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 등록 중 오류가 발생했습니다.')),
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
        title: Text(
          _post?['title'] ?? widget.boardName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                                  // 카테고리명
                                  Text(
                                    _getBoardDisplayName(widget.boardId),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF74512D),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // 작성자 정보
                                  Row(
                                    children: [
                                      // 프로필 이미지
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.grey,
                                        backgroundImage: (_post!['author']?['photoURL'] ??
                                                         _post!['author']?['profileImageUrl'] ?? '').isNotEmpty
                                            ? NetworkImage(_post!['author']['photoURL'] ??
                                                         _post!['author']['profileImageUrl'])
                                            : null,
                                        child: (_post!['author']?['photoURL'] ??
                                               _post!['author']?['profileImageUrl'] ?? '').isEmpty
                                            ? Text(
                                                (_post!['author']?['displayName'] ?? '익명')[0],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _post!['author']?['displayName'] ?? '익명',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _post!['author']?['displayGrade'] ?? '이코노미 Lv.1',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 팔로우 버튼
                                      if (_currentUser?.uid != _post!['author']?['uid'])
                                        TextButton(
                                          onPressed: _toggleFollow,
                                          style: TextButton.styleFrom(
                                            backgroundColor: _isFollowing
                                                ? Colors.grey[200]
                                                : const Color(0xFF74512D),
                                            minimumSize: const Size(60, 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            _isFollowing ? '팔로잉' : '팔로우',
                                            style: TextStyle(
                                              color: _isFollowing ? Colors.grey[600] : Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // 게시글 제목
                                  Text(
                                    _post!['title'] ?? '제목 없음',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // 제목 밑 구분선
                                  Container(
                                    height: 1,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),

                                  // 게시글 내용
                                  Html(
                                    data: (_post!['contentHtml'] ?? '')
                                        .replaceAll(RegExp(r'<br\s*/?>\s*</p>', caseSensitive: false), '</p>') // 이미지 뒤 <br> 제거
                                        .replaceAll(RegExp(r'<br\s*/?>\s*$', caseSensitive: false), ''), // 끝에 오는 <br> 제거
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
                                      ),
                                      "br": Style(
                                        margin: Margins.zero,
                                        display: Display.none, // <br> 태그 완전히 숨기기
                                      ),
                                      "img": Style(
                                        margin: Margins.zero,
                                        display: Display.block,
                                      ),
                                      "u": Style(
                                        margin: Margins.zero,
                                      ),
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // 하단 정보 (날짜, 조회수, 댓글수, 좋아요수)
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime((_post!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_post!['viewsCount'] ?? 0}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.mode_comment_outlined, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_post!['commentCount'] ?? 0}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        _isLiked ? Icons.favorite : Icons.favorite_border,
                                        size: 16,
                                        color: _isLiked ? Colors.red : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_post!['likesCount'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _isLiked ? Colors.red : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

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
                                                Icons.chat_bubble_outline,
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
                                    onPressed: _pickImage,
                                    icon: Icon(
                                      Icons.image_outlined,
                                      color: Colors.grey[600],
                                      size: 24,
                                    ),
                                    tooltip: '이미지 첨부',
                                  ),
                                  const SizedBox(width: 8),

                                  // 텍스트 입력 필드
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      decoration: InputDecoration(
                                        hintText: '댓글을 입력하세요',
                                        hintStyle: TextStyle(color: Colors.grey[500]),
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
                                      maxLines: null,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _addComment(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // 전송 버튼
                                  FloatingActionButton(
                                    onPressed: (_isUploadingImage || _isAddingComment) ? null : _addComment,
                                    backgroundColor: (_isUploadingImage || _isAddingComment)
                                        ? Colors.grey[400]
                                        : const Color(0xFF74512D),
                                    mini: true,
                                    child: (_isUploadingImage || _isAddingComment)
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF74512D),
                                            ),
                                          )
                                        : const Icon(Icons.send, color: Colors.white, size: 20),
                                  ),
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
    
    return Container(
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
            const SizedBox(width: 12),
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
                        '이코노미 Lv.1', // 실제로는 comment에서 가져와야 함
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
                        onTap: () => _toggleCommentLike(comment['commentId']),
                        child: Row(
                          children: [
                            Icon(
                              (_commentLikes[comment['commentId']] ?? false)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: (_commentLikes[comment['commentId']] ?? false)
                                  ? Colors.red
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${comment['likesCount'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (_commentLikes[comment['commentId']] ?? false)
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
    final contentHtml = comment['contentHtml'] ?? comment['content'] ?? '';
    final hasMention = comment['hasMention'] == true;
    
    return Html(
      data: contentHtml,
      style: {
        "body": Style(
          fontSize: FontSize(14),
          color: Colors.black87,
          lineHeight: LineHeight(1.4),
          margin: Margins.zero,
        ),
        "p": Style(
          margin: Margins.only(bottom: 2),
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
        // 멘션 스타일링
        "span[data-mention]": Style(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      },
    );
  }
} 