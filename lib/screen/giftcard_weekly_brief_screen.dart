import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../services/analytics_service.dart';
import 'giftcard_rates_screen.dart';

/// P4 주간 상품권 시세 브리핑 랜딩.
/// Cloud Functions(giftcardWeeklyBriefPush)가 매주 금요일 집계해 둔
/// giftcardWeeklyBriefs/{weekKey} 문서 1개를 읽어 렌더링한다.
class GiftcardWeeklyBriefScreen extends StatefulWidget {
  /// 푸시 payload로 전달된 주차 키(예: "2026-W27"). 없으면 최신 문서.
  final String? weekKey;

  const GiftcardWeeklyBriefScreen({super.key, this.weekKey});

  @override
  State<GiftcardWeeklyBriefScreen> createState() =>
      _GiftcardWeeklyBriefScreenState();
}

class _GiftcardWeeklyBriefScreenState extends State<GiftcardWeeklyBriefScreen> {
  final NumberFormat _won = NumberFormat('#,###');

  Map<String, dynamic>? _brief;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(
      'giftcard_weekly_brief',
      screenClass: 'GiftcardWeeklyBriefScreen',
      source: widget.weekKey != null ? 'push_deep_link' : 'screen_init',
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final col =
          FirebaseFirestore.instance.collection('giftcardWeeklyBriefs');
      DocumentSnapshot<Map<String, dynamic>>? doc;

      final weekKey = widget.weekKey?.trim();
      if (weekKey != null && weekKey.isNotEmpty) {
        final byKey = await col.doc(weekKey).get();
        if (byKey.exists) doc = byKey;
      }
      if (doc == null) {
        final latest = await col
            .orderBy('generatedAt', descending: true)
            .limit(1)
            .get();
        if (latest.docs.isNotEmpty) doc = latest.docs.first;
      }

      if (!mounted) return;
      setState(() {
        _brief = doc?.data();
        _loading = false;
      });
    } catch (e) {
      debugPrint('주간 브리핑 로드 오류: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items {
    final raw = _brief?['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _fmtPrice(num? v) => v == null ? '-' : '${_won.format(v)}원';

  String _formatGeneratedAt() {
    final raw = _brief?['generatedAt'];
    if (raw is Timestamp) {
      return DateFormat('yyyy.MM.dd HH:mm').format(raw.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 시세 브리핑', style: McTextStyles.appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
        shadowColor: McColors.line,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: McColors.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(GiftcardColors.accent),
              ),
            )
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    '아직 준비된 브리핑이 없습니다.\n매주 금요일 오전에 갱신돼요.',
                    textAlign: TextAlign.center,
                    style: McTextStyles.body,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    for (final item in _items) ...[
                      _buildItemCard(item),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final weekKey = (_brief?['weekKey'] as String?) ?? '';
    final generatedAt = _formatGeneratedAt();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GiftcardColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GiftcardColors.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: GiftcardColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                weekKey.isEmpty ? '이번 주 상품권 시세' : '$weekKey 상품권 시세',
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '10만원권 최고 매입가 기준 주간 변동입니다.'
            '${generatedAt.isEmpty ? '' : ' · $generatedAt 집계'}',
            style: McTextStyles.meta,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final giftcardId = (item['giftcardId'] as String?) ?? '';
    final name = (item['name'] as String?) ?? giftcardId;
    final price = item['price'] as num?;
    final changePct = (item['changePct'] as num?)?.toDouble();
    final branch = (item['bestSellBranchName'] as String?) ?? '';

    final bool hasChange = changePct != null;
    final bool rising = (changePct ?? 0) > 0;
    final bool flat = hasChange && changePct == 0;
    final Color changeColor = !hasChange || flat
        ? McColors.mutedLight
        : rising
            ? const Color(0xFF15803D)
            : const Color(0xFFB91C1C);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: giftcardId.isEmpty
          ? null
          : () {
              AnalyticsService.instance
                  .logAction('giftcard_rate_open', params: {
                'screen': 'giftcard_weekly_brief',
                'giftcard_id': giftcardId,
                'source': 'weekly_brief_item',
              });
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GiftcardBrandRatesPage(
                    giftcardId: giftcardId,
                    giftcardName: name,
                    initialTabIndex: 2,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: McColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '매입가 ${_fmtPrice(price)}'
                    '${branch.isEmpty ? '' : ' · $branch'}',
                    style: McTextStyles.meta,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  !hasChange
                      ? '-'
                      : '${rising ? '+' : ''}'
                          '${changePct!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('주간 변동', style: McTextStyles.meta),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
