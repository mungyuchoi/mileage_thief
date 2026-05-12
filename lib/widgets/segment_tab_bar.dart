import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../const/colors.dart';

/// 인스타 스타일의 세그먼트 탭(캡슐 인디케이터 + 햅틱)
class SegmentTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color activeColor;
  final Color backgroundColor;

  const SegmentTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.padding = const EdgeInsets.all(4),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.activeColor = McColors.accentSoft,
    this.backgroundColor = McColors.field,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        controller: controller,
        onTap: (_) => HapticFeedback.selectionClick(),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: activeColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: McColors.accent.withValues(alpha: 0.18)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: McColors.accent,
        unselectedLabelColor: McColors.muted,
        labelStyle: McTextStyles.tabSelected,
        unselectedLabelStyle: McTextStyles.tab,
        tabs: [
          for (final t in labels) Tab(text: t),
        ],
      ),
    );
  }
}
