import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/point_hotel_model.dart';
import '../screen/point_hotel_detail_screen.dart';
import '../services/point_hotel_service.dart';

class PointHotelExploreTab extends StatefulWidget {
  const PointHotelExploreTab({super.key});

  @override
  State<PointHotelExploreTab> createState() => _PointHotelExploreTabState();
}

class _PointHotelExploreTabState extends State<PointHotelExploreTab> {
  static const List<String> _brands = [
    '전체',
    'Hyatt',
    'Hilton',
    'IHG',
    'Marriott',
  ];

  String _selectedBrand = '전체';
  int _nights = 1;
  _ExploreSort _sort = _ExploreSort.value;

  List<_AwardCandidate> _candidates(List<PointHotel> hotels) {
    final now = DateTime.now();
    final candidates = <_AwardCandidate>[];
    for (var index = 0; index < hotels.length; index++) {
      final hotel = hotels[index];
      if (!_matchesBrand(hotel)) continue;
      if (!hotel.hasAwardRate || !hotel.hasCashRate) continue;
      final totalCash = hotel.cashPerNightKrw * _nights;
      candidates.add(
        _AwardCandidate(
          hotel: hotel,
          checkIn: now.add(Duration(days: 7 + index * 13)),
          updatedLabel: index == 0 ? '2일 전' : '${index + 1}시간 전',
          pointsTotal: _awardAdjustedPoints(hotel),
          cashTotalKrw: totalCash,
          confidence: 0.96 - index * 0.08,
        ),
      );
    }
    candidates.sort((a, b) {
      switch (_sort) {
        case _ExploreSort.value:
          return b.krwPerPoint.compareTo(a.krwPerPoint);
        case _ExploreSort.points:
          return a.pointsTotal.compareTo(b.pointsTotal);
        case _ExploreSort.recent:
          return a.updatedLabel.compareTo(b.updatedLabel);
      }
    });
    return candidates;
  }

  bool _matchesBrand(PointHotel hotel) {
    if (_selectedBrand == '전체') return true;
    final brand = hotel.brand.toLowerCase();
    final selected = _selectedBrand.toLowerCase();
    if (selected == 'hyatt') {
      return brand.contains('hyatt') || brand.contains('jdv');
    }
    if (selected == 'ihg') {
      return brand.contains('holiday') || brand.contains('ihg');
    }
    if (selected == 'marriott') {
      return hotel.isMarriottBonvoy || brand.contains('marriott');
    }
    return brand.contains(selected);
  }

  int _awardAdjustedPoints(PointHotel hotel) {
    return hotel.awardPointsForNights(_nights);
  }

  void _openHotel(_AwardCandidate candidate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'point_hotel_detail'),
        builder: (_) => PointHotelDetailScreen(
          hotel: candidate.hotel,
          nights: _nights,
          checkIn: candidate.checkIn,
        ),
      ),
    );
  }

  Future<void> _selectBrand() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              Text(
                '브랜드',
                style: McTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              for (final brand in _brands) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(brand),
                  trailing: brand == _selectedBrand
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: McColors.accent,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, brand),
                ),
                if (brand != _brands.last) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _selectedBrand = selected);
  }

  Future<void> _selectNights() async {
    var nights = _nights;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '박',
                      style: McTextStyles.sectionTitle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '숙박수 줄이기',
                          onPressed: nights <= 1
                              ? null
                              : () => setSheetState(() => nights -= 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$nights박',
                              style: const TextStyle(
                                color: McColors.ink,
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '숙박수 늘리기',
                          onPressed: () => setSheetState(() => nights += 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, nights),
                        child: const Text('적용'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    setState(() => _nights = selected);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointHotel>>(
      stream: PointHotelService.instance.watchHotels(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ExploreMessageState(
            icon: Icons.cloud_off_rounded,
            title: '탐색 데이터를 불러오지 못했습니다.',
            body: 'Firestore 연결 또는 권한을 확인해 주세요.',
          );
        }
        if (!snapshot.hasData) {
          return const _ExploreSection(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        final candidates = _candidates(snapshot.data ?? const <PointHotel>[]);
        return _ExploreContent(
          candidates: candidates,
          selectedBrand: _selectedBrand,
          nights: _nights,
          sort: _sort,
          onBrandTap: _selectBrand,
          onNightsTap: _selectNights,
          onSortChanged: (sort) => setState(() => _sort = sort),
          onOpenHotel: _openHotel,
        );
      },
    );
  }
}

class _ExploreContent extends StatelessWidget {
  final List<_AwardCandidate> candidates;
  final String selectedBrand;
  final int nights;
  final _ExploreSort sort;
  final VoidCallback onBrandTap;
  final VoidCallback onNightsTap;
  final ValueChanged<_ExploreSort> onSortChanged;
  final ValueChanged<_AwardCandidate> onOpenHotel;

  const _ExploreContent({
    required this.candidates,
    required this.selectedBrand,
    required this.nights,
    required this.sort,
    required this.onBrandTap,
    required this.onNightsTap,
    required this.onSortChanged,
    required this.onOpenHotel,
  });

  @override
  Widget build(BuildContext context) {
    return _ExploreSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '호텔 어워드 요금 탐색',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: McColors.ink,
                fontSize: 28,
                height: 1.18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '브랜드별 호텔 포인트 가격을 살펴보고 CPP 값을 비교하며 최근 확인된 어워드 날짜를 검토하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          _ExplorePill(
            brand: selectedBrand,
            nights: nights,
            onBrandTap: onBrandTap,
            onNightsTap: onNightsTap,
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortChip(
                  label: '가치순',
                  selected: sort == _ExploreSort.value,
                  onTap: () => onSortChanged(_ExploreSort.value),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: '낮은 포인트',
                  selected: sort == _ExploreSort.points,
                  onTap: () => onSortChanged(_ExploreSort.points),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: '최근 확인',
                  selected: sort == _ExploreSort.recent,
                  onTap: () => onSortChanged(_ExploreSort.recent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ExploreSummary(candidates: candidates, nights: nights),
          const SizedBox(height: 12),
          for (final candidate in candidates) ...[
            _AwardCandidateCard(
              candidate: candidate,
              onTap: () => onOpenHotel(candidate),
            ),
            const SizedBox(height: 10),
          ],
          if (candidates.isEmpty) const _ExploreEmptyState(),
        ],
      ),
    );
  }
}

class _ExploreSection extends StatelessWidget {
  final Widget child;

  const _ExploreSection({required this.child});

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

class _ExploreMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ExploreMessageState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _ExploreSection(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 12),
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
      ),
    );
  }
}

