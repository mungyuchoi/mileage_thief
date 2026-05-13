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
  final bool isScrollable;

  const SegmentTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.padding = const EdgeInsets.all(4),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.activeColor = McColors.accentSoft,
    this.backgroundColor = McColors.field,
    this.isScrollable = false,
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
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : null,
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

class ScrollableUnderlineTabBar extends StatefulWidget {
  final TabController controller;
  final List<String> labels;
  final EdgeInsetsGeometry padding;
  final double separatorWidth;

  const ScrollableUnderlineTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.separatorWidth = 20,
  });

  @override
  State<ScrollableUnderlineTabBar> createState() =>
      _ScrollableUnderlineTabBarState();
}

class _ScrollableUnderlineTabBarState
    extends State<ScrollableUnderlineTabBar> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  late List<GlobalKey> _tabKeys;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.index;
    _tabKeys = _createKeys();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_selectedIndex, animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant ScrollableUnderlineTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _selectedIndex = widget.controller.index;
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.labels.length != widget.labels.length) {
      _tabKeys = _createKeys();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  List<GlobalKey> _createKeys() =>
      List<GlobalKey>.generate(widget.labels.length, (_) => GlobalKey());

  void _handleControllerChanged() {
    final nextIndex = widget.controller.index;
    if (nextIndex == _selectedIndex) return;
    setState(() {
      _selectedIndex = nextIndex;
    });
    _scrollToIndex(nextIndex);
  }

  void _selectTab(int index) {
    HapticFeedback.selectionClick();
    if (index == widget.controller.index) {
      _scrollToIndex(index);
      return;
    }
    widget.controller.animateTo(index);
  }

  void _scrollToIndex(int index, {bool animated = true}) {
    if (index < 0 || index >= _tabKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      final tabContext = _tabKeys[index].currentContext;
      final viewportContext = _viewportKey.currentContext;
      if (tabContext == null || viewportContext == null) return;

      final tabBox = tabContext.findRenderObject() as RenderBox?;
      final viewportBox = viewportContext.findRenderObject() as RenderBox?;
      if (tabBox == null || viewportBox == null) return;

      final tabLeft = tabBox.localToGlobal(Offset.zero).dx -
          viewportBox.localToGlobal(Offset.zero).dx;
      final tabCenter = tabLeft + tabBox.size.width / 2;
      final viewportCenter = viewportBox.size.width / 2;
      final rawOffset = _scrollController.offset + tabCenter - viewportCenter;
      final targetOffset = rawOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      if (animated) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: McColors.line, width: 0.8),
        ),
      ),
      child: ListView.separated(
        key: _viewportKey,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.labels.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: widget.separatorWidth),
        itemBuilder: (context, index) {
          return _UnderlineTabButton(
            key: _tabKeys[index],
            label: widget.labels[index],
            selected: index == _selectedIndex,
            onTap: () => _selectTab(index),
          );
        },
      ),
    );
  }
}

class _UnderlineTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnderlineTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 탭',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style:
                    (selected ? McTextStyles.tabSelected : McTextStyles.tab)
                        .copyWith(fontSize: 14),
              ),
              const SizedBox(height: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 32 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: McColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
