import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../widgets/image_viewer.dart';

class ContestPostDetailScreen extends StatefulWidget {
  final String contestId;
  final String submissionId;

  const ContestPostDetailScreen({
    Key? key,
    required this.contestId,
    required this.submissionId,
  }) : super(key: key);

  @override
  State<ContestPostDetailScreen> createState() => _ContestPostDetailScreenState();
}

class _ContestPostDetailScreenState extends State<ContestPostDetailScreen> {
  Map<String, dynamic>? _submission;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
    _checkLikeStatus();
  }

  Future<void> _loadSubmission() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId)
          .get();

      if (doc.exists) {
        setState(() {
          _submission = doc.data();
          _isLoading = false;
        });

        // 조회수 증가
        await FirebaseFirestore.instance
            .collection('contests')
            .doc(widget.contestId)
            .collection('submissions')
            .doc(widget.submissionId)
            .update({
          'viewCount': FieldValue.increment(1),
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('제출물 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLikeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('likes')
          .doc(user.uid)
          .get();

      setState(() {
        _isLiked = likeDoc.exists;
      });
    } catch (e) {
      print('좋아요 상태 확인 오류: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (_isLiking || _submission == null) return;

    setState(() {
      _isLiking = true;
    });

    try {
      final likeRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('likes')
          .doc(user.uid);

      final submissionRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId);

      if (_isLiked) {
        // 좋아요 취소
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.delete(likeRef);
          transaction.update(submissionRef, {
            'likeCount': FieldValue.increment(-1),
          });
        });

        setState(() {
          _isLiked = false;
          _submission!['likeCount'] = ((_submission!['likeCount'] as int?) ?? 1) - 1;
        });
      } else {
        // 좋아요 추가
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.set(likeRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(submissionRef, {
            'likeCount': FieldValue.increment(1),
          });
        });

        setState(() {
          _isLiked = true;
          _submission!['likeCount'] = ((_submission!['likeCount'] as int?) ?? 0) + 1;
        });
      }
    } catch (e) {
      print('좋아요 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLiking = false;
      });
    }
  }

  // HTML에서 이미지 URL 목록 추출
  List<String> _extractImageUrlsFromHtml(String htmlContent) {
    final RegExp imgTagRegex = RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false);
    final Iterable<RegExpMatch> matches = imgTagRegex.allMatches(htmlContent);
    final List<String> urls = matches
        .map((m) => m.group(2))
        .whereType<String>()
        .toList();
    return urls;
  }

  // 이미지 URL인지 확인
  bool _isImageUrl(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('firebasestorage.googleapis.com') ||
        lowerUrl.contains('storage.googleapis.com')) {
      return true;
    }
    return imageExtensions.any((ext) => lowerUrl.contains(ext));
  }

  // HTML의 이미지를 클릭 가능한 링크로 변환
  String _makeImagesClickable(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false),
      (match) {
        final beforeSrc = match.group(1) ?? '';
        final srcUrl = match.group(2) ?? '';
        final afterSrc = match.group(3) ?? '';
        return '<a href="$srcUrl"><img${beforeSrc}src="$srcUrl"${afterSrc}/></a>';
      },
    );
  }

  void _openImageViewerFromHtml(String imageUrl, String htmlContent) {
    final List<String> imageUrls = _extractImageUrlsFromHtml(htmlContent);
    if (imageUrls.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SingleImageViewer(imageUrl: imageUrl),
        ),
      );
      return;
    }
    final int initialIndex = imageUrls.indexOf(imageUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('콘테스트 참여', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
          ),
        ),
      );
    }

    if (_submission == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('콘테스트 참여', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(
          child: Text('제출물을 찾을 수 없습니다.'),
        ),
      );
    }

    final title = _submission!['title'] as String? ?? '제목 없음';
    final contentHtml = _submission!['contentHtml'] as String? ?? '';
    final displayName = _submission!['displayName'] as String? ?? '익명';
    final photoURL = _submission!['photoURL'] as String? ?? '';
    final createdAt = _submission!['createdAt'] as Timestamp?;
    final likeCount = _submission!['likeCount'] as int? ?? 0;
    final viewCount = _submission!['viewCount'] as int? ?? 0;
    final imageUrls = _extractImageUrlsFromHtml(contentHtml);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('콘테스트 참여', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: photoURL.isNotEmpty
                        ? NetworkImage(photoURL)
                        : null,
                    child: photoURL.isEmpty
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm').format(createdAt.toDate()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 제목
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            // 본문 내용
            if (contentHtml.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Html(
                  data: contentHtml,
                  style: {
                    "body": Style(
                      fontSize: FontSize(15),
                      color: Colors.black87,
                      lineHeight: LineHeight(1.4),
                      margin: Margins.zero,
                    ),
                    "p": Style(
                      margin: Margins.only(bottom: 8),
                      padding: HtmlPaddings.zero,
                    ),
                    "img": Style(
                      margin: Margins.only(bottom: 8),
                      width: Width(100, Unit.percent),
                    ),
                    "a": Style(
                      color: Colors.blue,
                      textDecoration: TextDecoration.underline,
                    ),
                  },
                  onLinkTap: (url, _, __) {
                    if (url != null) {
                      if (_isImageUrl(url)) {
                        _openImageViewerFromHtml(url, contentHtml);
                      }
                    }
                  },
                ),
              ),
            // 통계 정보
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '조회 $viewCount회',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 좋아요 버튼
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLiking ? null : _toggleLike,
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? const Color(0xFF74512D) : Colors.white,
                  size: 24,
                ),
                label: Text(
                  '좋아요 ${likeCount}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isLiked ? const Color(0xFF74512D) : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLiked ? Colors.white : const Color(0xFF74512D),
                  disabledBackgroundColor: Colors.grey[300],
                  side: _isLiked ? const BorderSide(color: Color(0xFF74512D), width: 2) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 100), // 하단 여백
          ],
        ),
      ),
    );
  }
}
