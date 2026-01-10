import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mileage_thief/model/giftcard_info_data.dart';
import 'package:mileage_thief/model/giftcard_period.dart';
import 'package:mileage_thief/services/giftcard_service.dart';
import 'package:mileage_thief/widgets/info_pill.dart';

import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';

enum GiftcardKpiType {
  totalBuy,
  totalSell,
  totalProfit,
  totalMiles,
  avgCostPerMile,
  openQty,
}

class GiftcardKpiDetailScreen extends StatefulWidget {
  final GiftcardKpiType kpiType;
  final DashboardPeriodType periodType;
  final DateTime selectedMonth;
  final int selectedYear;

  const GiftcardKpiDetailScreen({
    super.key,
    required this.kpiType,
    required this.periodType,
    required this.selectedMonth,
    required this.selectedYear,
  });

  @override
  State<GiftcardKpiDetailScreen> createState() => _GiftcardKpiDetailScreenState();
}

class _GiftcardKpiDetailScreenState extends State<GiftcardKpiDetailScreen> {
  bool _loading = true;
  GiftcardInfoData? _data;

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _fmtWon(int v) => '${v.toString().replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (m) => ',')}원';

  String _fmtDiscount(dynamic v) {
    final double d = _asDouble(v);
    final bool isInt = d == d.roundToDouble();
    return '${isInt ? d.toStringAsFixed(0) : d.toStringAsFixed(2)}%';
  }

  DateTime _tsOf(Map<String, dynamic> x, {required bool sale}) {
    final ts = sale ? x['sellDate'] : x['buyDate'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _kpiTitle() {
    switch (widget.kpiType) {
      case GiftcardKpiType.totalBuy:
        return '총 매입금액';
      case GiftcardKpiType.totalSell:
        return '총 판매금액';
      case GiftcardKpiType.totalProfit:
        return '총 손익';
      case GiftcardKpiType.totalMiles:
        return '누적 마일';
      case GiftcardKpiType.avgCostPerMile:
        return '평균마일원가(원/마일)';
      case GiftcardKpiType.openQty:
        return '미교환 수량';
    }
  }

  bool get _isBuyList {
    switch (widget.kpiType) {
      case GiftcardKpiType.totalBuy:
      case GiftcardKpiType.openQty:
        return true;
      default:
        return false;
    }
  }

  String _periodDetailText() {
    final range = getGiftcardPeriodRange(
      periodType: widget.periodType,
      selectedMonth: widget.selectedMonth,
      selectedYear: widget.selectedYear,
    );
    if (range.start == null || range.end == null) {
      return '전체 기간 (날짜 필터 없음)';
    }
    final start = giftcardYmd(range.start!);
    // end는 exclusive라서 사용자 표시용으로는 -1일로 안내
    final endInclusive = giftcardYmd(range.end!.subtract(const Duration(days: 1)));
    return '$start ~ $endInclusive';
  }

  String _kpiDescription() {
    final period = _periodDetailText();

    // 공통: 이 화면은 '대시보드 기간'과 동일 기준을 그대로 따라간다.
    final common = StringBuffer()
      ..writeln('선택한 기간: $period')
      ..writeln('')
      ..writeln('이 화면에 포함되는 내역 기준')
      ..writeln('- 구매 내역: “구매일”이 선택한 기간 안에 들어가는 건만 포함합니다.')
      ..writeln('- 판매 내역: 아래 2가지를 모두 포함합니다.')
      ..writeln('  1) 선택한 기간에 “구매한 건”이 나중에 판매된 내역')
      ..writeln('  2) 선택한 기간에 “판매일”이 들어가는 판매 내역')
      ..writeln('  (같은 판매가 중복으로 잡히면 1번만 포함됩니다.)');

    switch (widget.kpiType) {
      case GiftcardKpiType.totalBuy:
        common
          ..writeln('')
          ..writeln('총 매입금액(구매 총액)은 이렇게 계산돼요')
          ..writeln('- 대상: 위 기준의 “구매 내역”')
          ..writeln('- 계산: 각 구매의 (수량 × 매입가)을 모두 더한 값');
        return common.toString();
      case GiftcardKpiType.totalSell:
        common
          ..writeln('')
          ..writeln('총 판매금액(판매 총액)은 이렇게 계산돼요')
          ..writeln('- 대상: 위 기준의 “판매 내역”')
          ..writeln('- 계산: 각 판매의 “판매총액”을 모두 더한 값');
        return common.toString();
      case GiftcardKpiType.totalProfit:
        common
          ..writeln('')
          ..writeln('총 손익은 이렇게 계산돼요')
          ..writeln('- 대상: 위 기준의 “판매 내역”')
          ..writeln('- 계산: 각 판매의 “손익”을 모두 더한 값');
        return common.toString();
      case GiftcardKpiType.totalMiles:
        common
          ..writeln('')
          ..writeln('누적 마일은 이렇게 계산돼요')
          ..writeln('- 대상: 위 기준의 “판매 내역”')
          ..writeln('- 계산: 각 판매에서 적립된 “마일”을 모두 더한 값');
        return common.toString();
      case GiftcardKpiType.avgCostPerMile:
        common
          ..writeln('')
          ..writeln('평균 마일 원가(원/마일)는 이렇게 계산돼요')
          ..writeln('- 의미: “마일 1을 얻기 위해 실제로 얼마를 썼는지(원)”를 평균으로 보여줘요.')
          ..writeln('- 계산: 총 손익과 누적 마일을 이용해 계산합니다.')
          ..writeln('- 참고: 누적 마일이 0이면 계산이 불가해서 0으로 표시돼요.');
        return common.toString();
      case GiftcardKpiType.openQty:
        common
          ..writeln('')
          ..writeln('미교환 수량은 이렇게 계산돼요')
          ..writeln('- 대상: 위 기준의 “구매 내역” 중 아직 교환/판매하지 않은 건')
          ..writeln('- 계산: 해당 구매들의 “수량(장)”을 모두 더한 값');
        return common.toString();
    }
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x1174512D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFF74512D), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _kpiDescription(),
              style: const TextStyle(color: Colors.black87, height: 1.35, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = null;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await GiftcardService.loadInfoData(
        uid: uid,
        periodType: widget.periodType,
        selectedMonth: widget.selectedMonth,
        selectedYear: widget.selectedYear,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _loading = false;
      });
    }
  }

