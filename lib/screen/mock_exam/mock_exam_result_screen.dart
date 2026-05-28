import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../const/colors.dart';
import '../../models/mock_exam_model.dart';
import '../../services/analytics_service.dart';
import '../../services/branch_service.dart';
import '../../services/mock_exam_service.dart';
import '../../widgets/admob_banner.dart';
import 'mock_exam_helpers.dart';
import 'mock_exam_ranking_screen.dart';
import 'mock_exam_take_screen.dart';

class MockExamResultScreen extends StatefulWidget {
  final String attemptId;
  final MockExamAttempt? initialAttempt;

  const MockExamResultScreen({
    super.key,
    required this.attemptId,
    this.initialAttempt,
  });

  @override
  State<MockExamResultScreen> createState() => _MockExamResultScreenState();
}

class _MockExamResultScreenState extends State<MockExamResultScreen> {
  final MockExamService _service = MockExamService();
  late Future<_ResultState> _future;
  bool _sharing = false;
  bool _buyingRetry = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logScreenView(
      'mock_exam_result',
      screenClass: 'MockExamResultScreen',
      source: 'screen_init',
    ));
    _future = _load();
  }

  Future<_ResultState> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final attempt = widget.initialAttempt ??
        await _service.loadAttempt(
          uid: user.uid,
          attemptId: widget.attemptId,
        );
    if (attempt == null) {
      throw StateError('응시 결과를 찾을 수 없습니다.');
    }

    final results = await Future.wait<dynamic>([
      _service.loadExam(attempt.examId),
      _service.loadQuestions(attempt.examId),
      _service.loadProgress(uid: user.uid, examId: attempt.examId),
    ]);
    final exam = results[0] as MockExam?;
    final questions = results[1] as List<MockExamQuestion>;
    final progress = results[2] as MockExamProgress?;
    if (exam == null) {
      throw StateError('회차 정보를 찾을 수 없습니다.');
    }

    return _ResultState(
      attempt: attempt,
      exam: exam,
      progress: progress,
      questionsById: {
        for (final question in questions) question.id: question,
      },
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openRanking(MockExam exam) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_ranking'),
        builder: (_) => MockExamRankingScreen(exam: exam),
      ),
    );
  }

  Future<void> _retry(MockExam exam) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_take'),
        builder: (_) => MockExamTakeScreen(exam: exam),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _shareCurrentResult() async {
    if (_sharing || _buyingRetry) return;
    try {
      final state = await _future;
      await _shareResult(state, grantRetry: false);
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '공유할 결과를 불러오지 못했습니다.');
    }
  }

  Future<void> _shareForRetry(_ResultState state) async {
    await _shareResult(state, grantRetry: true);
  }

  Future<void> _shareResult(
    _ResultState state, {
    required bool grantRetry,
  }) async {
    if (_sharing || _buyingRetry) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    setState(() => _sharing = true);
    try {
      unawaited(AnalyticsService.instance.logAction(
        'mock_exam_share_click',
        params: {
          'exam_id': state.exam.id,
          'attempt_id': state.attempt.id,
          'score': state.attempt.score,
          'grant_retry': grantRetry,
        },
      ));

      final link = await BranchService().createMockExamShareLink(
        examId: state.exam.id,
        attemptId: state.attempt.id,
        roundNo: state.exam.roundNo,
        score: state.attempt.score,
        referrerUid: user.uid,
        title: state.exam.title,
        description: '${state.attempt.score}점 기록에 도전해보세요!',
      );
      if (link == null || link.isEmpty) {
        Fluttertoast.showToast(msg: '공유 링크를 만들지 못했습니다.');
        return;
      }

      final shareText = '${state.exam.title}에서 ${state.attempt.score}점!\n'
          '내 점수 넘으면 인정.\n\n$link';
      await SharePlus.instance.share(ShareParams(text: shareText));

      if (!grantRetry) {
        if (!mounted) return;
        Fluttertoast.showToast(msg: '마일고사 링크를 공유했습니다.');
        return;
      }

      final granted = await _service.grantShareRetry(
        examId: state.exam.id,
        attemptId: state.attempt.id,
        shareUrl: link,
      );
      unawaited(AnalyticsService.instance.logAction(
        'mock_exam_share_reward_grant',
        params: {
          'exam_id': state.exam.id,
          'attempt_id': state.attempt.id,
          'granted': granted,
        },
      ));

      if (!mounted) return;
      Fluttertoast.showToast(
        msg: granted ? '재도전권 1회가 열렸습니다.' : '이미 재도전권을 받았습니다.',
      );
      await _refresh();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.message ?? '공유 보상 처리에 실패했습니다.');
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '공유 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _purchaseRetryWithPeanuts(_ResultState state) async {
    if (_buyingRetry) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('땅콩 50개로 재도전'),
            content: const Text(
              '보유 땅콩에서 50개를 차감하고 재도전권 1회를 받을까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mockExamAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('재도전'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _buyingRetry = true);
    try {
      await _service.purchaseRetryWithPeanuts(
        examId: state.exam.id,
        attemptId: state.attempt.id,
      );
      unawaited(AnalyticsService.instance.logAction(
        'mock_exam_retry_purchase',
        params: {
          'exam_id': state.exam.id,
          'attempt_id': state.attempt.id,
          'cost_peanuts': 50,
        },
      ));
      if (!mounted) return;
      Fluttertoast.showToast(msg: '땅콩 50개로 재도전권이 열렸습니다.');
      setState(() => _buyingRetry = false);
      await _retry(state.exam);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.message ?? '재도전권 구매에 실패했습니다.');
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '재도전권 구매에 실패했습니다.');
    } finally {
      if (mounted && _buyingRetry) {
        setState(() => _buyingRetry = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('마일고사 결과'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '공유',
            onPressed: _sharing || _buyingRetry ? null : _shareCurrentResult,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_ResultState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return MockExamEmptyState(
              icon: Icons.error_outline,
              title: '결과를 불러오지 못했어요',
              message: '잠시 후 다시 시도해 주세요.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            );
          }

          final state = snapshot.data!;
          final attempt = state.attempt;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _ScoreSummaryCard(
                  exam: state.exam,
                  attempt: attempt,
                  progress: state.progress,
                  sharing: _sharing,
                  buyingRetry: _buyingRetry,
                  onRanking: () => _openRanking(state.exam),
                  onRetry: () => _retry(state.exam),
                  onShareForRetry: () => _shareForRetry(state),
                  onPurchaseRetry: () => _purchaseRetryWithPeanuts(state),
                ),
                const SizedBox(height: 12),
                _CategoryScoreCard(attempt: attempt),
                const SizedBox(height: 12),
                const AppBannerAd(),
                const SizedBox(height: 12),
                _AnswerReviewSection(
                  answers: attempt.answers,
                  questionsById: state.questionsById,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScoreSummaryCard extends StatelessWidget {
  final MockExam exam;
  final MockExamAttempt attempt;
  final MockExamProgress? progress;
  final bool sharing;
  final bool buyingRetry;
  final VoidCallback onRanking;
  final VoidCallback onRetry;
  final VoidCallback onShareForRetry;
  final VoidCallback onPurchaseRetry;

  const _ScoreSummaryCard({
    required this.exam,
    required this.attempt,
    required this.progress,
    required this.sharing,
    required this.buyingRetry,
    required this.onRanking,
    required this.onRetry,
    required this.onShareForRetry,
    required this.onPurchaseRetry,
  });

  @override
  Widget build(BuildContext context) {
    final canRetry = progress?.canRetry == true;
    final shareRewardGranted = progress?.shareRewardGranted == true;
    final purchaseRetry = shareRewardGranted && !canRetry;
    final retryBusy = sharing || buyingRetry;
    final retryLabel = canRetry
        ? '다시 풀기'
        : purchaseRetry
            ? '땅콩 50개로 재도전'
            : '공유하고 다시 풀기';
    final retryColor = purchaseRetry ? const Color(0xFFB66A00) : mockExamAccent;
    final retryIcon = retryBusy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(canRetry
            ? Icons.refresh_outlined
            : purchaseRetry
                ? Icons.account_balance_wallet_outlined
                : Icons.ios_share_outlined);
    final retryPressed = retryBusy
        ? null
        : canRetry
            ? onRetry
            : purchaseRetry
                ? onPurchaseRetry
                : onShareForRetry;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exam.title,
                  style: McTextStyles.cardTitle.copyWith(fontSize: 17),
                ),
              ),
              if (attempt.isBestAttempt)
                const MockExamChip(
                  label: '최고 기록',
                  color: Colors.green,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${attempt.score}',
                style: const TextStyle(
                  color: mockExamAccent,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  ' / ${attempt.totalScore}점',
                  style: McTextStyles.bodyStrong.copyWith(
                    color: McColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                icon: Icons.check_circle_outline,
                label: '${attempt.correctCount}/${attempt.questionCount} 정답',
              ),
              _MetricPill(
                icon: Icons.timer_outlined,
                label: mockExamDurationLabel(attempt.durationSeconds),
              ),
              _MetricPill(
                icon: Icons.today_outlined,
                label: mockExamDateLabel(attempt.submittedAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRanking,
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('랭킹 보기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mockExamAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: retryPressed,
                  icon: retryIcon,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(retryLabel),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: retryColor,
                    side: BorderSide(color: retryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: McColors.muted),
          const SizedBox(width: 5),
          Text(label, style: McTextStyles.meta),
        ],
      ),
    );
  }
}

class _CategoryScoreCard extends StatelessWidget {
  final MockExamAttempt attempt;

  const _CategoryScoreCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final entries = attempt.categoryScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('분야별 점수', style: McTextStyles.sectionTitle),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              '분야별 점수 정보가 없습니다.',
              style: McTextStyles.body.copyWith(color: McColors.muted),
            )
          else
            ...entries.map((entry) {
              final maxScore = _categoryMaxScore(
                attempt.questionCount,
                attempt.totalScore,
                entries.length,
              );
              final value = maxScore == 0 ? 0.0 : entry.value / maxScore;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mockExamCategoryLabel(entry.key),
                            style: McTextStyles.bodyStrong,
                          ),
                        ),
                        Text(
                          '${entry.value}점',
                          style: McTextStyles.bodyStrong.copyWith(
                            color: mockExamAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: value.clamp(0.0, 1.0),
                        backgroundColor: McColors.field,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          mockExamAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  int _categoryMaxScore(int questionCount, int totalScore, int categoryCount) {
    if (questionCount == 0 || categoryCount == 0) return 0;
    return totalScore ~/ categoryCount;
  }
}

class _AnswerReviewSection extends StatelessWidget {
  final List<MockExamAttemptAnswer> answers;
  final Map<String, MockExamQuestion> questionsById;

  const _AnswerReviewSection({
    required this.answers,
    required this.questionsById,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오답과 해설', style: McTextStyles.sectionTitle),
          const SizedBox(height: 12),
          if (answers.isEmpty)
            Text(
              '제출된 답안 정보가 없습니다.',
              style: McTextStyles.body.copyWith(color: McColors.muted),
            )
          else
            ...answers.asMap().entries.map((entry) {
              final index = entry.key;
              final answer = entry.value;
              final question = questionsById[answer.questionId];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == answers.length - 1 ? 0 : 12,
                ),
                child: _AnswerReviewCard(
                  index: index,
                  answer: answer,
                  question: question,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  final int index;
  final MockExamAttemptAnswer answer;
  final MockExamQuestion? question;

  const _AnswerReviewCard({
    required this.index,
    required this.answer,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final color = answer.isCorrect ? Colors.green : Colors.redAccent;
    final selectedText = question?.choiceText(answer.selectedChoiceId) ??
        (answer.selectedChoiceId ?? '미응답');
    final correctText = answer.answerText.isNotEmpty
        ? answer.answerText
        : question?.choiceText(answer.correctChoiceId) ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MockExamChip(label: 'Q${index + 1}', color: color),
              MockExamChip(
                label: answer.isCorrect ? '정답' : '오답',
                color: color,
              ),
              if (answer.category.isNotEmpty)
                MockExamChip(
                  label: mockExamCategoryLabel(answer.category),
                  color: McColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question?.question ?? answer.questionId,
            style: McTextStyles.bodyStrong,
          ),
          const SizedBox(height: 10),
          _AnswerLine(label: '내 답', value: selectedText),
          const SizedBox(height: 5),
          _AnswerLine(label: '정답', value: correctText),
          if (answer.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              answer.explanation,
              style: McTextStyles.body.copyWith(
                color: McColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final String label;
  final String value;

  const _AnswerLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(label, style: McTextStyles.meta),
        ),
        Expanded(
          child: Text(
            value,
            style: McTextStyles.bodyStrong.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ResultState {
  final MockExamAttempt attempt;
  final MockExam exam;
  final MockExamProgress? progress;
  final Map<String, MockExamQuestion> questionsById;

  const _ResultState({
    required this.attempt,
    required this.exam,
    required this.progress,
    required this.questionsById,
  });
}
