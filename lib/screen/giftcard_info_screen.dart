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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
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
                Text(label,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
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

class _GiftcardInfoScreenState extends State<GiftcardInfoScreen>
    with TickerProviderStateMixin {
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
  // 대시보드 하단 고급 섹션 토글
  bool _showDashboardAdvancedSections = true;

  bool _isDashboardScrolling = false;
  bool _isCalendarScrolling = false;
  bool _isDailyListScrolling = false;

  bool _pieByAmount = true; // true: 금액, false: 수량
  Map<String, Map<String, dynamic>> _cards =
      {}; // cardId -> {credit, check, name}
  final TextEditingController _marketPriceController = TextEditingController();
  final TextEditingController _targetCostPerMileController =
      TextEditingController();

  // 대시보드 전용 캐시
  List<Map<String, dynamic>> _dashboardSalesForKpi = <Map<String, dynamic>>[];
  int _cachedSumBuy = 0;
  int _cachedSumSell = 0;
  int _cachedSumProfit = 0;
  int _cachedSumMiles = 0;
  int _cachedOpenQty = 0;
  double _cachedAvgCostPerMile = 0;
  Map<String, int> _brandAmountByGiftcard = <String, int>{};
  Map<String, int> _brandCountByGiftcard = <String, int>{};
  List<MapEntry<String, int>> _brandAmountEntries = <MapEntry<String, int>>[];
  List<MapEntry<String, int>> _brandCountEntries = <MapEntry<String, int>>[];
  List<MapEntry<String, int>> _brandRemainEntries = <MapEntry<String, int>>[];
  double _cachedWeightedAvgBuy = 0;
  int _cachedRemainingQty = 0;
  List<Map<String, dynamic>> _cachedCardEfficiencyRows =
      <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _cachedMonthlyTrendRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cachedDailyTrendRows = <Map<String, dynamic>>[];
  List<MapEntry<String, double>> _cachedBrandTurnoverRateEntries =
      <MapEntry<String, double>>[];
  List<MapEntry<String, double>> _cachedBrandRoiEntries =
      <MapEntry<String, double>>[];
  Map<double, int> _cachedDiscountBuckets = <double, int>{};
  List<Map<String, dynamic>> _cachedBrandRoiDetailed = <Map<String, dynamic>>[];
  double? _cachedCurrentPeriodAvgDiscount;
  double? _cachedPreviousPeriodAvgDiscount;
  MapEntry<String, double>? _cachedBestBrandByProfitRate;
  bool _monthlyTrendExpanded = false;
  int? _monthlyTrendExpandedYear;
  List<Map<String, dynamic>> _cachedMonthlyTrendExpandedRows =
      <Map<String, dynamic>>[];
  bool _monthlyTrendExpansionLoading = false;

  static const int _maxDailyTrendPointsAll = 120;
  static const int _monthlyTrendExpansionPeanutCost = 5;

  // 필터 관련
  Set<String> _selectedGiftcardIdsForDaily =
      {}; // 일간(통합) 탭 선택된 상품권 ID 목록 (빈 Set이면 전체)

  // 랭킹 데이터
  List<Map<String, dynamic>> _userRankings = <Map<String, dynamic>>[];
  bool _rankingLoading = false;
  DateTime? _rankingUpdatedAt; // 랭킹 데이터 업데이트 시간

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _isDashboardScrolling = false;
        _isCalendarScrolling = false;
        _isDailyListScrolling = false;
      }
      // 랭킹 탭(인덱스 3)이 선택되었을 때 데이터 로드
      if (_tabController.index == 3 &&
          _periodType == DashboardPeriodType.month) {
        _loadRanking();
      }
    });
    _load();
    _loadMinDataMonth(); // 가장 오래된 데이터 월 계산
    // 초기 캘린더 월 데이터 로드 (대시보드 월과는 독립적으로 관리)
    _loadCalendarMonth(_calendarMonth);
    // 초기 랭킹 데이터 로드
    _loadRanking();
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
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _monthlyTrendExpanded = false;
      _monthlyTrendExpandedYear = null;
      _cachedMonthlyTrendExpandedRows = <Map<String, dynamic>>[];
    });
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
        _rebuildDashboardCaches();
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _resetMonthlyTrendExpansion() {
    _monthlyTrendExpanded = false;
    _monthlyTrendExpandedYear = null;
    _cachedMonthlyTrendExpandedRows = <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _monthlyTrendRowsFromSales(
    List<Map<String, dynamic>> sales,
  ) {
    final Map<String, Map<String, int>> monthlyStats = {};
    for (final s in sales) {
      final d = s['sellDate'];
      if (d is! Timestamp) continue;
      final dt = d.toDate();
      final month = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final monthEntry = monthlyStats.putIfAbsent(
          month, () => {'profit': 0, 'sell': 0, 'miles': 0});
      monthEntry['profit'] = (monthEntry['profit'] ?? 0) + _asInt(s['profit']);
      monthEntry['sell'] = (monthEntry['sell'] ?? 0) + _asInt(s['sellTotal']);
      monthEntry['miles'] = (monthEntry['miles'] ?? 0) + _asInt(s['miles']);
    }
    final monthKeys = monthlyStats.keys.toList()..sort();
    return monthKeys.map((key) => {'key': key, ...monthlyStats[key]!}).toList();
  }

  Future<void> _loadMonthlyTrendExpandedData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_periodType != DashboardPeriodType.month) return;
    final selectedYear = _selectedMonth.year;
    if (_monthlyTrendExpandedYear == selectedYear &&
        _cachedMonthlyTrendExpandedRows.isNotEmpty) {
      if (mounted) {
        setState(() {
          _monthlyTrendExpanded = true;
          _monthlyTrendExpansionLoading = false;
        });
      }
      return;
    }

    setState(() {
      _monthlyTrendExpansionLoading = true;
    });
    try {
      final data = await GiftcardService.loadInfoData(
        uid: uid,
        periodType: DashboardPeriodType.year,
        selectedMonth: _selectedMonth,
        selectedYear: selectedYear,
      );
      final expandedRows = _monthlyTrendRowsFromSales(data.sales);
      setState(() {
        _cachedMonthlyTrendExpandedRows = expandedRows;
        _monthlyTrendExpandedYear = selectedYear;
        _monthlyTrendExpanded = true;
      });
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '월별 추세 확장 데이터를 불러오지 못했습니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
      if (mounted) {
        _monthlyTrendExpanded = false;
        _cachedMonthlyTrendExpandedRows = <Map<String, dynamic>>[];
        _monthlyTrendExpandedYear = null;
      }
    } finally {
      if (mounted) {
        setState(() {
          _monthlyTrendExpansionLoading = false;
        });
      }
    }
  }

  String _monthlyTrendExpandedScopeLabel() {
    final now = DateTime.now();
    final selectedYear = _selectedMonth.year;
    if (selectedYear == now.year) {
      final month = _selectedMonth.month.toString().padLeft(2, '0');
      if (_selectedMonth.month <= 1) {
        return '${selectedYear}년 전체';
      }
      return '${selectedYear}년 1월 ~ ${selectedYear}년 $month월';
    }
    return '${selectedYear}년 전체';
  }

  Future<void> _confirmAndExpandMonthlyTrend() async {
    if (_periodType != DashboardPeriodType.month) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await UserService.getUserFromFirestore(uid);
      final currentPeanuts = _asInt(userData?['peanutCount']);
      if (currentPeanuts < _monthlyTrendExpansionPeanutCost) {
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

      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '확인',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '월별 차트를 ${_monthlyTrendExpandedScopeLabel()} 범위로 확장하려면 땅콩 '
              '${_monthlyTrendExpansionPeanutCost}개를 소모합니다.\n\n'
              '진행하시겠습니까?',
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  '취소',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  '확인',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
      if (ok != true) return;

      await UserService.updatePeanutCount(
        uid,
        currentPeanuts - _monthlyTrendExpansionPeanutCost,
      );
      await _loadMonthlyTrendExpandedData();
      if (mounted) {
        Fluttertoast.showToast(
          msg: '땅콩 ${_monthlyTrendExpansionPeanutCost}개가 사용되었습니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '월별 차트 확장 처리 중 오류가 발생했습니다.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  List<Map<String, dynamic>> _getMonthlyTrendChartRows() {
    List<Map<String, dynamic>> rows = _monthlyTrendRows();
    if (_monthlyTrendExpanded &&
        _periodType == DashboardPeriodType.month &&
        _cachedMonthlyTrendExpandedRows.isNotEmpty) {
      rows = _cachedMonthlyTrendExpandedRows;
    }

    if (_periodType != DashboardPeriodType.month) return rows;

    final selectedYear = _selectedMonth.year;
    final now = DateTime.now();
    final maxMonth = (selectedYear == now.year) ? now.month : 12;
    return rows.where((r) {
      final key = r['key'] as String? ?? '';
      final parts = key.split('-');
      if (parts.length != 2) return false;
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      if (year != selectedYear) return false;
      if (month < 1 || month > maxMonth) return false;
      return true;
    }).toList();
  }

  Future<String?> _askTemplateName(String initialName) async {
    final nameController = TextEditingController(text: initialName);
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('템플릿 이름 입력',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '템플릿명',
            labelStyle: TextStyle(color: Colors.black54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('저장',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBuyEntryAsTemplate(GiftcardLedgerEntry entry) async {
    if (entry.type != GiftcardLedgerEntryType.buy) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final String defaultName =
        '${DateFormat('yyyyMMdd').format(entry.dateTime)} 구매건';
    final String? name = await _askTemplateName(defaultName);
    if (name == null || name.isEmpty) return;

    final payload = {
      'giftcardId': entry.raw['giftcardId'],
      'cardId': entry.raw['cardId'],
      'whereToBuyId': entry.raw['whereToBuyId'],
      'payType': entry.raw['payType'],
      'faceValue': _asInt(entry.raw['faceValue']),
      'qty': _asInt(entry.raw['qty']),
      'priceInputMode': 'buyUnit',
      'buyUnit': _asInt(entry.raw['buyUnit']),
      'discount': _asDouble(entry.raw['discount']),
      'memo': (entry.raw['memo'] as String?)?.trim() ?? '',
      'buyDate': entry.raw['buyDate'] is Timestamp
          ? entry.raw['buyDate']
          : Timestamp.fromDate(entry.dateTime),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gift_templates')
          .add({
        'name': name,
        'nameLower': name.toLowerCase(),
        'pinned': false,
        'useCount': 0,
        'lastUsedAt': null,
        'dateMode': 'manual',
        'payload': payload,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      });
      Fluttertoast.showToast(msg: '템플릿으로 저장되었습니다.');
      if (mounted) _load();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 저장 실패: $e');
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
        _calendarLots =
            lotsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _calendarSales =
            salesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
    final DateTime effectiveMinMonth =
        _minDataMonth ?? DateTime(now.year, now.month);
    final DateTime minMonth =
        DateTime(effectiveMinMonth.year, effectiveMinMonth.month);
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
                        color:
                            selected ? const Color(0xFF74512D) : Colors.black26,
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
                  _resetMonthlyTrendExpansion();
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
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (context, index) {
                  final int y = years[index];
                  final bool isCurrent =
                      _periodType == DashboardPeriodType.year &&
                          _selectedYear == y;
                  return ListTile(
                    title: Text(
                      '$y년도 전체',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      _resetMonthlyTrendExpansion();
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
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (context, index) {
                  final d = months[index];
                  final bool isCurrent =
                      _periodType == DashboardPeriodType.month &&
                          d.year == _selectedMonth.year &&
                          d.month == _selectedMonth.month;
                  return ListTile(
                    title: Text(
                      _formatYearMonth(d),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      _resetMonthlyTrendExpansion();
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

  void _rebuildDashboardCaches() {
    final lotIds = _lots
        .map((e) => e['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final Map<String, int> brandAmount = {};
    final Map<String, int> brandCount = {};
    final Map<String, int> brandTotalQty = {};
    final Map<String, int> brandSoldQty = {};
    final Map<String, int> remainByBrand = {};
    final Map<String, int> brandBuyTotal = {};
    final Map<String, int> brandSellTotal = {};
    final Map<String, String> lotToBrand = {
      for (final l in _lots)
        if ((l['id'] as String?)?.isNotEmpty ?? false)
          l['id'] as String: (l['giftcardId'] as String?) ?? '기타',
    };
    final Map<String, String> lotToCard = {
      for (final l in _lots)
        if ((l['id'] as String?)?.isNotEmpty ?? false)
          l['id'] as String: (l['cardId'] as String? ?? ''),
    };

    final Map<String, Map<String, int>> monthlyStats = {};
    final Map<DateTime, Map<String, int>> dailyStats = {};
    final Map<double, int> discountBuckets = {
      for (double v = 2.0;
          v <= 3.5;
          v = double.parse((v + 0.1).toStringAsFixed(1)))
        v: 0,
    };

    final dashboardSales = <Map<String, dynamic>>[];
    int sumSell = 0;
    int sumProfit = 0;
    int sumMiles = 0;
    int sumSoldMiles = 0;
    int sumBuy = 0;
    int openQty = 0;
    int remainingQty = 0;
    int weightedBuyTotal = 0;
    int weightedQtyTotal = 0;

    for (final lot in _lots) {
      final qty = _asInt(lot['qty']);
      final buyUnit = _asInt(lot['buyUnit']);
      final brand = (lot['giftcardId'] as String?) ?? '기타';
      final status = (lot['status'] as String?) ?? 'open';
      final buyTs = lot['buyDate'];

      sumBuy += buyUnit * qty;
      sumMiles += _effectiveLotMiles(lot);
      brandAmount[brand] = (brandAmount[brand] ?? 0) + (buyUnit * qty);
      brandCount[brand] = (brandCount[brand] ?? 0) + qty;
      brandTotalQty[brand] = (brandTotalQty[brand] ?? 0) + qty;
      brandBuyTotal[brand] = (brandBuyTotal[brand] ?? 0) + buyUnit * qty;

      if (status == 'open') {
        openQty += qty;
      }
      if (status == 'sold') {
        brandSoldQty[brand] = (brandSoldQty[brand] ?? 0) + qty;
      } else {
        remainByBrand[brand] = (remainByBrand[brand] ?? 0) + qty;
        remainingQty += qty;
        weightedBuyTotal += buyUnit * qty;
        weightedQtyTotal += qty;
      }

      if (buyTs is Timestamp) {
        final d = buyTs.toDate();
        final day = DateTime(d.year, d.month, d.day);
        final dayEntry = dailyStats.putIfAbsent(
            day, () => {'buy': 0, 'sell': 0, 'miles': 0});
        dayEntry['buy'] = (dayEntry['buy'] ?? 0) + buyUnit * qty;
      }
    }

    for (final s in _sales) {
      final lotId = s['lotId'] as String?;
      if (lotId != null && lotIds.contains(lotId)) {
        dashboardSales.add(s);
        sumSell += _asInt(s['sellTotal']);
        sumProfit += _asInt(s['profit']);
        sumSoldMiles += _asInt(s['miles']);

        final d = s['sellDate'];
        if (d is Timestamp) {
          final dt = d.toDate();
          final month = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          final monthEntry = monthlyStats.putIfAbsent(
              month, () => {'profit': 0, 'sell': 0, 'miles': 0});
          monthEntry['profit'] =
              (monthEntry['profit'] ?? 0) + _asInt(s['profit']);
          monthEntry['sell'] =
              (monthEntry['sell'] ?? 0) + _asInt(s['sellTotal']);
          monthEntry['miles'] = (monthEntry['miles'] ?? 0) + _asInt(s['miles']);

          final day = DateTime(dt.year, dt.month, dt.day);
          final dayEntry = dailyStats.putIfAbsent(
              day, () => {'buy': 0, 'sell': 0, 'miles': 0});
          dayEntry['sell'] = (dayEntry['sell'] ?? 0) + _asInt(s['sellTotal']);
          dayEntry['miles'] = (dayEntry['miles'] ?? 0) + _asInt(s['miles']);
        }

        final discount = (s['discount'] as num?)?.toDouble();
        if (discount != null) {
          final bucket = (discount * 10).round() / 10.0;
          if (discountBuckets.containsKey(bucket)) {
            discountBuckets[bucket] = (discountBuckets[bucket] ?? 0) + 1;
          }
        }

        final brand = lotToBrand[lotId];
        if (brand != null) {
          brandSellTotal[brand] =
              (brandSellTotal[brand] ?? 0) + _asInt(s['sellTotal']);
        }
      }
    }

    final Map<String, double> cardEfficiencySum = {};
    final Map<String, int> cardEfficiencyCnt = {};
    for (final s in dashboardSales) {
      final lotId = s['lotId'] as String?;
      if (lotId == null) continue;
      final cardId = lotToCard[lotId] ?? '';
      if (cardId.isEmpty) continue;
      final t = (s['costPerMile'] as num?)?.toDouble();
      if (t == null) continue;
      cardEfficiencySum[cardId] = (cardEfficiencySum[cardId] ?? 0) + t;
      cardEfficiencyCnt[cardId] = (cardEfficiencyCnt[cardId] ?? 0) + 1;
    }

    final monthKeys = monthlyStats.keys.toList()..sort();
    final List<Map<String, dynamic>> monthlyRows =
        monthKeys.map((key) => {'key': key, ...monthlyStats[key]!}).toList();

    final List<DateTime> dailyKeys = dailyStats.keys.toList()..sort();
    final List<Map<String, dynamic>> allDailyRows = dailyKeys.map((date) {
      final entry = dailyStats[date]!;
      return {
        'date': date,
        'label': DateFormat('MM/dd').format(date),
        'buy': entry['buy'] ?? 0,
        'sell': entry['sell'] ?? 0,
        'miles': entry['miles'] ?? 0,
      };
    }).toList();
    final int maxDailyPoints = _maxDailyTrendPoints();
    final List<Map<String, dynamic>> dailyRows =
        (allDailyRows.length > maxDailyPoints)
            ? allDailyRows.sublist(allDailyRows.length - maxDailyPoints)
            : allDailyRows;

    final List<MapEntry<String, double>> brandTurnoverEntries = [];
    for (final e in brandTotalQty.entries) {
      final total = e.value;
      if (total <= 0) continue;
      final sold = brandSoldQty[e.key] ?? 0;
      brandTurnoverEntries.add(MapEntry(e.key, sold / total * 100));
    }
    brandTurnoverEntries.sort((a, b) => b.value.compareTo(a.value));

    final List<MapEntry<String, double>> brandRoiEntries = [];
    final List<Map<String, dynamic>> brandRoiDetailed = [];
    brandBuyTotal.forEach((brand, buyTotal) {
      if (buyTotal == 0) return;
      final sellTotal = brandSellTotal[brand] ?? 0;
      final roi = ((sellTotal - buyTotal) / buyTotal) * 100;
      brandRoiEntries.add(MapEntry(brand, roi));
      brandRoiDetailed.add({
        'brand': brand,
        'sell': sellTotal.toDouble(),
        'roi': roi,
        'buy': buyTotal.toDouble()
      });
    });
    brandRoiEntries.sort((a, b) => b.value.compareTo(a.value));

    final range = getGiftcardPeriodRange(
      periodType: _periodType,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
    );
    double? currentDiscountAvg;
    double? previousDiscountAvg;
    if (range.start != null && range.end != null && dashboardSales.isNotEmpty) {
      currentDiscountAvg =
          _averageDiscountInRange(dashboardSales, range.start!, range.end!);
      if (_periodType == DashboardPeriodType.month) {
        final prev = DateTime(range.start!.year, range.start!.month - 1);
        previousDiscountAvg = _averageDiscountInRange(
          dashboardSales,
          DateTime(prev.year, prev.month),
          DateTime(range.start!.year, range.start!.month),
        );
      } else if (_periodType == DashboardPeriodType.year) {
        previousDiscountAvg = _averageDiscountInRange(
          dashboardSales,
          DateTime(_selectedYear - 1, 1, 1),
          DateTime(_selectedYear, 1, 1),
        );
      }
    }

    final List<Map<String, dynamic>> cardEfficiencyRows = [];
    cardEfficiencySum.forEach((cardId, total) {
      final c = cardEfficiencyCnt[cardId] ?? 1;
      final avg = total / c;
      final name = _cards[cardId]?['name'] as String? ?? cardId;
      cardEfficiencyRows.add({'cardId': cardId, 'name': name, 'avgT': avg});
    });
    cardEfficiencyRows
        .sort((a, b) => (a['avgT'] as double).compareTo(b['avgT'] as double));

    final List<MapEntry<String, int>> brandAmountEntries = brandAmount.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<MapEntry<String, int>> brandCountEntries =
        brandCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final List<MapEntry<String, int>> remainEntries = remainByBrand.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _dashboardSalesForKpi = dashboardSales;
    _cachedSumBuy = sumBuy;
    _cachedSumSell = sumSell;
    _cachedSumProfit = sumProfit;
    _cachedSumMiles = sumMiles;
    _cachedOpenQty = openQty;
    _cachedAvgCostPerMile = sumSoldMiles == 0 ? 0 : (-sumProfit / sumSoldMiles);
    _brandAmountByGiftcard = brandAmount;
    _brandCountByGiftcard = brandCount;
    _brandAmountEntries = brandAmountEntries;
    _brandCountEntries = brandCountEntries;
    _brandRemainEntries = remainEntries;
    _cachedWeightedAvgBuy =
        weightedQtyTotal == 0 ? 0 : (weightedBuyTotal / weightedQtyTotal);
    _cachedRemainingQty = remainingQty;
    _cachedCardEfficiencyRows = cardEfficiencyRows;
    _cachedMonthlyTrendRows = monthlyRows;
    _cachedDailyTrendRows = dailyRows;
    _cachedBrandTurnoverRateEntries = brandTurnoverEntries;
    _cachedBrandRoiEntries = brandRoiEntries;
    _cachedDiscountBuckets = discountBuckets;
    _cachedBrandRoiDetailed = brandRoiDetailed;
    _cachedCurrentPeriodAvgDiscount = currentDiscountAvg;
    _cachedPreviousPeriodAvgDiscount = previousDiscountAvg;
    _cachedBestBrandByProfitRate =
        _cachedBrandRoiEntries.isNotEmpty ? _cachedBrandRoiEntries.first : null;
  }

  /// 대시보드 KPI(평균마일원가 등)는 "구매일(기간) 기준"으로 집계한다.
  /// - lots: 선택 기간에 구매한 lot만 들어있음 (GiftcardService에서 buyDate 기준 필터)
  /// - sales: 일간/내역 탭을 위해 sellDate 기준 판매도 섞여 들어올 수 있음
  /// 따라서 KPI 집계는 "선택 기간 lots에 연결된 판매(lotId)"만 사용한다.
  List<Map<String, dynamic>> _dashboardSales() {
    return _dashboardSalesForKpi;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _effectiveLotMiles(Map<String, dynamic> lot) {
    final storedMiles = _asInt(lot['miles']);
    if (storedMiles > 0) return storedMiles;

    final buyTotal = _asInt(lot['buyUnit']) * _asInt(lot['qty']);
    if (buyTotal <= 0) return 0;

    int rule = _asInt(lot['mileRuleUsedPerMileKRW']);
    if (rule <= 0) {
      final payType = (lot['payType'] as String?) ?? '신용';
      final cardId = (lot['cardId'] as String?) ?? '';
      final card = _cards[cardId];
      if (card != null) {
        rule = payType == '신용' ? _asInt(card['credit']) : _asInt(card['check']);
      }
    }

    if (rule <= 0) return 0;
    return (buyTotal / rule).round();
  }

  int _sumBuy() => _cachedSumBuy;
  int _sumSell() => _cachedSumSell;
  int _sumProfit() => _cachedSumProfit;
  int _sumMiles() => _cachedSumMiles;
  String _fmtWon(num v) => '${_won.format(v)}원';
  String _fmtDiscount(dynamic v) {
    final double d = _asDouble(v);
    if (d == 0) return '0%';
    final bool isInt = d == d.roundToDouble();
    return '${isInt ? d.toStringAsFixed(0) : d.toStringAsFixed(2)}%';
  }

  int _openQtyTotal() => _cachedOpenQty;

  // 브랜드별 분포(금액 기준)
  Map<String, int> _pieByBrandAmount() => _brandAmountByGiftcard;

  Map<String, int> _pieByBrandCount() => _brandCountByGiftcard;

  List<Map<String, dynamic>> _monthlyTrendRows() => _cachedMonthlyTrendRows;
  List<Map<String, dynamic>> _dailyTrendRows() => _cachedDailyTrendRows;
  List<MapEntry<String, double>> _brandTurnoverRows() =>
      _cachedBrandTurnoverRateEntries;
  List<MapEntry<String, double>> _brandRoiRows() => _cachedBrandRoiEntries;
  Map<double, int> _discountBuckets() => _cachedDiscountBuckets;

  int _maxDailyTrendPoints() {
    switch (_periodType) {
      case DashboardPeriodType.month:
        return 31;
      case DashboardPeriodType.year:
        return 180;
      case DashboardPeriodType.all:
        return _maxDailyTrendPointsAll;
    }
  }

  double? _averageDiscountInRange(
    List<Map<String, dynamic>> sales,
    DateTime start,
    DateTime end,
  ) {
    final List<double> values = [];
    for (final s in sales) {
      final ts = s['sellDate'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      if (d.isBefore(start) || !d.isBefore(end)) continue;
      final discount = (s['discount'] as num?)?.toDouble();
      if (discount == null) continue;
      values.add(discount);
    }
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
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

  Future<void> _showSectionInfoDialog({
    required String title,
    required String description,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          description,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '확인',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String description,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () => _showSectionInfoDialog(
                  title: title,
                  description: description,
                ),
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      Icon(Icons.info_outline, size: 18, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing,
        ],
      ],
    );
  }

  Widget _buildDashboard() {
    final sumBuy = _sumBuy();
    final sumSell = _sumSell();
    final sumProfit = _sumProfit();
    final sumMiles = _sumMiles();
    final avgCostPerMile = _cachedAvgCostPerMile;

    final bool showAdvanced = _showDashboardAdvancedSections;
    final List<MapEntry<String, int>> brandEntries = showAdvanced
        ? (_pieByAmount ? _brandAmountEntries : _brandCountEntries)
        : const <MapEntry<String, int>>[];
    final String brandDistLabel =
        _pieByAmount ? '브랜드별 분포 (금액 기준)' : '브랜드별 분포 (수량 기준)';

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (!_isDashboardScrolling) {
            _isDashboardScrolling = true;
            widget.onScrollChanged?.call(true);
          }
        } else if (notification is ScrollEndNotification) {
          if (_isDashboardScrolling) {
            _isDashboardScrolling = false;
            widget.onScrollChanged?.call(false);
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF74512D),
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // 월 헤더: "YYYY년도 MM월"  |  "MM월 ▼" 필터 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dashboardTitleText(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  TextButton.icon(
                    onPressed: _showMonthPicker,
                    icon: const Icon(Icons.filter_list,
                        color: Colors.black, size: 18),
                    label: Text(
                      _dashboardFilterLabel(),
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                    child: _KpiValue(
                        label: '총 매입금액',
                        value: _fmtWon(sumBuy),
                        icon: Icons.call_received_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressScale(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openKpiDetail(GiftcardKpiType.totalSell),
                    child: _KpiValue(
                        label: '총 판매금액',
                        value: _fmtWon(sumSell),
                        icon: Icons.call_made_outlined),
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
                    child: _KpiValue(
                        label: '총 손익',
                        value: _fmtWon(sumProfit),
                        icon: Icons.trending_up_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressScale(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openKpiDetail(GiftcardKpiType.totalMiles),
                    child: _KpiValue(
                        label: '누적 마일',
                        value: sumMiles.toString(),
                        icon: Icons.stars_outlined),
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
                    child: _KpiValue(
                        label: '평균마일원가(원/마일)',
                        value: avgCostPerMile.toStringAsFixed(2),
                        icon: Icons.percent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressScale(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openKpiDetail(GiftcardKpiType.openQty),
                    child: _KpiValue(
                        label: '미판매 수량',
                        value: '${_openQtyTotal()}장',
                        icon: Icons.account_balance_wallet_outlined),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  _GiftBanner(adUnitId: AdHelper.giftDashboardBannerAdUnitId),
            ),

            if (showAdvanced) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: brandDistLabel,
                description:
                    '브랜드별로 현재 기간의 보유량을 수량 또는 금액으로 분포를 확인해요. 토글로 기준을 바꿔 확인 가능합니다.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
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
              ),
              const SizedBox(height: 8),
              if (brandEntries.isEmpty)
                const Text('데이터가 부족합니다.',
                    style: TextStyle(color: Colors.black54))
              else
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(enabled: true),
                      sections: [
                        for (int i = 0; i < brandEntries.length; i++)
                          PieChartSectionData(
                            title: brandEntries[i].key,
                            value: brandEntries[i].value.toDouble(),
                            color:
                                Colors.primaries[i % Colors.primaries.length],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
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
                            color:
                                Colors.primaries[i % Colors.primaries.length],
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
              _buildSectionHeader(
                title: '브랜드별 잔여 소진율',
                description:
                    '브랜드별 잔여 수량 대비 이미 판매된 수량 비율을 보여줘요. 소진율이 높을수록 회전이 빠른 브랜드에요.',
              ),
              const SizedBox(height: 8),
              _buildBrandTurnoverBars(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '일별 매입/판매/마일 추세',
                description:
                    '일자별 매입금액, 판매금액, 누적 마일 변화를 보여줘요. 매출 변동 타이밍을 쉽게 파악할 수 있어요.',
              ),
              const SizedBox(height: 8),
              _buildDailyTrendChart(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '브랜드별 매입 대비 매출 ROI',
                description:
                    '브랜드별로 매입총액 대비 매출차익률을 계산해 보여줘요. 투자 효율을 비교할 때 사용해요.',
              ),
              const SizedBox(height: 8),
              _buildBrandRoiBars(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '카드별 평균 수익률 비교 (원/마일, 낮을수록 우수)',
                description:
                    '카드별 처리 건의 평균 원/마일 원가를 계산해 보여줘요. 값이 낮을수록 매입비 대비 수익성이 좋아요.',
              ),
              const SizedBox(height: 8),
              _buildCardEfficiencyBars(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '할인율 히스토그램',
                description:
                    '판매 내역의 할인율 구간별 빈도를 막대 형태로 보여줘요. 할인율 분포를 파악해 운영 전략에 반영할 수 있어요.',
              ),
              const SizedBox(height: 8),
              _buildDiscountHistogram(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '인사이트',
                description: '선택 기간 기준 요약 지표와 전 기간 비교 포인트를 보여줘요.',
              ),
              const SizedBox(height: 8),
              _buildInsightCards(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '월별 손익/판매/마일 추세',
                description:
                    '월 단위로 매입 대비 판매 추세를 손익, 판매금액, 획득 마일로 보여줘요. 기간별 흐름을 한눈에 확인해요.',
              ),
              const SizedBox(height: 8),
              _buildMonthlyTrendChart(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                title: '재고 현황',
                description: '현재 기간 기준 브랜드별 잔여 수량을 보여줘요.',
              ),
              const SizedBox(height: 8),
              _buildInventorySection(),
            ],
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _brandRemainQty() {
    return _brandRemainEntries;
  }

  double _weightedAvgBuy() {
    return _cachedWeightedAvgBuy;
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
    return _cachedRemainingQty;
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
          ? (payType == '신용'
              ? (_cards[cardId]!['credit'] ?? 0)
              : (_cards[cardId]!['check'] ?? 0))
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
    return _cachedCardEfficiencyRows;
  }

  Widget _buildCardEfficiencyBars() {
    final rows = _avgTByCard();
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }
    final double maxVal = rows
        .map<double>((e) => (e['avgT'] as double))
        .fold(0, (p, e) => e > p ? e : p);
    return Column(
      children: [
        for (final r in rows) ...[
          Row(
            children: [
              Expanded(
                child: Text('${r['name']}',
                    style: const TextStyle(color: Colors.black87)),
              ),
              Text((r['avgT'] as double).toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  Container(
                    width: width * ratio,
                    height: 10,
                    decoration: BoxDecoration(
                        color: const Color(0xFF74512D),
                        borderRadius: BorderRadius.circular(6)),
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

  Widget _buildMonthlyTrendChart() {
    final rows = _getMonthlyTrendChartRows();
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }

    final List<FlSpot> profitSpots = [];
    final List<FlSpot> sellSpots = [];
    final List<FlSpot> milesSpots = [];
    double minY = 0;
    double maxY = 0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final x = i.toDouble();
      final double profit = (r['profit'] as int).toDouble();
      final double sell = (r['sell'] as int).toDouble();
      final double miles = (r['miles'] as int).toDouble();
      for (final v in <double>[profit, sell, miles]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
      profitSpots.add(FlSpot(x, profit));
      sellSpots.add(FlSpot(x, sell));
      milesSpots.add(FlSpot(x, miles));
    }

    final firstMonth = rows.first['key'] as String? ?? '';
    final lastMonth = rows.last['key'] as String? ?? '';

    final axisMin = minY;
    final axisMax = (maxY == 0 ? 1 : maxY) * 1.1;
    final yRange = (axisMax - axisMin).abs();
    final yInterval = (yRange / 4).clamp(1.0, double.infinity);

    String axisLabel(double value) {
      final double abs = value.abs();
      final String prefix = value < 0 ? '-' : '';
      if (abs >= 100000000) {
        return '$prefix${(abs / 100000000).toStringAsFixed(1)}억';
      }
      if (abs >= 10000) {
        return '$prefix${(abs / 10000).toStringAsFixed(1)}만';
      }
      if (abs >= 1000) {
        return '$prefix${abs.round()}';
      }
      return '$prefix${value.toStringAsFixed(0)}';
    }

    Widget legendItem(String title, String desc, Color color) {
      return Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$title: $desc',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      );
    }

    final bool shouldDimChart =
        _periodType == DashboardPeriodType.month && !_monthlyTrendExpanded;
    final String scopeHint = _monthlyTrendExpandedScopeLabel();

    final Widget chartArea = SizedBox(
      width: double.infinity,
      height: 220,
      child: Stack(
        children: [
          RepaintBoundary(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            axisLabel(value),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: axisMin,
                maxY: axisMax,
                lineBarsData: [
                  LineChartBarData(
                    spots: sellSpots,
                    isCurved: false,
                    color: const Color(0xFF5E9EFF),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: profitSpots,
                    isCurved: false,
                    color: const Color(0xFFFFA000),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: milesSpots,
                    isCurved: false,
                    color: const Color(0xFF4CAF50),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          if (shouldDimChart) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(0.52),
                ),
              ),
            ),
            if (_monthlyTrendExpansionLoading)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF74512D),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _confirmAndExpandMonthlyTrend,
                    icon: const Icon(
                      Icons.lock_open_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      '$scopeHint 보기 (땅콩 ${_monthlyTrendExpansionPeanutCost}개)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF74512D),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chartArea,
        const SizedBox(height: 8),
        Text(
          'X축: 월 (${firstMonth.isEmpty ? '월' : firstMonth} ~ '
          '${lastMonth.isEmpty ? '월' : lastMonth}), Y축: 값(상대 비교용 스케일)',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        const Text(
          '세로축 단위: 파란선·주황선 = 원(₩), 초록선 = 마일',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            legendItem('파란선', '매출액(판매금액)', const Color(0xFF5E9EFF)),
            legendItem('주황선', '손익', const Color(0xFFFFA000)),
            legendItem('초록선', '마일(누적마일)', const Color(0xFF4CAF50)),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyTrendChart() {
    final rows = _dailyTrendRows();
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }

    double minY = 0;
    double maxY = 0;
    final List<FlSpot> buySpots = [];
    final List<FlSpot> sellSpots = [];
    final List<FlSpot> milesSpots = [];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final x = i.toDouble();
      final double buy = (r['buy'] as int? ?? 0).toDouble();
      final double sell = (r['sell'] as int? ?? 0).toDouble();
      final double miles = (r['miles'] as int? ?? 0).toDouble();
      for (final v in <double>[buy, sell, miles]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
      buySpots.add(FlSpot(x, buy));
      sellSpots.add(FlSpot(x, sell));
      milesSpots.add(FlSpot(x, miles));
    }

    final firstDay = rows.first['label'] as String? ??
        (rows.first['date'] is DateTime
            ? DateFormat('MM/dd').format(rows.first['date'] as DateTime)
            : '');
    final lastDay = rows.last['label'] as String? ??
        (rows.last['date'] is DateTime
            ? DateFormat('MM/dd').format(rows.last['date'] as DateTime)
            : '');

    final axisMin = minY;
    final axisMax = (maxY == 0 ? 1 : maxY) * 1.1;
    final yRange = (axisMax - axisMin).abs();
    final yInterval = (yRange / 4).clamp(1.0, double.infinity);

    String axisLabel(double value) {
      final double abs = value.abs();
      final String prefix = value < 0 ? '-' : '';
      if (abs >= 100000000) {
        return '$prefix${(abs / 100000000).toStringAsFixed(1)}억';
      }
      if (abs >= 10000) {
        return '$prefix${(abs / 10000).toStringAsFixed(1)}만';
      }
      if (abs >= 1000) {
        return '$prefix${abs.round()}';
      }
      return '$prefix${value.toStringAsFixed(0)}';
    }

    Widget legendItem(String title, String desc, Color color) {
      return Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$title: $desc',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            axisLabel(value),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: axisMin,
                maxY: axisMax,
                lineBarsData: [
                  LineChartBarData(
                    spots: buySpots,
                    isCurved: false,
                    color: const Color(0xFF4CAF50),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: sellSpots,
                    isCurved: false,
                    color: const Color(0xFF5E9EFF),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: milesSpots,
                    isCurved: false,
                    color: const Color(0xFFFFA000),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'X축: 일 (${firstDay.isEmpty ? '일' : firstDay} ~ '
          '${lastDay.isEmpty ? '일' : lastDay}), Y축: 값(상대 비교용 스케일)',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        const Text(
          '세로축 단위: 초록선 = 원(₩), 파란선 = 원(₩), 주황선 = 마일',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            legendItem('초록선', '매입금액', const Color(0xFF4CAF50)),
            legendItem('파란선', '판매금액', const Color(0xFF5E9EFF)),
            legendItem('주황선', '마일(획득마일)', const Color(0xFFFFA000)),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandTurnoverBars() {
    final rows = _brandTurnoverRows();
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }
    final takeCount = rows.length > 12 ? 12 : rows.length;
    final maxVal = rows.take(takeCount).first.value == 0
        ? 1
        : rows.take(takeCount).first.value;

    return Column(
      children: [
        for (final row in rows.take(takeCount)) ...[
          Row(
            children: [
              Expanded(
                child: Text(row.key,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
              Text(
                '${row.value.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, constraints) {
              final width = constraints.maxWidth;
              final ratio = (row.value / maxVal).clamp(0.0, 1.0);
              return Container(
                height: 9,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width * ratio,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFF74512D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildBrandRoiBars() {
    final rows = _cachedBrandRoiDetailed;
    if (rows.isEmpty) {
      return const Text('데이터가 부족합니다.', style: TextStyle(color: Colors.black54));
    }
    final takeCount = rows.length > 12 ? 12 : rows.length;
    final maxAbs = rows
        .take(takeCount)
        .map((e) => (e['roi'] as double).abs())
        .fold<double>(0, (p, v) => v > p ? v : p);
    final base = (maxAbs == 0 ? 1 : maxAbs);
    return Column(
      children: [
        for (final row in rows.take(takeCount)) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  row['brand'] as String,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              Text(
                '${(row['roi'] as double).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, constraints) {
              final width = constraints.maxWidth;
              final ratio = ((row['roi'] as double).abs() / base);
              final positive = (row['roi'] as double) >= 0;
              return Container(
                height: 9,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width * ratio,
                    height: 9,
                    decoration: BoxDecoration(
                      color: positive
                          ? const Color(0xFF74512D)
                          : const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDiscountHistogram() {
    final buckets = _discountBuckets();
    final entries = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxCount =
        entries.map((e) => e.value).fold<int>(0, (p, v) => v > p ? v : p);
    if (maxCount == 0) {
      return const Text('할인율 데이터가 부족합니다.',
          style: TextStyle(color: Colors.black54));
    }

    final first = entries.first.key;
    final last = entries.last.key;
    final descItem = entries.length == 1
        ? '${first.toStringAsFixed(1)}%'
        : '${first.toStringAsFixed(1)}% ~ ${last.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in entries) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, constraints) {
                            final ratio = entry.value / maxCount;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                height: constraints.maxHeight * ratio * 0.88,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF74512D),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'X축: 할인율 구간($descItem), Y축: 건수(판매 건 수)',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        const Text(
          '해석: 각 막대는 해당 할인율 구간의 판매 빈도를 의미하며, 막대가 클수록 그 구간에서의 판매가 많다는 뜻입니다.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildInsightCards() {
    final cur = _cachedCurrentPeriodAvgDiscount;
    final prev = _cachedPreviousPeriodAvgDiscount;
    final best = _cachedBestBrandByProfitRate;
    final delta = (cur != null && prev != null) ? (cur - prev) : null;

    String discountText() {
      if (cur == null) return '선택 기간 평균 할인율: 데이터 없음';
      final curStr = cur.toStringAsFixed(2);
      final scope = switch (_periodType) {
        DashboardPeriodType.month =>
          '${_selectedMonth.year}.${_selectedMonth.month.toString().padLeft(2, '0')}',
        DashboardPeriodType.year => '$_selectedYear년도',
        DashboardPeriodType.all => '전체 기간',
      };
      if (delta == null) {
        return '선택 기간 평균 할인율($scope): $curStr%';
      }
      final sign = delta >= 0 ? '+' : '';
      return '선택 기간 평균 할인율($scope): $curStr% (비교 기간 대비 $sign${delta.toStringAsFixed(2)}%)';
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
            Expanded(
                child:
                    Text(text, style: const TextStyle(color: Colors.black87))),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in remainList)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                  color: Colors.white,
                ),
                child: Text('${e.key}: ${e.value}장',
                    style: const TextStyle(color: Colors.black)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('가중평균 매입가: ${_won.format(avgBuy.round())}원 / 장, 잔여 ${remainQty}장',
            style: const TextStyle(color: Colors.black87)),
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
        final d =
            DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        byDay.putIfAbsent(d, () => []).add({...s, 'type': 'sale'});
      }
    }
    for (final l in _calendarLots) {
      final ts = l['buyDate'];
      if (ts is Timestamp) {
        final d =
            DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
        byDay.putIfAbsent(d, () => []).add({...l, 'type': 'lot'});
      }
    }

    final selectedItems = (_selectedDay != null)
        ? (byDay[_selectedDay!] ?? [])
        : const <Map<String, dynamic>>[];

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          locale: 'ko_KR',
          selectedDayPredicate: (day) =>
              _selectedDay != null &&
              day.year == _selectedDay!.year &&
              day.month == _selectedDay!.month &&
              day.day == _selectedDay!.day,
          calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: Color(0x2074512D), shape: BoxShape.circle)),
          headerStyle: const HeaderStyle(
              formatButtonVisible: false, titleCentered: true),
          // 달(페이지)이 변경될 때마다 해당 월 기준으로 캘린더 전용 데이터를 다시 로드
          onPageChanged: (focused) {
            setState(() {
              _focusedDay = focused;
            });
            _loadCalendarMonth(DateTime(focused.year, focused.month));
          },
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay =
                  DateTime(selected.year, selected.month, selected.day);
              _focusedDay = focused;
            });
          },
          eventLoader: (day) =>
              byDay[DateTime(day.year, day.month, day.day)] ?? [],
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              final widgets = <Widget>[];
              final list = events.take(3).toList();
              for (final e in list) {
                final Map<String, dynamic>? m =
                    e is Map<String, dynamic> ? e : null;
                final bool isSale = (m?['type'] == 'sale');
                widgets.add(Container(
                  width: 6,
                  height: 6,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
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
                if (!_isCalendarScrolling) {
                  _isCalendarScrolling = true;
                  widget.onScrollChanged?.call(true);
                }
              } else if (notification is ScrollEndNotification) {
                if (_isCalendarScrolling) {
                  _isCalendarScrolling = false;
                  widget.onScrollChanged?.call(false);
                }
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
                      child: _GiftBanner(
                          adUnitId: AdHelper.giftCalendarBannerAdUnitId),
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
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InfoPill(
                                    text: isSale ? '판매' : '구매',
                                    icon: isSale
                                        ? Icons.attach_money_outlined
                                        : Icons.shopping_cart_outlined,
                                    filled: true),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$brand $qty장',
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700),
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
                                  InfoPill(
                                      icon: Icons.sell_outlined,
                                      text:
                                          '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                                  InfoPill(
                                      icon: Icons.trending_up_outlined,
                                      text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                                  InfoPill(
                                      icon: Icons.today_outlined, text: date),
                                ] else ...[
                                  InfoPill(
                                      icon: Icons.payments_outlined,
                                      text:
                                          '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                                  InfoPill(
                                      icon: Icons.credit_card_outlined,
                                      text: '카드 ${m['cardId'] ?? ''}'),
                                  InfoPill(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      text: '${m['payType'] ?? ''}'),
                                  InfoPill(
                                      icon: Icons.today_outlined, text: date),
                                  if (memo != null && memo.trim().isNotEmpty)
                                    InfoPill(
                                        icon: Icons.note_outlined, text: memo),
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
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
  Future<void> _confirmAndConsumePeanutsThen(Function() onConfirmed,
      {int cost = 20}) async {
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
            title: const Text('확인',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            content: const Text('땅콩 20개가 소모됩니다.',
                style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
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

  Future<void> _confirmAndDeleteSale(Map<String, dynamic> sale,
      {int cost = 20}) async {
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
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '삭제',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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

  Future<void> _confirmAndDeleteLot(Map<String, dynamic> lot,
      {int cost = 20}) async {
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
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '삭제',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
    final List<Map<String, dynamic>> lots =
        List<Map<String, dynamic>>.from(_lots.map((e) => {...e}));
    final List<Map<String, dynamic>> sales =
        List<Map<String, dynamic>>.from(_sales.map((e) => {...e}));

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
      final String date = (m['buyDate'] is Timestamp)
          ? _yMd.format((m['buyDate'] as Timestamp).toDate())
          : '';
      final String brand = (m['giftcardId'] as String?) ?? '';
      final int qty = _asInt(m['qty']);
      final String status = (m['status'] as String?) ?? 'open';
      final bool sold = status == 'sold';
      final bool canDelete = status == 'open';
      final Color? buyColor =
          sold ? const Color(0xFF1E88E5) : const Color(0xFF74512D);
      final String? memo = m['memo'] as String?;
      final bool isTraded = sold ? true : ((m['trade'] as bool?) ?? false);
      return GestureDetector(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                InfoPill(
                    text: '구매',
                    icon: Icons.shopping_cart_outlined,
                    filled: true,
                    fillColor: buyColor),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('$brand $qty장',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if ((m['whereToBuyId'] as String?) != null) ...[
                  const SizedBox(width: 8),
                  InfoPill(
                    icon: Icons.storefront_outlined,
                    text: _whereToBuyNames[(m['whereToBuyId'] as String?)!] ??
                        (m['whereToBuyId'] as String),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '편집',
                  onPressed: () async {
                    await _confirmAndConsumePeanutsThen(() async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                GiftBuyScreen(editLotId: m['id'] as String?)),
                      );
                      if (mounted) _load();
                    }, cost: 20);
                  },
                ),
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.black54),
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
                  InfoPill(
                      icon: Icons.payments_outlined,
                      text: '매입가 ${_fmtWon(m['buyUnit'] ?? 0)}'),
                  InfoPill(
                      icon: Icons.credit_card_outlined,
                      text: '카드 ${m['cardId'] ?? ''}'),
                  InfoPill(
                      icon: Icons.account_balance_wallet_outlined,
                      text: '${m['payType'] ?? ''}'),
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
      final String date = (m['sellDate'] is Timestamp)
          ? _yMd.format((m['sellDate'] as Timestamp).toDate())
          : '';
      final String brand = (m['giftcardId'] as String?) ?? '';
      final int qty = _asInt(m['qty']);
      final bool hasDiscount =
          m.containsKey('discount') && m['discount'] != null;

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
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const InfoPill(
                    text: '판매',
                    icon: Icons.attach_money_outlined,
                    filled: true),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('$brand $qty장',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '편집',
                  onPressed: () async {
                    await _confirmAndConsumePeanutsThen(() async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                GiftSellScreen(editSaleId: m['id'] as String?)),
                      );
                      if (mounted) _load();
                    }, cost: 20);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.black54),
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
                  InfoPill(
                      icon: Icons.sell_outlined,
                      text: '판매가 ${_fmtWon(m['sellUnit'] ?? 0)}'),
                  if (hasDiscount)
                    InfoPill(
                        icon: Icons.percent,
                        text: '할인율 ${_fmtDiscount(m['discount'])}'),
                  InfoPill(
                      icon: Icons.trending_up_outlined,
                      text: '손익 ${_fmtWon(m['profit'] ?? 0)}'),
                  InfoPill(icon: Icons.today_outlined, text: date),
                  if (lotGiftcardName != null && lotGiftcardName.isNotEmpty)
                    InfoPill(
                        icon: Icons.card_giftcard_outlined,
                        text: lotGiftcardName),
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
                icon: const Icon(Icons.filter_list,
                    color: Colors.black, size: 18),
                label: Text(
                  _selectedGiftcardIdsForDaily.isEmpty
                      ? '전체 ▼'
                      : '${_selectedGiftcardIdsForDaily.length}개 선택 ▼',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  if (!_isDailyListScrolling) {
                    _isDailyListScrolling = true;
                    widget.onScrollChanged?.call(true);
                  }
                } else if (notification is ScrollEndNotification) {
                  if (_isDailyListScrolling) {
                    _isDailyListScrolling = false;
                    widget.onScrollChanged?.call(false);
                  }
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
                          MaterialPageRoute(
                              builder: (_) =>
                                  GiftBuyScreen(editLotId: entry.id)),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GiftSellScreen(editSaleId: entry.id)),
                        );
                      }
                      if (mounted) _load();
                    }, cost: 20);
                  },
                  onDelete: (entry) async {
                    if (entry.type == GiftcardLedgerEntryType.buy) {
                      await _confirmAndDeleteLot(
                          Map<String, dynamic>.from(entry.raw),
                          cost: 20);
                    } else {
                      await _confirmAndDeleteSale(
                          Map<String, dynamic>.from(entry.raw),
                          cost: 20);
                    }
                  },
                  onSaveTemplate: (entry) => _saveBuyEntryAsTemplate(entry),
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
        final Map<String, dynamic> cur = agg[uid] ??
            {'uid': uid, 'displayName': dn, 'photoUrl': pu, 'sellTotal': 0};
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

  String _maskRankingName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '익명';
    final List<int> runes = trimmed.runes.toList();
    if (runes.length <= 1) return trimmed;
    return '${String.fromCharCode(runes.first)}${'*' * (runes.length - 1)}';
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
                  const Text('사용자 랭킹',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (updateTimeText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      updateTimeText,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  Text('${_userRankings.length}명',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _rankingLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
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
                        final String name = _maskRankingName(
                            u['displayName'] as String? ?? '익명');
                        final String? photo = u['photoUrl'] as String?;
                        final int total =
                            (u['sellTotal'] as num?)?.toInt() ?? 0;

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
                                  builder: (_) =>
                                      UserProfileScreen(userUid: uid),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
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
                                  backgroundImage:
                                      (photo != null && photo.isNotEmpty)
                                          ? NetworkImage(photo)
                                          : null,
                                  child: (photo == null || photo.isEmpty)
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
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