  Future<void> _openFabActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: const Text('상품권 구매 등록'),
                onTap: () => Navigator.pop(context, 'buy'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money_outlined),
                title: const Text('상품권 판매 등록'),
                onTap: () => Navigator.pop(context, 'sell'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    if (action == 'buy') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftBuyScreen()));
      await _load();
    } else if (action == 'sell') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftSellScreen()));
      await _load();
    }
  }

  Widget _buildLotTile(Map<String, dynamic> m) {
    final ts = m['buyDate'];
    final date = ts is Timestamp ? giftcardYmd(ts.toDate()) : '';
    final giftId = (m['giftcardId'] as String?) ?? '';
    final giftName = (_data?.giftcardNames[giftId] ?? giftId).trim();
    final qty = _asInt(m['qty']);
    final buyUnit = _asInt(m['buyUnit']);
    final total = qty * buyUnit;
    final payType = (m['payType'] as String?) ?? '';
    final cardId = (m['cardId'] as String?) ?? '';
    final status = (m['status'] as String?) ?? 'open';
    final memo = (m['memo'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InfoPill(
                text: status == 'open' ? '미교환' : '판매완료',
                icon: status == 'open' ? Icons.inventory_2_outlined : Icons.check_circle_outline,
                filled: true,
                fillColor: status == 'open' ? const Color(0xFF74512D) : Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${giftName.isEmpty ? giftId : giftName} $qty장',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(icon: Icons.payments_outlined, text: '매입가 ${_fmtWon(buyUnit)}'),
              InfoPill(icon: Icons.calculate_outlined, text: '매입총액 ${_fmtWon(total)}'),
              if (payType.isNotEmpty) InfoPill(icon: Icons.account_balance_wallet_outlined, text: payType),
              if (cardId.isNotEmpty) InfoPill(icon: Icons.credit_card_outlined, text: '카드 $cardId'),
              if (memo.trim().isNotEmpty) InfoPill(icon: Icons.note_outlined, text: memo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> m) {
    final ts = m['sellDate'];
    final date = ts is Timestamp ? giftcardYmd(ts.toDate()) : '';
    final qty = _asInt(m['qty']);
    final sellUnit = _asInt(m['sellUnit']);
    final sellTotal = _asInt(m['sellTotal']);
    final profit = _asInt(m['profit']);
    final miles = _asInt(m['miles']);
    final costPerMile = (_asDouble(m['costPerMile']) == 0) ? null : _asDouble(m['costPerMile']);
    final hasDiscount = m.containsKey('discount') && m['discount'] != null;

    // lotId를 통해 상품권 이름/지점 이름
    String giftName = '';
    final lotId = m['lotId'] as String?;
    if (lotId != null && _data != null) {
      final lot = _data!.lots.firstWhere((e) => e['id'] == lotId, orElse: () => <String, dynamic>{});
      final giftId = (lot['giftcardId'] as String?) ?? '';
      giftName = (_data!.giftcardNames[giftId] ?? giftId).trim();
    }

    final branchId = (m['branchId'] as String?) ?? '';
    final branchName = (_data?.branchNames[branchId] ?? branchId).trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const InfoPill(text: '판매', icon: Icons.attach_money_outlined, filled: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${giftName.isEmpty ? '' : '$giftName '}$qty장',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(icon: Icons.sell_outlined, text: '판매가 ${_fmtWon(sellUnit)}'),
              if (sellTotal > 0) InfoPill(icon: Icons.receipt_long_outlined, text: '판매총액 ${_fmtWon(sellTotal)}'),
              if (hasDiscount) InfoPill(icon: Icons.percent, text: '할인율 ${_fmtDiscount(m['discount'])}'),
              InfoPill(icon: Icons.trending_up_outlined, text: '손익 ${_fmtWon(profit)}'),
              if (miles > 0) InfoPill(icon: Icons.stars_outlined, text: '마일 $miles'),
              if (costPerMile != null) InfoPill(icon: Icons.percent, text: '원/마일 ${costPerMile.toStringAsFixed(2)}'),
              if (branchName.isNotEmpty) InfoPill(icon: Icons.store_outlined, text: branchName),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final periodText = giftcardPeriodTitleText(
      periodType: widget.periodType,
      selectedMonth: widget.selectedMonth,
      selectedYear: widget.selectedYear,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_kpiTitle()} 내역', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(periodText, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF74512D),
        onPressed: _openFabActions,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF74512D),
              backgroundColor: Colors.white,
              child: Builder(
                builder: (context) {
                  final data = _data;
                  if (data == null) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      children: [
                        _buildDescriptionCard(),
                        const SizedBox(height: 12),
                        const SizedBox(height: 80),
                        const Center(child: Text('데이터를 불러오지 못했습니다.', style: TextStyle(color: Colors.black54))),
                      ],
                    );
                  }

                  if (_isBuyList) {
                    final lots = List<Map<String, dynamic>>.from(data.lots);
                    if (widget.kpiType == GiftcardKpiType.openQty) {
                      lots.removeWhere((e) => ((e['status'] as String?) ?? 'open') != 'open');
                    }
                    lots.sort((a, b) => _tsOf(b, sale: false).compareTo(_tsOf(a, sale: false)));

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: lots.length + 1,
                      separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) return _buildDescriptionCard();
                        return _buildLotTile(lots[i - 1]);
                      },
                    );
                  }

                  final sales = List<Map<String, dynamic>>.from(data.sales);
                  sales.sort((a, b) => _tsOf(b, sale: true).compareTo(_tsOf(a, sale: true)));
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: sales.length + 1,
                    separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) return _buildDescriptionCard();
                      return _buildSaleTile(sales[i - 1]);
                    },
                  );
                },
              ),
            ),
    );
  }
}


