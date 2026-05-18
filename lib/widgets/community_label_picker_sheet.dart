import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/community_label_model.dart';
import '../services/community_label_service.dart';

class CommunityLabelPickerSheet extends StatefulWidget {
  const CommunityLabelPickerSheet({
    super.key,
    required this.selectedLabels,
    required this.maxLabels,
    required this.labelService,
    required this.onChanged,
    this.accentColor = const Color(0xFF74512D),
  });

  final List<CommunityLabel> selectedLabels;
  final int maxLabels;
  final CommunityLabelService labelService;
  final ValueChanged<List<CommunityLabel>> onChanged;
  final Color accentColor;

  @override
  State<CommunityLabelPickerSheet> createState() =>
      _CommunityLabelPickerSheetState();
}

class _CommunityLabelPickerSheetState extends State<CommunityLabelPickerSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  Timer? _debounce;
  CommunityLabelBrowseData? _browseData;
  List<CommunityLabel> _searchResults = const <CommunityLabel>[];
  List<CommunityLabel> _selectedLabels = <CommunityLabel>[];
  bool _isLoadingBrowse = true;
  bool _isSearching = false;
  String _query = '';
  String? _browseError;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedLabels = CommunityLabel.dedupe(widget.selectedLabels)
        .take(widget.maxLabels)
        .toList(growable: false);
    _loadBrowseData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrowseData() async {
    setState(() {
      _isLoadingBrowse = true;
      _browseError = null;
    });
    try {
      final data = await widget.labelService.browse();
      if (!mounted) return;
      setState(() {
        _browseData = data;
        _isLoadingBrowse = false;
      });
      if (_query.isNotEmpty) {
        _runSearch(_query);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _browseError = error.toString();
        _isLoadingBrowse = false;
      });
    }
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final token = ++_searchToken;
    setState(() {
      _isSearching = true;
    });

    final browseData = _browseData;
    if (browseData != null) {
      final labels = CommunityLabelService.filterBrowseItems(
        CommunityLabelService.flattenBrowseData(browseData),
        trimmed,
      ).map((item) => item.label).toList(growable: false);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchResults = labels;
        _isSearching = false;
      });
      return;
    }

    try {
      final labels = await widget.labelService.search(trimmed);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchResults = labels;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchResults = const <CommunityLabel>[];
        _isSearching = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    setState(() {
      _query = query;
    });
    if (query.isEmpty) {
      _searchToken++;
      setState(() {
        _searchResults = const <CommunityLabel>[];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 280),
      () => _runSearch(query),
    );
  }

  void _toggleLabel(CommunityLabel label) {
    final alreadySelected =
        _selectedLabels.any((item) => item.key == label.key);
    if (!alreadySelected && _selectedLabels.length >= widget.maxLabels) {
      Fluttertoast.showToast(
        msg: '라벨은 최대 ${widget.maxLabels}개까지 추가할 수 있습니다.',
      );
      return;
    }

    final nextLabels = alreadySelected
        ? _selectedLabels
            .where((item) => item.key != label.key)
            .toList(growable: false)
        : CommunityLabel.dedupe([..._selectedLabels, label])
            .take(widget.maxLabels)
            .toList(growable: false);

    setState(() {
      _selectedLabels = nextLabels;
    });
    widget.onChanged(_selectedLabels);
  }

  bool _isSelected(CommunityLabel label) {
    return _selectedLabels.any((item) => item.key == label.key);
  }

  IconData _labelIcon(String type) {
    switch (type) {
      case 'branch':
        return Icons.storefront_outlined;
      case 'giftcard':
        return Icons.card_giftcard_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'calculator':
        return Icons.calculate_outlined;
      case 'feature':
        return Icons.hotel_outlined;
      default:
        return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E4EC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '라벨 추가',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.accentColor,
                    ),
                    child: const Text('완료'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: '지점, 상품권, 카드명 검색',
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onQueryChanged,
                onSubmitted: _runSearch,
              ),
              _buildSelectedChips(),
              const SizedBox(height: 10),
              Expanded(
                child: _query.isEmpty ? _buildBrowseBody() : _buildSearchBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChips() {
    if (_selectedLabels.isEmpty) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in _selectedLabels)
            InputChip(
              avatar: Icon(
                _labelIcon(label.type),
                size: 16,
                color: widget.accentColor,
              ),
              label: Text(
                label.displayName,
                overflow: TextOverflow.ellipsis,
              ),
              labelStyle: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
              backgroundColor: const Color(0xFFF8F4EF),
              side: const BorderSide(color: Color(0xFFE7D8C6)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _toggleLabel(label),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없습니다.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final label = _searchResults[index];
        return _buildLabelTile(
          label: label,
          description: label.subtitle,
        );
      },
    );
  }

  Widget _buildBrowseBody() {
    if (_isLoadingBrowse) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_browseError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '라벨 목록을 불러오지 못했습니다.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadBrowseData,
              style: TextButton.styleFrom(
                foregroundColor: widget.accentColor,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final data = _browseData;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: widget.accentColor,
          unselectedLabelColor: Colors.black54,
          indicatorColor: widget.accentColor,
          tabs: const [
            Tab(text: '지점'),
            Tab(text: '상품권'),
            Tab(text: '카드'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildItemList(
                items: data.branchItems,
                emptyText: '등록된 상품권 지점이 없습니다.',
              ),
              _buildItemList(
                items: data.giftcardItems,
                emptyText: '등록된 상품권 브랜드가 없습니다.',
              ),
              _buildCardGroups(data.cardGroups),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemList({
    required List<CommunityLabelBrowseItem> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildLabelTile(
          label: item.label,
          description:
              item.description.isEmpty ? item.label.subtitle : item.description,
        );
      },
    );
  }

  Widget _buildCardGroups(List<CommunityLabelGroup> groups) {
    if (groups.isEmpty) {
      return const Center(
        child: Text(
          '등록된 카드가 없습니다.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(left: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFF8F4EF),
            foregroundColor: widget.accentColor,
            child: const Icon(Icons.account_balance_outlined, size: 20),
          ),
          title: Text(
            group.title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${group.items.length}개 카드',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          children: [
            for (final item in group.items)
              _buildLabelTile(
                label: item.label,
                description: item.description.isEmpty
                    ? item.label.subtitle
                    : item.description,
                dense: true,
              ),
          ],
        );
      },
    );
  }

  Widget _buildLabelTile({
    required CommunityLabel label,
    required String description,
    bool dense = false,
  }) {
    final selected = _isSelected(label);
    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 0,
        vertical: dense ? 0 : 2,
      ),
      leading: CircleAvatar(
        radius: dense ? 18 : 20,
        backgroundColor: const Color(0xFFF8F4EF),
        foregroundColor: widget.accentColor,
        child: Icon(
          _labelIcon(label.type),
          size: dense ? 18 : 20,
        ),
      ),
      title: Text(
        label.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: description.trim().isEmpty
          ? null
          : Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: widget.accentColor,
            )
          : const Icon(
              Icons.radio_button_unchecked,
              color: Colors.black26,
            ),
      onTap: () => _toggleLabel(label),
    );
  }
}
