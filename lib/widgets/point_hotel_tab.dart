import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/point_hotel_model.dart';
import '../screen/point_hotel_detail_screen.dart';
import '../services/point_hotel_service.dart';
import 'admob_banner.dart';
import 'point_hotel_favorite_button.dart';

enum _HotelViewMode { list, map }

class PointHotelTab extends StatefulWidget {
  const PointHotelTab({super.key});

  @override
  State<PointHotelTab> createState() => _PointHotelTabState();
}

class _PointHotelTabState extends State<PointHotelTab> {
  String _query = '';
  int _nights = 1;
  DateTime? _checkIn;
  _HotelViewMode _viewMode = _HotelViewMode.list;

  List<PointHotel> _filterHotels(List<PointHotel> hotels) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return hotels;
    return hotels
        .where((hotel) => hotel.searchableText.contains(needle))
        .toList(growable: false);
  }

  void _openHotel(PointHotel hotel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'point_hotel_detail'),
        builder: (_) => PointHotelDetailScreen(
          hotel: hotel,
          nights: _nights,
          checkIn: _checkIn,
        ),
      ),
    );
  }

  Future<void> _openSearchSheet(List<PointHotel> availableHotels) async {
    final result = await showModalBottomSheet<_HotelSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HotelSearchSheet(
        initialQuery: _query,
        initialNights: _nights,
        initialCheckIn: _checkIn,
        hotels: availableHotels,
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _query = result.query.trim();
      _nights = result.nights;
      _checkIn = result.checkIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointHotel>>(
      stream: PointHotelService.instance.watchHotels(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _HotelMessageState(
            icon: Icons.cloud_off_rounded,
            title: '호텔 정보를 불러오지 못했습니다.',
            body: 'Firestore 연결 또는 권한을 확인해 주세요.',
          );
        }
        if (!snapshot.hasData) {
          return const _HotelLoadingState();
        }

        final allHotels = snapshot.data ?? const <PointHotel>[];
        final hotels = _filterHotels(allHotels);
        return _HotelContent(
          hotels: hotels,
          totalHotelCount: allHotels.length,
          query: _query,
          nights: _nights,
          checkIn: _checkIn,
          viewMode: _viewMode,
          onOpenSearch: () => _openSearchSheet(allHotels),
          onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          onTapHotel: _openHotel,
        );
      },
    );
  }
}

class _HotelContent extends StatelessWidget {
  final List<PointHotel> hotels;
  final int totalHotelCount;
  final String query;
  final int nights;
  final DateTime? checkIn;
  final _HotelViewMode viewMode;
  final VoidCallback onOpenSearch;
  final ValueChanged<_HotelViewMode> onViewModeChanged;
  final ValueChanged<PointHotel> onTapHotel;

