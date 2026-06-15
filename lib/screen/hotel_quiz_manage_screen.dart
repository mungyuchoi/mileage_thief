import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/hotel_catch_service.dart';
import 'hotel_quiz_create_screen.dart';

/// 내가 이 호텔에 낸 퀴즈 목록 — 수정/삭제/추가.
class HotelQuizManageScreen extends StatelessWidget {
  const HotelQuizManageScreen({
    super.key,
    required this.hotelId,
    required this.hotelName,
  });

  final String hotelId;
  final String hotelName;

  static const Map<String, String> _typeLabel = <String, String>{
    'ox': 'OX',
    'mcq': '객관식',
    'short': '주관식',
  };
  static const Map<String, String> _tagLabel = <String, String>{
    'honeymoon': '🍯 신혼각',
    'parents': '👨‍👩‍👧 효도각',
    'view': '🌊 뷰맛집',
    'value': '💸 가성비',
    'upgrade': '🛎️ 업글',
    'general': '📌 일반',
  };

  Future<void> _openCreate(BuildContext context, {HotelQuizItem? quiz}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => HotelQuizCreateScreen(
          hotelId: hotelId,
          hotelName: hotelName,
          quiz: quiz,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, HotelQuizItem q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 삭제'),
        content: const Text('이 퀴즈를 삭제할까요? 되돌릴 수 없어요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await HotelCatchService.instance.deleteQuiz(hotelId, q.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('삭제했어요')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('삭제에 실패했어요')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('내 퀴즈 · $hotelName')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('퀴즈 내기'),
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요해요'))
          : StreamBuilder<List<HotelQuizItem>>(
              stream: HotelCatchService.instance.myQuizzes(hotelId, user.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final quizzes = snap.data ?? const <HotelQuizItem>[];
                if (quizzes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '아직 낸 퀴즈가 없어요.\n아래 + 버튼으로 첫 퀴즈를 내보세요!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: quizzes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final q = quizzes[i];
                    final rate = q.solveCount > 0
                        ? '${(q.correctCount * 100 / q.solveCount).round()}%'
                        : '-';
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(spacing: 6, children: <Widget>[
                              Chip(
                                label: Text(_typeLabel[q.type] ?? q.type),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text(_tagLabel[q.tag] ?? q.tag),
                                visualDensity: VisualDensity.compact,
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              q.question,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Text(
                                  '${q.solveCount}명 풀이 · 정답률 $rate',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: '수정',
                                  onPressed: () =>
                                      _openCreate(context, quiz: q),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: '삭제',
                                  onPressed: () => _confirmDelete(context, q),
                                ),
                              ],
                            ),
                          ],
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
