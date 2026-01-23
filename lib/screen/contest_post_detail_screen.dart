import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../widgets/image_viewer.dart';
import 'contest_post_edit_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
    print('=== 이미지 URL 추출 시작 ===');
    print('HTML 내용 길이: ${htmlContent.length}');
    
    final RegExp imgTagRegex = RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false);
    final Iterable<RegExpMatch> matches = imgTagRegex.allMatches(htmlContent);
    
    print('정규식 매칭 결과 개수: ${matches.length}');
    
    final List<String> urls = matches
        .map((m) {
          final url = m.group(2);
          print('추출된 URL: $url');
          return url;
        })
        .whereType<String>()
        .toList();
    
    print('최종 추출된 URL 개수: ${urls.length}');
    print('=== 이미지 URL 추출 완료 ===');
    
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

  // HTML의 이미지를 클릭 가능한 링크로 변환하고 전체 너비로 설정
  String _makeImagesClickable(String htmlContent) {
    try {
      print('=== 이미지 클릭 가능 변환 시작 ===');
      print('원본 HTML 길이: ${htmlContent.length}');
      print('원본 HTML (처음 500자): ${htmlContent.substring(0, htmlContent.length > 500 ? 500 : htmlContent.length)}');
      
      final imgRegex = RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false);
      final matches = imgRegex.allMatches(htmlContent);
      print('이미지 태그 발견 개수: ${matches.length}');
      
      if (matches.isEmpty) {
        print('이미지 태그가 없습니다. 원본 HTML 반환');
        return htmlContent;
      }
      
      String result = htmlContent.replaceAllMapped(
        imgRegex,
        (match) {
          try {
            final beforeSrc = match.group(1) ?? '';
            final srcUrl = match.group(2) ?? '';
            final afterSrc = match.group(3) ?? '';
            
            print('--- 이미지 처리 ---');
            print('beforeSrc: $beforeSrc');
            print('srcUrl: $srcUrl');
            print('afterSrc: $afterSrc');
            
            if (srcUrl.isEmpty) {
              print('경고: srcUrl이 비어있습니다. 원본 태그 반환');
              return match.group(0) ?? '';
            }
            
            // 기존 style 속성 제거하고 새로운 스타일 추가
            String imgAttributes = beforeSrc.replaceAll(
              RegExp(r'style="[^"]*"', caseSensitive: false),
              '',
            ).trim();
            
            print('정리된 imgAttributes: $imgAttributes');
            
            // 공백 정리 - imgAttributes가 비어있어도 style 앞에 공백이 필요
            if (imgAttributes.isEmpty) {
              imgAttributes = ' ';
            } else if (!imgAttributes.endsWith(' ')) {
              imgAttributes = '$imgAttributes ';
            }
            
            // 이미지를 감싸는 구조 없이 이미지만 반환 (TagExtension에서 처리)
            // div와 a 태그를 제거하고 이미지만 반환하여 TagExtension이 직접 처리하도록 함
            final imgWithStyle = '<img${imgAttributes}style="width: 100%; max-width: 100%; display: block; margin: 8px 0; padding: 0; box-sizing: border-box;" src="$srcUrl"${afterSrc}/>';
            
            print('변환된 이미지 태그: $imgWithStyle');
            
            // 이미지만 반환 (링크는 TagExtension에서 GestureDetector로 처리)
            return imgWithStyle;
          } catch (e) {
            print('이미지 변환 중 오류 발생: $e');
            print('스택 트레이스: ${StackTrace.current}');
            return match.group(0) ?? '';
          }
        },
      );
      
      print('변환된 HTML 길이: ${result.length}');
      print('변환된 HTML (처음 500자): ${result.substring(0, result.length > 500 ? 500 : result.length)}');
      print('=== 이미지 클릭 가능 변환 완료 ===');
      
      return result;
    } catch (e) {
      print('_makeImagesClickable 함수에서 오류 발생: $e');
      print('스택 트레이스: ${StackTrace.current}');
      print('원본 HTML 반환');
      return htmlContent;
    }
  }

  // p 태그 내부의 줄바꿈 문자를 <br> 태그로 변환
  String _convertNewlinesInPTags(String htmlContent) {
    return htmlContent.replaceAllMapped(
      RegExp(r'<p([^>]*?)>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) {
        final pAttributes = match.group(1) ?? '';
        final pContent = match.group(2) ?? '';
        // 줄바꿈 문자를 <br> 태그로 변환
        final convertedContent = pContent
            .replaceAll('\n\n', '<br><br>') // 연속된 줄바꿈은 두 개의 <br>로
            .replaceAll('\n', '<br>'); // 단일 줄바꿈은 <br>로
        return '<p$pAttributes>$convertedContent</p>';
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

  void _navigateToEdit() {
    if (_submission == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContestPostEditScreen(
          contestId: widget.contestId,
          submissionId: widget.submissionId,
          initialSubmission: _submission!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // 수정 완료 후 데이터 새로고침
        _loadSubmission();
      }
    });
  }

  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSubmission();
    }
  }

  Future<void> _deleteSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: '로그인이 필요합니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. contests/{contestId}/submissions/{submissionId} 삭제
      final submissionRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId);
      batch.delete(submissionRef);

      // 2. 좋아요 서브컬렉션 삭제 (모든 좋아요 문서 삭제)
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('likes')
          .get();
      
      for (final likeDoc in likesSnapshot.docs) {
        batch.delete(likeDoc.reference);
      }

      // 3. users/{uid}/contests/{contestId} 삭제
      final userContestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contests')
          .doc(widget.contestId);
      batch.delete(userContestRef);

      // 4. contests/{contestId}의 participantCount 감소
      final contestRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId);
      batch.update(contestRef, {
        'participantCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 배치 실행
      await batch.commit();

      Fluttertoast.showToast(
        msg: '게시글이 삭제되었습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // 삭제 완료 후 이전 화면으로 돌아가기
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('제출물 삭제 오류: $e');
      Fluttertoast.showToast(
        msg: '게시글 삭제 중 오류가 발생했습니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Widget _buildMoreOptionsMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final submissionUid = _submission?['uid'] as String?;
    
    // 본인 작성 글인지 확인
    if (user == null || submissionUid != user.uid) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black),
      color: Colors.white,
      onSelected: (value) {
        if (value == 'edit') {
          _navigateToEdit();
        } else if (value == 'delete') {
          _showDeleteConfirmDialog();
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text('수정', style: TextStyle(color: Colors.black87)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
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
        actions: [
          _buildMoreOptionsMenu(),
        ],
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
              Builder(
                builder: (context) {
                  // 이미지 URL 추출
                  final extractedUrls = _extractImageUrlsFromHtml(contentHtml);
                  
                  // HTML에서 이미지 태그 제거 (텍스트만 남김)
                  String textOnlyHtml = contentHtml.replaceAll(
                    RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false),
                    '',
                  );
                  textOnlyHtml = _convertNewlinesInPTags(textOnlyHtml);
                  
                  final screenWidth = MediaQuery.of(context).size.width;
                  
                  // 텍스트와 이미지를 분리하여 렌더링
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 텍스트 내용 (padding 있음)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Html(
                          data: textOnlyHtml,
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
                            "a": Style(
                              color: Colors.blue,
                              textDecoration: TextDecoration.none,
                            ),
                          },
                        ),
                      ),
                      // 이미지들 (padding 없음, 전체 너비)
                      ...extractedUrls.map((imageUrl) {
                        return Container(
                          color: Colors.white,
                          margin: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _openImageViewerFromHtml(imageUrl, contentHtml);
                            },
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: screenWidth,
                              height: null, // 비율 유지
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: screenWidth,
                                  height: 200,
                                  alignment: Alignment.center,
                                  color: Colors.grey[200],
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: screenWidth,
                                  height: 200,
                                  alignment: Alignment.center,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
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
