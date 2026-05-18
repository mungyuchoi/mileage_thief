import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../models/hotel_award_model.dart';
import '../services/hotel_award_service.dart';

class HotelAwardDetailScreen extends StatelessWidget {
  final HotelAwardSnapshot initialSnapshot;

  const HotelAwardDetailScreen({
    super.key,
    required this.initialSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('포숙 상세'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.4,
        actions: [
          IconButton(
            tooltip: '공식 확인',
            icon: const Icon(Icons.open_in_new_outlined),
            onPressed: () => _launchOfficial(initialSnapshot),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<HotelAwardSnapshot>>(
          stream: HotelAwardService.watchPropertySnapshots(
            propertyId: initialSnapshot.propertyId,
          ),
          builder: (context, snapshot) {
            final snapshots = snapshot.data ?? [initialSnapshot];
            final selected = snapshots.firstWhere(
              (item) => item.id == initialSnapshot.id,
              orElse: () => initialSnapshot,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HeroSection(snapshot: selected),
                const SizedBox(height: 12),
                _ValueSection(snapshot: selected),
                const SizedBox(height: 12),
                _CalendarSection(snapshots: snapshots),
                const SizedBox(height: 12),
                _MethodSection(snapshot: selected),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _launchOfficial(HotelAwardSnapshot snapshot) async {
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

class _HeroSection extends StatelessWidget {
  final HotelAwardSnapshot snapshot;

  const _HeroSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  snapshot.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                ),
              ),
            )
          else
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: _ImageFallback(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgramPill(snapshot: snapshot),
                const SizedBox(height: 10),
                Text(
                  snapshot.hotelName,
                  style: const TextStyle(
                    color: McColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    snapshot.displayBrand,
                    snapshot.displayLocation,
                  ].where((item) => item.trim().isNotEmpty).join(' · '),
                  style: McTextStyles.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueSection extends StatelessWidget {
  final HotelAwardSnapshot snapshot;

  const _ValueSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('선택 날짜 가치', style: McTextStyles.cardTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: '포인트',
                  value: '${_number.format(snapshot.pointsTotal)}P',
                  subtitle: '${snapshot.nights}박',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: '현금가',
                  value: snapshot.cashTotalKrw == null
                      ? '-'
                      : '${_number.format(snapshot.cashTotalKrw)}원',
                  subtitle: '세금 포함 기준',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: '원/pt',
                  value: snapshot.krwPerPoint == null
                      ? '-'
                      : snapshot.krwPerPoint!.toStringAsFixed(2),
                  subtitle: snapshot.valueRatio > 0
                      ? '${snapshot.valueRatio.toStringAsFixed(2)}x 기준'
                      : '기준가 비교 대기',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: '상태',
                  value: snapshot.isBookable ? '예약 가능' : '확인 필요',
                  subtitle: snapshot.isFresh ? '24시간 이내' : '재확인 권장',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  final List<HotelAwardSnapshot> snapshots;

  const _CalendarSection({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final byDate = snapshots.toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('날짜별 스냅샷', style: McTextStyles.cardTitle),
          const SizedBox(height: 10),
          if (byDate.isEmpty)
            const Text('아직 날짜별 스냅샷이 없습니다.', style: McTextStyles.meta)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final snapshot in byDate.take(36))
                  _DateChip(snapshot: snapshot),
              ],
            ),
        ],
      ),
    );
  }
}

class _MethodSection extends StatelessWidget {
  final HotelAwardSnapshot snapshot;

  const _MethodSection({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('데이터 확인', style: McTextStyles.cardTitle),
          const SizedBox(height: 8),
          _InfoRow(label: '출처', value: snapshot.source),
          _InfoRow(
              label: '마지막 확인', value: _dateTime.format(snapshot.fetchedAt)),
          _InfoRow(
            label: '신뢰도',
            value: '${(snapshot.confidence * 100).round()}%',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => HotelAwardDetailScreen._launchOfficial(snapshot),
              icon: const Icon(Icons.open_in_new_outlined, size: 18),
              label: const Text('공식 사이트에서 최종 확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final HotelAwardSnapshot snapshot;

  const _DateChip({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final goodValue = (snapshot.krwPerPoint ?? 0) >= 10;
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: goodValue ? const Color(0xFFEFF6FF) : McColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: goodValue ? const Color(0xFF93C5FD) : McColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MM.dd').format(snapshot.checkIn),
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_compactPoints(snapshot.pointsTotal)}P',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.micro,
          ),
          Text(
            snapshot.krwPerPoint == null
                ? '-'
                : '${snapshot.krwPerPoint!.toStringAsFixed(1)}원/pt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.micro.copyWith(
              color: goodValue ? const Color(0xFF1D4ED8) : McColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramPill extends StatelessWidget {
  final HotelAwardSnapshot snapshot;

  const _ProgramPill({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: McColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        snapshot.program.label,
        style: const TextStyle(
          color: McColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: McTextStyles.micro),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.micro,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(label, style: McTextStyles.meta),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: McTextStyles.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: child,
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

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

final NumberFormat _number = NumberFormat('#,###');
final DateFormat _dateTime = DateFormat('yyyy.MM.dd HH:mm');

String _compactPoints(int points) {
  if (points >= 1000) return '${(points / 1000).round()}K';
  return points.toString();
}
