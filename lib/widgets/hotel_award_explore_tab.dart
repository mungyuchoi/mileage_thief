import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../models/hotel_award_model.dart';
import '../screen/hotel_award_detail_screen.dart';
import '../services/hotel_award_service.dart';

class HotelAwardExploreTab extends StatefulWidget {
  const HotelAwardExploreTab({super.key});

  @override
  State<HotelAwardExploreTab> createState() => _HotelAwardExploreTabState();
}

class _HotelAwardExploreTabState extends State<HotelAwardExploreTab> {
  final TextEditingController _locationController = TextEditingController();
  final Set<HotelAwardProgram> _programs = {
    ...HotelAwardProgram.values,
  };

  late DateTime _checkIn;
  int _nights = 1;
  int? _maxPoints;
  double? _minKrwPerPoint;
  int? _maxCashKrw;
  HotelAwardSort _sort = HotelAwardSort.value;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _checkIn = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 30),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  HotelAwardSearchQuery get _query => HotelAwardSearchQuery(
        locationText: _locationController.text,
        checkIn: _checkIn,
        nights: _nights,
        programs: _programs,
        maxPoints: _maxPoints,
        minKrwPerPoint: _minKrwPerPoint,
        maxCashKrw: _maxCashKrw,
        sort: _sort,
      );

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchPanel(
          locationController: _locationController,
          checkIn: _checkIn,
          nights: _nights,
          programs: _programs,
          maxPoints: _maxPoints,
          minKrwPerPoint: _minKrwPerPoint,
          maxCashKrw: _maxCashKrw,
          sort: _sort,
          onLocationChanged: (_) => setState(() {}),
          onPickDate: _pickDate,
          onNightsChanged: (value) => setState(() => _nights = value),
          onToggleProgram: _toggleProgram,
          onMaxPointsChanged: (value) => setState(() => _maxPoints = value),
          onMinValueChanged: (value) => setState(() => _minKrwPerPoint = value),
          onMaxCashChanged: (value) => setState(() => _maxCashKrw = value),
          onSortChanged: (value) => setState(() => _sort = value),
        ),
        const SizedBox(height: 12),
        StreamBuilder<Set<String>>(
          stream: HotelAwardService.watchSavedAwardHotelIds(),
          builder: (context, savedSnapshot) {
            final savedIds = savedSnapshot.data ?? <String>{};
            return StreamBuilder<List<HotelAwardSnapshot>>(
              stream: HotelAwardService.watchAwardSnapshots(query),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ExploreStatePanel(
                    icon: Icons.error_outline,
                    title: '탐색 데이터를 불러오지 못했습니다.',
                    subtitle: snapshot.error.toString(),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _ExploreLoadingPanel();
                }

                final results = snapshot.data ?? const <HotelAwardSnapshot>[];
                if (results.isEmpty) {
                  return const _ExploreStatePanel(
                    icon: Icons.hotel_class_outlined,
                    title: '조건에 맞는 포숙 스냅샷이 없습니다.',
                    subtitle: '크롤러 PoC가 데이터를 쌓으면 날짜별 후보가 표시됩니다.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultSummary(count: results.length, query: query),
                    const SizedBox(height: 10),
                    for (final item in results) ...[
                      _AwardResultCard(
                        snapshot: item,
                        isSaved: savedIds.contains(item.propertyId),
                        onTap: () => _openDetail(item),
                        onToggleSaved: () => _toggleSaved(
                          item,
                          isSaved: savedIds.contains(item.propertyId),
                        ),
                        onCreateAlert: () => _createAlert(item),
                        onOpenOfficial: () => _launchOfficial(item),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 370)),
      helpText: '체크인 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked == null) return;
    setState(() => _checkIn = DateTime(picked.year, picked.month, picked.day));
  }

  void _toggleProgram(HotelAwardProgram? program) {
    setState(() {
      if (program == null) {
        _programs
          ..clear()
          ..addAll(HotelAwardProgram.values);
        return;
      }
      if (_programs.length == HotelAwardProgram.values.length) {
        _programs.clear();
      }
      if (_programs.contains(program)) {
        _programs.remove(program);
      } else {
        _programs.add(program);
      }
      if (_programs.isEmpty) {
        _programs.addAll(HotelAwardProgram.values);
      }
    });
  }

  Future<void> _toggleSaved(
    HotelAwardSnapshot snapshot, {
    required bool isSaved,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 저장할 수 있습니다.');
      return;
    }
    try {
      await HotelAwardService.toggleSavedAwardHotel(snapshot);
      Fluttertoast.showToast(msg: isSaved ? '저장을 해제했습니다.' : '호텔을 저장했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 상태를 바꾸지 못했습니다.');
    }
  }

  Future<void> _createAlert(HotelAwardSnapshot snapshot) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 알림을 만들 수 있습니다.');
      return;
    }
    try {
      await HotelAwardService.saveAwardAlert(
        snapshot: snapshot,
        maxPoints: _maxPoints,
        minKrwPerPoint: _minKrwPerPoint,
      );
      Fluttertoast.showToast(msg: '포숙 알림을 저장했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '알림을 저장하지 못했습니다.');
    }
  }

  void _openDetail(HotelAwardSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'hotel_award_detail'),
        builder: (_) => HotelAwardDetailScreen(initialSnapshot: snapshot),
      ),
    );
  }

  Future<void> _launchOfficial(HotelAwardSnapshot snapshot) async {
    final url = snapshot.officialUrl.isNotEmpty
        ? snapshot.officialUrl
        : snapshot.sourceUrl;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Fluttertoast.showToast(msg: '공식 확인 링크를 열 수 없습니다.');
    }
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController locationController;
  final DateTime checkIn;
  final int nights;
  final Set<HotelAwardProgram> programs;
  final int? maxPoints;
  final double? minKrwPerPoint;
  final int? maxCashKrw;
  final HotelAwardSort sort;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback onPickDate;
  final ValueChanged<int> onNightsChanged;
  final ValueChanged<HotelAwardProgram?> onToggleProgram;
  final ValueChanged<int?> onMaxPointsChanged;
  final ValueChanged<double?> onMinValueChanged;
  final ValueChanged<int?> onMaxCashChanged;
  final ValueChanged<HotelAwardSort> onSortChanged;

  const _SearchPanel({
    required this.locationController,
    required this.checkIn,
    required this.nights,
    required this.programs,
    required this.maxPoints,
    required this.minKrwPerPoint,
    required this.maxCashKrw,
    required this.sort,
    required this.onLocationChanged,
    required this.onPickDate,
    required this.onNightsChanged,
    required this.onToggleProgram,
    required this.onMaxPointsChanged,
    required this.onMinValueChanged,
    required this.onMaxCashChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ExplorePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_outlined, color: McColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text('포숙 탐색', style: McTextStyles.cardTitle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationController,
            onChanged: onLocationChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: '도시, 호텔명, 국가',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PickerButton(
                  icon: Icons.event_outlined,
                  label: DateFormat('MM.dd').format(checkIn),
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NightStepper(
                  nights: nights,
                  onChanged: onNightsChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ChipLine(
            children: [
              _FilterChip(
                label: '전체',
                selected: programs.length == HotelAwardProgram.values.length,
                onTap: () => onToggleProgram(null),
              ),
              for (final program in HotelAwardProgram.values)
                _FilterChip(
                  label: program.shortLabel,
                  selected:
                      programs.length != HotelAwardProgram.values.length &&
                          programs.contains(program),
                  onTap: () => onToggleProgram(program),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipLine(
            children: [
              _FilterChip(
                label: '포인트 전체',
                selected: maxPoints == null,
                onTap: () => onMaxPointsChanged(null),
              ),
              for (final option in _pointOptions.entries)
                _FilterChip(
                  label: option.key,
                  selected: maxPoints == option.value,
                  onTap: () => onMaxPointsChanged(option.value),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipLine(
            children: [
              _FilterChip(
                label: '가치 전체',
                selected: minKrwPerPoint == null,
                onTap: () => onMinValueChanged(null),
              ),
              for (final option in _valueOptions.entries)
                _FilterChip(
                  label: option.key,
                  selected: minKrwPerPoint == option.value,
                  onTap: () => onMinValueChanged(option.value),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipLine(
            children: [
              _FilterChip(
                label: '현금 전체',
                selected: maxCashKrw == null,
                onTap: () => onMaxCashChanged(null),
              ),
              for (final option in _cashOptions.entries)
                _FilterChip(
                  label: option.key,
                  selected: maxCashKrw == option.value,
                  onTap: () => onMaxCashChanged(option.value),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipLine(
            children: [
              for (final option in HotelAwardSort.values)
                _FilterChip(
                  label: _sortLabel(option),
                  selected: sort == option,
                  onTap: () => onSortChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AwardResultCard extends StatelessWidget {
  final HotelAwardSnapshot snapshot;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final VoidCallback onCreateAlert;
  final VoidCallback onOpenOfficial;

  const _AwardResultCard({
    required this.snapshot,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSaved,
    required this.onCreateAlert,
    required this.onOpenOfficial,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: McColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardImage(
                  snapshot: snapshot, isSaved: isSaved, onSave: onToggleSaved),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TinyPill(text: snapshot.program.shortLabel),
                        const SizedBox(width: 6),
                        if (snapshot.isBookable)
                          const _TinyPill(
                            text: '예약 가능',
                            color: Color(0xFFEFF6FF),
                            textColor: Color(0xFF1D4ED8),
                          )
                        else
                          const _TinyPill(text: '확인 필요'),
                        const Spacer(),
                        Text(
                          snapshot.isFresh ? 'fresh' : 'stale',
                          style: McTextStyles.micro,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      snapshot.hotelName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.23,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        snapshot.displayBrand,
                        snapshot.displayLocation,
                      ].where((item) => item.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CardMetric(
                            label: '포인트',
                            value: '${_number.format(snapshot.pointsTotal)}P',
                          ),
                        ),
                        Expanded(
                          child: _CardMetric(
                            label: '현금가',
                            value: snapshot.cashTotalKrw == null
                                ? '-'
                                : '${_number.format(snapshot.cashTotalKrw)}원',
                          ),
                        ),
                        Expanded(
                          child: _CardMetric(
                            label: '가치',
                            value: snapshot.krwPerPoint == null
                                ? '-'
                                : '${snapshot.krwPerPoint!.toStringAsFixed(1)}원/pt',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onCreateAlert,
                            icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 17),
                            label: const Text('알림'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onOpenOfficial,
                            icon: const Icon(Icons.open_in_new_outlined,
                                size: 17),
                            label: const Text('공식 확인'),
                          ),
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

class _CardImage extends StatelessWidget {
  final HotelAwardSnapshot snapshot;
  final bool isSaved;
  final VoidCallback onSave;

  const _CardImage({
    required this.snapshot,
    required this.isSaved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 8.2,
            child: snapshot.imageUrl.isEmpty
                ? const _HotelImageFallback()
                : Image.network(
                    snapshot.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _HotelImageFallback(),
                  ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: isSaved ? '저장 해제' : '저장',
                onPressed: onSave,
                icon: Icon(
                  isSaved ? Icons.favorite : Icons.favorite_border,
                  color: isSaved ? Colors.red[300] : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: McTextStyles.micro),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: McColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final int count;
  final HotelAwardSearchQuery query;

  const _ResultSummary({required this.count, required this.query});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count개 후보 · ${query.checkInKey} · ${query.nights}박',
            style: McTextStyles.bodyStrong,
          ),
        ),
        Text(_sortLabel(query.sort), style: McTextStyles.meta),
      ],
    );
  }
}

class _NightStepper extends StatelessWidget {
  final int nights;
  final ValueChanged<int> onChanged;

  const _NightStepper({
    required this.nights,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '숙박수 줄이기',
            onPressed: nights <= 1 ? null : () => onChanged(nights - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          Expanded(
            child: Text(
              '$nights박',
              textAlign: TextAlign.center,
              style: McTextStyles.bodyStrong,
            ),
          ),
          IconButton(
            tooltip: '숙박수 늘리기',
            onPressed: nights >= 14 ? null : () => onChanged(nights + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: McColors.field,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: McColors.muted),
              const SizedBox(width: 7),
              Text(label, style: McTextStyles.bodyStrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: McColors.accentSoft,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? McColors.accent : McColors.line,
      ),
      labelStyle: TextStyle(
        color: selected ? McColors.accent : McColors.muted,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _ChipLine extends StatelessWidget {
  final List<Widget> children;

  const _ChipLine({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _TinyPill({
    required this.text,
    this.color = McColors.accentSoft,
    this.textColor = McColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExploreLoadingPanel extends StatelessWidget {
  const _ExploreLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const _ExplorePanel(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text('포숙 후보를 불러오는 중입니다.', style: McTextStyles.meta),
          ),
        ],
      ),
    );
  }
}

class _ExploreStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ExploreStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _ExplorePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: McColors.mutedLight, size: 38),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: McTextStyles.body),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: McTextStyles.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorePanel extends StatelessWidget {
  final Widget child;

  const _ExplorePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: child,
    );
  }
}

class _HotelImageFallback extends StatelessWidget {
  const _HotelImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: McColors.field,
      child: const Center(
        child: Icon(Icons.hotel_class_outlined, color: McColors.mutedLight),
      ),
    );
  }
}

const Map<String, int> _pointOptions = {
  '40K↓': 40000,
  '80K↓': 80000,
  '120K↓': 120000,
};

const Map<String, double> _valueOptions = {
  '7원/pt↑': 7,
  '10원/pt↑': 10,
  '15원/pt↑': 15,
};

const Map<String, int> _cashOptions = {
  '30만↓': 300000,
  '60만↓': 600000,
  '100만↓': 1000000,
};

final NumberFormat _number = NumberFormat('#,###');

String _sortLabel(HotelAwardSort sort) {
  switch (sort) {
    case HotelAwardSort.points:
      return '포인트 낮은순';
    case HotelAwardSort.cash:
      return '현금가 낮은순';
    case HotelAwardSort.recent:
      return '최근 확인순';
    case HotelAwardSort.value:
      return '가치 높은순';
  }
}
