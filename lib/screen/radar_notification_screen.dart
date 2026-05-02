import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../models/radar_item_model.dart';
import '../services/radar_service.dart';
import 'login_screen.dart';

class RadarNotificationScreen extends StatefulWidget {
  const RadarNotificationScreen({super.key});

  @override
  State<RadarNotificationScreen> createState() =>
      _RadarNotificationScreenState();
}

class _RadarNotificationScreenState extends State<RadarNotificationScreen> {
  static const _tabs = ['알림 조건', '매칭 내역'];
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFEFF1F5),
      body: SafeArea(
        child: Column(
          children: [
            _RadarNotificationHeader(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RadarSegmentedTabs(
                tabs: _tabs,
                selectedIndex: _selectedTabIndex,
                onChanged: (index) => setState(() => _selectedTabIndex = index),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: user == null
                  ? _RadarLoginEmptyState(
                      onLogin: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    )
                  : _selectedTabIndex == 0
                      ? _RadarSubscriptionTab(uid: user.uid)
                      : _RadarMatchHistoryTab(uid: user.uid),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarNotificationHeader extends StatelessWidget {
  const _RadarNotificationHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1D27),
            ),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              '레이더 알림',
              style: TextStyle(
                color: Color(0xFF1A1D27),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Image.asset(
            'asset/img/app_icon.png',
            width: 34,
            height: 34,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.radar_rounded,
              color: Color(0xFF1A1D27),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarSegmentedTabs extends StatelessWidget {
  const _RadarSegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1A1D27)
                        : const Color(0xFF727A89),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RadarSubscriptionTab extends StatelessWidget {
  const _RadarSubscriptionTab({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RadarService.watchRadarSubscriptions(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RadarMessageState(
            title: '알림 조건을 불러오지 못했습니다.',
            subtitle: snapshot.error.toString(),
            icon: Icons.error_outline_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const _RadarLoadingState();
        }

        final entries = snapshot.data!.docs
            .map(_RadarSubscriptionEntry.fromDoc)
            .toList(growable: false);
        if (entries.isEmpty) {
          return const _RadarMessageState(
            title: '저장된 레이더 알림이 없습니다.',
            subtitle: '가이드 탭의 마일캐치 레이더 카드에서 알림을 눌러 조건을 저장하세요.',
            icon: Icons.notifications_none_rounded,
          );
        }

        final activeCount = entries.where((entry) => entry.isActiveNow).length;
        final mutedCount = entries.where((entry) => !entry.pushEnabled).length;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: entries.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _RadarSubscriptionSummary(
                totalCount: entries.length,
                activeCount: activeCount,
                mutedCount: mutedCount,
              );
            }
            final entry = entries[index - 1];
            return _RadarSubscriptionCard(entry: entry);
          },
        );
      },
    );
  }
}

class _RadarMatchHistoryTab extends StatelessWidget {
  const _RadarMatchHistoryTab({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RadarService.watchRadarNotifications(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RadarMessageState(
            title: '매칭 내역을 불러오지 못했습니다.',
            subtitle: snapshot.error.toString(),
            icon: Icons.error_outline_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const _RadarLoadingState();
        }

        final entries = snapshot.data!.docs
            .map(_RadarMatchEntry.fromDoc)
            .toList(growable: false);
        if (entries.isEmpty) {
          return const _RadarMessageState(
            title: '아직 레이더 매칭 내역이 없습니다.',
            subtitle: '저장한 조건에 새 좌석, 특가, 상품권 변동이 잡히면 여기에 표시됩니다.',
            icon: Icons.radar_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _RadarMatchCard(entry: entries[index]);
          },
        );
      },
    );
  }
}

class _RadarSubscriptionSummary extends StatelessWidget {
  const _RadarSubscriptionSummary({
    required this.totalCount,
    required this.activeCount,
    required this.mutedCount,
  });

  final int totalCount;
  final int activeCount;
  final int mutedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '레이더가 보고 있는 조건',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전체 $totalCount개 · 활성 $activeCount개 · 꺼짐 $mutedCount개',
                  style: const TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontWeight: FontWeight.w700,
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

class _RadarSubscriptionCard extends StatefulWidget {
  const _RadarSubscriptionCard({required this.entry});

  final _RadarSubscriptionEntry entry;

  @override
  State<_RadarSubscriptionCard> createState() => _RadarSubscriptionCardState();
}

class _RadarSubscriptionCardState extends State<_RadarSubscriptionCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accent = _radarAccent(entry.type);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isExpired ? const Color(0xFFFECACA) : Colors.transparent,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_radarIcon(entry.type), color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _RadarStatusPill(
                          text: entry.statusLabel,
                          color: entry.statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.typeLabel,
                          style: const TextStyle(
                            color: Color(0xFF727A89),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1D27),
                        fontSize: 16,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5F6877),
                          fontSize: 13,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: entry.pushEnabled && !entry.isExpired,
                activeThumbColor: const Color(0xFF111827),
                onChanged: _busy ? null : _togglePush,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (entry.route.isNotEmpty)
                _RadarInfoChip(icon: Icons.route_outlined, text: entry.route),
              if (entry.dateRange.isNotEmpty)
                _RadarInfoChip(
                  icon: Icons.date_range_outlined,
                  text: entry.dateRange,
                ),
              _RadarInfoChip(
                icon: Icons.schedule_rounded,
                text: entry.expiresAtLabel,
              ),
              if (entry.source.isNotEmpty)
                _RadarInfoChip(icon: Icons.public_rounded, text: entry.source),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _extend,
                  icon: const Icon(Icons.update_rounded, size: 18),
                  label: const Text('30일 연장'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFD7DCE5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _busy ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFB42318),
                tooltip: '삭제',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _busy = true);
    try {
      await RadarService.updateRadarSubscriptionPush(
        subscriptionId: widget.entry.id,
        pushEnabled: value,
      );
      Fluttertoast.showToast(msg: value ? '레이더 알림을 켰습니다.' : '레이더 알림을 껐습니다.');
    } catch (_) {
      Fluttertoast.showToast(msg: '알림 상태 변경에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend() async {
    setState(() => _busy = true);
    try {
      await RadarService.extendRadarSubscription(
          subscriptionId: widget.entry.id);
      Fluttertoast.showToast(msg: '레이더 알림을 30일 연장했습니다.');
    } catch (_) {
      Fluttertoast.showToast(msg: '알림 연장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '레이더 알림 삭제',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text('${widget.entry.title}\n\n이 조건을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318)),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await RadarService.deleteRadarSubscription(widget.entry.id);
      Fluttertoast.showToast(msg: '레이더 알림을 삭제했습니다.');
    } catch (_) {
      Fluttertoast.showToast(msg: '알림 삭제에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RadarMatchCard extends StatelessWidget {
  const _RadarMatchCard({required this.entry});

  final _RadarMatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = _radarAccent(entry.type);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => RadarService.markRadarNotificationRead(entry.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: entry.isRead ? Colors.white : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_radarIcon(entry.type), color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1D27),
                      fontSize: 16,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5F6877),
                      fontSize: 13,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.createdAtLabel,
                    style: const TextStyle(
                      color: Color(0xFF8A93A3),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!entry.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadarStatusPill extends StatelessWidget {
  const _RadarStatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RadarInfoChip extends StatelessWidget {
  const _RadarInfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5F6877)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarLoadingState extends StatelessWidget {
  const _RadarLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'asset/img/app_icon.png',
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.radar_rounded,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: Color(0xFF111827),
            strokeWidth: 2.4,
          ),
        ],
      ),
    );
  }
}

class _RadarMessageState extends StatelessWidget {
  const _RadarMessageState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        children: [
          const Spacer(flex: 7),
          Image.asset(
            'asset/img/app_icon.png',
            width: 150,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(icon, size: 112, color: const Color(0xFFB1B6C1)),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1B1E27),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF717986),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(flex: 9),
        ],
      ),
    );
  }
}

