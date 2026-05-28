import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../const/colors.dart';
import '../models/mock_exam_model.dart';
import '../services/mock_exam_service.dart';
import 'mock_exam/mock_exam_helpers.dart';

class AdminMockExamManageScreen extends StatefulWidget {
  const AdminMockExamManageScreen({super.key});

  @override
  State<AdminMockExamManageScreen> createState() =>
      _AdminMockExamManageScreenState();
}

class _AdminMockExamManageScreenState extends State<AdminMockExamManageScreen> {
  final MockExamService _service = MockExamService();
  late Future<List<MockExam>> _future;
  final Set<String> _updatingExamIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MockExam>> _load() {
    return _service.loadExams(includeDraft: true);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _changeStatus(MockExam exam, String status) async {
    if (exam.status == status || _updatingExamIds.contains(exam.id)) return;
    setState(() => _updatingExamIds.add(exam.id));
    try {
      await _service.updateExamStatus(examId: exam.id, status: status);
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: '${exam.title} 상태를 ${mockExamStatusLabel(status)}로 변경했습니다.',
      );
      await _refresh();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.message ?? '상태 변경에 실패했습니다.');
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '상태 변경에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _updatingExamIds.remove(exam.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('마일고사 관리'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<MockExam>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AdminMockExamEmpty(
              icon: Icons.error_outline,
              title: '마일고사를 불러오지 못했습니다.',
              actionLabel: '다시 불러오기',
              onAction: _refresh,
            );
          }
          final exams = snapshot.data ?? const <MockExam>[];
          if (exams.isEmpty) {
            return const _AdminMockExamEmpty(
              icon: Icons.quiz_outlined,
              title: '등록된 마일고사가 없습니다.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exam = exams[index];
                return _AdminMockExamCard(
                  exam: exam,
                  updating: _updatingExamIds.contains(exam.id),
                  onChangeStatus: (status) => _changeStatus(exam, status),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AdminMockExamCard extends StatelessWidget {
  const _AdminMockExamCard({
    required this.exam,
    required this.updating,
    required this.onChangeStatus,
  });

  final MockExam exam;
  final bool updating;
  final ValueChanged<String> onChangeStatus;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: mockExamAccentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.quiz_outlined, color: mockExamAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: McTextStyles.cardTitle.copyWith(fontSize: 16),
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
              MockExamChip(
                label: mockExamStatusLabel(exam.status),
                color: mockExamStatusColor(exam.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MockExamChip(label: 'round ${exam.roundNo}'),
              MockExamChip(label: '${exam.questionCount}문항'),
              MockExamChip(label: '${exam.totalScore}점'),
              MockExamChip(label: '${exam.timeLimitSeconds ~/ 60}분'),
            ],
          ),
          const SizedBox(height: 14),
          if (updating)
            const LinearProgressIndicator(minHeight: 3)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const ['draft', 'locked', 'published'])
                  ChoiceChip(
                    selected: exam.status == status,
                    label: Text(mockExamStatusLabel(status)),
                    selectedColor:
                        mockExamStatusColor(status).withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: exam.status == status
                          ? mockExamStatusColor(status)
                          : McColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: exam.status == status
                          ? mockExamStatusColor(status)
                          : McColors.line,
                    ),
                    onSelected: (_) => onChangeStatus(status),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdminMockExamEmpty extends StatelessWidget {
  const _AdminMockExamEmpty({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: McColors.muted, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: McTextStyles.bodyStrong,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
