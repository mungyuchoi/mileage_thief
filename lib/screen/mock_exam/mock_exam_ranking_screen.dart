import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../const/colors.dart';
import '../../models/mock_exam_model.dart';
import '../../services/analytics_service.dart';
import '../../services/mock_exam_service.dart';
import 'mock_exam_helpers.dart';

class MockExamRankingScreen extends StatefulWidget {
  final MockExam exam;

  const MockExamRankingScreen({
    super.key,
    required this.exam,
  });

  @override
  State<MockExamRankingScreen> createState() => _MockExamRankingScreenState();
}

class _MockExamRankingScreenState extends State<MockExamRankingScreen> {
  final MockExamService _service = MockExamService();
  late Future<List<MockExamLeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logScreenView(
      'mock_exam_ranking',
      screenClass: 'MockExamRankingScreen',
      source: 'screen_init',
    ));
    _future = _load();
  }

  Future<List<MockExamLeaderboardEntry>> _load() {
    return _service.loadLeaderboard(examId: widget.exam.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('마일고사 랭킹'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<MockExamLeaderboardEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MockExamEmptyState(
              icon: Icons.error_outline,
              title: '랭킹을 불러오지 못했어요',
              message: '잠시 후 다시 시도해 주세요.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            );
          }
          final entries = snapshot.data ?? const <MockExamLeaderboardEntry>[];
          if (entries.isEmpty) {
            return MockExamEmptyState(
              icon: Icons.emoji_events_outlined,
              title: '아직 랭킹이 없어요',
              message: '첫 응시자가 되면 이곳에 기록이 표시됩니다.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            );
          }

          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: entries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _RankingHeader(exam: widget.exam);
                }
                final rank = index;
                final entry = entries[index - 1];
                return _RankingTile(
                  rank: rank,
                  entry: entry,
                  isMe: entry.uid == currentUid,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  final MockExam exam;

  const _RankingHeader({required this.exam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: mockExamAccentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: mockExamAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.title,
                  style: McTextStyles.cardTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                const Text(
                  '최고 점수 기준 · 동점은 풀이 시간순',
                  style: McTextStyles.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final MockExamLeaderboardEntry entry;
  final bool isMe;

  const _RankingTile({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= 3 ? mockExamAccent : McColors.muted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? mockExamAccentSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? mockExamAccent : McColors.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Avatar(entry: entry),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McTextStyles.bodyStrong,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const MockExamChip(label: '나'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  mockExamDurationLabel(entry.durationSeconds),
                  style: McTextStyles.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.score}점',
            style: McTextStyles.cardTitle.copyWith(
              color: mockExamAccent,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final MockExamLeaderboardEntry entry;

  const _Avatar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: McColors.field,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_outline,
        color: McColors.muted,
        size: 20,
      ),
    );

    if (entry.photoUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        entry.photoUrl,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