class _RadarLoginEmptyState extends StatelessWidget {
  const _RadarLoginEmptyState({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        children: [
          const Spacer(flex: 7),
          Image.asset(
            'asset/img/app_icon.png',
            width: 150,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.lock_outline_rounded,
              size: 112,
              color: Color(0xFFB1B6C1),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '로그인 후 레이더 알림을 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1B1E27),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '저장한 좌석, 특가, 상품권 조건을 한 곳에서 관리합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF717986),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('로그인'),
          ),
          const Spacer(flex: 9),
        ],
      ),
    );
  }
}

class _RadarSubscriptionEntry {
  const _RadarSubscriptionEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.route,
    required this.dateRange,
    required this.source,
    required this.price,
    required this.miles,
    required this.pushEnabled,
    required this.isActive,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String route;
  final String dateRange;
  final String source;
  final int? price;
  final int? miles;
  final bool pushEnabled;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isActiveNow => isActive && pushEnabled && !isExpired;

  String get typeLabel => _radarTypeLabel(type);

  String get statusLabel {
    if (isExpired) return '만료';
    if (!pushEnabled) return '꺼짐';
    return '활성';
  }

  Color get statusColor {
    if (isExpired) return const Color(0xFFB42318);
    if (!pushEnabled) return const Color(0xFF6B7280);
    return const Color(0xFF047857);
  }

