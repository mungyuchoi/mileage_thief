import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mileage_thief/model/giftcard_period.dart';
import 'package:mileage_thief/services/giftcard_service.dart';
import 'package:mileage_thief/services/user_service.dart';
import 'package:mileage_thief/widgets/giftcard_daily_ledger.dart';
import 'package:mileage_thief/widgets/info_pill.dart';
import 'package:mileage_thief/widgets/press_scale.dart';
import 'package:mileage_thief/widgets/segment_tab_bar.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';
import 'giftcard_kpi_detail_screen.dart';
import 'user_profile_screen.dart';

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

  // 데이터
  bool _loading = true;
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _sales = [];
  Map<String, String> _giftcardNames = {}; // giftcardId -> name
  Map<String, String> _branchNames = {}; // branchId -> name
  Map<String, String> _whereToBuyNames = {}; // whereToBuyId -> name
  final DateFormat _yMd = DateFormat('yyyy-MM-dd');
  final NumberFormat _won = NumberFormat('#,###');

  // 대시보드: 기간 필터 상태
  DashboardPeriodType _periodType = DashboardPeriodType.month;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;
  DateTime? _minDataMonth; // lots/sales에서 가장 오래된 월

  // 캘린더 탭: 대시보드와 독립적인 월/데이터 상태
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _calendarLots = [];
  List<Map<String, dynamic>> _calendarSales = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  // 대시보드 하단(고급) 섹션들 임시 비활성화 플래그
  // - 브랜드별 분포
  // - 카드별 평균 수익률 비교
  // - 재고 현황
  bool _showDashboardAdvancedSections = false;

  bool _pieByAmount = true; // true: 금액, false: 수량
  Map<String, Map<String, dynamic>> _cards = {}; // cardId -> {credit, check, name}
  final TextEditingController _marketPriceController = TextEditingController();
  final TextEditingController _targetCostPerMileController = TextEditingController();
  
  // 필터 관련
  Set<String> _selectedGiftcardIdsForDaily = {}; // 일간(통합) 탭 선택된 상품권 ID 목록 (빈 Set이면 전체)

  // 랭킹 데이터
  List<Map<String, dynamic>> _userRankings = <Map<String, dynamic>>[];
  bool _rankingLoading = false;
  bool _rankingAgreement = true; // 랭킹 동의 상태 (기본값 true)
  DateTime? _rankingUpdatedAt; // 랭킹 데이터 업데이트 시간

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // 랭킹 탭(인덱스 3)이 선택되었을 때 데이터 로드
      if (_tabController.index == 3 && _periodType == DashboardPeriodType.month) {
        _loadRanking();
      }
    });
    _load();
    _loadMinDataMonth(); // 가장 오래된 데이터 월 계산
    // 초기 캘린더 월 데이터 로드 (대시보드 월과는 독립적으로 관리)
    _loadCalendarMonth(_calendarMonth);
    // 초기 랭킹 데이터 로드
    _loadRanking();
    // 랭킹 동의 상태 로드
    _loadRankingAgreement();
  }

  // 랭킹 동의 상태 로드
  Future<void> _loadRankingAgreement() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data();
      if (data != null && data.containsKey('ranking_agree')) {
        setState(() {
          _rankingAgreement = data['ranking_agree'] as bool? ?? true;
        });
      }
    } catch (e) {
      // 오류 시 기본값 유지
    }
  }

  // 랭킹 동의 상태 저장
  Future<void> _saveRankingAgreement(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'ranking_agree': value});
      setState(() {
        _rankingAgreement = value;
      });
    } catch (e) {
      debugPrint('랭킹 동의 상태 저장 오류: $e');
    }
  }

  // 랭킹 동의 토글 변경 처리
  Future<void> _handleRankingAgreementToggle(bool newValue) async {
    // true로 변경하는 경우 그냥 허용
    if (newValue) {
      await _saveRankingAgreement(true);
      return;
    }

    // false로 변경하려는 경우 땅콩 50개 차감 확인
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = _asInt(userData?['peanutCount']);

      if (currentPeanuts < 50) {
        Fluttertoast.showToast(
          msg: '땅콩이 모자랍니다.',
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
            title: const Text(
              '확인',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '랭킹 동의를 해제하시겠습니까?',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• 땅콩 50개가 소모됩니다.',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• 동의하지 않음으로 변경하게 되면 다음번 랭킹 집계할 때 제외됩니다.',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• 동의하지 않음으로 변경하게 되면 지도, 시세, 지점탭을 이용할 수 없습니다.',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  '현재 보유 땅콩: ${currentPeanuts}개',
                  style: TextStyle(
                    color: currentPeanuts >= 50 ? Colors.green : Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '변경',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (ok == true) {
        await UserService.updatePeanutCount(uid, currentPeanuts - 50);
        await _saveRankingAgreement(false);
        Fluttertoast.showToast(
          msg: '땅콩 50개가 사용되었습니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      debugPrint('랭킹 동의 토글 처리 오류: $e');
    }
  }
  
  // 외부에서 호출할 수 있는 새로고침 메서드
  void refresh() {
    _load();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
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
      final data = await GiftcardService.loadInfoData(
        uid: uid,
        periodType: _periodType,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
      );
      setState(() {
        _lots = data.lots;
        _sales = data.sales;
        _cards = data.cards;
        _giftcardNames = data.giftcardNames;
        _branchNames = data.branchNames;
        _whereToBuyNames = data.whereToBuyNames;
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  /// lots/sales 전체에서 가장 오래된 매입/판매 일자를 찾아
  /// 해당 연/월을 _minDataMonth에 저장한다.
  Future<void> _loadMinDataMonth() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      DateTime? oldest;

      final lotsMinSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .orderBy('buyDate')
          .limit(1)
          .get();
      if (lotsMinSnap.docs.isNotEmpty) {
        final data = lotsMinSnap.docs.first.data();
        final ts = data['buyDate'];
        if (ts is Timestamp) {
          oldest = ts.toDate();
        }
      }

      final salesMinSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sales')
          .orderBy('sellDate')
          .limit(1)
          .get();
      if (salesMinSnap.docs.isNotEmpty) {
        final data = salesMinSnap.docs.first.data();
        final ts = data['sellDate'];
        if (ts is Timestamp) {
          final d = ts.toDate();
          if (oldest == null || d.isBefore(oldest)) {
            oldest = d;
          }
        }
      }

      if (!mounted || oldest == null) return;
      setState(() {
        _minDataMonth = DateTime(oldest!.year, oldest!.month);
      });
    } catch (_) {
      // 실패 시 조용히 무시
    }
  }

  /// 캘린더 탭 전용: 캘린더에서 보고 있는 월에 맞춰 별도로 데이터 로드
  Future<void> _loadCalendarMonth(DateTime month) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _calendarMonth = DateTime(month.year, month.month);
        _calendarLots = [];
        _calendarSales = [];
      });
      return;
    }
    try {
      final DateTime start = DateTime(month.year, month.month);
      final DateTime end = DateTime(month.year, month.month + 1);

      final lotsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .where('buyDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('buyDate', isLessThan: Timestamp.fromDate(end))
          .orderBy('buyDate')
          .get();

      final salesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sales')
          .where('sellDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('sellDate', isLessThan: Timestamp.fromDate(end))
          .orderBy('sellDate')
          .get();

      if (!mounted) return;
      setState(() {
        _calendarMonth = DateTime(month.year, month.month);
        _calendarLots = lotsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _calendarSales = salesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {
      // 캘린더 데이터 로드 실패 시 기존 값 유지 (조용히 무시)
    }
  }

  String _formatYearMonth(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}년도 $m월';
  }

  String _dashboardTitleText() {
    switch (_periodType) {
      case DashboardPeriodType.all:
        return '전체 기간';
      case DashboardPeriodType.year:
        return '${_selectedYear}년도 전체';
      case DashboardPeriodType.month:
        return _formatYearMonth(_selectedMonth);
    }
  }

  String _dashboardFilterLabel() {
    switch (_periodType) {
      case DashboardPeriodType.all:
        return '전체 ▼';
      case DashboardPeriodType.year:
        return '$_selectedYear년 ▼';
      case DashboardPeriodType.month:
        return '${_selectedMonth.month.toString().padLeft(2, '0')}월 ▼';
    }
  }

  Future<void> _showMonthPicker() async {
    final DateTime now = DateTime.now();
    // lots/sales에서 가장 오래된 월 기준, 없으면 현재 월 기준
    final DateTime effectiveMinMonth = _minDataMonth ?? DateTime(now.year, now.month);
    final DateTime minMonth = DateTime(effectiveMinMonth.year, effectiveMinMonth.month);
    final int minYear = minMonth.year;

    // 월 리스트: 현재 월부터 거슬러 올라가되, 가장 오래된 월 이전은 제외
    final List<DateTime> months = [];
    DateTime cursor = DateTime(now.year, now.month);
    while (!cursor.isBefore(minMonth)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1);
    }

    // 연도 리스트: 가장 오래된 연도까지 내려감
    final List<int> years = [];
    for (int y = now.year; y >= minYear; y--) {
      years.add(y);
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // 높이를 비율로 제어
      builder: (sheetContext) {
        DashboardPeriodType mode = _periodType;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildTypeChip(DashboardPeriodType type, String label) {
              final bool selected = mode == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setModalState(() {
                      mode = type;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF74512D) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? const Color(0xFF74512D) : Colors.black26,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget body;
            if (mode == DashboardPeriodType.all) {
              body = ListTile(
                title: const Text(
                  '전체 기간 보기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '모든 매입/판매 데이터를 기준으로 대시보드를 보여줍니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _periodType = DashboardPeriodType.all;
                    _loading = true;
                  });
                  await _load();
                },
              );
            } else if (mode == DashboardPeriodType.year) {
              body = ListView.separated(
                itemCount: years.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (context, index) {
                  final int y = years[index];
                  final bool isCurrent = _periodType == DashboardPeriodType.year && _selectedYear == y;
                  return ListTile(
                    title: Text(
                      '$y년도 전체',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _periodType = DashboardPeriodType.year;
                        _selectedYear = y;
                        _loading = true;
                      });
                      await _load();
                    },
                  );
                },
              );
            } else {
              body = ListView.separated(
                itemCount: months.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (context, index) {
                  final d = months[index];
                  final bool isCurrent = _periodType == DashboardPeriodType.month &&
                      d.year == _selectedMonth.year &&
                      d.month == _selectedMonth.month;
                  return ListTile(
                    title: Text(
                      _formatYearMonth(d),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _periodType = DashboardPeriodType.month;
                        _selectedMonth = DateTime(d.year, d.month);
                        _selectedYear = d.year;
                        _loading = true;
                      });
                      await _load();
                      await _loadRanking();
                    },
                  );
                },
              );
            }

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.7, // 화면 높이의 70%까지만 차지
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '기간 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          buildTypeChip(DashboardPeriodType.all, '전체'),
                          const SizedBox(width: 8),
                          buildTypeChip(DashboardPeriodType.year, '연도별'),
                          const SizedBox(width: 8),
                          buildTypeChip(DashboardPeriodType.month, '월별'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 리스트 영역은 남은 공간을 차지하면서 스크롤되도록
                      Expanded(
                        child: mode == DashboardPeriodType.all
                            ? SingleChildScrollView(child: body)
                            : body,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 집계/파싱 헬퍼
  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// 대시보드 KPI(평균마일원가 등)는 "구매일(기간) 기준"으로 집계한다.
  /// - lots: 선택 기간에 구매한 lot만 들어있음 (GiftcardService에서 buyDate 기준 필터)
  /// - sales: 일간/내역 탭을 위해 sellDate 기준 판매도 섞여 들어올 수 있음
  /// 따라서 KPI 집계는 "선택 기간 lots에 연결된 판매(lotId)"만 사용한다.
  Set<String> _currentLotIdSet() {
    return _lots
        .map((e) => e['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  List<Map<String, dynamic>> _dashboardSales() {
    // 전체 기간은 lots도 전체라서 _sales 그대로 사용해도 동일하지만,
    // 안전하게 lotId 연결이 있는 판매만 KPI에 반영한다.
    final lotIds = _currentLotIdSet();
    if (lotIds.isEmpty) return const <Map<String, dynamic>>[];
    return _sales.where((s) {
      final lotId = s['lotId'] as String?;
      return lotId != null && lotIds.contains(lotId);
    }).toList();
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _sumBuy() => _lots.fold(
        0,
        (p, e) => p + _asInt(e['buyUnit']) * _asInt(e['qty']),
      );
  int _sumSell() => _dashboardSales().fold(0, (p, e) => p + _asInt(e['sellTotal']));
  int _sumProfit() => _dashboardSales().fold(0, (p, e) => p + _asInt(e['profit']));
  int _sumMiles() => _dashboardSales().fold(0, (p, e) => p + _asInt(e['miles']));
  String _fmtWon(num v) => '${_won.format(v)}원';
  String _fmtDiscount(dynamic v) {
    final double d = _asDouble(v);
    if (d == 0) return '0%';
    final bool isInt = d == d.roundToDouble();
    return '${isInt ? d.toStringAsFixed(0) : d.toStringAsFixed(2)}%';
  }
  int _openQtyTotal() {
    int total = 0;
    for (final lot in _lots) {
      final String status = (lot['status'] as String?) ?? 'open';
      if (status != 'open') continue;
      total += _asInt(lot['qty']);
    }
    return total;
  }

  // 브랜드별 분포(금액 기준)
  Map<String, int> _pieByBrandAmount() {
    final Map<String, int> m = {};
    for (final lot in _lots) {
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      m[brand] = (m[brand] ?? 0) + _asInt(lot['buyUnit']) * _asInt(lot['qty']);
    }
    return m;
  }

  Map<String, int> _pieByBrandCount() {
    final Map<String, int> m = {};
    for (final lot in _lots) {
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      m[brand] = (m[brand] ?? 0) + _asInt(lot['qty']);
    }
    return m;
  }

  // 월별 손익/마일
  Map<String, Map<String, int>> _monthlyStats() {
    final Map<String, Map<String, int>> m = {};
    for (final s in _dashboardSales()) {
      final ts = s['sellDate'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final profit = _asInt(s['profit']);
        final miles = _asInt(s['miles']);
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
    for (final s in _dashboardSales()) {
      final d = (s['discount'] as num?)?.toDouble();
      if (d == null) continue;
      final key = (d * 10).round() / 10.0; // 0.1단위 반올림
      if (m.containsKey(key)) m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  Future<void> _openKpiDetail(GiftcardKpiType kpiType) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftcardKpiDetailScreen(
          kpiType: kpiType,
          periodType: _periodType,
          selectedMonth: _selectedMonth,
          selectedYear: _selectedYear,
        ),
      ),
    );
    if (mounted) {
      _load();
    }
  }

  Widget _buildDashboard() {
    final sumBuy = _sumBuy();
    final sumSell = _sumSell();
    final sumProfit = _sumProfit();
    final sumMiles = _sumMiles();
    final avgCostPerMile = sumMiles == 0 ? 0 : (-sumProfit / sumMiles);

    final bool showAdvanced = _showDashboardAdvancedSections;
    final Map<String, int> brandMap =
        showAdvanced ? (_pieByAmount ? _pieByBrandAmount() : _pieByBrandCount()) : const <String, int>{};
    final List<MapEntry<String, int>> brandEntries = brandMap.entries.toList();

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
          // 월 헤더: "YYYY년도 MM월"  |  "MM월 ▼" 필터 버튼
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dashboardTitleText(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                TextButton.icon(
                  onPressed: _showMonthPicker,
                  icon: const Icon(Icons.filter_list, color: Colors.black, size: 18),
                  label: Text(
                    _dashboardFilterLabel(),
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
          // KPI
          Row(
            children: [
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.totalBuy),
                  child: _KpiValue(label: '총 매입금액', value: _fmtWon(sumBuy), icon: Icons.call_received_outlined),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.totalSell),
                  child: _KpiValue(label: '총 판매금액', value: _fmtWon(sumSell), icon: Icons.call_made_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.totalProfit),
                  child: _KpiValue(label: '총 손익', value: _fmtWon(sumProfit), icon: Icons.trending_up_outlined),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.totalMiles),
                  child: _KpiValue(label: '누적 마일', value: sumMiles.toString(), icon: Icons.stars_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.avgCostPerMile),
                  child: _KpiValue(label: '평균마일원가(원/마일)', value: avgCostPerMile.toStringAsFixed(2), icon: Icons.percent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PressScale(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openKpiDetail(GiftcardKpiType.openQty),
                  child: _KpiValue(label: '미판매 수량', value: '${_openQtyTotal()}장', icon: Icons.account_balance_wallet_outlined),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _GiftBanner(adUnitId: AdHelper.giftDashboardBannerAdUnitId),
          ),

          if (showAdvanced) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _pieByAmount ? '브랜드별 분포 (금액 기준)' : '브랜드별 분포 (수량 기준)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
                        Container(
                          width: 10,
                          height: 10,
                          color: Colors.primaries[i % Colors.primaries.length],
                        ),
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
            const Text(
              '카드별 평균 수익률 비교 (원/마일, 낮을수록 우수)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildCardEfficiencyBars(),
          ],

          // NOTE: 대시보드 하단 인사이트(2개 카드) 임시 비활성화
          // - 이번 달 평균 할인율
          // - 가장 수익률이 높았던 브랜드
          //
          // const SizedBox(height: 20),
          // _buildInsightCards(),

          // 그래프 섹션 제거됨 (요청)

          if (showAdvanced) ...[
            const SizedBox(height: 20),
            const Text('재고 현황', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildInventorySection(),
          ],
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
      m[brand] = (m[brand] ?? 0) + _asInt(lot['qty']);
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
      final qty = _asInt(lot['qty']);
      totalQty += qty;
      totalBuy += qty * _asInt(lot['buyUnit']);
    }
    return totalQty == 0 ? 0 : totalBuy / totalQty;
  }

  int _remainingBuyTotal() {
    int total = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      total += _asInt(lot['buyUnit']) * _asInt(lot['qty']);
    }
    return total;
  }

  int _remainingQtyTotal() {
    int total = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      total += _asInt(lot['qty']);
    }
    return total;
  }

  int _remainingExpectedProfit(int sellUnit) {
    int sellTotal = 0;
    for (final lot in _lots) {
      if ((lot['status'] as String?) == 'sold') continue;
      sellTotal += sellUnit * _asInt(lot['qty']);
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
      final qty = _asInt(lot['qty']);
      final buyUnit = _asInt(lot['buyUnit']);
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
    // ⚠️ 캘린더는 대시보드의 월 필터(_selectedMonth)와 독립적으로,
    //     자체적으로 관리하는 _calendarMonth 기준 데이터(_calendarLots/_calendarSales)를 사용한다.
    final Map<DateTime, List<Map<String, dynamic>>> byDay = {};
    for (final s in _calendarSales) {
      final ts = s['sellDate'];
      if (ts is Timestamp) {
        final d = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        byDay.putIfAbsent(d, () => []).add({...s, 'type': 'sale'});
      }
    }
    for (final l in _calendarLots) {
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
          // 달(페이지)이 변경될 때마다 해당 월 기준으로 캘린더 전용 데이터를 다시 로드
          onPageChanged: (focused) {
            setState(() {
              _focusedDay = focused;
            });
            _loadCalendarMonth(DateTime(focused.year, focused.month));
          },
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
              // 캘린더 탭에서는 현재 보고 있는 월(_calendarMonth) 기준으로만 새로고침
              onRefresh: () => _loadCalendarMonth(_calendarMonth),
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
              final qty = _asInt(m['qty']);
              final String? memo = isSale ? null : (m['memo'] as String?);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
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
                            InfoPill(text: isSale ? '판매' : '구매', icon: isSale ? Icons.attach_money_outlined : Icons.shopping_cart_outlined, filled: true),
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
                              InfoPill(icon: Icons.sell_outlined, text: '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                              InfoPill(icon: Icons.trending_up_outlined, text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                              InfoPill(icon: Icons.today_outlined, text: date),
                            ] else ...[
                              InfoPill(icon: Icons.payments_outlined, text: '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                              InfoPill(icon: Icons.credit_card_outlined, text: '카드 ${m['cardId'] ?? ''}'),
                              InfoPill(icon: Icons.account_balance_wallet_outlined, text: '${m['payType'] ?? ''}'),
                              InfoPill(icon: Icons.today_outlined, text: date),
                              if (memo != null && memo.trim().isNotEmpty)
                                InfoPill(icon: Icons.note_outlined, text: memo),
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

  Future<void> _showDailyFilterDialog() async {
    // lots + sales(역참조 포함)에서 등장하는 상품권 목록을 구성
    final Set<String> giftcardIds = {};
    for (final lot in _lots) {
      final id = (lot['giftcardId'] as String?) ?? '';
      if (id.isNotEmpty) giftcardIds.add(id);
    }
    for (final sale in _sales) {
      final id = (sale['giftcardId'] as String?) ?? '';
      if (id.isNotEmpty) {
        giftcardIds.add(id);
        continue;
      }
      final lotId = sale['lotId'] as String?;
      if (lotId == null) continue;
      final lot = _lots.firstWhere(
        (lot) => lot['id'] == lotId,
        orElse: () => <String, dynamic>{},
      );
      final giftcardId = (lot['giftcardId'] as String?) ?? '';
      if (giftcardId.isNotEmpty) giftcardIds.add(giftcardId);
    }
    final List<String> giftcardList = giftcardIds.toList()..sort();

    // 현재 선택된 상품권 ID (빈 Set이면 전체)
    final currentSelected = _selectedGiftcardIdsForDaily;
    Set<String> tempSelected = currentSelected.isEmpty ? Set<String>.from(giftcardList) : Set<String>.from(currentSelected);

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
                                _giftcardNames[giftcardId] ?? giftcardId,
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
              onPressed: () {
                // 아무것도 선택하지 않으면 전체로 처리(빈 Set)
                if (tempSelected.isEmpty) {
                  Navigator.pop(context, <String>{});
                } else if (tempSelected.length == giftcardList.length) {
                  Navigator.pop(context, <String>{});
                } else {
                  Navigator.pop(context, tempSelected);
                }
              },
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
        _selectedGiftcardIdsForDaily = result;
      });
    }
  }

  // 편집 진입 전 땅콩 확인 및 차감 처리
  Future<void> _confirmAndConsumePeanutsThen(Function() onConfirmed, {int cost = 20}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = _asInt(userData?['peanutCount']);

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

  Future<void> _confirmAndDeleteSale(Map<String, dynamic> sale, {int cost = 20}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final String saleId = (sale['id'] as String?) ?? '';
    final String lotId = (sale['lotId'] as String?) ?? '';
    if (saleId.isEmpty) {
      Fluttertoast.showToast(msg: '삭제할 판매 정보가 올바르지 않습니다.');
      return;
    }

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = _asInt(userData?['peanutCount']);

      if (currentPeanuts < cost) {
        Fluttertoast.showToast(msg: '삭제를 하기 위해서는 땅콩이 필요합니다.');
        return;
      }

      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '삭제',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '땅콩 $cost개가 소모됩니다.\n삭제하시겠습니까?',
              style: const TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (ok != true) return;

      // 1) 땅콩 차감
      await UserService.updatePeanutCount(uid, currentPeanuts - cost);

      // 2) Firestore 업데이트: lot.status=open 복구 후 sale 삭제
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final saleRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sales')
            .doc(saleId);

        if (lotId.isNotEmpty) {
          final lotRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('lots')
              .doc(lotId);
          final lotSnap = await tx.get(lotRef);
          if (lotSnap.exists) {
            tx.update(lotRef, <String, dynamic>{
              'status': 'open',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        tx.delete(saleRef);
      });

      if (!mounted) return;
      await _load();
      Fluttertoast.showToast(msg: '판매 내역이 삭제되었습니다.');
    } catch (e) {
      debugPrint('판매 삭제 오류: $e');
      Fluttertoast.showToast(msg: '삭제 중 오류가 발생했습니다.');
    }
  }

  Future<void> _updateTradeStatus(String lotId, bool trade) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .doc(lotId)
          .update({
        'trade': trade,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await _load();
    } catch (e) {
      debugPrint('교환 상태 업데이트 오류: $e');
      Fluttertoast.showToast(msg: '교환 상태 업데이트 중 오류가 발생했습니다.');
    }
  }

  Future<void> _confirmAndDeleteLot(Map<String, dynamic> lot, {int cost = 20}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final String lotId = (lot['id'] as String?) ?? '';
    final String status = (lot['status'] as String?) ?? 'open';
    if (lotId.isEmpty) {
      Fluttertoast.showToast(msg: '삭제할 구매 정보가 올바르지 않습니다.');
      return;
    }
    if (status != 'open') {
      Fluttertoast.showToast(msg: '이미 판매된 구매 내역은 삭제할 수 없습니다.');
      return;
    }

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = _asInt(userData?['peanutCount']);

      if (currentPeanuts < cost) {
        Fluttertoast.showToast(msg: '삭제를 하기 위해서는 땅콩이 필요합니다.');
        return;
      }

      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '삭제',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '땅콩 $cost개가 소모됩니다.\n삭제하시겠습니까?',
              style: const TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (ok != true) return;

      // 1) 땅콩 차감
      await UserService.updatePeanutCount(uid, currentPeanuts - cost);

      // 2) lot 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .doc(lotId)
          .delete();

      if (!mounted) return;
      await _load();
      Fluttertoast.showToast(msg: '구매 내역이 삭제되었습니다.');
    } catch (e) {
      debugPrint('구매 삭제 오류: $e');
      Fluttertoast.showToast(msg: '삭제 중 오류가 발생했습니다.');
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
    
    // 일간(통합) 필터 적용
    if (_selectedGiftcardIdsForDaily.isNotEmpty) {
      lots.removeWhere((lot) {
        final giftcardId = (lot['giftcardId'] as String?) ?? '';
        return !_selectedGiftcardIdsForDaily.contains(giftcardId);
      });
    }
    
    // 판매 리스트도 동일 필터 적용 (lotId 역참조 포함)
    if (_selectedGiftcardIdsForDaily.isNotEmpty) {
      sales.removeWhere((sale) {
        final directGiftcardId = (sale['giftcardId'] as String?) ?? '';
        if (directGiftcardId.isNotEmpty) {
          return !_selectedGiftcardIdsForDaily.contains(directGiftcardId);
        }
        final lotId = sale['lotId'] as String?;
        if (lotId == null) return true;
        final lot = _lots.firstWhere(
          (lot) => lot['id'] == lotId,
          orElse: () => <String, dynamic>{},
        );
        final giftcardId = lot['giftcardId'] as String?;
        if (giftcardId == null) return true;
        return !_selectedGiftcardIdsForDaily.contains(giftcardId);
      });
    }
    
    lots.sort((a, b) => tsOf(b, sale: false).compareTo(tsOf(a, sale: false)));
    sales.sort((a, b) => tsOf(b, sale: true).compareTo(tsOf(a, sale: true)));

    Widget lotTile(Map m) {
      final String date = (m['buyDate'] is Timestamp) ? _yMd.format((m['buyDate'] as Timestamp).toDate()) : '';
      final String brand = (m['giftcardId'] as String?) ?? '';
      final int qty = _asInt(m['qty']);
      final String status = (m['status'] as String?) ?? 'open';
      final bool sold = status == 'sold';
      final bool canDelete = status == 'open';
      final Color? buyColor = sold ? const Color(0xFF1E88E5) : const Color(0xFF74512D);
      final String? memo = m['memo'] as String?;
      final bool isTraded = sold ? true : ((m['trade'] as bool?) ?? false);
      return GestureDetector(
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
                InfoPill(text: '구매', icon: Icons.shopping_cart_outlined, filled: true, fillColor: buyColor),
                const SizedBox(width: 8),
                Expanded(child: Text('$brand $qty장', style: const TextStyle(fontWeight: FontWeight.w700))),
                if ((m['whereToBuyId'] as String?) != null) ...[
                  const SizedBox(width: 8),
                  InfoPill(
                    icon: Icons.storefront_outlined,
                    text: _whereToBuyNames[(m['whereToBuyId'] as String?)!] ?? (m['whereToBuyId'] as String),
                  ),
                ],
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
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '삭제',
                    onPressed: () async {
                      await _confirmAndDeleteLot(
                        Map<String, dynamic>.from(m as Map),
                        cost: 20,
                      );
                    },
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(icon: Icons.payments_outlined, text: '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                  InfoPill(icon: Icons.credit_card_outlined, text: '카드 ${m['cardId'] ?? ''}'),
                  InfoPill(icon: Icons.account_balance_wallet_outlined, text: '${m['payType'] ?? ''}'),
                  InfoPill(icon: Icons.today_outlined, text: date),
                  if (memo != null && memo.trim().isNotEmpty)
                    InfoPill(icon: Icons.note_outlined, text: memo),
                  // status가 'open'인 구매 건에만 미교환/교환완료 버튼 추가
                  if (status == 'open')
                    GestureDetector(
                      onTap: () async {
                        await _updateTradeStatus(m['id'] as String, !isTraded);
                      },
                      child: InfoPill(
                        icon: Icons.swap_horiz_outlined,
                        text: isTraded ? '교환완료' : '미교환',
                      ),
                    ),
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
      final int qty = _asInt(m['qty']);
      final bool hasDiscount = m.containsKey('discount') && m['discount'] != null;
      
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
                const InfoPill(text: '판매', icon: Icons.attach_money_outlined, filled: true),
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
                        MaterialPageRoute(builder: (_) => GiftSellScreen(editSaleId: m['id'] as String?)),
                      );
                      if (mounted) _load();
                    }, cost: 20);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '삭제',
                  onPressed: () async {
                    await _confirmAndDeleteSale(
                      Map<String, dynamic>.from(m as Map),
                      cost: 20,
                    );
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoPill(icon: Icons.sell_outlined, text: '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                  if (hasDiscount)
                    InfoPill(icon: Icons.percent, text: '할인율 ${_fmtDiscount(m['discount'])}'),
                  InfoPill(icon: Icons.trending_up_outlined, text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                  InfoPill(icon: Icons.today_outlined, text: date),
                  if (lotGiftcardName != null && lotGiftcardName.isNotEmpty)
                    InfoPill(icon: Icons.card_giftcard_outlined, text: lotGiftcardName),
                  if (branchName != null && branchName.isNotEmpty)
                    InfoPill(icon: Icons.store_outlined, text: branchName),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final lotById = <String, Map<String, dynamic>>{
      for (final l in lots)
        if (l['id'] is String) l['id'] as String: Map<String, dynamic>.from(l),
    };
    final groups = GiftcardDailyLedgerMapper.buildDayGroups(
      lots: lots,
      sales: sales,
      giftcardNames: _giftcardNames,
      lotById: lotById,
      branchNames: _branchNames,
      whereToBuyNames: _whereToBuyNames,
      cards: _cards,
      filterGiftcardIds: _selectedGiftcardIdsForDaily,
    );
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _showDailyFilterDialog,
                icon: const Icon(Icons.filter_list, color: Colors.black, size: 18),
                label: Text(
                  _selectedGiftcardIdsForDaily.isEmpty ? '전체 ▼' : '${_selectedGiftcardIdsForDaily.length}개 선택 ▼',
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  widget.onScrollChanged?.call(true);
                } else if (notification is ScrollEndNotification) {
                  widget.onScrollChanged?.call(false);
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF74512D),
                backgroundColor: Colors.white,
                child: GiftcardDailyLedger(
                  groups: groups,
                  wonFormat: _won,
                  dayFormat: _yMd,
                  onEdit: (entry) async {
                    await _confirmAndConsumePeanutsThen(() async {
                      if (entry.type == GiftcardLedgerEntryType.buy) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GiftBuyScreen(editLotId: entry.id)),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GiftSellScreen(editSaleId: entry.id)),
                        );
                      }
                      if (mounted) _load();
                    }, cost: 20);
                  },
                  onDelete: (entry) async {
                    if (entry.type == GiftcardLedgerEntryType.buy) {
                      await _confirmAndDeleteLot(Map<String, dynamic>.from(entry.raw), cost: 20);
                    } else {
                      await _confirmAndDeleteSale(Map<String, dynamic>.from(entry.raw), cost: 20);
                    }
                  },
                  onTradeToggle: (entry, trade) async {
                    await _updateTradeStatus(entry.id, trade);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadRanking() async {
    if (_rankingLoading) return;
    setState(() {
      _rankingLoading = true;
    });
    try {
      final String monthKey = DateFormat('yyyyMM').format(_selectedMonth);
      print('[GiftcardInfoScreen] 랭킹 데이터 로드 시작 - monthKey: $monthKey');
      
      final docRef = FirebaseFirestore.instance
          .collection('meta')
          .doc('rates_monthly_v2')
          .collection('rates_monthly_v2')
          .doc(monthKey);
      
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('[GiftcardInfoScreen] 랭킹 데이터 없음');
      setState(() {
        _userRankings = [];
        _rankingUpdatedAt = null;
        _rankingLoading = false;
      });
      return;
    }
    
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      setState(() {
        _userRankings = [];
        _rankingUpdatedAt = null;
        _rankingLoading = false;
      });
      return;
    }
      
      final List<dynamic> users = (data['users'] is List) 
          ? List<dynamic>.from(data['users'] as List) 
          : <dynamic>[];
      
      // uid별 합산으로 랭킹 계산
      final Map<String, Map<String, dynamic>> agg = {};
      for (final u in users) {
        if (u is! Map) continue;
        final String uid = (u['uid'] as String?) ?? '';
        if (uid.isEmpty) continue;
        final int v = (u['sellTotal'] as num?)?.toInt() ?? 0;
        final String dn = (u['displayName'] as String?) ?? '';
        final String pu = (u['photoUrl'] as String?) ?? '';
        final Map<String, dynamic> cur = agg[uid] ?? {
          'uid': uid,
          'displayName': dn,
          'photoUrl': pu,
          'sellTotal': 0
        };
        cur['sellTotal'] = ((cur['sellTotal'] as int?) ?? 0) + v;
        cur['displayName'] = dn; // 최신 정보로 업데이트
        cur['photoUrl'] = pu;
        agg[uid] = cur;
      }
      
      final List<Map<String, dynamic>> ranked = agg.values.toList()
        ..sort((a, b) => ((b['sellTotal'] as int) - (a['sellTotal'] as int)));
      
      // updatedAt 시간 가져오기
      DateTime? updatedAt;
      final updatedAtField = data['updatedAt'];
      if (updatedAtField is Timestamp) {
        updatedAt = updatedAtField.toDate();
      }
      
      print('[GiftcardInfoScreen] 랭킹 데이터 로드 완료 - ${ranked.length}명');
      
      setState(() {
        _userRankings = ranked;
        _rankingUpdatedAt = updatedAt;
        _rankingLoading = false;
      });
    } catch (e) {
      print('[GiftcardInfoScreen] 랭킹 데이터 로드 오류: $e');
      setState(() {
        _userRankings = [];
        _rankingUpdatedAt = null;
        _rankingLoading = false;
      });
    }
  }

  String _formatCurrency(int value) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(value)}원';
  }

  Widget _buildRanking() {
    final String updateTimeText = _rankingUpdatedAt != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(_rankingUpdatedAt!)
        : '';
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('사용자 랭킹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (updateTimeText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      updateTimeText,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  Text('${_userRankings.length}명', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(width: 12),
                  const Text('동의', style: TextStyle(color: Colors.black87, fontSize: 12)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _rankingAgreement,
                    activeColor: const Color(0xFF74512D),
                    onChanged: _handleRankingAgreementToggle,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _rankingLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                  ),
                )
              : _userRankings.isEmpty
                  ? const Center(
                      child: Text(
                        '랭킹 데이터가 없습니다.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _userRankings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> u = _userRankings[index];
                        final String uid = u['uid'] as String? ?? '';
                        final String name = u['displayName'] as String? ?? '익명';
                        final String? photo = u['photoUrl'] as String?;
                        final int total = (u['sellTotal'] as num?)?.toInt() ?? 0;

                        Color bg;
                        Color fg = Colors.white;
                        String label;
                        switch (index) {
                          case 0:
                            bg = const Color(0xFFFFD700);
                            label = '1';
                            break;
                          case 1:
                            bg = const Color(0xFFB0BEC5);
                            label = '2';
                            break;
                          case 2:
                            bg = const Color(0xFFCD7F32);
                            label = '3';
                            break;
                          default:
                            bg = Colors.grey.shade200;
                            fg = Colors.black87;
                            label = '${index + 1}';
                        }

                        return InkWell(
                          onTap: () {
                            if (uid.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(userUid: uid),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: bg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: (photo != null && photo.isNotEmpty)
                                      ? NetworkImage(photo)
                                      : null,
                                  child: (photo == null || photo.isEmpty)
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '총 ${_formatCurrency(total)}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatCurrency(total),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
          SegmentTabBar(
            controller: _tabController,
            labels: const ['대시보드', '달력', '일일', '랭킹'],
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                  _buildRanking(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


