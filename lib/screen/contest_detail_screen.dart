import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'community_post_create_screen_v3.dart';
import 'community_detail_screen.dart';
import 'contest_post_create_screen.dart';
import 'contest_post_detail_screen.dart';
import '../services/branch_service.dart';

/// 콘테스트 상세 화면
class ContestDetailScreen extends StatefulWidget {
  final String contestId;

  const ContestDetailScreen({
    super.key,
    required this.contestId,
  });

  @override
  State<ContestDetailScreen> createState() => _ContestDetailScreenState();
}

class _ContestDetailScreenState extends State<ContestDetailScreen> {
  Map<String, dynamic>? _contest;
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String _sortOrder = '최신순'; // 최신순, 인기순, 순위순

  /// 날짜 기반으로 콘테스트 상태를 계산
  String _calculateStatus(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return 'PRE_ACTIVE';
    
    final now = DateTime.now();
    final startDate = start.toDate();
    final endDate = end.toDate();
    
    if (now.isBefore(startDate)) {
      return 'PRE_ACTIVE'; // 시작 전
    } else if (now.isAfter(endDate)) {
      return 'FINISHED'; // 종료됨
    } else {
      return 'ACTIVE'; // 진행 중
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('yyyy년 M월 d일(E)', 'ko_KR').format(timestamp.toDate());
  }

  String _formatDateRange(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '-';
    final startStr = DateFormat('yyyy. MM. dd.').format(start.toDate());
    final endStr = DateFormat('yyyy. MM. dd.').format(end.toDate());
    return '$startStr ~ $endStr';
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

  @override
  void initState() {
    super.initState();
    _loadContest();
    _loadSubmissions();
  }

  Future<void> _loadContest() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .get();

      if (doc.exists) {
        setState(() {
          _contest = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('콘테스트 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubmissions() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions');

      // 정렬 기준에 따라 쿼리 변경
      if (_sortOrder == '최신순') {
        query = query.orderBy('createdAt', descending: true);
      } else if (_sortOrder == '인기순') {
        query = query.orderBy('likeCount', descending: true);
      } else if (_sortOrder == '순위순') {
        query = query.orderBy('rank', descending: false).where('rank', isGreaterThan: 0);
      }

      final snapshot = await query.get();

      setState(() {
        _submissions = snapshot.docs.map<Map<String, dynamic>>((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
          return <String, dynamic>{
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print('제출물 로드 오류: $e');
    }
  }

  Future<void> _createPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final status = _calculateStatus(
      _contest?['postingDateStart'] as Timestamp?,
      _contest?['postingDateEnd'] as Timestamp?,
    );

    if (status != 'ACTIVE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 참여 기간이 아닙니다.')),
      );
      return;
    }

    // 게시글 작성 화면으로 이동 (contestId 전달)
    final contestTitle = (_contest!['title'] as String?) ?? '콘테스트';
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContestPostCreateScreen(
          contestId: widget.contestId,
          contestTitle: contestTitle,
        ),
      ),
    );

    // 게시글 작성 완료 후 새로고침
    if (result == true) {
      _loadSubmissions();
    }
  }

  Future<void> _shareContest() async {
    if (_contest == null) return;

    final title = (_contest!['title'] as String?) ?? '콘테스트';
    final description = (_contest!['description'] as String?) ?? '';
    
    // HTML 태그 제거하여 간단한 텍스트로 변환
    final plainDescription = description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final shareDescription = plainDescription.length > 100 
        ? '${plainDescription.substring(0, 100)}...' 
        : plainDescription;

    try {
      // Branch.io 딥링크 생성 및 공유 시트 표시
      await BranchService().showContestShareSheet(
        contestId: widget.contestId,
        title: title,
        description: shareDescription.isNotEmpty ? shareDescription : '마일리지 커뮤니티의 콘테스트에 참여해보세요!',
      );
    } catch (e) {
      print('콘테스트 공유 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('콘테스트', style: TextStyle(color: Colors.black)),
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

    if (_contest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('콘테스트', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(
          child: Text('콘테스트를 찾을 수 없습니다.'),
        ),
      );
    }

    final title = (_contest!['title'] as String?) ?? '제목 없음';
    final description = (_contest!['description'] as String?) ?? '';
    final postingDateStart = _contest!['postingDateStart'] as Timestamp?;
    final postingDateEnd = _contest!['postingDateEnd'] as Timestamp?;
    final participantCount = (_contest!['participantCount'] as int?) ?? 0;
    final status = _calculateStatus(postingDateStart, postingDateEnd);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('콘테스트', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: _shareContest,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 콘테스트 상세 정보
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 제목과 내용 사이 구분선
                        Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                        const SizedBox(height: 16),
                        // 설명 (HTML 뷰어)
                        if (description.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Html(
                              data: description,
                              style: {
                                "body": Style(
                                  fontSize: FontSize(14),
                                  color: Colors.black87,
                                  lineHeight: LineHeight(1.5),
                                  margin: Margins.zero,
                                ),
                                "h2": Style(
                                  fontSize: FontSize(18),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  margin: Margins.only(bottom: 12, top: 8),
                                ),
                                "h3": Style(
                                  fontSize: FontSize(16),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  margin: Margins.only(bottom: 10, top: 8),
                                ),
                                "p": Style(
                                  margin: Margins.only(bottom: 8),
                                  padding: HtmlPaddings.zero,
                                ),
                                "ul": Style(
                                  margin: Margins.only(bottom: 8, left: 20),
                                  padding: HtmlPaddings.zero,
                                ),
                                "li": Style(
                                  margin: Margins.only(bottom: 4),
                                  padding: HtmlPaddings.zero,
                                ),
                                "hr": Style(
                                  margin: Margins.symmetric(vertical: 16),
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                  ),
                                ),
                                "strong": Style(
                                  fontWeight: FontWeight.bold,
                                ),
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        // 이벤트 경품 (있는 경우)
                        if (_contest!['prize'] != null) ...[
                          Row(
                            children: [
                              const Text(
                                '이벤트 경품: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _contest!['prize'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // 당첨자 발표 (있는 경우)
                        if (_contest!['winnerAnnouncement'] != null) ...[
                          Row(
                            children: [
                              const Text(
                                '당첨자 발표: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _contest!['winnerAnnouncement'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // 참여 안내 (있는 경우)
                        if (_contest!['participationNote'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _contest!['participationNote'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        // 링크들 (있는 경우)
                        if (_contest!['eventDetailUrl'] != null || _contest!['privacyConsentUrl'] != null) ...[
                          const SizedBox(height: 16),
                          if (_contest!['eventDetailUrl'] != null)
                            InkWell(
                              onTap: () async {
                                final url = _contest!['eventDetailUrl'] as String;
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                '이벤트 자세히 보기',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (_contest!['eventDetailUrl'] != null && _contest!['privacyConsentUrl'] != null)
                            const SizedBox(height: 8),
                          if (_contest!['privacyConsentUrl'] != null)
                            InkWell(
                              onTap: () async {
                                final url = _contest!['privacyConsentUrl'] as String;
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                '개인정보 수집 이용 동의하기',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 참여자 목록 헤더
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 날짜 (위쪽)
                        Row(
                          children: [
                            Text(
                              _formatDateRange(postingDateStart, postingDateEnd),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '참여자 ${participantCount}명',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 정렬 드롭다운 (날짜 밑 왼쪽)
                        DropdownButton<String>(
                          value: _sortOrder,
                          underline: Container(),
                          dropdownColor: Colors.white,
                          items: const [
                            DropdownMenuItem(value: '최신순', child: Text('최신순')),
                            DropdownMenuItem(value: '인기순', child: Text('인기순')),
                            DropdownMenuItem(value: '순위순', child: Text('순위순')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortOrder = value;
                              });
                              _loadSubmissions();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // 참여자 목록
                  if (_submissions.isEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(32),
                      child: const Center(
                        child: Text(
                          '아직 참여한 게시글이 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) {
                        final submission = _submissions[index];
                        final postId = submission['postId'] as String?;
                        final dateString = submission['dateString'] as String?;

                        if (postId == null || dateString == null) {
                          return const SizedBox.shrink();
                        }

                        // 이미지 URL 추출
                        final contentHtml = submission['contentHtml'] as String? ?? '';
                        final imageUrls = _extractImageUrlsFromHtml(contentHtml);
                        final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
                        final submissionId = submission['id'] as String? ?? postId;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContestPostDetailScreen(
                                  contestId: widget.contestId,
                                  submissionId: submissionId,
                                ),
                              ),
                            ).then((_) {
                              // 돌아왔을 때 새로고침
                              _loadSubmissions();
                            });
                          },
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 1),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 이미지 썸네일
                                if (firstImageUrl != null)
                                  Container(
                                    width: 80,
                                    height: 80,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[200],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        firstImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        submission['title'] as String? ?? '제목 없음',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            submission['displayName'] as String? ?? submission['authorName'] as String? ?? '익명',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('HH:mm').format(
                                              (submission['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '조회 ${submission['viewCount'] ?? 0}회',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (submission['rank'] != null && (submission['rank'] as int) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${submission['rank']}위',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 100), // 하단 마진 (소프트 키 방지)
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: status == 'ACTIVE'
          ? FloatingActionButton(
              onPressed: _createPost,
              backgroundColor: const Color(0xFF74512D),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }
}
