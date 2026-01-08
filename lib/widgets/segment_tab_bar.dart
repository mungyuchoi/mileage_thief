import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.activeColor = const Color(0xFF74512D),
    this.backgroundColor = const Color(0xFFF1F2F4),
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
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: activeColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black87,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          for (final t in labels) Tab(text: t),
        ],
      ),
    );
  }
}


