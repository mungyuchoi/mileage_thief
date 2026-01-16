import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'contest_create_screen.dart';

/// 콘테스트를 관리하는 관리자 전용 화면
/// 리스트 화면 + 생성/편집/삭제 기능
class ContestManageScreen extends StatelessWidget {
  const ContestManageScreen({super.key});

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PRE_ACTIVE':
        return Colors.grey;
      case 'ACTIVE':
        return Colors.green;
      case 'FINISHED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String contestId,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '콘테스트 삭제',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '정말로 "$title" 콘테스트를 삭제하시겠습니까?\n삭제된 콘테스트는 복구할 수 없습니다.',
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('contests')
          .doc(contestId)
          .delete();

      if (context.mounted) {
        Fluttertoast.showToast(
          msg: '콘테스트가 삭제되었습니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Fluttertoast.showToast(
          msg: '콘테스트 삭제 중 오류가 발생했습니다: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '콘테스트 관리',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContestCreateScreen(),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '등록된 콘테스트가 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '오른쪽 상단 + 버튼을 눌러 추가해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final contestId = doc.id;
              final title = (data['title'] as String?) ?? '제목 없음';
              final description = (data['description'] as String?) ?? '';
              final participantCount = (data['participantCount'] as int?) ?? 0;
              final postingDateStart = data['postingDateStart'] as Timestamp?;
              final postingDateEnd = data['postingDateEnd'] as Timestamp?;

              // 날짜 기반으로 상태 계산
              final status = _calculateStatus(postingDateStart, postingDateEnd);

              return Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    // 편집 화면으로 이동 (생성 화면을 재사용)
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContestCreateScreen(contestId: contestId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description.replaceAll(RegExp(r'<[^>]*>'), ''), // HTML 태그 제거
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${_formatDate(postingDateStart)} ~ ${_formatDate(postingDateEnd)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '참여자: $participantCount명',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.black54,
                                size: 20,
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ContestCreateScreen(contestId: contestId),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () {
                                _confirmDelete(context, contestId, title);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
