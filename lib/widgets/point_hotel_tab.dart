import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/point_hotel_model.dart';
import '../screen/point_hotel_detail_screen.dart';
import '../services/point_hotel_service.dart';

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

  Future<void> _openSearchSheet() async {
    final controller = TextEditingController(text: _query);
    var selectedDate = _checkIn;
    var selectedNights = _nights;

    final result = await showModalBottomSheet<_HotelSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setSheetState(() => selectedDate = picked);
              }
            }

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
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      _SearchPanel(
                        title: '어디',
                        subtitle: '목적지 검색',
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded, size: 28),
                            hintText: '호텔 또는 위치 검색...',
                          ),
                          onSubmitted: (_) => Navigator.pop(
                            context,
                            _HotelSearchResult(
                              query: controller.text,
                              nights: selectedNights,
                              checkIn: selectedDate,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SearchPanel(
                        title: '언제',
                        subtitle: selectedDate == null
                            ? '날짜 추가'
                            : DateFormat('M월 d일').format(selectedDate!),
                        onTap: pickDate,
                      ),
                      const SizedBox(height: 14),
                      _SearchPanel(
                        title: '박',
                        subtitle: '$selectedNights박',
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '숙박수 줄이기',
                              onPressed: selectedNights <= 1
                                  ? null
                                  : () => setSheetState(
                                        () => selectedNights -= 1,
                                      ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$selectedNights박',
                              style: const TextStyle(
                                color: McColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip: '숙박수 늘리기',
                              onPressed: () => setSheetState(
                                () => selectedNights += 1,
                              ),
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
                            backgroundColor: const Color(0xFFF3A5AA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(
                            context,
                            _HotelSearchResult(
                              query: controller.text,
                              nights: selectedNights,
                              checkIn: selectedDate,
                            ),
                          ),
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
          },
        );
      },
    );

    controller.dispose();
    if (result == null) return;
    setState(() {
      _query = result.query.trim();
      _nights = result.nights;
      _checkIn = result.checkIn;
    });
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.of(context).padding.bottom,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('필터', style: McTextStyles.sectionTitle),
              SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(label: '게스트 선호'),
                  _FilterChip(label: '15,000 pts 이하'),
                  _FilterChip(label: '메리어트'),
                  _FilterChip(label: '하얏트'),
                  _FilterChip(label: '힐튼'),
                  _FilterChip(label: '수영장'),
                ],
              ),
            ],
          ),
        );
      },
    );
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
          onOpenSearch: _openSearchSheet,
          onShowFilters: _showFilters,
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
  final VoidCallback onShowFilters;
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
    required this.onShowFilters,
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
              Row(
                children: [
                  _FilterButton(onTap: onShowFilters),
                  const Spacer(),
                  _ViewModeSwitch(
                    mode: viewMode,
                    onChanged: onViewModeChanged,
                  ),
                ],
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
                    fontWeight: FontWeight.w900,
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

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FilterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: McColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.tune_rounded),
      label: const Text(
        '필터',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                if (hotel.guestFavorite)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        child: Text(
                          '게스트 선호',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 34,
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
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18),
                    const SizedBox(width: 3),
                    Text(
                      hotel.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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

class _FilterChip extends StatelessWidget {
  final String label;

  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFF7F7F8),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
    );
  }
}

class _HotelMapPreview extends StatelessWidget {
  final List<PointHotel> hotels;
  final ValueChanged<PointHotel> onTapHotel;

  const _HotelMapPreview({
    required this.hotels,
    required this.onTapHotel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DDE3)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapLinePainter()),
          ),
          for (var i = 0; i < hotels.length; i++)
            Positioned(
              left: 28.0 + (i % 2) * 145,
              top: 42.0 + (i ~/ 2) * 72,
              child: _MapHotelPin(
                hotel: hotels[i],
                onTap: () => onTapHotel(hotels[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapHotelPin extends StatelessWidget {
  final PointHotel hotel;
  final VoidCallback onTap;

  const _MapHotelPin({
    required this.hotel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            hotel.hasAwardRate
                ? '${NumberFormat('#,###').format(hotel.pointsPerNight)} pts'
                : '확인 전',
            style: const TextStyle(
              color: McColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final thinPaint = Paint()
      ..color = const Color(0xFFD1D8DE)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(-20, size.height * 0.22),
      Offset(size.width + 30, size.height * 0.52),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, -20),
      Offset(size.width * 0.74, size.height + 20),
      roadPaint,
    );
    canvas.drawLine(
      Offset(20, size.height * 0.76),
      Offset(size.width - 20, size.height * 0.18),
      thinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
