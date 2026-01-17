import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contest_detail_screen.dart';
import 'my_contest_list_screen.dart';

/// 콘테스트 목록을 보여주는 화면
class ContestListScreen extends StatefulWidget {
  const ContestListScreen({super.key});

  @override
  State<ContestListScreen> createState() => _ContestListScreenState();
}

class _ContestListScreenState extends State<ContestListScreen> {

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

  String _getStatusText(String status) {
    switch (status) {
      case 'PRE_ACTIVE':
        return '시작 전';
      case 'ACTIVE':
        return '진행 중';
      case 'FINISHED':
        return '종료됨';
      default:
        return '시작 전';
    }
  }

  Color _getCardColor(String status) {
    switch (status) {
      case 'PRE_ACTIVE':
        return Colors.white;
      case 'ACTIVE':
        return const Color(0xFFE3F2FD); // 연한 파란색
      case 'FINISHED':
        return Colors.grey[200]!; // 회색 (disabled)
      default:
        return Colors.white;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('yyyy. MM. dd.').format(timestamp.toDate());
  }

  String _formatDateRange(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return '-';
    final startStr = DateFormat('yyyy. MM. dd.').format(start.toDate());
    final endStr = DateFormat('yyyy. MM. dd.').format(end.toDate());
    return '$startStr ~ $endStr';
  }

  Widget _buildContestCard(Map<String, dynamic> data, String docId) {
    final title = (data['title'] as String?) ?? '제목 없음';
    final description = (data['description'] as String?) ?? '';
    final participantCount = (data['participantCount'] as int?) ?? 0;
    final postingDateStart = data['postingDateStart'] as Timestamp?;
    final postingDateEnd = data['postingDateEnd'] as Timestamp?;
    final imageUrl = data['imageUrl'] as String?;

    // 날짜 기반으로 상태 계산
    final status = _calculateStatus(postingDateStart, postingDateEnd);
    final cardColor = _getCardColor(status);
    final isFinished = status == 'FINISHED';

    return Card(
      color: cardColor,
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
              builder: (context) => ContestDetailScreen(contestId: docId),
            ),
          );
        },
        child: Opacity(
          opacity: isFinished ? 0.6 : 1.0, // 종료된 것은 약간 투명하게
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 제목
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isFinished ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description.replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: TextStyle(
                          fontSize: 14,
                          color: isFinished ? Colors.grey[500] : Colors.black87,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // 날짜 정보와 상태 버튼 (같은 줄에 배치)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 날짜 정보 (왼쪽)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isFinished ? Colors.grey[500] : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateRange(postingDateStart, postingDateEnd),
                          style: TextStyle(
                            fontSize: 13,
                            color: isFinished ? Colors.grey[500] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    // 상태 버튼 (오른쪽)
                    isFinished
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '종료됨',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'PRE_ACTIVE'
                                  ? Colors.grey[300]
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: status == 'ACTIVE'
                                  ? Border.all(color: Colors.blue, width: 1)
                                  : null,
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: status == 'PRE_ACTIVE'
                                    ? Colors.black87
                                    : Colors.blue,
                              ),
                            ),
                          ),
                  ],
                ),
                // 이미지가 있는 경우 (진행 중 콘테스트)
                if (imageUrl != null && imageUrl.isNotEmpty && status == 'ACTIVE') ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
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
      ),
    );
  }

  Widget _buildAllContestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contests')
          .orderBy('createdAt', descending: true)
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
              '콘테스트를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              '등록된 콘테스트가 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            return _buildContestCard(doc.data(), doc.id);
          }).toList(),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '콘테스트',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyContestListScreen(),
                ),
              );
            },
            child: const Text(
              '내 콘테스트',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: _buildAllContestsTab(),
    );
  }
}