  const _HotelContent({
    required this.hotels,
    required this.totalHotelCount,
    required this.query,
    required this.nights,
    required this.checkIn,
    required this.viewMode,
    required this.onOpenSearch,
    required this.onViewModeChanged,
    required this.onTapHotel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PointHotelSection(
          child: Column(
            children: [
              _HotelSearchSummary(
                query: query,
                nights: nights,
                checkIn: checkIn,
                onTap: onOpenSearch,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: _ViewModeSwitch(
                  mode: viewMode,
                  onChanged: onViewModeChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _PointHotelSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  '포인트로 최고의 호텔 찾기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: McColors.ink,
                    fontSize: 28,
                    height: 1.18,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '호텔 포인트 가격을 비교하고 CPP를 계산하며 다음 여행에 가장 좋은 리워드 숙박을 찾아보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 34),
              Text(
                '${NumberFormat('#,###').format(totalHotelCount)}개 호텔',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const AppBannerAd(padding: EdgeInsets.only(bottom: 16)),
              if (hotels.isEmpty)
                _HotelMessageState(
                  icon: Icons.search_off_rounded,
                  title:
                      query.trim().isEmpty ? '등록된 호텔이 없습니다.' : '검색 결과가 없습니다.',
                  body: query.trim().isEmpty
                      ? 'Firestore pointHotels에 active 호텔을 추가하면 여기에 표시됩니다.'
                      : '다른 호텔명, 도시, 브랜드로 다시 검색해 보세요.',
                  compact: true,
                )
              else if (viewMode == _HotelViewMode.map)
                _HotelMapPreview(hotels: hotels, onTapHotel: onTapHotel)
              else
                for (final hotel in hotels) ...[
                  _HotelCard(
                    hotel: hotel,
                    onTap: () => onTapHotel(hotel),
                  ),
                  const SizedBox(height: 28),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PointHotelSection extends StatelessWidget {
  final Widget child;

  const _PointHotelSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _HotelLoadingState extends StatelessWidget {
  const _HotelLoadingState();

  @override
  Widget build(BuildContext context) {
    return const _PointHotelSection(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      ),
    );
  }
}

class _HotelMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool compact;

  const _HotelMessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 28 : 42,
        horizontal: 12,
      ),
      child: Column(
        children: [
          Icon(icon, color: McColors.mutedLight, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: McTextStyles.meta,
          ),
        ],
      ),
    );
    if (compact) return content;
    return _PointHotelSection(child: content);
  }
}

class _HotelSearchResult {
  final String query;
  final int nights;
  final DateTime? checkIn;

  const _HotelSearchResult({
    required this.query,
    required this.nights,
    required this.checkIn,
  });
}

class _HotelSearchSheet extends StatefulWidget {
  final String initialQuery;
  final int initialNights;
  final DateTime? initialCheckIn;
  final List<PointHotel> hotels;

  const _HotelSearchSheet({
    required this.initialQuery,
    required this.initialNights,
    required this.initialCheckIn,
    required this.hotels,
  });

  @override
  State<_HotelSearchSheet> createState() => _HotelSearchSheetState();
}

class _HotelSearchSheetState extends State<_HotelSearchSheet> {
  late final TextEditingController _controller;
  late DateTime? _selectedDate;
  late int _selectedNights;
  PointHotel? _selectedHotel;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_handleQueryChanged);
    _selectedDate = widget.initialCheckIn;
    _selectedNights = widget.initialNights;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    if (_selectedHotel != null &&
        _controller.text.trim() != _selectedHotel!.name.trim()) {
      _selectedHotel = null;
    }
    setState(() {});
  }

  List<PointHotel> _matchingHotels() {
    final needle = _controller.text.trim().toLowerCase();
    if (needle.isEmpty || _selectedHotel != null) {
      return const <PointHotel>[];
    }

    return widget.hotels
        .where((hotel) => hotel.name.toLowerCase().contains(needle))
        .take(8)
        .toList(growable: false);
  }

  void _selectHotel(PointHotel hotel) {
    setState(() => _selectedHotel = hotel);
    _controller.value = TextEditingValue(
      text: hotel.name,
      selection: TextSelection.collapsed(offset: hotel.name.length),
    );
    FocusScope.of(context).unfocus();
  }

  void _clearQuery() {
    setState(() => _selectedHotel = null);
    _controller.clear();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      _HotelSearchResult(
        query: _controller.text,
        nights: _selectedNights,
        checkIn: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final matchingHotels = _matchingHotels();
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              18 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close_rounded, size: 28),
                  onPressed: _close,
                ),
              ),
              _SearchPanel(
                title: '어디',
                subtitle: '목적지 검색',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 28),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: _clearQuery,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        hintText: '호텔 또는 위치 검색...',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (matchingHotels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HotelSuggestionList(
                        hotels: matchingHotels,
                        query: query,
                        onSelected: _selectHotel,
                      ),
                    ],
                  ],
                ),
              ),
              if (query.isNotEmpty &&
                  matchingHotels.isEmpty &&
                  _selectedHotel == null) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '일치하는 호텔명이 없습니다.',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _SearchPanel(
                title: '언제',
                subtitle: _selectedDate == null
                    ? '날짜 추가'
                    : DateFormat('M월 d일').format(_selectedDate!),
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              _SearchPanel(
                title: '박',
                subtitle: '$_selectedNights박',
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '숙박수 줄이기',
                      onPressed: _selectedNights <= 1
                          ? null
                          : () => setState(() => _selectedNights -= 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_selectedNights박',
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: '숙박수 늘리기',
                      onPressed: () => setState(() => _selectedNights += 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PointStayColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.search_rounded, size: 28),
                  label: const Text(
                    '검색',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HotelSuggestionList extends StatelessWidget {
  final List<PointHotel> hotels;
  final String query;
  final ValueChanged<PointHotel> onSelected;

  const _HotelSuggestionList({
    required this.hotels,
    required this.query,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < hotels.length; index++) ...[
            _HotelSuggestionTile(
              hotel: hotels[index],
              query: query,
              onTap: () => onSelected(hotels[index]),
            ),
            if (index != hotels.length - 1)
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ],
      ),
    );
  }
}

class _HotelSuggestionTile extends StatelessWidget {
  final PointHotel hotel;
  final String query;
  final VoidCallback onTap;

  const _HotelSuggestionTile({
    required this.hotel,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              const Icon(
                Icons.hotel_outlined,
                size: 22,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      _highlightHotelName(hotel.name, query),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hotel.locationText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        hotel.locationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

TextSpan _highlightHotelName(String name, String query) {
  final needle = query.trim().toLowerCase();
  const normalStyle = TextStyle(
    color: McColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
  const highlightStyle = TextStyle(
    color: PointStayColors.accent,
    fontSize: 15,
    fontWeight: FontWeight.w900,
  );

  if (needle.isEmpty) {
    return TextSpan(text: name, style: normalStyle);
  }

  final lowerName = name.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (start < name.length) {
    final matchIndex = lowerName.indexOf(needle, start);
    if (matchIndex < 0) {
      spans.add(TextSpan(text: name.substring(start), style: normalStyle));
      break;
    }

    if (matchIndex > start) {
      spans.add(
        TextSpan(
          text: name.substring(start, matchIndex),
          style: normalStyle,
        ),
      );
    }

    final matchEnd = matchIndex + needle.length;
    spans.add(
      TextSpan(
        text: name.substring(matchIndex, matchEnd),
        style: highlightStyle,
      ),
    );
    start = matchEnd;
  }

  return TextSpan(children: spans, style: normalStyle);
}

class _HotelSearchSummary extends StatelessWidget {
  final String query;
  final int nights;
  final DateTime? checkIn;
  final VoidCallback onTap;

  const _HotelSearchSummary({
    required this.query,
    required this.nights,
    required this.checkIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        checkIn == null ? '모든 날짜' : DateFormat('M월 d일').format(checkIn!);
    final destination = query.isEmpty ? '어디든' : query;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.chevron_left_rounded, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel · $nights박',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeSwitch extends StatelessWidget {
  final _HotelViewMode mode;
  final ValueChanged<_HotelViewMode> onChanged;

  const _ViewModeSwitch({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(
              label: '목록',
              icon: Icons.menu_rounded,
              selected: mode == _HotelViewMode.list,
              onTap: () => onChanged(_HotelViewMode.list),
            ),
            _ModeButton(
              label: '',
              icon: Icons.map_outlined,
              selected: mode == _HotelViewMode.map,
              onTap: () => onChanged(_HotelViewMode.map),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 12 : 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            if (label.isNotEmpty) ...[
              Text(
                label,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(icon, size: 22, color: McColors.ink),
          ],
        ),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final PointHotel hotel;
  final VoidCallback onTap;

  const _HotelCard({
    required this.hotel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      hotel.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Icon(Icons.hotel_outlined, size: 40),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: PointHotelFavoriteButton(
                    hotel: hotel,
                    color: Colors.white,
                    selectedColor: Colors.white,
                    size: 34,
                    minTouchSize: 48,
                    splashRadius: 24,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hotel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: McColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (hotel.hasMilecatchReviews)
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFFACC15),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hotel.milecatchRatingAverage!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    '리뷰 없음',
                    style: TextStyle(
                      color: Color(0xFF717171),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              hotel.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF717171),
                fontSize: 16,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hotel.hostText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF717171),
                fontSize: 16,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 9),
            if (hotel.hasAwardRate)
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: McColors.ink),
                  children: [
                    TextSpan(
                      text:
                          '${NumberFormat('#,###').format(hotel.pointsPerNight)} pts',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(
                      text: '/박',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                '포인트 확인 전',
                style: TextStyle(
                  color: McColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;
  final VoidCallback? onTap;

  const _SearchPanel({
    required this.title,
    required this.subtitle,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (child != null) ...[
                const SizedBox(height: 16),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelMapPreview extends StatefulWidget {
  final List<PointHotel> hotels;
  final ValueChanged<PointHotel> onTapHotel;

  const _HotelMapPreview({
    required this.hotels,
    required this.onTapHotel,
  });

  @override
  State<_HotelMapPreview> createState() => _HotelMapPreviewState();
}

class _HotelMapPreviewState extends State<_HotelMapPreview> {
  GoogleMapController? _mapController;
  Map<String, BitmapDescriptor> _markerIcons = const {};
  int _markerIconVersion = 0;

  List<PointHotel> get _mappableHotels => widget.hotels
      .where((hotel) => hotel.latitude != null && hotel.longitude != null)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _buildMarkerIcons();
  }

  @override
  void didUpdateWidget(covariant _HotelMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotels != widget.hotels) {
      _buildMarkerIcons();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToHotels());
    }
  }

  Future<void> _buildMarkerIcons() async {
    final version = ++_markerIconVersion;
    final hotels = _mappableHotels;
    final entries = await Future.wait(
      hotels.map((hotel) async {
        return MapEntry(
          hotel.id,
          await _buildHotelNameMarkerIcon(hotel.name),
        );
      }),
    );
    if (!mounted || version != _markerIconVersion) return;
    setState(() => _markerIcons = Map<String, BitmapDescriptor>.fromEntries(
          entries,
        ));
  }

  CameraPosition _initialCamera(List<PointHotel> hotels) {
    if (hotels.isEmpty) {
      return const CameraPosition(
        target: LatLng(37.5665, 126.9780),
        zoom: 10,
      );
    }

    final center = _centerForHotels(hotels);
    return CameraPosition(target: center, zoom: hotels.length == 1 ? 14.5 : 11);
  }

  LatLng _centerForHotels(List<PointHotel> hotels) {
    final lat = hotels
            .map((hotel) => hotel.latitude!)
            .reduce((value, element) => value + element) /
        hotels.length;
    final lng = hotels
            .map((hotel) => hotel.longitude!)
            .reduce((value, element) => value + element) /
        hotels.length;
    return LatLng(lat, lng);
  }

  LatLngBounds _boundsForHotels(List<PointHotel> hotels) {
    var minLat = hotels.first.latitude!;
    var maxLat = hotels.first.latitude!;
    var minLng = hotels.first.longitude!;
    var maxLng = hotels.first.longitude!;

    for (final hotel in hotels.skip(1)) {
      final lat = hotel.latitude!;
      final lng = hotel.longitude!;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitMapToHotels() async {
    final controller = _mapController;
    final hotels = _mappableHotels;
    if (controller == null || hotels.isEmpty) return;

    try {
      if (hotels.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(hotels.first.latitude!, hotels.first.longitude!),
            14.5,
          ),
        );
        return;
      }

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsForHotels(hotels), 56),
      );
    } catch (_) {
      // GoogleMap이 아직 레이아웃되기 전이면 초기 카메라 위치만 사용합니다.
    }
  }

  Set<Marker> _markersForHotels(List<PointHotel> hotels) {
    return hotels.map((hotel) {
      return Marker(
        markerId: MarkerId('hotel_${hotel.id}'),
        position: LatLng(hotel.latitude!, hotel.longitude!),
        anchor: const Offset(0.5, 1),
        icon: _markerIcons[hotel.id] ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: hotel.name,
          snippet: hotel.address,
          onTap: () => widget.onTapHotel(hotel),
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final hotels = _mappableHotels;
    if (hotels.isEmpty) {
      return const _HotelMessageState(
        icon: Icons.map_outlined,
        title: '지도에 표시할 위치가 없습니다.',
        body: '호텔 좌표가 등록되면 지도에서 위치를 볼 수 있습니다.',
        compact: true,
      );
    }

    return Container(
      height: 420,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DDE3)),
      ),
      child: GoogleMap(
        initialCameraPosition: _initialCamera(hotels),
        markers: _markersForHotels(hotels),
        onMapCreated: (controller) {
          _mapController = controller;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _fitMapToHotels());
        },
        compassEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}

Future<BitmapDescriptor> _buildHotelNameMarkerIcon(String name) async {
  const width = 250.0;
  const height = 108.0;
  const labelHeight = 48.0;
  const pinTop = 58.0;
  const pinRadius = 13.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.18)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
  final labelRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(8, 4, width - 16, labelHeight),
    const Radius.circular(22),
  );
  canvas.drawRRect(labelRect.shift(const Offset(0, 4)), shadowPaint);
  canvas.drawRRect(labelRect, Paint()..color = Colors.white);

  final textPainter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(
        color: McColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: width - 44);
  textPainter.paint(
    canvas,
    Offset(
      (width - textPainter.width) / 2,
      4 + (labelHeight - textPainter.height) / 2,
    ),
  );

  const pinCenter = Offset(width / 2, pinTop + pinRadius);
  final pinPaint = Paint()..color = PointStayColors.accent;
  final pinShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.2)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
  final pinPath = Path()
    ..addOval(Rect.fromCircle(center: pinCenter, radius: pinRadius))
    ..moveTo(width / 2 - 8, pinTop + pinRadius + 8)
    ..lineTo(width / 2, height - 4)
    ..lineTo(width / 2 + 8, pinTop + pinRadius + 8)
    ..close();
  canvas.drawPath(pinPath.shift(const Offset(0, 2)), pinShadowPaint);
  canvas.drawPath(pinPath, pinPaint);
  canvas.drawCircle(pinCenter, 4.5, Paint()..color = Colors.white);

  final image = await recorder.endRecording().toImage(
        width.toInt(),
        height.toInt(),
      );
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    imagePixelRatio: 2,
  );
}
