import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contest_post_detail_screen.dart';

/// 내 콘테스트 목록을 보여주는 화면
class MyContestListScreen extends StatefulWidget {
  const MyContestListScreen({super.key});

  @override
  State<MyContestListScreen> createState() => _MyContestListScreenState();
}

class _MyContestListScreenState extends State<MyContestListScreen> {
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('MM.dd.').format(timestamp.toDate());
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('yyyy.MM.dd HH:mm').format(timestamp.toDate());
  }

  // HTML에서 이미지 URL 추출
  List<String> _extractImageUrlsFromHtml(String htmlContent) {
    final RegExp imgTagRegex = RegExp(r'<img([^>]*?)src="([^"]*)"([^>]*?)/?>', caseSensitive: false);
    final Iterable<RegExpMatch> matches = imgTagRegex.allMatches(htmlContent);
    final List<String> urls = matches
        .map((m) => m.group(2))
        .whereType<String>()
        .toList();
    return urls;
  }

  // 제출물 데이터 로드
  Future<List<Map<String, dynamic>>> _loadSubmissionsData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userContestDocs,
  ) async {
    final submissions = <Map<String, dynamic>>[];

    for (final doc in userContestDocs) {
      final data = doc.data();
      final contestId = data['contestId'] as String?;
      final contestTitle = data['contestTitle'] as String?;
      final submissionId = data['submissionId'] as String?;
      final submissionTitle = data['submissionTitle'] as String?;
      final participatedAt = data['participatedAt'] as Timestamp?;

      if (contestId == null || submissionId == null) continue;

      // 제출물 상세 정보 가져오기
      Map<String, dynamic>? submissionData;
      try {
        final submissionDoc = await FirebaseFirestore.instance
            .collection('contests')
            .doc(contestId)
            .collection('submissions')
            .doc(submissionId)
            .get();

        if (submissionDoc.exists) {
          submissionData = submissionDoc.data();
        }
      } catch (e) {
        print('제출물 정보 로드 오류: $e');
      }

      submissions.add({
        'contestId': contestId,
        'contestTitle': contestTitle,
        'submissionId': submissionId,
        'submissionTitle': submissionTitle,
        'participatedAt': participatedAt,
        'submissionData': submissionData,
      });
    }

    return submissions;
  }

  Widget _buildSubmissionCard({
    required String contestId,
    required String contestTitle,
    required String submissionId,
    required String submissionTitle,
    required Timestamp? participatedAt,
    required Map<String, dynamic>? submissionData,
  }) {
    final displayName = submissionData?['displayName'] as String? ?? '익명';
    final photoURL = submissionData?['photoURL'] as String? ?? '';
    final createdAt = submissionData?['createdAt'] as Timestamp? ?? participatedAt;
    final viewCount = submissionData?['viewCount'] as int? ?? 0;
    final likeCount = submissionData?['likeCount'] as int? ?? 0;
    final contentHtml = submissionData?['contentHtml'] as String? ?? '';
    final imageUrls = _extractImageUrlsFromHtml(contentHtml);
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContestPostDetailScreen(
                contestId: contestId,
                submissionId: submissionId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 콘테스트 제목 (회색, 작게)
              Text(
                contestTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              // 제출물 제목 (진하게, 크게)
              Text(
                submissionTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // 작성자 정보 및 통계
              Row(
                children: [
                  // 프로필 이미지
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: photoURL.isNotEmpty
                        ? NetworkImage(photoURL)
                        : null,
                    child: photoURL.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // 작성자 이름
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 날짜
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  // 조회수
                  Text(
                    '조회 ${viewCount}회',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 좋아요 수
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likeCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 썸네일 이미지 (있는 경우)
              if (firstImageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    firstImageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '내 콘테스트',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '내 콘테스트',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contests')
            .orderBy('participatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '내 콘테스트를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }

          final userContestDocs = snapshot.data?.docs ?? [];
          if (userContestDocs.isEmpty) {
            return const Center(
              child: Text(
                '참여한 콘테스트가 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          // 제출물 정보를 가져오기 위한 FutureBuilder 사용
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadSubmissionsData(userContestDocs),
            builder: (context, submissionsSnapshot) {
              if (submissionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                  ),
                );
              }

              if (submissionsSnapshot.hasError) {
                return Center(
                  child: Text(
                    '제출물 정보를 불러오는 중 오류가 발생했습니다.\n${submissionsSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                );
              }

              final submissions = submissionsSnapshot.data ?? [];
              if (submissions.isEmpty) {
                return const Center(
                  child: Text(
                    '참여한 콘테스트가 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: submissions.map((item) {
                  return _buildSubmissionCard(
                    contestId: item['contestId'] as String,
                    contestTitle: item['contestTitle'] as String? ?? '콘테스트',
                    submissionId: item['submissionId'] as String,
                    submissionTitle: item['submissionTitle'] as String? ?? '제목 없음',
                    participatedAt: item['participatedAt'] as Timestamp?,
                    submissionData: item['submissionData'] as Map<String, dynamic>?,
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
