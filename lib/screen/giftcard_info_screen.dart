import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mileage_thief/services/user_service.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';

class _KpiValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _KpiValue({required this.label, required this.value, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 78),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0x1174512D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF74512D), size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool filled;
  final Color? fillColor;
  const _InfoPill({required this.text, this.icon, this.filled = false, this.fillColor});
  @override
  Widget build(BuildContext context) {
    final Color effectiveFill = fillColor ?? (filled ? const Color(0xFF74512D) : const Color(0x1174512D));
    final Color textColor = (fillColor != null || filled) ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GiftBanner extends StatefulWidget {
  final String adUnitId;
  const _GiftBanner({required this.adUnitId});
  @override
  State<_GiftBanner> createState() => _GiftBannerState();
}

class _GiftBannerState extends State<_GiftBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: _ad!.size.width.toDouble(),
          height: _ad!.size.height.toDouble(),
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}

class GiftcardInfoScreen extends StatefulWidget {
  final ValueChanged<bool>? onScrollChanged;
  const GiftcardInfoScreen({super.key, this.onScrollChanged});
  @override
  State<GiftcardInfoScreen> createState() => _GiftcardInfoScreenState();
}

class _GiftcardInfoScreenState extends State<GiftcardInfoScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final TabController _buySellTabController;

  // 데이터
  bool _loading = true;
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _sales = [];
  Map<String, String> _giftcardNames = {}; // giftcardId -> name
  Map<String, String> _branchNames = {}; // branchId -> name
  final DateFormat _yMd = DateFormat('yyyy-MM-dd');
  final NumberFormat _won = NumberFormat('#,###');

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _pieByAmount = true; // true: 금액, false: 수량
  Map<String, Map<String, dynamic>> _cards = {}; // cardId -> {credit, check, name}
  final TextEditingController _marketPriceController = TextEditingController();
  final TextEditingController _targetCostPerMileController = TextEditingController();
  
  // 필터 관련
  Set<String> _selectedGiftcardIdsForBuy = {}; // 구매 탭 선택된 상품권 ID 목록 (빈 Set이면 전체)
  Set<String> _selectedGiftcardIdsForSell = {}; // 판매 탭 선택된 상품권 ID 목록 (빈 Set이면 전체)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _buySellTabController = TabController(length: 2, vsync: this);
    _buySellTabController.addListener(() {
      if (!_buySellTabController.indexIsChanging) {
        setState(() {}); // 탭 변경 완료 시 필터 버튼 업데이트
      }
    });
    _load();
  }
  
  // 외부에서 호출할 수 있는 새로고침 메서드
  void refresh() {
    _load();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _buySellTabController.dispose();
    _marketPriceController.dispose();
    _targetCostPerMileController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final lotsSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('lots').get();
      final salesSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('sales').get();
      final cardsSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('cards').get();
      final giftsSnap = await FirebaseFirestore.instance.collection('giftcards').get();
      final branchesSnap = await FirebaseFirestore.instance.collection('branches').get();
      setState(() {
        _lots = lotsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _sales = salesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _cards = {
          for (final d in cardsSnap.docs)
            d.id: {
              'name': d.data()['name'],
              'credit': ((d.data()['creditPerMileKRW'] as num?)?.toInt()) ?? 0,
              'check': ((d.data()['checkPerMileKRW'] as num?)?.toInt()) ?? 0,
            }
        };
        _giftcardNames = {
          for (final d in giftsSnap.docs)
            d.id: (d.data()['name'] as String?) ?? d.id
        };
        _branchNames = {
          for (final d in branchesSnap.docs)
            d.id: (d.data()['name'] as String?) ?? d.id
        };
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  // 집계 헬퍼
  int _sumBuy() => _lots.fold(0, (p, e) => p + ((e['buyUnit'] ?? 0) as int) * ((e['qty'] ?? 0) as int));
  int _sumSell() => _sales.fold(0, (p, e) => p + ((e['sellTotal'] ?? 0) as int));
  int _sumProfit() => _sales.fold(0, (p, e) => p + ((e['profit'] ?? 0) as int));
  int _sumMiles() => _sales.fold(0, (p, e) => p + ((e['miles'] ?? 0) as int));
  String _fmtWon(num v) => '${_won.format(v)}원';

  // 브랜드별 분포(금액 기준)
  Map<String, int> _pieByBrandAmount() {
    final Map<String, int> m = {};
    for (final lot in _lots) {
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      m[brand] = (m[brand] ?? 0) + ((lot['buyUnit'] ?? 0) as int) * ((lot['qty'] ?? 0) as int);
    }
    return m;
  }

  Map<String, int> _pieByBrandCount() {
    final Map<String, int> m = {};
    for (final lot in _lots) {
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      m[brand] = (m[brand] ?? 0) + ((lot['qty'] ?? 0) as int);
    }
    return m;
  }

  // 월별 손익/마일
  Map<String, Map<String, int>> _monthlyStats() {
    final Map<String, Map<String, int>> m = {};
    for (final s in _sales) {
      final ts = s['sellDate'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final profit = (s['profit'] ?? 0) as int;
        final miles = (s['miles'] ?? 0) as int;
        m.putIfAbsent(key, () => {'profit': 0, 'miles': 0});
        m[key]!['profit'] = (m[key]!['profit'] ?? 0) + profit;
        m[key]!['miles'] = (m[key]!['miles'] ?? 0) + miles;
      }
    }
    return m;
  }

  // 할인율 히스토그램(2.0~3.5, 0.1단위)
  Map<double, int> _discountBuckets() {
    final Map<double, int> m = { for (double v = 2.0; v <= 3.5; v = double.parse((v + 0.1).toStringAsFixed(1))) v: 0 };
    for (final s in _sales) {
      final d = (s['discount'] as num?)?.toDouble();
      if (d == null) continue;
      final key = (d * 10).round() / 10.0; // 0.1단위 반올림
      if (m.containsKey(key)) m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  Widget _buildDashboard() {
    final sumBuy = _sumBuy();
    final sumSell = _sumSell();
    final sumProfit = _sumProfit();
    final sumMiles = _sumMiles();
    final avgCostPerMile = sumMiles == 0 ? 0 : (-sumProfit / sumMiles);

    final brandMap = _pieByAmount ? _pieByBrandAmount() : _pieByBrandCount();
    final brandEntries = brandMap.entries.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 스크롤 중
          widget.onScrollChanged?.call(true);
        } else if (notification is ScrollEndNotification) {
          // 스크롤 멈춤
          widget.onScrollChanged?.call(false);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF74512D),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI
          Row(
            children: [
              Expanded(child: _KpiValue(label: '총 매입금액', value: _fmtWon(sumBuy), icon: Icons.call_received_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _KpiValue(label: '총 판매금액', value: _fmtWon(sumSell), icon: Icons.call_made_outlined)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _KpiValue(label: '총 손익', value: _fmtWon(sumProfit), icon: Icons.trending_up_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _KpiValue(label: '누적 마일', value: sumMiles.toString(), icon: Icons.stars_outlined)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _KpiValue(label: '평균마일원가(원/마일)', value: avgCostPerMile.toStringAsFixed(2), icon: Icons.percent)),
              const SizedBox(width: 8),
              Expanded(child: _KpiValue(label: '보유 잔여(미판매)', value: _fmtWon(_remainingBuyTotal()), icon: Icons.account_balance_wallet_outlined)),
            ],
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GiftBanner(adUnitId: AdHelper.giftDashboardBannerAdUnitId),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_pieByAmount ? '브랜드별 분포 (금액 기준)' : '브랜드별 분포 (수량 기준)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Row(
                children: [
                  const Text('수량', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _pieByAmount,
                    activeColor: const Color(0xFF74512D),
                    onChanged: (v) => setState(() => _pieByAmount = v),
                  ),
                  const Text('금액', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.4,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: true),
                sections: [
                  for (int i = 0; i < brandEntries.length; i++)
                    PieChartSectionData(
                      title: brandEntries[i].key,
                      value: brandEntries[i].value.toDouble(),
                      color: Colors.primaries[i % Colors.primaries.length],
                      radius: 60,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (int i = 0; i < brandEntries.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: Colors.primaries[i % Colors.primaries.length]),
                      const SizedBox(width: 6),
                      Text(
                        _pieByAmount
                            ? '${brandEntries[i].key}: ${_fmtWon(brandEntries[i].value)}'
                            : '${brandEntries[i].key}: ${brandEntries[i].value}개',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          const Text('카드별 평균 수익률 비교 (원/마일, 낮을수록 우수)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _buildCardEfficiencyBars(),

          const SizedBox(height: 20),
          _buildInsightCards(),

          // 그래프 섹션 제거됨 (요청)

          const SizedBox(height: 20),
          const Text('재고 현황', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _buildInventorySection(),
        ],
      ),
    ),
    ),
    );
  }

  List<MapEntry<String, int>> _brandRemainQty() {
    final Map<String, int> m = {};
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      m[brand] = (m[brand] ?? 0) + ((lot['qty'] ?? 0) as int);
    }
    final list = m.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  double _weightedAvgBuy() {
    int totalQty = 0;
    int totalBuy = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      final qty = (lot['qty'] ?? 0) as int;
      totalQty += qty;
      totalBuy += qty * ((lot['buyUnit'] ?? 0) as int);
    }
    return totalQty == 0 ? 0 : totalBuy / totalQty;
  }

  int _remainingBuyTotal() {
    int total = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      total += ((lot['buyUnit'] ?? 0) as int) * ((lot['qty'] ?? 0) as int);
    }
    return total;
  }

  int _remainingQtyTotal() {
    int total = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      total += ((lot['qty'] ?? 0) as int);
    }
    return total;
  }

  int _remainingExpectedProfit(int sellUnit) {
    int sellTotal = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      sellTotal += sellUnit * ((lot['qty'] ?? 0) as int);
    }
    return sellTotal - _remainingBuyTotal();
  }

  // 목표 원/마일에 필요한 평균 판매가
  double _breakEvenSellUnit(double targetCostPerMile) {
    // buyTotal and miles over remaining open lots
    int buyTotal = 0;
    int qtyTotal = 0;
    double miles = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      final qty = (lot['qty'] ?? 0) as int;
      final buyUnit = (lot['buyUnit'] ?? 0) as int;
      final payType = (lot['payType'] as String?) ?? '신용';
      final cardId = (lot['cardId'] as String?) ?? '';
      final rule = (_cards[cardId] != null)
          ? (payType == '신용' ? (_cards[cardId]!['credit'] ?? 0) : (_cards[cardId]!['check'] ?? 0))
          : 0;
      buyTotal += qty * buyUnit;
      qtyTotal += qty;
      if (rule > 0) miles += (qty * buyUnit) / rule;
    }
    if (qtyTotal == 0) return 0;
    final requiredSellTotal = buyTotal - targetCostPerMile * miles;
    return requiredSellTotal / qtyTotal;
  }

  List<Map<String, dynamic>> _avgTByCard() {
    // lotId -> cardId
    final Map<String, String> lotToCard = {
      for (final l in _lots) l['id'] as String: (l['cardId'] as String? ?? '')
    };
    final Map<String, double> sumT = {};
    final Map<String, int> count = {};
    for (final s in _sales) {
      final lotId = s['lotId'] as String?;
      if (lotId == null) continue;
      final cardId = lotToCard[lotId];
      if (cardId == null || cardId.isEmpty) continue;
      final t = (s['costPerMile'] as num?)?.toDouble();
      if (t == null) continue;
      sumT[cardId] = (sumT[cardId] ?? 0) + t;
      count[cardId] = (count[cardId] ?? 0) + 1;
    }
    final List<Map<String, dynamic>> rows = [];
    sumT.forEach((cardId, total) {
      final c = count[cardId] ?? 1;
      final avg = total / c;
      final name = _cards[cardId]?['name'] as String? ?? cardId;
      rows.add({'cardId': cardId, 'name': name, 'avgT': avg});
    });
    rows.sort((a, b) => (a['avgT'] as double).compareTo(b['avgT'] as double));
    return rows;
  }

  Widget _buildCardEfficiencyBars() {
    final rows = _avgTByCard();
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }
    final double maxVal = rows.map<double>((e) => (e['avgT'] as double)).fold(0, (p, e) => e > p ? e : p);
    return Column(
      children: [
        for (final r in rows) ...[
          Row(
            children: [
              Expanded(
                child: Text('${r['name']}', style: const TextStyle(color: Colors.black87)),
              ),
              Text((r['avgT'] as double).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final ratio = maxVal == 0 ? 0 : ((r['avgT'] as double) / maxVal);
              return Stack(
                children: [
                  Container(
                    width: width,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: width * ratio,
                    height: 10,
                    decoration: BoxDecoration(color: const Color(0xFF74512D), borderRadius: BorderRadius.circular(6)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  double? _avgDiscountFor(int year, int month) {
    final List<double> vals = [];
    for (final s in _sales) {
      final ts = s['sellDate'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        if (d.year == year && d.month == month) {
          final v = (s['discount'] as num?)?.toDouble();
          if (v != null) vals.add(v);
        }
      }
    }
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  MapEntry<String, double>? _bestBrandByProfitRate() {
    final Map<String, String> lotToBrand = {for (final l in _lots) l['id'] as String: (l['giftcardId'] as String? ?? '기타')};
    final Map<String, double> sumRate = {};
    final Map<String, int> cnt = {};
    for (final s in _sales) {
      final lotId = s['lotId'] as String?;
      if (lotId == null) continue;
      final brand = lotToBrand[lotId] ?? '기타';
      final buyTotal = (s['buyTotal'] as num?)?.toDouble() ?? 0;
      final profit = (s['profit'] as num?)?.toDouble() ?? 0;
      if (buyTotal == 0) continue;
      final rate = (profit / buyTotal) * 100.0;
      sumRate[brand] = (sumRate[brand] ?? 0) + rate;
      cnt[brand] = (cnt[brand] ?? 0) + 1;
    }
    if (sumRate.isEmpty) return null;
    final entries = sumRate.entries
        .map((e) => MapEntry(e.key, e.value / (cnt[e.key] ?? 1)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  Widget _buildInsightCards() {
    final now = DateTime.now();
    final cur = _avgDiscountFor(now.year, now.month);
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prev = _avgDiscountFor(prevMonthDate.year, prevMonthDate.month);
    final delta = (cur != null && prev != null) ? (cur - prev) : null;
    final best = _bestBrandByProfitRate();

    String discountText() {
      if (cur == null) return '이번 달 평균 할인율: 데이터 없음';
      final curStr = cur.toStringAsFixed(2);
      if (delta == null) return '이번 달 평균 할인율: $curStr%';
      final sign = delta >= 0 ? '+' : '';
      return '이번 달 평균 할인율: $curStr% (전월 대비 $sign${delta.toStringAsFixed(2)}%)';
    }

    String bestBrandText() {
      if (best == null) return '가장 수익률이 높았던 브랜드: 데이터 없음';
      final name = best.key;
      final v = best.value;
      final sign = v >= 0 ? '+' : '';
      return '가장 수익률이 높았던 브랜드: $name (평균 $sign${v.toStringAsFixed(2)}%)';
    }

    Widget card(String text) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Text('💡 '),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(discountText()),
        card(bestBrandText()),
      ],
    );
  }

  Widget _buildInventorySection() {
    final remainList = _brandRemainQty();
    final avgBuy = _weightedAvgBuy();
    final remainQty = _remainingQtyTotal();
    final controller = _marketPriceController;
    final targetController = _targetCostPerMileController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in remainList)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                  color: Colors.white,
                ),
                child: Text('${e.key}: ${e.value}장', style: const TextStyle(color: Colors.black)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('가중평균 매입가: ${_won.format(avgBuy.round())}원 / 장, 잔여 ${remainQty}장', style: const TextStyle(color: Colors.black87)),
      ],
    );
  }

  Widget _buildCalendar() {
    // 판매 기준으로 표시, 날짜 클릭 시 해당 일 매입/판매 리스트
    final Map<DateTime, List<Map<String, dynamic>>> byDay = {};
    for (final s in _sales) {
      final ts = s['sellDate'];
      if (ts is Timestamp) {
        final d = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        byDay.putIfAbsent(d, () => []).add({...s, 'type': 'sale'});
      }
    }
    for (final l in _lots) {
      final ts = l['buyDate'];
      if (ts is Timestamp) {
        final d = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        byDay.putIfAbsent(d, () => []).add({...l, 'type': 'lot'});
      }
    }

    final selectedItems = (_selectedDay != null) ? (byDay[_selectedDay!] ?? []) : const <Map<String, dynamic>>[];

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          locale: 'ko_KR',
          selectedDayPredicate: (day) => _selectedDay != null && day.year == _selectedDay!.year && day.month == _selectedDay!.month && day.day == _selectedDay!.day,
          calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Color(0x2074512D), shape: BoxShape.circle)),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = DateTime(selected.year, selected.month, selected.day);
              _focusedDay = focused;
            });
          },
          eventLoader: (day) => byDay[DateTime(day.year, day.month, day.day)] ?? [],
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              final widgets = <Widget>[];
              final list = events.take(3).toList();
              for (final e in list) {
                final Map<String, dynamic>? m = e is Map<String, dynamic> ? e : null;
                final bool isSale = (m?['type'] == 'sale');
                widgets.add(Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSale ? Colors.blueAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ));
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widgets,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                // 스크롤 중
                widget.onScrollChanged?.call(true);
              } else if (notification is ScrollEndNotification) {
                // 스크롤 멈춤
                widget.onScrollChanged?.call(false);
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF74512D),
              backgroundColor: Colors.white,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: selectedItems.length + 1, // 광고를 위한 +1
                itemBuilder: (context, index) {
              // 첫 번째 아이템은 광고
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _GiftBanner(adUnitId: AdHelper.giftCalendarBannerAdUnitId),
                );
              }
              // 나머지는 선택된 날짜의 아이템들
              final m = selectedItems[index - 1];
              final isSale = m['type'] == 'sale';
              final ts = isSale ? m['sellDate'] : m['buyDate'];
              final date = ts is Timestamp ? _yMd.format(ts.toDate()) : '';
              final brand = (m['giftcardId'] as String?) ?? '';
              final qty = (m['qty'] ?? 0) as int;
              final String? memo = isSale ? null : (m['memo'] as String?);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onLongPress: () async {
                    if (isSale) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GiftSellScreen(editSaleId: m['id'] as String?)),
                      );
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GiftBuyScreen(editLotId: m['id'] as String?)),
                      );
                    }
                    if (mounted) _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _InfoPill(text: isSale ? '판매' : '구매', icon: isSale ? Icons.attach_money_outlined : Icons.shopping_cart_outlined, filled: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$brand $qty장',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isSale) ...[
                              _InfoPill(icon: Icons.sell_outlined, text: '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                              _InfoPill(icon: Icons.trending_up_outlined, text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                              _InfoPill(icon: Icons.today_outlined, text: date),
                            ] else ...[
                              _InfoPill(icon: Icons.payments_outlined, text: '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                              _InfoPill(icon: Icons.credit_card_outlined, text: '카드 ${m['cardId'] ?? ''}'),
                              _InfoPill(icon: Icons.account_balance_wallet_outlined, text: '${m['payType'] ?? ''}'),
                              _InfoPill(icon: Icons.today_outlined, text: date),
                              if (memo != null && memo.trim().isNotEmpty)
                                _InfoPill(icon: Icons.note_outlined, text: memo),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
              },
            ),
          ),
        ),
      ),
      ],
    );
  }

  Future<void> _showFilterDialog({required bool isBuy}) async {
    // 구매/판매에 따라 상품권 종류 목록 가져오기
    Set<String> giftcardIds;
    if (isBuy) {
      // 구매한 상품권 종류
      giftcardIds = _lots.map((e) => (e['giftcardId'] as String?) ?? '').where((id) => id.isNotEmpty).toSet();
    } else {
      // 판매한 상품권 종류 (lotId를 통해 찾기)
      giftcardIds = {};
      for (final sale in _sales) {
        final lotId = sale['lotId'] as String?;
        if (lotId != null) {
          final lot = _lots.firstWhere(
            (lot) => lot['id'] == lotId,
            orElse: () => <String, dynamic>{},
          );
          final giftcardId = lot['giftcardId'] as String?;
          if (giftcardId != null && giftcardId.isNotEmpty) {
            giftcardIds.add(giftcardId);
          }
        }
      }
    }
    final List<String> giftcardList = giftcardIds.toList()..sort();
    
    // 상품권 이름 가져오기
    final Map<String, String> giftcardNames = {};
    try {
      final giftsSnap = await FirebaseFirestore.instance.collection('giftcards').get();
      for (final doc in giftsSnap.docs) {
        giftcardNames[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
      }
    } catch (_) {}
    
    // 현재 선택된 상품권 ID (빈 Set이면 전체)
    final currentSelected = isBuy ? _selectedGiftcardIdsForBuy : _selectedGiftcardIdsForSell;
    Set<String> tempSelected = currentSelected.isEmpty 
        ? Set<String>.from(giftcardList) 
        : Set<String>.from(currentSelected);
    
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '상품권 필터',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final giftcardId in giftcardList)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (tempSelected.contains(giftcardId)) {
                            tempSelected.remove(giftcardId);
                          } else {
                            tempSelected.add(giftcardId);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: tempSelected.contains(giftcardId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    tempSelected.add(giftcardId);
                                  } else {
                                    tempSelected.remove(giftcardId);
                                  }
                                });
                              },
                              activeColor: const Color(0xFF74512D),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                giftcardNames[giftcardId] ?? giftcardId,
                                style: const TextStyle(color: Colors.black),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempSelected),
              child: const Text(
                '적용',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        if (isBuy) {
          _selectedGiftcardIdsForBuy = result;
        } else {
          _selectedGiftcardIdsForSell = result;
        }
      });
    }
  }

  // 편집 진입 전 땅콩 확인 및 차감 처리
  Future<void> _confirmAndConsumePeanutsThen(Function() onConfirmed, {int cost = 20}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = (userData?['peanutCount'] as int?) ?? 0;

      if (currentPeanuts < cost) {
        Fluttertoast.showToast(
          msg: '수정을 하기 위해서는 땅콩이 필요합니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('확인', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            content: const Text('땅콩 20개가 소모됩니다.', style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (ok == true) {
        await UserService.updatePeanutCount(uid, currentPeanuts - cost);
        onConfirmed();
      }
    } catch (e) {
      // 무시하고 진행하지 않음
    }
  }

  Widget _buildDaily() {
    final List<Map<String, dynamic>> lots = List<Map<String, dynamic>>.from(_lots.map((e) => {...e}));
    final List<Map<String, dynamic>> sales = List<Map<String, dynamic>>.from(_sales.map((e) => {...e}));

    DateTime tsOf(Map<String, dynamic> x, {required bool sale}) {
      final ts = sale ? x['sellDate'] : x['buyDate'];
      if (ts is Timestamp) return ts.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    
    // 구매 리스트 필터링 적용
    if (_selectedGiftcardIdsForBuy.isNotEmpty) {
      lots.removeWhere((lot) {
        final giftcardId = (lot['giftcardId'] as String?) ?? '';
        return !_selectedGiftcardIdsForBuy.contains(giftcardId);
      });
    }
    
    // 판매 리스트 필터링 적용
    if (_selectedGiftcardIdsForSell.isNotEmpty) {
      sales.removeWhere((sale) {
        final lotId = sale['lotId'] as String?;
        if (lotId == null) return true;
        final lot = _lots.firstWhere(
          (lot) => lot['id'] == lotId,
          orElse: () => <String, dynamic>{},
        );
        final giftcardId = lot['giftcardId'] as String?;
        if (giftcardId == null) return true;
        return !_selectedGiftcardIdsForSell.contains(giftcardId);
      });
    }
    
    lots.sort((a, b) => tsOf(b, sale: false).compareTo(tsOf(a, sale: false)));
    sales.sort((a, b) => tsOf(b, sale: true).compareTo(tsOf(a, sale: true)));

    Widget lotTile(Map m) {
      final String date = (m['buyDate'] is Timestamp) ? _yMd.format((m['buyDate'] as Timestamp).toDate()) : '';
      final String brand = (m['giftcardId'] as String?) ?? '';
      final int qty = (m['qty'] ?? 0) as int;
      final bool sold = (m['status'] as String?) == 'sold';
      final Color? buyColor = sold ? const Color(0xFF1E88E5) : const Color(0xFF74512D);
      final String? memo = m['memo'] as String?;
      return GestureDetector(
        onLongPress: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GiftBuyScreen(editLotId: m['id'] as String?)),
          );
          if (mounted) _load();
        },
        child: Container(
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
              Row(children: [
                _InfoPill(text: '구매', icon: Icons.shopping_cart_outlined, filled: true, fillColor: buyColor),
                const SizedBox(width: 8),
                Expanded(child: Text('$brand $qty장', style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '편집',
                  onPressed: () async {
                    await _confirmAndConsumePeanutsThen(() async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GiftBuyScreen(editLotId: m['id'] as String?)),
                      );
                      if (mounted) _load();
                    }, cost: 20);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: Icons.payments_outlined, text: '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                  _InfoPill(icon: Icons.credit_card_outlined, text: '카드 ${m['cardId'] ?? ''}'),
                  _InfoPill(icon: Icons.account_balance_wallet_outlined, text: '${m['payType'] ?? ''}'),
                  _InfoPill(icon: Icons.today_outlined, text: date),
                  if (memo != null && memo.trim().isNotEmpty)
                    _InfoPill(icon: Icons.note_outlined, text: memo),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget saleTile(Map m) {
      final String date = (m['sellDate'] is Timestamp) ? _yMd.format((m['sellDate'] as Timestamp).toDate()) : '';
      final String brand = (m['giftcardId'] as String?) ?? '';
      final int qty = (m['qty'] ?? 0) as int;
      
      // lotId를 통해 해당 lot의 giftcardId 찾기
      String? lotGiftcardName;
      final lotId = m['lotId'] as String?;
      if (lotId != null) {
        final lot = _lots.firstWhere(
          (lot) => lot['id'] == lotId,
          orElse: () => <String, dynamic>{},
        );
        final lotGiftcardId = lot['giftcardId'] as String?;
        if (lotGiftcardId != null) {
          lotGiftcardName = _giftcardNames[lotGiftcardId] ?? lotGiftcardId;
        }
      }
      
      // branchId를 통해 지점 이름 찾기
      String? branchName;
      final branchId = m['branchId'] as String?;
      if (branchId != null && _branchNames.containsKey(branchId)) {
        branchName = _branchNames[branchId];
      }
      
      return GestureDetector(
        onLongPress: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GiftSellScreen(editSaleId: m['id'] as String?)),
          );
          if (mounted) _load();
        },
        child: Container(
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
              Row(children: [
                const _InfoPill(text: '판매', icon: Icons.attach_money_outlined, filled: true),
                const SizedBox(width: 8),
                Expanded(child: Text('$brand $qty장', style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: Icons.sell_outlined, text: '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                  _InfoPill(icon: Icons.trending_up_outlined, text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                  _InfoPill(icon: Icons.today_outlined, text: date),
                  if (lotGiftcardName != null && lotGiftcardName.isNotEmpty)
                    _InfoPill(icon: Icons.card_giftcard_outlined, text: lotGiftcardName),
                  if (branchName != null && branchName.isNotEmpty)
                    _InfoPill(icon: Icons.store_outlined, text: branchName),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isBuy = _buySellTabController.index == 0;
    final selectedIds = isBuy ? _selectedGiftcardIdsForBuy : _selectedGiftcardIdsForSell;
    
    return Column(
      children: [
        TabBar(
          controller: _buySellTabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF74512D),
          tabs: const [Tab(text: '구매'), Tab(text: '판매')],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showFilterDialog(isBuy: isBuy),
                icon: const Icon(Icons.filter_list, color: Colors.black, size: 18),
                label: Text(
                  selectedIds.isEmpty ? '전체 ▼' : '${selectedIds.length}개 선택 ▼',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _buySellTabController,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    // 스크롤 중
                    widget.onScrollChanged?.call(true);
                  } else if (notification is ScrollEndNotification) {
                    // 스크롤 멈춤
                    widget.onScrollChanged?.call(false);
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF74512D),
                  backgroundColor: Colors.white,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: lots.length + 1, // 광고를 위한 +1
                    separatorBuilder: (_, index) {
                      // 광고 다음에만 separator 추가
                      if (index == 0) return const SizedBox(height: 8);
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, i) {
                    // 첫 번째 아이템은 광고
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _GiftBanner(adUnitId: AdHelper.giftDailyBannerAdUnitId),
                      );
                    }
                    // 나머지는 구매 리스트
                    return lotTile({...lots[i - 1], 'id': lots[i - 1]['id']});
                  },
                ),
              ),
              ),
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    // 스크롤 중
                    widget.onScrollChanged?.call(true);
                  } else if (notification is ScrollEndNotification) {
                    // 스크롤 멈춤
                    widget.onScrollChanged?.call(false);
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF74512D),
                  backgroundColor: Colors.white,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: sales.length + 1, // 광고를 위한 +1
                    separatorBuilder: (_, index) {
                      // 광고 다음에만 separator 추가
                      if (index == 0) return const SizedBox(height: 8);
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, i) {
                    // 첫 번째 아이템은 광고
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _GiftBanner(adUnitId: AdHelper.giftDailyBannerAdUnitId),
                      );
                    }
                    // 나머지는 판매 리스트
                    return saleTile({...sales[i - 1], 'id': sales[i - 1]['id']});
                  },
                ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Color(0xFF74512D),
              tabs: const [
                Tab(text: '대시보드'),
                Tab(text: '캘린더'),
                Tab(text: '일간'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboard(),
                  _buildCalendar(),
                  _buildDaily(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


