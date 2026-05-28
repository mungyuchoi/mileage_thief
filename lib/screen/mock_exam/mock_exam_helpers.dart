import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../const/colors.dart';

const Color mockExamAccent = Color(0xFF4F46E5);
const Color mockExamAccentSoft = Color(0xFFEFF1FF);

String mockExamCategoryLabel(String category) {
  switch (category) {
    case 'airline':
      return '항공';
    case 'card':
      return '카드';
    case 'giftcard':
      return '상품권';
    case 'hotel':
      return '호텔';
    default:
      return category;
  }
}

String mockExamDifficultyLabel(String difficulty) {
  switch (difficulty) {
    case 'easy':
      return '쉬움';
    case 'hard':
      return '어려움';
    case 'normal':
    default:
      return '보통';
  }
}

String mockExamStatusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'draft';
    case 'published':
      return '공개';
    case 'locked':
      return '잠금';
    default:
      return status;
  }
}

Color mockExamStatusColor(String status) {
  switch (status) {
    case 'draft':
      return Colors.deepOrange;
    case 'published':
      return Colors.green;
    case 'locked':
      return McColors.muted;
    default:
      return mockExamAccent;
  }
}

String mockExamDurationLabel(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remain = safeSeconds % 60;
  return '$minutes분 ${remain.toString().padLeft(2, '0')}초';
}

String mockExamDateLabel(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('yyyy.MM.dd HH:mm').format(date);
}

class MockExamChip extends StatelessWidget {
  final String label;
  final Color color;

  const MockExamChip({
    super.key,
    required this.label,
    this.color = mockExamAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class MockExamEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MockExamEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: mockExamAccentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: mockExamAccent, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: McTextStyles.cardTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: McTextStyles.body.copyWith(color: McColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mockExamAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
