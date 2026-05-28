import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../const/colors.dart';
import '../../models/mock_exam_model.dart';
import '../../services/analytics_service.dart';
import '../../services/mock_exam_service.dart';
import '../../widgets/admob_banner.dart';
import 'mock_exam_helpers.dart';
import 'mock_exam_ranking_screen.dart';
import 'mock_exam_result_screen.dart';
import 'mock_exam_take_screen.dart';

class MockExamListScreen extends StatefulWidget {
  final VoidCallback? onRequireLogin;

  const MockExamListScreen({
    super.key,
    this.onRequireLogin,
  });

  @override
  State<MockExamListScreen> createState() => _MockExamListScreenState();
}

class _MockExamListScreenState extends State<MockExamListScreen> {
  static const String _rewardIntroDismissedKey =
      'mock_exam_reward_intro_dismissed';

  final MockExamService _service = MockExamService();
  late Future<_MockExamListState> _future;
  bool? _showRewardIntroOverride;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logScreenView(
      'mock_exam_list',
      screenClass: 'MockExamListScreen',
      source: 'screen_init',
    ));
    _future = _load();
  }

  Future<_MockExamListState> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _MockExamListState(
        isLoggedIn: false,
        isAdmin: false,
        showRewardIntro: false,
        exams: <MockExam>[],
        progressByExamId: <String, MockExamProgress>{},
      );
    }

    final isAdmin = await _service.isAdminUser(user);
    final results = await Future.wait<dynamic>([
      _service.loadExams(includeDraft: isAdmin),
      _service.loadProgressMap(user.uid),
      SharedPreferences.getInstance(),
    ]);
    final prefs = results[2] as SharedPreferences;
    return _MockExamListState(
      isLoggedIn: true,
      isAdmin: isAdmin,
      showRewardIntro: !(prefs.getBool(_rewardIntroDismissedKey) ?? false),
      exams: results[0] as List<MockExam>,
      progressByExamId: results[1] as Map<String, MockExamProgress>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _openLogin() {
    Fluttertoast.showToast(msg: '마일고사는 로그인 후 이용할 수 있습니다.');
    widget.onRequireLogin?.call();
  }

  Future<void> _openTake(MockExam exam) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_take'),
        builder: (_) => MockExamTakeScreen(exam: exam),
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openResult(String attemptId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_result'),
        builder: (_) => MockExamResultScreen(attemptId: attemptId),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openRanking(MockExam exam) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_ranking'),
        builder: (_) => MockExamRankingScreen(exam: exam),
      ),
    );
  }

  void _showLockedToast() {
    Fluttertoast.showToast(msg: '아직 잠긴 마일고사입니다.');
  }

  Future<void> _dismissRewardIntro() async {
    setState(() => _showRewardIntroOverride = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rewardIntroDismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('마일고사'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
      ),
      body: FutureBuilder<_MockExamListState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MockExamEmptyState(
              icon: Icons.error_outline,
              title: '모의고사를 불러오지 못했어요',
              message: '잠시 후 다시 시도해 주세요.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            );
          }

          final state = snapshot.data;
          if (state == null || !state.isLoggedIn) {
            return MockExamEmptyState(
              icon: Icons.lock_outline,
              title: '로그인이 필요해요',
              message: '점수와 랭킹을 기록하려면 로그인이 필요합니다.',
              actionLabel: '로그인하기',
              onAction: _openLogin,
            );
          }

          if (state.exams.isEmpty) {
            return const MockExamEmptyState(
              icon: Icons.quiz_outlined,
              title: '열린 마일고사가 없어요',
              message: '공개된 회차가 생기면 여기에서 바로 응시할 수 있습니다.',
            );
          }

          final showRewardIntro =
              _showRewardIntroOverride ?? state.showRewardIntro;
          final showInlineAd = state.exams.length >= 2;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
              itemCount: state.exams.length +
                  (showRewardIntro ? 1 : 0) +
                  (showInlineAd ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (showRewardIntro && index == 0) {
                  return _MockExamIntroCard(onDismiss: _dismissRewardIntro);
                }
                var examIndex = showRewardIntro ? index - 1 : index;
                if (showInlineAd && examIndex == 1) {
                  return const _MockExamInlineAd();
                }
                if (showInlineAd && examIndex > 1) {
                  examIndex -= 1;
                }
                final exam = state.exams[examIndex];
                final progress = state.progressByExamId[exam.id];
                return _ExamCard(
                  exam: exam,
                  progress: progress,
                  isAdmin: state.isAdmin,
                  onTake: () => _openTake(exam),
                  onResult: progress?.bestAttemptId == null
                      ? null
                      : () => _openResult(progress!.bestAttemptId!),
                  onRanking: () => _openRanking(exam),
                  onLocked: _showLockedToast,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MockExamInlineAd extends StatelessWidget {
  const _MockExamInlineAd();

  @override
  Widget build(BuildContext context) {
    return const AppBannerAd(
      padding: EdgeInsets.symmetric(vertical: 2),
    );
  }
}

class _MockExamIntroCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const _MockExamIntroCard({
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3D8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: Color(0xFFB66A00),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '첫 응시 보상',
                      style: McTextStyles.bodyStrong.copyWith(fontSize: 15),
                    ),
                    const MockExamChip(
                      label: '+100 땅콩',
                      color: Color(0xFFB66A00),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '마일고사를 제출하면 회차별 첫 응시에 한해 땅콩 100개를 지급합니다. '
                  '재도전은 점수와 랭킹 갱신만 가능하며 땅콩 보상은 추가 지급되지 않습니다.',
                  style: McTextStyles.body.copyWith(
                    color: McColors.inkSoft,
                    fontSize: 13,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '풀이 후 오답과 해설을 확인하고, 랭킹에서 내 기록을 비교해 보세요.',
                  style: McTextStyles.meta.copyWith(color: McColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox.square(
            dimension: 32,
            child: IconButton(
              tooltip: '닫기',
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                foregroundColor: McColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final MockExam exam;
  final MockExamProgress? progress;
  final bool isAdmin;
  final VoidCallback onTake;
  final VoidCallback? onResult;
  final VoidCallback onRanking;
  final VoidCallback onLocked;

  const _ExamCard({
    required this.exam,
    required this.progress,
    required this.isAdmin,
    required this.onTake,
    required this.onResult,
    required this.onRanking,
    required this.onLocked,
  });

  @override
  Widget build(BuildContext context) {
    final completed = progress?.completed == true;
    final canRetry = progress?.canRetry == true;
    final lockedForUser = exam.isLocked && !isAdmin;
    final primaryLabel = lockedForUser
        ? '잠금'
        : completed
            ? canRetry
                ? '다시 풀기'
                : '결과 보기'
            : '응시하기';
    final primaryAction = lockedForUser
        ? onLocked
        : completed && !canRetry
            ? onResult
            : onTake;
    final primaryIcon = lockedForUser ? Icons.lock_outline : null;
    final cardBorderRadius = BorderRadius.circular(12);
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: lockedForUser ? McColors.field : mockExamAccentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                lockedForUser ? Icons.lock_outline : Icons.quiz_outlined,
                color: lockedForUser ? McColors.muted : mockExamAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        exam.title,
                        style: McTextStyles.cardTitle.copyWith(fontSize: 17),
                      ),
                      if (exam.isDraft || exam.isLocked || isAdmin)
                        MockExamChip(
                          label: mockExamStatusLabel(exam.status),
                          color: mockExamStatusColor(exam.status),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exam.description,
                    style: McTextStyles.body.copyWith(
                      color: McColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MockExamChip(label: '${exam.questionCount}문항'),
            MockExamChip(label: '${exam.totalScore}점'),
            MockExamChip(label: '${exam.timeLimitSeconds ~/ 60}분'),
            if (completed)
              MockExamChip(
                label: '최고 ${progress!.bestScore}점',
                color: Colors.green,
              ),
          ],
        ),
        if (completed && progress != null) ...[
          const SizedBox(height: 12),
          Text(
            '응시 ${progress!.attemptCount}회 · '
            '최고 기록 ${mockExamDurationLabel(progress!.bestDurationSeconds)}',
            style: McTextStyles.meta,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: primaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      lockedForUser ? McColors.mutedLight : mockExamAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: primaryIcon == null
                    ? Text(primaryLabel)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(primaryIcon, size: 18),
                          const SizedBox(width: 6),
                          Text(primaryLabel),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: lockedForUser ? onLocked : onRanking,
              tooltip: lockedForUser ? '잠긴 회차' : '랭킹',
              style: IconButton.styleFrom(
                backgroundColor:
                    lockedForUser ? const Color(0xFFF2F2F3) : McColors.field,
                foregroundColor:
                    lockedForUser ? McColors.mutedLight : McColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.emoji_events_outlined),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onResult,
              tooltip: '결과',
              style: IconButton.styleFrom(
                backgroundColor:
                    lockedForUser ? const Color(0xFFF2F2F3) : McColors.field,
                foregroundColor: onResult == null || lockedForUser
                    ? McColors.mutedLight
                    : McColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lockedForUser ? const Color(0xFFF8F8FA) : Colors.white,
        borderRadius: cardBorderRadius,
        border: Border.all(
          color: lockedForUser ? const Color(0xFFE5E5EA) : McColors.line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: lockedForUser ? 0.56 : 1,
            child: cardContent,
          ),
          if (lockedForUser)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: cardBorderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: cardBorderRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (lockedForUser)
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: McColors.muted,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '오픈 예정',
                          style: McTextStyles.meta.copyWith(
                            color: McColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MockExamListState {
  final bool isLoggedIn;
  final bool isAdmin;
  final bool showRewardIntro;
  final List<MockExam> exams;
  final Map<String, MockExamProgress> progressByExamId;

  const _MockExamListState({
    required this.isLoggedIn,
    required this.isAdmin,
    required this.showRewardIntro,
    required this.exams,
    required this.progressByExamId,
  });
}
