import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isDisliked = false;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPostDetail();
    _checkUserLikeStatus();
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
        setState(() {
          _post = docSnapshot.data() as Map<String, dynamic>;
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

  Future<void> _checkUserLikeStatus() async {
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

      // 싫어요 상태 확인
      final dislikeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.dateString)
          .collection('posts')
          .doc(widget.postId)
          .collection('dislikes')
          .doc(_currentUser!.uid)
          .get();

      setState(() {
        _isLiked = likeDoc.exists;
        _isDisliked = dislikeDoc.exists;
      });
    } catch (e) {
      print('좋아요/싫어요 상태 확인 오류: $e');
    }
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
      final dislikeRef = postRef.collection('dislikes').doc(_currentUser!.uid);

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
          'userId': _currentUser!.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'likesCount': FieldValue.increment(1)});

        // 싫어요가 있다면 제거
        if (_isDisliked) {
          batch.delete(dislikeRef);
          batch.update(postRef, {'dislikesCount': FieldValue.increment(-1)});
          setState(() {
            _isDisliked = false;
            if (_post != null) {
              _post!['dislikesCount'] = (_post!['dislikesCount'] ?? 0) - 1;
            }
          });
        }

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

  Future<void> _toggleDislike() async {
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
      final dislikeRef = postRef.collection('dislikes').doc(_currentUser!.uid);

      if (_isDisliked) {
        // 싫어요 취소
        batch.delete(dislikeRef);
        batch.update(postRef, {'dislikesCount': FieldValue.increment(-1)});
        setState(() {
          _isDisliked = false;
          if (_post != null) {
            _post!['dislikesCount'] = (_post!['dislikesCount'] ?? 0) - 1;
          }
        });
      } else {
        // 싫어요 추가
        batch.set(dislikeRef, {
          'userId': _currentUser!.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'dislikesCount': FieldValue.increment(1)});

        // 좋아요가 있다면 제거
        if (_isLiked) {
          batch.delete(likeRef);
          batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
          setState(() {
            _isLiked = false;
            if (_post != null) {
              _post!['likesCount'] = (_post!['likesCount'] ?? 0) - 1;
            }
          });
        }

        setState(() {
          _isDisliked = true;
          if (_post != null) {
            _post!['dislikesCount'] = (_post!['dislikesCount'] ?? 0) + 1;
          }
        });
      }

      await batch.commit();
    } catch (e) {
      print('싫어요 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다.')),
      );
    }
  }

  void _sharePost() {
    if (_post != null) {
      final title = _post!['title'] ?? '제목 없음';
      final content = _removeHtmlTags(_post!['contentHtml'] ?? '');
      final shareText = '$title\n\n$content\n\n마일리지도둑 커뮤니티에서 공유';
      Share.share(shareText);
    }
  }

  String _removeHtmlTags(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[^;]+;'), '')
        .trim();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('yyyy.MM.dd HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF8DC), Color(0xFF74512D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.boardName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _sharePost,
          ),
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 게시글 제목
                            Text(
                              _post!['title'] ?? '제목 없음',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 작성자 정보
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  // 프로필 이미지
                                  Builder(
                                    builder: (context) {
                                      final photoURL = _post!['author']?['photoURL'] ?? 
                                                      _post!['author']?['profileImageUrl'] ?? '';
                                      
                                      return CircleAvatar(
                                        backgroundColor: Colors.grey[300],
                                        radius: 20,
                                        backgroundImage: photoURL.isNotEmpty
                                            ? NetworkImage(photoURL)
                                            : null,
                                        child: photoURL.isEmpty
                                            ? const Icon(Icons.person,
                                                color: Colors.black54, size: 24)
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _post!['author']['displayName'] ?? '익명',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTime((_post!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 게시글 내용
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _removeHtmlTags(_post!['contentHtml'] ?? ''),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 통계 정보
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    Icons.visibility_outlined,
                                    '조회수',
                                    '${_post!['viewsCount'] ?? 0}',
                                  ),
                                  _buildStatItem(
                                    Icons.mode_comment_outlined,
                                    '댓글',
                                    '${_post!['commentCount'] ?? 0}',
                                  ),
                                  _buildStatItem(
                                    Icons.favorite_border,
                                    '좋아요',
                                    '${_post!['likesCount'] ?? 0}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 댓글 영역 (기본 레이아웃)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.mode_comment_outlined,
                                        color: Color(0xFF74512D),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '댓글 ${_post!['commentCount'] ?? 0}개',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: Text(
                                      '댓글 시스템은 다음 단계에서 구현 예정입니다.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 하단 좋아요/싫어요 버튼
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleLike,
                              icon: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                size: 20,
                              ),
                              label: Text(
                                '좋아요 ${_post!['likesCount'] ?? 0}',
                                style: TextStyle(
                                  color: _isLiked ? Colors.red : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.grey[600],
                                elevation: 0,
                                side: BorderSide(
                                  color: _isLiked ? Colors.red : Colors.grey[300]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleDislike,
                              icon: Icon(
                                _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                color: _isDisliked ? Colors.blue : Colors.grey[600],
                                size: 20,
                              ),
                              label: Text(
                                '싫어요 ${_post!['dislikesCount'] ?? 0}',
                                style: TextStyle(
                                  color: _isDisliked ? Colors.blue : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.grey[600],
                                elevation: 0,
                                side: BorderSide(
                                  color: _isDisliked ? Colors.blue : Colors.grey[300]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF74512D),
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF74512D),
          ),
        ),
      ],
    );
  }
} 