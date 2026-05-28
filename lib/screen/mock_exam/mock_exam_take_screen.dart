import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../const/colors.dart';
import '../../models/mock_exam_model.dart';
import '../../services/analytics_service.dart';
import '../../services/mock_exam_service.dart';
import '../../widgets/image_viewer.dart';
import 'mock_exam_helpers.dart';
import 'mock_exam_result_screen.dart';

class MockExamTakeScreen extends StatefulWidget {
  final MockExam exam;

  const MockExamTakeScreen({
    super.key,
    required this.exam,
  });

  @override
  State<MockExamTakeScreen> createState() => _MockExamTakeScreenState();
}

class _MockExamTakeScreenState extends State<MockExamTakeScreen> {
  final MockExamService _service = MockExamService();
  final Map<String, String> _selectedAnswers = <String, String>{};
  late Future<_TakeSession> _future;
  Timer? _timer;
  DateTime? _deadlineAt;
  late int _remainingSeconds;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.exam.timeLimitSeconds;
    unawaited(AnalyticsService.instance.logScreenView(
      'mock_exam_take',
      screenClass: 'MockExamTakeScreen',
      source: 'screen_init',
    ));
    _future = _start();
  }

  Future<_TakeSession> _start() async {
    final results = await Future.wait<dynamic>([
      _service.startMockExam(widget.exam.id),
      _service.loadQuestions(widget.exam.id),
    ]);
    final attemptId = results[0] as String;
    final questions = results[1] as List<MockExamQuestion>;
    if (attemptId.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: '응시 정보를 만들지 못했습니다.',
      );
    }
    _startTimer();
    return _TakeSession(attemptId: attemptId, questions: questions);
  }

  void _startTimer() {
    _timer?.cancel();
    final limitSeconds = widget.exam.timeLimitSeconds;
    if (limitSeconds <= 0 || !mounted) return;
    _deadlineAt = DateTime.now().add(Duration(seconds: limitSeconds));
    _syncRemainingSeconds();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncRemainingSeconds(),
    );
  }

  void _syncRemainingSeconds() {
    final deadlineAt = _deadlineAt;
    if (deadlineAt == null || !mounted) return;

    final remainingMs = deadlineAt.difference(DateTime.now()).inMilliseconds;
    final nextSeconds = remainingMs <= 0
        ? 0
        : ((remainingMs + 999) ~/ 1000)
            .clamp(0, widget.exam.timeLimitSeconds)
            .toInt();
    if (nextSeconds != _remainingSeconds) {
      setState(() => _remainingSeconds = nextSeconds);
    }
    if (nextSeconds <= 0) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmAndSubmit(_TakeSession session) async {
    final unanswered = session.questions.length - _selectedAnswers.length;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text('미응답 문항이 있어요'),
              content: Text(
                '$unanswered개 문항을 풀지 않았습니다.\n'
                '미응답 문항은 오답으로 처리됩니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('계속 풀기'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mockExamAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('제출하기'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    await _submit(session);
  }

  Future<void> _submit(_TakeSession session) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await _service.submitMockExam(
        examId: widget.exam.id,
        attemptId: session.attemptId,
        selectedAnswers: _selectedAnswers,
      );
      final attempt = result.attempt;
      unawaited(AnalyticsService.instance.logAction(
        'mock_exam_submit',
        params: {
          'exam_id': widget.exam.id,
          'round_no': widget.exam.roundNo,
          'score': attempt.score,
          'duration_seconds': attempt.durationSeconds,
          'peanut_reward_granted': result.peanutRewardGranted,
        },
      ));
      if (!mounted) return;
      if (result.peanutRewardGranted && result.peanutRewardAmount > 0) {
        Fluttertoast.showToast(
          msg: '땅콩 ${result.peanutRewardAmount}개가 지급되었습니다.',
        );
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'mock_exam_result'),
          builder: (_) => MockExamResultScreen(
            attemptId: attempt.id,
            initialAttempt: attempt,
          ),
        ),
        result: true,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.message ?? '제출에 실패했습니다.');
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '제출에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: McColors.background,
        appBar: AppBar(
          title: Text(widget.exam.title),
          backgroundColor: Colors.white,
          foregroundColor: McColors.ink,
          elevation: 0.5,
        ),
        body: FutureBuilder<_TakeSession>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return MockExamEmptyState(
                icon: Icons.error_outline,
                title: '응시를 시작하지 못했어요',
                message: _errorMessage(snapshot.error),
                actionLabel: '닫기',
                onAction: () => Navigator.pop(context),
              );
            }
            final session = snapshot.data!;
            return Column(
              children: [
                _ProgressHeader(
                  answered: _selectedAnswers.length,
                  total: session.questions.length,
                  totalScore: widget.exam.totalScore,
                  remainingSeconds: _remainingSeconds,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: session.questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final question = session.questions[index];
                      return _QuestionCard(
                        index: index,
                        question: question,
                        selectedChoiceId: _selectedAnswers[question.id],
                        onSelect: (choiceId) {
                          setState(() {
                            _selectedAnswers[question.id] = choiceId;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: FutureBuilder<_TakeSession>(
          future: _future,
          builder: (context, snapshot) {
            final session = snapshot.data;
            return ColoredBox(
              color: Colors.white,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: session == null || _submitting
                          ? null
                          : () => _confirmAndSubmit(session),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_submitting ? '채점 중' : '제출하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mockExamAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? '잠시 후 다시 시도해 주세요.';
    }
    return '잠시 후 다시 시도해 주세요.';
  }
}

class _ProgressHeader extends StatelessWidget {
  final int answered;
  final int total;
  final int totalScore;
  final int remainingSeconds;

  const _ProgressHeader({
    required this.answered,
    required this.total,
    required this.totalScore,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : answered / total;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '답변 $answered / $total',
                  style: McTextStyles.bodyStrong,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TimerPill(remainingSeconds: remainingSeconds),
                  const SizedBox(height: 4),
                  Text(
                    '$totalScore점 만점',
                    style: McTextStyles.meta,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: McColors.field,
              valueColor: const AlwaysStoppedAnimation<Color>(mockExamAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final int remainingSeconds;

  const _TimerPill({
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final safeSeconds = remainingSeconds < 0 ? 0 : remainingSeconds;
    final isUrgent = safeSeconds <= 60;
    final color = isUrgent ? Colors.redAccent : mockExamAccent;
    final minutes = safeSeconds ~/ 60;
    final seconds = safeSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final MockExamQuestion question;
  final String? selectedChoiceId;
  final ValueChanged<String> onSelect;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedChoiceId,
    required this.onSelect,
  });

  void _openImageViewer(BuildContext context) {
    final imageUrl = question.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'mock_exam_image_viewer'),
        builder: (_) => SingleImageViewer(
          imageUrl: imageUrl,
          heroTag: 'mock_exam_image_${question.id}',
        ),
      ),
    );
  }

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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MockExamChip(label: 'Q${index + 1}'),
              MockExamChip(label: mockExamCategoryLabel(question.category)),
              MockExamChip(
                label: mockExamDifficultyLabel(question.difficulty),
                color: McColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: McTextStyles.cardTitle.copyWith(fontSize: 16),
          ),
          if (question.imageUrl != null) ...[
            const SizedBox(height: 12),
            _QuestionImage(
              question: question,
              onTap: () => _openImageViewer(context),
            ),
          ],
          const SizedBox(height: 14),
          ...question.choices.map(
            (choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceTile(
                choice: choice,
                selected: selectedChoiceId == choice.id,
                onTap: () => onSelect(choice.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  final MockExamQuestion question;
  final VoidCallback onTap;

  const _QuestionImage({
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = question.imageUrl!;
    return Semantics(
      button: true,
      label: '문항 이미지 크게 보기',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Hero(
                tag: 'mock_exam_image_${question.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_out_map_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final MockExamChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? mockExamAccentSoft : McColors.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? mockExamAccent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? mockExamAccent : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? mockExamAccent : McColors.line,
                ),
              ),
              child: Text(
                choice.id.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : McColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                choice.text,
                style: TextStyle(
                  color: selected ? mockExamAccent : McColors.ink,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeSession {
  final String attemptId;
  final List<MockExamQuestion> questions;

  const _TakeSession({
    required this.attemptId,
    required this.questions,
  });
}
