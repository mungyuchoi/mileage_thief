import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/marriott_stay_record.dart';
import '../services/analytics_service.dart';
import '../services/marriott_stay_service.dart';
import 'marriott_stay_form_screen.dart';

class MarriottStayListScreen extends StatefulWidget {
  const MarriottStayListScreen({super.key});

  @override
  State<MarriottStayListScreen> createState() => _MarriottStayListScreenState();
}

class _MarriottStayListScreenState extends State<MarriottStayListScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(
      'marriott_stay_list',
      screenClass: 'MarriottStayListScreen',
      source: 'point_stay',
    );
  }

  Future<void> _openMarriottStayForm([MarriottStayRecord? record]) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    AnalyticsService.instance.logAction('marriott_stay_form_open', params: {
      'mode': record == null ? 'create' : 'edit',
      'screen': 'marriott_stay_list',
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'marriott_stay_form'),
        builder: (_) => MarriottStayFormScreen(initialRecord: record),
      ),
    );
  }

  Future<void> _confirmDeleteMarriottStay(MarriottStayRecord record) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '숙박기록 삭제',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${record.hotelName} 기록을 삭제할까요?',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await MarriottStayService.deleteStay(uid: uid, stayId: record.id);
      AnalyticsService.instance.logAction('marriott_stay_deleted', params: {
        'stay_type': record.stayType.value,
        'nights': record.nights,
        'screen': 'marriott_stay_list',
      });
      Fluttertoast.showToast(msg: '숙박기록이 삭제되었습니다.');
    } catch (e) {
      debugPrint('메리어트 숙박기록 삭제 오류: $e');
      Fluttertoast.showToast(msg: '삭제 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('전체 숙박기록'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.4,
        actions: [
          IconButton(
            tooltip: '기록 추가',
            icon: const Icon(Icons.add),
            onPressed: () => _openMarriottStayForm(),
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const _StayListSignedOut()
            : StreamBuilder<List<MarriottStayRecord>>(
                stream: MarriottStayService.watchUserStays(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _StayListLoading();
                  }

                  if (snapshot.hasError) {
                    return _StayListStatePanel(
                      icon: Icons.error_outline,
                      title: '숙박기록을 불러오지 못했습니다.',
                      subtitle: snapshot.error.toString(),
                    );
                  }

                  final records = snapshot.data ?? const <MarriottStayRecord>[];
                  if (records.isEmpty) {
                    return _StayListStatePanel(
                      icon: Icons.hotel_class_outlined,
                      title: '아직 저장된 숙박기록이 없습니다.',
                      subtitle: '체크인, 지출, 포인트, 예약번호를 한 번에 모아볼 수 있어요.',
                      action: TextButton.icon(
                        onPressed: () => _openMarriottStayForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('첫 숙박 기록 추가'),
                      ),
                    );
                  }

                  return _StayListBody(
                    records: records,
                    onAdd: () => _openMarriottStayForm(),
                    onEdit: _openMarriottStayForm,
                    onDelete: _confirmDeleteMarriottStay,
                  );
                },
              ),
      ),
    );
  }
}

class _StayListBody extends StatelessWidget {
  final List<MarriottStayRecord> records;
  final VoidCallback onAdd;
  final ValueChanged<MarriottStayRecord> onEdit;
  final Future<void> Function(MarriottStayRecord record) onDelete;

  const _StayListBody({
    required this.records,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
      itemCount: records.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _StayListSummary(records: records, onAdd: onAdd);
        }
        return _StayListCard(
          record: records[index - 1],
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _StayListSummary extends StatelessWidget {
  final List<MarriottStayRecord> records;
  final VoidCallback onAdd;

  const _StayListSummary({
    required this.records,
    required this.onAdd,
  });

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${records.length}건 · $totalNights박',
                  style: McTextStyles.cardTitle,
                ),
                const SizedBox(height: 5),
                Text(
                  '총 지출 ${won.format(totalAmount)}원 · 획득 ${points.format(totalPoints)}P',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McTextStyles.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _StayListCard extends StatelessWidget {
  final MarriottStayRecord record;
  final ValueChanged<MarriottStayRecord> onEdit;
  final Future<void> Function(MarriottStayRecord record) onDelete;

  const _StayListCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final points = NumberFormat('#,###');
    final amountText = record.totalAmount <= 0
        ? record.stayType.label
        : '${won.format(record.totalAmount)}원';

    final pills = <Widget>[
      _StayInfoPill(
        text: _dateRange(record.checkIn, record.checkOut),
        icon: Icons.event_outlined,
      ),
      _StayInfoPill(
        text: '${points.format(record.earnedPoints)}P',
        icon: Icons.stars_outlined,
      ),
      _StayInfoPill(
        text: '회수율 ${record.returnRate.toStringAsFixed(1)}%',
        icon: Icons.percent,
      ),
      _StayInfoPill(
        text: record.eliteTierName,
        icon: Icons.workspace_premium,
      ),
    ];
    if (record.bookingNumber.isNotEmpty) {
      pills.add(
        _StayInfoPill(
          text: '예약 ${record.bookingNumber}',
          icon: Icons.confirmation_number_outlined,
        ),
      );
    }
    if (record.memo.isNotEmpty) {
      pills.add(_StayInfoPill(text: record.memo, icon: Icons.note_outlined));
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onEdit(record),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StayTypeLabel(type: record.stayType),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${record.nights}박 · ${record.hotelName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McTextStyles.bodyStrong.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('yyyy-MM-dd').format(record.checkIn),
                          style: McTextStyles.micro,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountText,
                    style: TextStyle(
                      color: record.totalAmount <= 0
                          ? McColors.accent
                          : Colors.red,
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pills,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateRange(DateTime checkIn, DateTime checkOut) {
    final start = DateFormat('MM.dd').format(checkIn);
    final end = DateFormat('MM.dd').format(checkOut);
    return '$start - $end';
  }
}

class _StayTypeLabel extends StatelessWidget {
  final MarriottStayType type;

  const _StayTypeLabel({required this.type});

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

class _StayInfoPill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _StayInfoPill({
    required this.text,
    required this.icon,
  });

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
          Icon(icon, size: 13, color: McColors.muted),
          const SizedBox(width: 6),
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

class _StayListLoading extends StatelessWidget {
  const _StayListLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _StayListSignedOut extends StatelessWidget {
  const _StayListSignedOut();

  @override
  Widget build(BuildContext context) {
    return const _StayListStatePanel(
      icon: Icons.lock_outline,
      title: '로그인 후 숙박기록을 볼 수 있습니다.',
      subtitle: '기록은 내 계정에만 저장됩니다.',
    );
  }
}

class _StayListStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StayListStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            children: [
              Icon(icon, color: McColors.mutedLight, size: 38),
              const SizedBox(height: 10),
              Text(
                title,
                style: McTextStyles.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: McTextStyles.meta,
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