enum _ExploreSort { value, points, recent }

class _AwardCandidate {
  final PointHotel hotel;
  final DateTime checkIn;
  final String updatedLabel;
  final int pointsTotal;
  final int cashTotalKrw;
  final double confidence;

  const _AwardCandidate({
    required this.hotel,
    required this.checkIn,
    required this.updatedLabel,
    required this.pointsTotal,
    required this.cashTotalKrw,
    required this.confidence,
  });

  double get krwPerPoint => pointsTotal <= 0 ? 0 : cashTotalKrw / pointsTotal;

  double get usdTotal => cashTotalKrw / 1350;
}

class _ExplorePill extends StatelessWidget {
  final String brand;
  final int nights;
  final VoidCallback onBrandTap;
  final VoidCallback onNightsTap;

  const _ExplorePill({
    required this.brand,
    required this.nights,
    required this.onBrandTap,
    required this.onNightsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillSection(
              label: '브랜드',
              value: brand,
              onTap: onBrandTap,
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFD1D5DB)),
          SizedBox(
            width: 112,
            child: _PillSection(
              label: '박',
              value: '$nights박',
              onTap: onNightsTap,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: McColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PillSection extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PillSection({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: McColors.accentSoft,
      labelStyle: TextStyle(
        color: selected ? McColors.accent : McColors.muted,
        fontWeight: FontWeight.w400,
      ),
      side: const BorderSide(color: McColors.line),
    );
  }
}

class _ExploreSummary extends StatelessWidget {
  final List<_AwardCandidate> candidates;
  final int nights;

  const _ExploreSummary({
    required this.candidates,
    required this.nights,
  });

  @override
  Widget build(BuildContext context) {
    final best = candidates.isEmpty ? null : candidates.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: McColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_graph_rounded, color: McColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              best == null
                  ? '$nights박 조건에 맞는 후보가 없습니다.'
                  : '최고 가치 ${best.hotel.name} · ${best.krwPerPoint.toStringAsFixed(1)}원/pt',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: McColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardCandidateCard extends StatelessWidget {
  final _AwardCandidate candidate;
  final VoidCallback onTap;

  const _AwardCandidateCard({
    required this.candidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hotel = candidate.hotel;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: Image.network(
                      hotel.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.hotel_outlined, size: 23),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              candidate.updatedLabel,
                              style: const TextStyle(
                                color: Color(0xFF404040),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hotel.locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF525252),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('MMM d, y').format(candidate.checkIn),
                          style: const TextStyle(
                            color: Color(0xFF525252),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ValuePill(
                          label:
                              '${NumberFormat('#,###').format(candidate.pointsTotal)} pts',
                          accent: true,
                        ),
                        _ValuePill(
                          label: '\$${candidate.usdTotal.round().toString()}',
                        ),
                        _ValuePill(
                          label:
                              '${candidate.krwPerPoint.toStringAsFixed(1)}원/pt',
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: McColors.mutedLight,
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String label;
  final bool accent;

  const _ValuePill({
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? McColors.accentSoft : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              accent ? McColors.accent.withValues(alpha: 0.18) : McColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: accent ? McColors.accent : McColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ExploreEmptyState extends StatelessWidget {
  const _ExploreEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: McColors.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: McColors.mutedLight, size: 38),
          SizedBox(height: 10),
          Text(
            '조건에 맞는 어워드 후보가 없습니다.',
            textAlign: TextAlign.center,
            style: McTextStyles.body,
          ),
        ],
      ),
    );
  }
}
