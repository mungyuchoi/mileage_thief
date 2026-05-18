import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/marriott_stay_record.dart';
import '../services/marriott_stay_service.dart';

class MarriottStayRecordsTab extends StatelessWidget {
  final VoidCallback onAdd;
  final ValueChanged<MarriottStayRecord> onEdit;
  final Future<void> Function(MarriottStayRecord record) onDelete;

  const MarriottStayRecordsTab({
    super.key,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _RecordsPanel(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: McColors.mutedLight,
                  size: 38,
                ),
                SizedBox(height: 10),
                Text(
                  '로그인 후 숙박기록을 저장할 수 있습니다.',
                  style: McTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  '기록은 내 계정에만 저장됩니다.',
                  style: McTextStyles.meta,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<MarriottStayRecord>>(
      stream: MarriottStayService.watchUserStays(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _RecordsPanel(
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '숙박기록을 불러오는 중입니다.',
                    style: McTextStyles.meta,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _RecordsPanel(
            child: Text(
              '숙박기록을 불러오지 못했습니다.\n${snapshot.error}',
              style: McTextStyles.meta,
            ),
          );
        }

        final records = snapshot.data ?? const <MarriottStayRecord>[];
        if (records.isEmpty) {
          return _RecordsPanel(
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.hotel_class_outlined,
                      color: McColors.mutedLight,
                      size: 38,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '아직 저장된 메리어트 숙박기록이 없습니다.',
                      style: McTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('첫 숙박 기록 추가'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final groups = _StayRecordGrouper.groupByCheckIn(records);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecordsHeader(onAdd: onAdd),
            const SizedBox(height: 12),
            _StaySummary(records: records),
            const SizedBox(height: 12),
            for (final group in groups) ...[
              _StayDayHeader(group: group),
              for (final record in group.records)
                _StayRecordRow(
                  record: record,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _RecordsHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const _RecordsHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _RecordsPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: McColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hotel_class_outlined,
              color: McColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '메리어트 숙박기록',
                  style: McTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                const Text(
                  '체크인 날짜별로 지출, 포인트, 회수율, 예약번호를 들고 다니듯 정리해요.',
                  style: McTextStyles.meta,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('기록 추가'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StayRecordGroup {
  final DateTime day;
  final List<MarriottStayRecord> records;

  const _StayRecordGroup({
    required this.day,
    required this.records,
  });
}

class _StayRecordGrouper {
  const _StayRecordGrouper._();

  static List<_StayRecordGroup> groupByCheckIn(
    List<MarriottStayRecord> records,
  ) {
    final byDay = <DateTime, List<MarriottStayRecord>>{};
    for (final record in records) {
      final day = DateTime(
        record.checkIn.year,
        record.checkIn.month,
        record.checkIn.day,
      );
      byDay.putIfAbsent(day, () => <MarriottStayRecord>[]).add(record);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        _StayRecordGroup(
          day: day,
          records: byDay[day]!..sort((a, b) => b.checkIn.compareTo(a.checkIn)),
        ),
    ];
  }
}

class _StaySummary extends StatelessWidget {
  final List<MarriottStayRecord> records;

  const _StaySummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final points = NumberFormat('#,###');
    final totalNights =
        records.fold<int>(0, (sum, record) => sum + record.nights);
    final totalAmount =
        records.fold<int>(0, (sum, record) => sum + record.totalAmount);
    final totalPoints =
        records.fold<int>(0, (sum, record) => sum + record.earnedPoints);
    final paidRecords =
        records.where((record) => record.totalAmount > 0).toList();
    final avgReturnRate = paidRecords.isEmpty
        ? 0.0
        : paidRecords.fold<double>(
              0,
              (sum, record) => sum + record.returnRate,
            ) /
            paidRecords.length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryTile(
          label: '총 박수',
          value: '$totalNights박',
          icon: Icons.nights_stay_outlined,
        ),
        _SummaryTile(
          label: '총 지출',
          value: '${won.format(totalAmount)}원',
          icon: Icons.payments_outlined,
        ),
        _SummaryTile(
          label: '획득 포인트',
          value: '${points.format(totalPoints)}P',
          icon: Icons.stars_outlined,
        ),
        _SummaryTile(
          label: '평균 회수율',
          value: '${avgReturnRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up_outlined,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: McColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: McColors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: McTextStyles.micro),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McTextStyles.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StayDayHeader extends StatelessWidget {
  final _StayRecordGroup group;

  const _StayDayHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('yyyy-MM-dd').format(group.day);
    final totalNights =
        group.records.fold<int>(0, (sum, record) => sum + record.nights);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: McTextStyles.bodyStrong.copyWith(fontSize: 13),
            ),
          ),
          Text(
            '${group.records.length}건 · $totalNights박',
            style: McTextStyles.meta.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StayRecordRow extends StatelessWidget {
  final MarriottStayRecord record;
  final ValueChanged<MarriottStayRecord> onEdit;
  final Future<void> Function(MarriottStayRecord record) onDelete;

  const _StayRecordRow({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final points = NumberFormat('#,###');
    final range = _dateRange(record.checkIn, record.checkOut);
    final amountText = record.totalAmount <= 0
        ? record.stayType.label
        : '${won.format(record.totalAmount)}원';

    final pills = <Widget>[
      _MiniPill(text: range, icon: Icons.event_outlined),
      _MiniPill(
        text: '${points.format(record.earnedPoints)}P',
        icon: Icons.stars_outlined,
      ),
      _MiniPill(
        text: '회수율 ${record.returnRate.toStringAsFixed(1)}%',
        icon: Icons.percent,
      ),
      _MiniPill(text: record.eliteTierName, icon: Icons.workspace_premium),
    ];
    if (record.bookingNumber.isNotEmpty) {
      pills.add(_MiniPill(
        text: '예약 ${record.bookingNumber}',
        icon: Icons.confirmation_number_outlined,
      ));
    }
    if (record.memo.isNotEmpty) {
      pills.add(_MiniPill(text: record.memo, icon: Icons.note_outlined));
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: McColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StayTypeBadge(type: record.stayType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${record.nights}박 · ${record.hotelName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McTextStyles.bodyStrong.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  color: record.totalAmount <= 0 ? McColors.accent : Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: McColors.muted,
                ),
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x14000000)),
                ),
                elevation: 6,
                onSelected: (value) async {
                  if (value == 'edit') {
                    onEdit(record);
                  } else if (value == 'delete') {
                    await onDelete(record);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      '편집',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills,
          ),
        ],
      ),
    );
  }

  String _dateRange(DateTime checkIn, DateTime checkOut) {
    final formatter = DateFormat('MM.dd');
    return '${formatter.format(checkIn)} - ${formatter.format(checkOut)}';
  }
}

class _StayTypeBadge extends StatelessWidget {
  final MarriottStayType type;

  const _StayTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      MarriottStayType.paid => Colors.blue,
      MarriottStayType.points => McColors.accent,
      MarriottStayType.freeNightAward => Colors.deepPurple,
    };
    return Text(
      type.label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _MiniPill({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: McColors.muted),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.micro.copyWith(color: McColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsPanel extends StatelessWidget {
  final Widget child;

  const _RecordsPanel({required this.child});

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
