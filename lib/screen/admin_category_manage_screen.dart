import 'package:flutter/material.dart';

import '../services/admin_category_service.dart';

class AdminCategoryManageScreen extends StatefulWidget {
  const AdminCategoryManageScreen({super.key});

  @override
  State<AdminCategoryManageScreen> createState() =>
      _AdminCategoryManageScreenState();
}

class _AdminCategoryManageScreenState extends State<AdminCategoryManageScreen> {
  static const Color _accent = Color(0xFF74512D);
  static const Color _background = Color(0xFFF7F7FA);

  List<AdminCommunityCategory> _categories = const <AdminCommunityCategory>[];
  String? _selectedId;
  bool _isLoading = true;
  bool _isMoving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  AdminCommunityCategory? get _selectedCategory {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final category in _categories) {
      if (category.id == selectedId) return category;
    }
    return null;
  }

  int get _selectedIndex {
    final selectedId = _selectedId;
    if (selectedId == null) return -1;
    return _categories.indexWhere((category) => category.id == selectedId);
  }

  bool get _canMoveUp => !_isMoving && _selectedIndex > 0;
  bool get _canMoveDown =>
      !_isMoving &&
      _selectedIndex >= 0 &&
      _selectedIndex < _categories.length - 1;

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await AdminCategoryService.loadCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedId = _resolveSelectedId(categories);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  String? _resolveSelectedId(List<AdminCommunityCategory> categories) {
    if (categories.isEmpty) return null;
    final selectedId = _selectedId;
    final hasSelected = categories.any((category) => category.id == selectedId);
    return hasSelected ? selectedId : categories.first.id;
  }

  Future<void> _move(AdminCategoryMoveDirection direction) async {
    final selected = _selectedCategory;
    if (selected == null) return;

    setState(() => _isMoving = true);
    try {
      final categories = await AdminCategoryService.moveCategory(
        categoryId: selected.id,
        direction: direction,
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedId = _resolveSelectedId(categories);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.name} 순서를 변경했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('순서 변경 실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _isMoving = false);
    }
  }

  void _select(AdminCommunityCategory category) {
    setState(() => _selectedId = category.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('카테고리 관리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading || _isMoving ? null : _loadCategories,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accent),
        ),
      );
    }

    if (_error != null) {
      return _ErrorState(
        error: _error!,
        onRetry: _loadCategories,
      );
    }

    if (_categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCategories,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                '등록된 카테고리가 없습니다.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCategories,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 12)
                  : const SizedBox(
                      height: 10,
                    ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategorySummary(
                    count: _categories.length,
                    selected: _selectedCategory,
                  );
                }
                final category = _categories[index - 1];
                return _CategoryTile(
                  category: category,
                  position: index,
                  selected: category.id == _selectedId,
                  onTap: () => _select(category),
                );
              },
            ),
          ),
        ),
        _MoveBar(
          selected: _selectedCategory,
          isMoving: _isMoving,
          canMoveUp: _canMoveUp,
          canMoveDown: _canMoveDown,
          onMoveUp: () => _move(AdminCategoryMoveDirection.up),
          onMoveDown: () => _move(AdminCategoryMoveDirection.down),
        ),
      ],
    );
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({
    required this.count,
    required this.selected,
  });

  final int count;
  final AdminCommunityCategory? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                color: _AdminCategoryManageScreenState._accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Realtime Database / CATEGORIES',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? '$count개 카테고리'
                : '$count개 카테고리 · 선택: ${selected!.name}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final AdminCommunityCategory category;
  final int position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _AdminCategoryManageScreenState._accent
        : const Color(0xFFE7E2DC);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderBadge(
                position: position,
                order: category.order,
                selected: selected,
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF4ECE5)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForName(category.icon),
                  color: selected
                      ? _AdminCategoryManageScreenState._accent
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: _AdminCategoryManageScreenState._accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description.isEmpty
                          ? category.id
                          : category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.tag_rounded,
                          text: category.id,
                        ),
                        if (category.group.isNotEmpty)
                          _MetaChip(
                            icon: Icons.folder_outlined,
                            text: category.group,
                          ),
                        _MetaChip(
                          icon: category.fabEnabled
                              ? Icons.add_circle_outline_rounded
                              : Icons.block_rounded,
                          text: category.fabEnabled ? 'FAB ON' : 'FAB OFF',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({
    required this.position,
    required this.order,
    required this.selected,
  });

  final int position;
  final double order;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? _AdminCategoryManageScreenState._accent
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$position',
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'order ${_formatOrder(order)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveBar extends StatelessWidget {
  const _MoveBar({
    required this.selected,
    required this.isMoving,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final AdminCommunityCategory? selected;
  final bool isMoving;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected == null ? '카테고리를 선택하세요' : selected!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              label: const Text('위로'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _AdminCategoryManageScreenState._accent,
                side: const BorderSide(
                  color: _AdminCategoryManageScreenState._accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: canMoveDown ? onMoveDown : null,
              icon: isMoving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded),
              label: const Text('아래로'),
              style: FilledButton.styleFrom(
                backgroundColor: _AdminCategoryManageScreenState._accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: _AdminCategoryManageScreenState._accent,
            ),
            const SizedBox(height: 12),
            Text(
              '카테고리를 불러오지 못했습니다.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForName(String name) {
  switch (name) {
    case 'help_outline':
      return Icons.help_outline;
    case 'card_giftcard':
      return Icons.card_giftcard;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'event_seat':
      return Icons.event_seat;
    case 'rate_review':
      return Icons.rate_review;
    case 'chat_bubble_outline':
      return Icons.chat_bubble_outline;
    case 'airline_seat_recline_extra':
      return Icons.airline_seat_recline_extra;
    case 'newspaper_outlined':
      return Icons.newspaper_outlined;
    case 'public':
      return Icons.public;
    case 'work_outline':
      return Icons.work_outline;
    case 'menu_book_outlined':
      return Icons.menu_book_outlined;
    case 'bug_report':
      return Icons.bug_report;
    case 'lightbulb_outline':
      return Icons.lightbulb_outline;
    case 'campaign':
      return Icons.campaign;
    default:
      return Icons.forum_outlined;
  }
}

String _formatOrder(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