  String get description {
    final parts = <String>[
      if (price != null && price! > 0)
        '${NumberFormat('#,###').format(price)}원',
      if (miles != null && miles! > 0)
        '${NumberFormat('#,###').format(miles)}마일',
      if (source.isNotEmpty) source,
    ];
    return parts.join(' · ');
  }

  String get expiresAtLabel {
    if (expiresAt == null) return '만료일 없음';
    final label = DateFormat('MM.dd HH:mm').format(expiresAt!);
    if (isExpired) return '$label 만료';
    final days = expiresAt!.difference(DateTime.now()).inDays;
    return days <= 0 ? '오늘까지' : '$days일 남음';
  }

  static _RadarSubscriptionEntry fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final conditions = Map<String, dynamic>.from(
      data['conditions'] as Map? ?? const {},
    );
    return _RadarSubscriptionEntry(
      id: doc.id,
      type: (data['type'] as String? ?? '').trim(),
      title: (conditions['title'] as String? ?? '레이더 알림').trim(),
      route: (conditions['route'] as String? ?? '').trim(),
      dateRange: (conditions['dateRange'] as String? ?? '').trim(),
      source: (conditions['source'] as String? ?? '').trim(),
      price: (conditions['price'] as num?)?.toInt(),
      miles: (conditions['miles'] as num?)?.toInt(),
      pushEnabled: (data['pushEnabled'] as bool?) ?? true,
      isActive: (data['isActive'] as bool?) ?? true,
      expiresAt: _dateTimeOf(data['expiresAt']),
      createdAt: _dateTimeOf(data['createdAt']),
    );
  }
}

class _RadarMatchEntry {
  const _RadarMatchEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  String get createdAtLabel {
    final value = createdAt;
    if (value == null) return '방금 전';
    return DateFormat('yyyy.MM.dd HH:mm').format(value);
  }

  static _RadarMatchEntry fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _RadarMatchEntry(
      id: doc.id,
      type: (data['type'] as String? ??
              data['itemType'] as String? ??
              RadarItemType.benefitNews)
          .trim(),
      title: (data['title'] as String? ?? '레이더 매칭').trim(),
      body: (data['body'] as String? ??
              data['message'] as String? ??
              '조건에 맞는 새 항목을 찾았습니다.')
          .trim(),
      isRead: (data['isRead'] as bool?) ?? false,
      createdAt: _dateTimeOf(data['createdAt']),
    );
  }
}

DateTime? _dateTimeOf(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _radarTypeLabel(String type) {
  switch (type) {
    case RadarItemType.mileageSeat:
      return '마일리지 좌석';
    case RadarItemType.cancelAlert:
      return '취소표';
    case RadarItemType.flightDeal:
      return '항공 특가';
    case RadarItemType.giftcard:
      return '상품권';
    case RadarItemType.valueCalculator:
      return '계산기';
    case RadarItemType.benefitNews:
    default:
      return '뉴스/혜택';
  }
}

IconData _radarIcon(String type) {
  switch (type) {
    case RadarItemType.mileageSeat:
      return Icons.airline_seat_recline_extra_rounded;
    case RadarItemType.cancelAlert:
      return Icons.notifications_active_outlined;
    case RadarItemType.flightDeal:
      return Icons.flight_takeoff_rounded;
    case RadarItemType.giftcard:
      return Icons.card_giftcard_rounded;
    case RadarItemType.valueCalculator:
      return Icons.calculate_outlined;
    case RadarItemType.benefitNews:
    default:
      return Icons.newspaper_rounded;
  }
}

Color _radarAccent(String type) {
  switch (type) {
    case RadarItemType.flightDeal:
      return const Color(0xFF2563EB);
    case RadarItemType.giftcard:
      return const Color(0xFFB45309);
    case RadarItemType.cancelAlert:
    case RadarItemType.mileageSeat:
      return const Color(0xFFDC2626);
    case RadarItemType.valueCalculator:
      return const Color(0xFF047857);
    case RadarItemType.benefitNews:
    default:
      return const Color(0xFF475569);
  }
}
