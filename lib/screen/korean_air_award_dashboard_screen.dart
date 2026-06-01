import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../helper/AdHelper.dart';
import '../services/korean_air_award_dashboard_service.dart';

const Color _koreanAirNavy = Color(0xFF123B64);
const Color _koreanAirBlue = Color(0xFF2A85C7);
const Color _businessColor = Color(0xFF0A5EA8);
const Color _firstColor = Color(0xFF8B1E3F);
const Color _successColor = Color(0xFF16815D);
const Color _warningColor = Color(0xFFD97706);
const String _routeOrderPreferenceKey = 'korean_air_award_route_order_v1';

Color _alpha(Color color, double opacity) {
  return color.withAlpha((opacity * 255).round());
}

enum _AwardInsightMode { business, firstClass, routes }

extension _AwardInsightModeCopy on _AwardInsightMode {
  String get title {
    switch (this) {
      case _AwardInsightMode.business:
        return '비즈니스';
      case _AwardInsightMode.firstClass:
        return '퍼스트';
      case _AwardInsightMode.routes:
        return '발견 노선';
    }
  }

  String get pageTitle {
    switch (this) {
      case _AwardInsightMode.business:
        return '비즈니스 가능일';
      case _AwardInsightMode.firstClass:
        return '퍼스트 가능일';
      case _AwardInsightMode.routes:
        return '발견 노선';
    }
  }

  String get summaryLabel {
    switch (this) {
      case _AwardInsightMode.business:
      case _AwardInsightMode.firstClass:
        return '가능일';
      case _AwardInsightMode.routes:
        return '노선';
    }
  }

  Color get color {
    switch (this) {
      case _AwardInsightMode.business:
        return _businessColor;
      case _AwardInsightMode.firstClass:
        return _firstColor;
      case _AwardInsightMode.routes:
        return _warningColor;
    }
  }

  IconData get icon {
    switch (this) {
      case _AwardInsightMode.business:
        return Icons.business_center_outlined;
      case _AwardInsightMode.firstClass:
        return Icons.workspace_premium_outlined;
      case _AwardInsightMode.routes:
        return Icons.route_outlined;
    }
  }
}

class KoreanAirAwardDashboardScreen extends StatefulWidget {
  const KoreanAirAwardDashboardScreen({super.key});

  @override
  State<KoreanAirAwardDashboardScreen> createState() =>
      _KoreanAirAwardDashboardScreenState();
}

class _KoreanAirAwardDashboardScreenState
    extends State<KoreanAirAwardDashboardScreen> {
  final KoreanAirAwardDashboardService _service =
      KoreanAirAwardDashboardService();

  KoreanAirAwardDashboardData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedRouteIndex = 0;
  bool _isOutbound = true;
  bool _showBusiness = true;
  bool _showFirst = true;
  bool _availableOnly = true;
  List<String> _routeOrder = const [];
  DateTime _focusedMonth = _monthOnly(DateTime.now());
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadSavedRouteOrder();
    _loadDashboard();
  }

  Future<void> _loadSavedRouteOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder =
        prefs.getStringList(_routeOrderPreferenceKey) ?? const [];
    if (!mounted) return;

    setState(() {
      final selectedAirport = _selectedRoute?.config.arrivalAirport;
      _routeOrder = savedOrder;
      final data = _data;
      if (data != null) {
        final orderedData = _applyRouteOrder(data);
        _data = orderedData;
        _selectedRouteIndex = _preferredRouteIndex(
          orderedData,
          preferredArrivalAirport: selectedAirport,
        );
      }
    });
  }

  Future<void> _loadDashboard() async {
    final selectedAirport = _selectedRoute?.config.arrivalAirport;
    if (_data == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawData = await _service.fetchDashboard();
      if (!mounted) return;

      final data = _applyRouteOrder(rawData);
      final nextRouteIndex = _preferredRouteIndex(
        data,
        preferredArrivalAirport: selectedAirport,
      );
      final route = data.routes.isEmpty ? null : data.routes[nextRouteIndex];
      final direction =
          route == null ? null : _directionFor(route, outbound: _isOutbound);
      final nearestDay =
          direction == null ? null : _nearestMatchingDay(direction);

      setState(() {
        _data = data;
        _selectedRouteIndex = nextRouteIndex;
        _selectedDate = nearestDay?.date;
        if (nearestDay != null) {
          _focusedMonth = _monthOnly(nearestDay.date);
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '대한항공 보너스석 현황을 불러오지 못했습니다.';
      });
    }
  }

  KoreanAirAwardDashboardData _applyRouteOrder(
    KoreanAirAwardDashboardData data,
  ) {
    if (data.routes.isEmpty) return data;

    final routeByAirport = {
      for (final route in data.routes) route.config.arrivalAirport: route,
    };
    final seenAirports = <String>{};
    final orderedAirports = <String>[
      for (final airport in _routeOrder)
        if (routeByAirport.containsKey(airport) && seenAirports.add(airport))
          airport,
      for (final route in data.routes)
        if (seenAirports.add(route.config.arrivalAirport))
          route.config.arrivalAirport,
    ];
    final orderedRoutes = [
      for (final airport in orderedAirports) routeByAirport[airport]!,
    ];

    return KoreanAirAwardDashboardData(routes: orderedRoutes);
  }

  int _preferredRouteIndex(
    KoreanAirAwardDashboardData data, {
    String? preferredArrivalAirport,
  }) {
    if (data.routes.isEmpty) return 0;
    if (preferredArrivalAirport != null) {
      final preferredIndex = data.routes.indexWhere(
        (route) => route.config.arrivalAirport == preferredArrivalAirport,
      );
      if (preferredIndex >= 0) return preferredIndex;
    }
    if (_data != null && _selectedRouteIndex < data.routes.length) {
      return _selectedRouteIndex;
    }
    final indexWithSeats =
        data.routes.indexWhere((route) => route.premiumDateCount > 0);
    return indexWithSeats >= 0 ? indexWithSeats : 0;
  }

  KoreanAirAwardDirection _directionFor(
    KoreanAirAwardRouteItem route, {
    required bool outbound,
  }) {
    return outbound ? route.outbound : route.inbound;
  }

  KoreanAirAwardDay? _nearestMatchingDay(
    KoreanAirAwardDirection direction, {
    bool? business,
    bool? first,
  }) {
    final includeBusiness = business ?? _showBusiness;
    final includeFirst = first ?? _showFirst;
    final today = DateUtils.dateOnly(DateTime.now());
    final matchingDays = direction.days
        .where((day) => day.matches(
              business: includeBusiness,
              first: includeFirst,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (matchingDays.isEmpty) return null;
    return matchingDays.firstWhere(
      (day) => !day.date.isBefore(today),
      orElse: () => matchingDays.first,
    );
  }

  Future<void> _openRouteOrderEditor() async {
    final data = _data;
    if (data == null || data.routes.isEmpty) return;

    final selectedAirport = _selectedRoute?.config.arrivalAirport;
    final nextOrder = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => _RouteOrderEditScreen(routes: data.routes),
      ),
    );
    if (nextOrder == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_routeOrderPreferenceKey, nextOrder);
    if (!mounted) return;

    setState(() {
      _routeOrder = nextOrder;
      final orderedData = _applyRouteOrder(data);
      _data = orderedData;
      _selectedRouteIndex = _preferredRouteIndex(
        orderedData,
        preferredArrivalAirport: selectedAirport,
      );
    });
  }

  void _selectRoute(int index) {
    final data = _data;
    if (data == null || index >= data.routes.length) return;
    final route = data.routes[index];
    final direction = _directionFor(route, outbound: _isOutbound);
    final nearestDay = _nearestMatchingDay(direction);
    setState(() {
      _selectedRouteIndex = index;
      _selectedDate = nearestDay?.date;
      if (nearestDay != null) {
        _focusedMonth = _monthOnly(nearestDay.date);
      }
    });
  }

  void _setDirection(bool outbound) {
    final route = _selectedRoute;
    if (route == null) return;
    final direction = _directionFor(route, outbound: outbound);
    final nearestDay = _nearestMatchingDay(direction);
    setState(() {
      _isOutbound = outbound;
      _selectedDate = nearestDay?.date;
      if (nearestDay != null) {
        _focusedMonth = _monthOnly(nearestDay.date);
      }
    });
  }

  void _setBusinessFilter(bool value) {
    if (!value && !_showFirst) return;
    setState(() {
      _showBusiness = value;
      _alignSelectionToFilters();
    });
  }

  void _setFirstFilter(bool value) {
    if (!value && !_showBusiness) return;
    setState(() {
      _showFirst = value;
      _alignSelectionToFilters();
    });
  }

  void _setAvailableOnly(bool value) {
    setState(() {
      _availableOnly = value;
      if (value) {
        _alignSelectionToFilters();
      }
    });
  }

  void _alignSelectionToFilters() {
    final direction = _selectedDirection;
    if (direction == null) return;
    final selectedDate = _selectedDate;
    if (selectedDate != null) {
      final selectedDay =
          direction.dayByKey[KoreanAirAwardDay.dateKey(selectedDate)];
      if (selectedDay != null &&
          selectedDay.matches(business: _showBusiness, first: _showFirst)) {
        return;
      }
    }

    final nearestDay = _nearestMatchingDay(direction);
    _selectedDate = nearestDay?.date;
    if (nearestDay != null) {
      _focusedMonth = _monthOnly(nearestDay.date);
    }
  }

  Future<void> _openAwardInsight(_AwardInsightMode mode) async {
    final data = _data;
    if (data == null) return;

    final selection = await Navigator.of(context).push<_AwardInsightSelection>(
      MaterialPageRoute(
        builder: (_) => _AwardInsightScreen(
          data: data,
          mode: mode,
          onOpenKoreanAirApp: _openKoreanAirApp,
        ),
      ),
    );
    if (!mounted || selection == null) return;

    setState(() {
      _selectedRouteIndex = selection.routeIndex;
      _isOutbound = selection.isOutbound;
      _showBusiness = selection.showBusiness;
      _showFirst = selection.showFirst;
      _availableOnly = true;
      _selectedDate = DateUtils.dateOnly(selection.date);
      _focusedMonth = _monthOnly(selection.date);
    });
  }

  KoreanAirAwardRouteItem? get _selectedRoute {
    final data = _data;
    if (data == null || data.routes.isEmpty) return null;
    final index = _selectedRouteIndex.clamp(0, data.routes.length - 1);
    return data.routes[index];
  }

  KoreanAirAwardDirection? get _selectedDirection {
    final route = _selectedRoute;
    if (route == null) return null;
    return _directionFor(route, outbound: _isOutbound);
  }

  Future<void> _openKoreanAirApp() async {
    final uri = Uri.parse(AdHelper.danMarketUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대한항공 앱을 열 수 없습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('대한항공 보너스석'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return const _DashboardLoadingState();
    }

    if (_errorMessage != null && _data == null) {
      return _DashboardErrorState(
        message: _errorMessage!,
        onRetry: _loadDashboard,
      );
    }

    final data = _data;
    if (data == null || data.routes.isEmpty) {
      return _DashboardErrorState(
        message: '표시할 대한항공 노선 정보가 없습니다.',
        onRetry: _loadDashboard,
      );
    }

    final selectedRoute = _selectedRoute ?? data.routes.first;
    final selectedDirection = _selectedDirection ?? selectedRoute.outbound;

    return RefreshIndicator(
      color: _koreanAirBlue,
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _DashboardHeader(
            data: data,
            onMetricSelected: _openAwardInsight,
          ),
          const SizedBox(height: 18),
          _FilterPanel(
            route: selectedRoute,
            isOutbound: _isOutbound,
            showBusiness: _showBusiness,
            showFirst: _showFirst,
            availableOnly: _availableOnly,
            onDirectionChanged: _setDirection,
            onBusinessChanged: _setBusinessFilter,
            onFirstChanged: _setFirstFilter,
            onAvailableOnlyChanged: _setAvailableOnly,
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.route_outlined,
            title: '노선별 현황',
            trailing: '${data.premiumRouteCount}개 노선 발견',
            action: _SectionIconButton(
              tooltip: '순서 편집',
              icon: Icons.edit_outlined,
              onTap: _openRouteOrderEditor,
            ),
          ),
          const SizedBox(height: 10),
          _RouteSummaryRail(
            routes: data.routes,
            selectedIndex: _selectedRouteIndex,
            onSelected: _selectRoute,
          ),
          const SizedBox(height: 22),
          _RouteDetailSection(
            route: selectedRoute,
            direction: selectedDirection,
            focusedMonth: _focusedMonth,
            selectedDate: _selectedDate,
            showBusiness: _showBusiness,
            showFirst: _showFirst,
            availableOnly: _availableOnly,
            onMonthChanged: (month) {
              setState(() => _focusedMonth = _monthOnly(month));
            },
            onDateSelected: (date) {
              setState(() => _selectedDate = DateUtils.dateOnly(date));
            },
            onOpenKoreanAirApp: _openKoreanAirApp,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _SoftNotice(message: _errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.data,
    required this.onMetricSelected,
  });

  final KoreanAirAwardDashboardData data;
  final ValueChanged<_AwardInsightMode> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alpha(_koreanAirBlue, 0.16)),
        boxShadow: [
          BoxShadow(
            color: _alpha(Colors.black, 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'asset/img/app_dan.png',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '보너스석 현황',
                      style: McTextStyles.sectionTitle.copyWith(
                        fontSize: 20,
                        color: _koreanAirNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.latestLabel} 현재',
                      style: McTextStyles.meta.copyWith(color: McColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _alpha(_successColor, 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '무료 조회',
                  style: McTextStyles.micro.copyWith(
                    color: _successColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: McColors.line,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: '비즈니스',
                  value: '${data.businessDateCount}일',
                  color: _businessColor,
                  onTap: () => onMetricSelected(_AwardInsightMode.business),
                ),
              ),
              Container(width: 1, height: 34, color: McColors.line),
              Expanded(
                child: _HeaderMetric(
                  label: '퍼스트',
                  value: '${data.firstDateCount}일',
                  color: _firstColor,
                  onTap: () => onMetricSelected(_AwardInsightMode.firstClass),
                ),
              ),
              Container(width: 1, height: 34, color: McColors.line),
              Expanded(
                child: _HeaderMetric(
                  label: '발견 노선',
                  value:
                      '${data.premiumRouteCount}/${KoreanAirAwardDashboardService.routeConfigs.length}',
                  color: _warningColor,
                  onTap: () => onMetricSelected(_AwardInsightMode.routes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McTextStyles.sectionTitle.copyWith(
                  color: color,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 13, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardInsightScreen extends StatelessWidget {
  const _AwardInsightScreen({
    required this.data,
    required this.mode,
    required this.onOpenKoreanAirApp,
  });

  final KoreanAirAwardDashboardData data;
  final _AwardInsightMode mode;
  final Future<void> Function() onOpenKoreanAirApp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: Text(mode.pageTitle),
        actions: [
          IconButton(
            tooltip: '대한항공 앱',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpenKoreanAirApp,
          ),
        ],
      ),
      body: SafeArea(
        child: mode == _AwardInsightMode.routes
            ? _buildRouteBody(context)
            : _buildDayBody(context),
      ),
    );
  }

  Widget _buildDayBody(BuildContext context) {
    final items = _awardDayItems(data, mode);
    final today = DateUtils.dateOnly(DateTime.now());
    final upcomingCount = items
        .where((item) => !DateUtils.dateOnly(item.day.date).isBefore(today))
        .length;
    final routeCount = items.map((item) => item.routeIndex).toSet().length;
    final totalSeats = items.fold<int>(
      0,
      (total, item) => total + _seatCountForMode(item.day, mode),
    );
    final nearest = items.isEmpty ? null : items.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _AwardInsightHero(
          mode: mode,
          totalValue: '${items.length}일',
          subtitle: '$routeCount개 노선 · $upcomingCount일 예정',
          stats: [
            _InsightStatData(
              label: '가장 빠른 날',
              value:
                  nearest == null ? '없음' : _formatCompactDate(nearest.day.date),
            ),
            _InsightStatData(label: '좌석합', value: '$totalSeats편'),
            _InsightStatData(
              label: '업데이트',
              value: _formatShortTimestampKey(data.latestTimestampKey),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          icon: Icons.calendar_today_outlined,
          title: '가까운 날짜순',
          trailing: '${items.length}일',
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _InsightEmptyState(
            color: mode.color,
            message: '${mode.title} 보너스석이 현재 발견되지 않았습니다.',
          )
        else
          ..._buildDayCards(context, items),
      ],
    );
  }

  Widget _buildRouteBody(BuildContext context) {
    final routes = _awardRouteItems(data);
    final nearest = routes.isEmpty ? null : routes.first.nearest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _AwardInsightHero(
          mode: mode,
          totalValue: '${routes.length}개',
          subtitle:
              '전체 ${KoreanAirAwardDashboardService.routeConfigs.length}개 노선 중 좌석 발견',
          stats: [
            _InsightStatData(
              label: '가장 빠른 날',
              value:
                  nearest == null ? '없음' : _formatCompactDate(nearest.day.date),
            ),
            _InsightStatData(
                label: '비즈니스', value: '${data.businessDateCount}일'),
            _InsightStatData(label: '퍼스트', value: '${data.firstDateCount}일'),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          icon: Icons.route_outlined,
          title: '노선별 보기',
          trailing: '${routes.length}개 발견',
        ),
        const SizedBox(height: 10),
        if (routes.isEmpty)
          _InsightEmptyState(
            color: mode.color,
            message: '현재 발견된 프리미엄 보너스 노선이 없습니다.',
          )
        else
          for (final route in routes) ...[
            _AwardRouteInsightCard(
              item: route,
              onTap: () {
                final nearest = route.nearest;
                if (nearest == null) return;
                Navigator.of(context).pop(
                  _AwardInsightSelection.fromDayItem(
                    nearest,
                    _AwardInsightMode.routes,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  List<Widget> _buildDayCards(
    BuildContext context,
    List<_AwardDayInsightItem> items,
  ) {
    final widgets = <Widget>[];
    String? currentMonth;

    for (final item in items) {
      final monthLabel = _formatMonthLabel(item.day.date);
      if (monthLabel != currentMonth) {
        currentMonth = monthLabel;
        widgets.add(_InsightMonthHeader(label: monthLabel));
      }

      widgets
        ..add(
          _AwardDayInsightCard(
            item: item,
            mode: mode,
            onTap: () {
              Navigator.of(context).pop(
                _AwardInsightSelection.fromDayItem(item, mode),
              );
            },
          ),
        )
        ..add(const SizedBox(height: 10));
    }

    return widgets;
  }
}

class _AwardInsightHero extends StatelessWidget {
  const _AwardInsightHero({
    required this.mode,
    required this.totalValue,
    required this.subtitle,
    required this.stats,
  });

  final _AwardInsightMode mode;
  final String totalValue;
  final String subtitle;
  final List<_InsightStatData> stats;

  @override
  Widget build(BuildContext context) {
    final color = mode.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alpha(color, 0.18)),
        boxShadow: [
          BoxShadow(
            color: _alpha(Colors.black, 0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _alpha(color, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mode.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.pageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.sectionTitle.copyWith(
                        color: _koreanAirNavy,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    totalValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McTextStyles.sectionTitle.copyWith(
                      color: color,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    mode.summaryLabel,
                    style: McTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: McColors.line),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                Expanded(
                  child: _InsightStat(
                    data: stats[index],
                    color: color,
                  ),
                ),
                if (index != stats.length - 1)
                  Container(width: 1, height: 32, color: McColors.line),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightStatData {
  const _InsightStatData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.data,
    required this.color,
  });

  final _InsightStatData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: McTextStyles.bodyStrong.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: McTextStyles.micro.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InsightMonthHeader extends StatelessWidget {
  const _InsightMonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        label,
        style: McTextStyles.bodyStrong.copyWith(color: _koreanAirNavy),
      ),
    );
  }
}

class _AwardDayInsightCard extends StatelessWidget {
  const _AwardDayInsightCard({
    required this.item,
    required this.mode,
    required this.onTap,
  });

  final _AwardDayInsightItem item;
  final _AwardInsightMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mode.color;
    final count = _seatCountForMode(item.day, mode);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _alpha(color, 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _InsightDateBadge(date: item.day.date, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${item.direction.departureAirport} → ${item.direction.arrivalAirport}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McTextStyles.bodyStrong.copyWith(
                              color: _koreanAirNavy,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _InsightTinyBadge(
                          label: item.route.config.arrivalCity,
                          color: _koreanAirNavy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.direction.label} · ${_relativeDayLabel(item.day.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.day.hasBusiness)
                          _InsightSeatChip(
                            label: 'B',
                            count: item.day.businessCount,
                            color: _businessColor,
                          ),
                        if (item.day.hasFirst)
                          _InsightSeatChip(
                            label: 'F',
                            count: item.day.firstCount,
                            color: _firstColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _InsightCountPill(
                    value: '$count편',
                    color: color,
                  ),
                  const SizedBox(height: 10),
                  Icon(Icons.chevron_right, size: 20, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardRouteInsightCard extends StatelessWidget {
  const _AwardRouteInsightCard({
    required this.item,
    required this.onTap,
  });

  final _AwardRouteInsightItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final route = item.route;
    final nearest = item.nearest;
    final nearestLabel = nearest == null
        ? '가능일 없음'
        : '${_formatCompactDate(nearest.day.date)} · ${nearest.direction.label}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _koreanAirNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.config.arrivalAirport,
                      style: McTextStyles.micro.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      route.config.arrivalCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.sectionTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  _InsightCountPill(
                    value: '${route.premiumDateCount}일',
                    color: _successColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RouteClassInsight(
                      label: '비즈니스',
                      count: route.businessDateCount,
                      nearest: item.nearestBusiness,
                      color: _businessColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RouteClassInsight(
                      label: '퍼스트',
                      count: route.firstDateCount,
                      nearest: item.nearestFirst,
                      color: _firstColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 17, color: _koreanAirNavy),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nearestLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta.copyWith(
                        color: _koreanAirNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: _koreanAirNavy),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteClassInsight extends StatelessWidget {
  const _RouteClassInsight({
    required this.label,
    required this.count,
    required this.nearest,
    required this.color,
  });

  final String label;
  final int count;
  final _AwardDayInsightItem? nearest;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final nearestItem = nearest;
    final nearestLabel = nearestItem == null
        ? '가능일 없음'
        : '${_formatCompactDate(nearestItem.day.date)} ${nearestItem.direction.label}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _alpha(color, 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _alpha(color, 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _alpha(color, 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  label.characters.first,
                  style: McTextStyles.micro.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McTextStyles.micro.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            count == 0 ? '없음' : '$count일',
            style: McTextStyles.bodyStrong.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            nearestLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.micro,
          ),
        ],
      ),
    );
  }
}

class _InsightDateBadge extends StatelessWidget {
  const _InsightDateBadge({
    required this.date,
    required this.color,
  });

  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: _alpha(color, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _alpha(color, 0.18)),
      ),
      child: Column(
        children: [
          Text(
            '${date.month}/${date.day}',
            style: McTextStyles.bodyStrong.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            _weekdayLabel(date),
            style: McTextStyles.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightSeatChip extends StatelessWidget {
  const _InsightSeatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _alpha(color, 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count편',
        style: McTextStyles.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InsightCountPill extends StatelessWidget {
  const _InsightCountPill({
    required this.value,
    required this.color,
  });

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _alpha(color, 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: McTextStyles.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InsightTinyBadge extends StatelessWidget {
  const _InsightTinyBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _alpha(color, 0.08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: McTextStyles.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InsightEmptyState extends StatelessWidget {
  const _InsightEmptyState({
    required this.color,
    required this.message,
  });

  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: McTextStyles.bodyStrong,
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.route,
    required this.isOutbound,
    required this.showBusiness,
    required this.showFirst,
    required this.availableOnly,
    required this.onDirectionChanged,
    required this.onBusinessChanged,
    required this.onFirstChanged,
    required this.onAvailableOnlyChanged,
  });

  final KoreanAirAwardRouteItem route;
  final bool isOutbound;
  final bool showBusiness;
  final bool showFirst;
  final bool availableOnly;
  final ValueChanged<bool> onDirectionChanged;
  final ValueChanged<bool> onBusinessChanged;
  final ValueChanged<bool> onFirstChanged;
  final ValueChanged<bool> onAvailableOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ICN 출발 · ${route.config.arrivalCity}',
            style: McTextStyles.bodyStrong.copyWith(color: _koreanAirNavy),
          ),
          const SizedBox(height: 12),
          _DirectionSwitch(
            destination: route.config.arrivalAirport,
            isOutbound: isOutbound,
            onChanged: onDirectionChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ClassFilterChip(
                label: '비즈니스',
                shortLabel: 'B',
                color: _businessColor,
                selected: showBusiness,
                onSelected: onBusinessChanged,
              ),
              _ClassFilterChip(
                label: '퍼스트',
                shortLabel: 'F',
                color: _firstColor,
                selected: showFirst,
                onSelected: onFirstChanged,
              ),
              _AvailabilityChip(
                selected: availableOnly,
                onSelected: onAvailableOnlyChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionSwitch extends StatelessWidget {
  const _DirectionSwitch({
    required this.destination,
    required this.isOutbound,
    required this.onChanged,
  });

  final String destination;
  final bool isOutbound;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DirectionButton(
              label: 'ICN → $destination',
              selected: isOutbound,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _DirectionButton(
              label: '$destination → ICN',
              selected: !isOutbound,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: McTextStyles.bodyStrong.copyWith(
              color: selected ? _koreanAirNavy : McColors.muted,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassFilterChip extends StatelessWidget {
  const _ClassFilterChip({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String shortLabel;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _alpha(color, 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _alpha(color, 0.45) : McColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : McColors.field,
                shape: BoxShape.circle,
              ),
              child: Text(
                shortLabel,
                style: McTextStyles.micro.copyWith(
                  color: selected ? Colors.white : McColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: McTextStyles.meta.copyWith(
                color: selected ? color : McColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({
    required this.selected,
    required this.onSelected,
  });

  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _alpha(_successColor, 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _alpha(_successColor, 0.42) : McColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? _successColor : McColors.muted,
            ),
            const SizedBox(width: 7),
            Text(
              '좌석 있는 날만',
              style: McTextStyles.meta.copyWith(
                color: selected ? _successColor : McColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryRail extends StatelessWidget {
  const _RouteSummaryRail({
    required this.routes,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<KoreanAirAwardRouteItem> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _RouteSummaryCard(
            route: routes[index],
            selected: index == selectedIndex,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final KoreanAirAwardRouteItem route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nearestBusiness = _nearestRouteDay(route, business: true);
    final nearestFirst = _nearestRouteDay(route, first: true);
    final hasSeats = route.premiumDateCount > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 172,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? _alpha(_koreanAirBlue, 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _koreanAirBlue : McColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? _koreanAirNavy : McColors.field,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.config.arrivalAirport,
                    style: McTextStyles.micro.copyWith(
                      color: selected ? Colors.white : _koreanAirNavy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    route.config.arrivalCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McTextStyles.bodyStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RouteSummaryLine(
              label: '비즈니스',
              value: nearestBusiness == null
                  ? '없음'
                  : _formatRouteDay(nearestBusiness),
              color: _businessColor,
            ),
            const SizedBox(height: 6),
            _RouteSummaryLine(
              label: '퍼스트',
              value:
                  nearestFirst == null ? '없음' : _formatRouteDay(nearestFirst),
              color: _firstColor,
            ),
            const Spacer(),
            Text(
              hasSeats ? '총 ${route.premiumDateCount}일 발견' : '현재 없음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.micro.copyWith(
                color: hasSeats ? _successColor : McColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryLine extends StatelessWidget {
  const _RouteSummaryLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: McTextStyles.micro.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: McTextStyles.micro.copyWith(
              color: McColors.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteOrderEditScreen extends StatefulWidget {
  const _RouteOrderEditScreen({required this.routes});

  final List<KoreanAirAwardRouteItem> routes;

  @override
  State<_RouteOrderEditScreen> createState() => _RouteOrderEditScreenState();
}

class _RouteOrderEditScreenState extends State<_RouteOrderEditScreen> {
  late List<KoreanAirAwardRouteItem> _routes;

  @override
  void initState() {
    super.initState();
    _routes = List<KoreanAirAwardRouteItem>.of(widget.routes);
  }

  void _moveRoute(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _routes.length || fromIndex == toIndex) {
      return;
    }
    setState(() {
      final route = _routes.removeAt(fromIndex);
      _routes.insert(toIndex, route);
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _routes.map((route) => route.config.arrivalAirport).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('노선 순서 편집'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '완료',
              style: McTextStyles.bodyStrong.copyWith(color: _koreanAirBlue),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          buildDefaultDragHandles: false,
          itemCount: _routes.length,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) newIndex -= 1;
            _moveRoute(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final route = _routes[index];
            return _RouteOrderTile(
              key: ValueKey(route.config.arrivalAirport),
              route: route,
              index: index,
              isFirst: index == 0,
              isLast: index == _routes.length - 1,
              onMoveUp: () => _moveRoute(index, index - 1),
              onMoveDown: () => _moveRoute(index, index + 1),
            );
          },
        ),
      ),
    );
  }
}

class _RouteOrderTile extends StatelessWidget {
  const _RouteOrderTile({
    super.key,
    required this.route,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final KoreanAirAwardRouteItem route;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final hasSeats = route.premiumDateCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: McColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _alpha(_koreanAirBlue, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: McTextStyles.bodyStrong.copyWith(
                    color: _koreanAirNavy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _koreanAirNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.config.arrivalAirport,
                  style: McTextStyles.micro.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.config.arrivalCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.bodyStrong,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasSeats ? '총 ${route.premiumDateCount}일 발견' : '현재 없음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.micro.copyWith(
                        color: hasSeats ? _successColor : McColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _RouteMoveButton(
                icon: Icons.keyboard_arrow_up,
                enabled: !isFirst,
                onTap: onMoveUp,
              ),
              _RouteMoveButton(
                icon: Icons.keyboard_arrow_down,
                enabled: !isLast,
                onTap: onMoveDown,
              ),
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.drag_handle, color: McColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteMoveButton extends StatelessWidget {
  const _RouteMoveButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 34),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        color: enabled ? _koreanAirNavy : McColors.mutedLight,
      ),
      onPressed: enabled ? onTap : null,
    );
  }
}

class _RouteDetailSection extends StatelessWidget {
  const _RouteDetailSection({
    required this.route,
    required this.direction,
    required this.focusedMonth,
    required this.selectedDate,
    required this.showBusiness,
    required this.showFirst,
    required this.availableOnly,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onOpenKoreanAirApp,
  });

  final KoreanAirAwardRouteItem route;
  final KoreanAirAwardDirection direction;
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final bool showBusiness;
  final bool showFirst;
  final bool availableOnly;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onOpenKoreanAirApp;

  @override
  Widget build(BuildContext context) {
    final selectedDay = selectedDate == null
        ? null
        : direction.dayByKey[KoreanAirAwardDay.dateKey(selectedDate!)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.calendar_month_outlined,
          title: '${route.config.arrivalCity} ${direction.label}',
          trailing: direction.timestampKey.isEmpty
              ? '업데이트 없음'
              : _formatTimestampKey(direction.timestampKey),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            children: [
              _AwardCalendar(
                direction: direction,
                focusedMonth: focusedMonth,
                selectedDate: selectedDate,
                showBusiness: showBusiness,
                showFirst: showFirst,
                availableOnly: availableOnly,
                onMonthChanged: onMonthChanged,
                onDateSelected: onDateSelected,
              ),
              const SizedBox(height: 14),
              _SelectedDayPanel(
                route: route,
                direction: direction,
                selectedDate: selectedDate,
                selectedDay: selectedDay,
                showBusiness: showBusiness,
                showFirst: showFirst,
                onOpenKoreanAirApp: onOpenKoreanAirApp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AwardCalendar extends StatelessWidget {
  const _AwardCalendar({
    required this.direction,
    required this.focusedMonth,
    required this.selectedDate,
    required this.showBusiness,
    required this.showFirst,
    required this.availableOnly,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final KoreanAirAwardDirection direction;
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final bool showBusiness;
  final bool showFirst;
  final bool availableOnly;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    final leadingBlankCount = firstDay.weekday % DateTime.daysPerWeek;
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final cellCount =
        ((leadingBlankCount + daysInMonth + 6) ~/ DateTime.daysPerWeek) *
            DateTime.daysPerWeek;

    return Column(
      children: [
        Row(
          children: [
            _CalendarNavButton(
              icon: Icons.chevron_left,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month - 1),
              ),
            ),
            Expanded(
              child: Text(
                '${focusedMonth.year}년 ${focusedMonth.month}월',
                textAlign: TextAlign.center,
                style: McTextStyles.sectionTitle.copyWith(
                  color: _koreanAirNavy,
                ),
              ),
            ),
            _CalendarNavButton(
              icon: Icons.chevron_right,
              onTap: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            _WeekdayLabel(label: '일', color: Color(0xFFDC2626)),
            _WeekdayLabel(label: '월'),
            _WeekdayLabel(label: '화'),
            _WeekdayLabel(label: '수'),
            _WeekdayLabel(label: '목'),
            _WeekdayLabel(label: '금'),
            _WeekdayLabel(label: '토', color: Color(0xFF2563EB)),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          itemCount: cellCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DateTime.daysPerWeek,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlankCount + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final key = KoreanAirAwardDay.dateKey(date);
            final awardDay = direction.dayByKey[key];
            final matches = awardDay?.matches(
                  business: showBusiness,
                  first: showFirst,
                ) ??
                false;
            final enabled = matches || !availableOnly;

            return _CalendarDayCell(
              date: date,
              awardDay: awardDay,
              selected: DateUtils.isSameDay(selectedDate, date),
              enabled: enabled,
              showBusiness: showBusiness,
              showFirst: showFirst,
              onTap: enabled ? () => onDateSelected(date) : null,
            );
          },
        ),
      ],
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: McColors.field,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: _koreanAirNavy, size: 22),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: McTextStyles.micro.copyWith(
          color: color ?? McColors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.awardDay,
    required this.selected,
    required this.enabled,
    required this.showBusiness,
    required this.showFirst,
    required this.onTap,
  });

  final DateTime date;
  final KoreanAirAwardDay? awardDay;
  final bool selected;
  final bool enabled;
  final bool showBusiness;
  final bool showFirst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasBusiness = showBusiness && (awardDay?.hasBusiness ?? false);
    final hasFirst = showFirst && (awardDay?.hasFirst ?? false);
    final hasSeats = hasBusiness || hasFirst;
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? _koreanAirNavy
                : hasSeats
                    ? _alpha(_koreanAirBlue, 0.08)
                    : enabled
                        ? Colors.white
                        : McColors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? _koreanAirNavy
                  : isToday
                      ? _alpha(_koreanAirBlue, 0.55)
                      : hasSeats
                          ? _alpha(_koreanAirBlue, 0.22)
                          : McColors.line,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                maxLines: 1,
                style: McTextStyles.micro.copyWith(
                  color: selected
                      ? Colors.white
                      : enabled
                          ? McColors.ink
                          : McColors.mutedLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (hasBusiness)
                _SeatBadge(
                  label: 'B',
                  count: awardDay!.businessCount,
                  color: _businessColor,
                  selected: selected,
                ),
              if (hasBusiness && hasFirst) const SizedBox(height: 2),
              if (hasFirst)
                _SeatBadge(
                  label: 'F',
                  count: awardDay!.firstCount,
                  color: _firstColor,
                  selected: selected,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _alpha(Colors.white, 0.18) : _alpha(color, 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$label$count',
          maxLines: 1,
          style: McTextStyles.micro.copyWith(
            color: selected ? Colors.white : color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.route,
    required this.direction,
    required this.selectedDate,
    required this.selectedDay,
    required this.showBusiness,
    required this.showFirst,
    required this.onOpenKoreanAirApp,
  });

  final KoreanAirAwardRouteItem route;
  final KoreanAirAwardDirection direction;
  final DateTime? selectedDate;
  final KoreanAirAwardDay? selectedDay;
  final bool showBusiness;
  final bool showFirst;
  final VoidCallback onOpenKoreanAirApp;

  @override
  Widget build(BuildContext context) {
    final hasBusiness = showBusiness && (selectedDay?.hasBusiness ?? false);
    final hasFirst = showFirst && (selectedDay?.hasFirst ?? false);
    final hasSeats = hasBusiness || hasFirst;
    final displayDate =
        selectedDate == null ? '날짜 선택' : _formatFullDate(selectedDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(12),
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
                    Text(
                      displayDate,
                      style: McTextStyles.bodyStrong.copyWith(
                        color: _koreanAirNavy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${direction.departureAirport} → ${direction.arrivalAirport} · ${route.config.arrivalCity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: hasSeats
                      ? _alpha(_successColor, 0.12)
                      : _alpha(McColors.muted, 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasSeats ? '가능' : '없음',
                  style: McTextStyles.micro.copyWith(
                    color: hasSeats ? _successColor : McColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasSeats) ...[
            if (hasBusiness)
              _AvailabilityRow(
                label: '비즈니스',
                count: selectedDay!.businessCount,
                color: _businessColor,
              ),
            if (hasBusiness && hasFirst) const SizedBox(height: 8),
            if (hasFirst)
              _AvailabilityRow(
                label: '퍼스트',
                count: selectedDay!.firstCount,
                color: _firstColor,
              ),
          ] else
            Text(
              '현재 비즈니스/퍼스트 좌석 없음',
              style: McTextStyles.body.copyWith(color: McColors.muted),
            ),
          const SizedBox(height: 12),
          Text(
            direction.timestampKey.isEmpty
                ? '업데이트 정보 없음'
                : '${_formatTimestampKey(direction.timestampKey)} 업데이트',
            style: McTextStyles.micro,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _koreanAirNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('대한항공 앱으로 이동'),
              onPressed: onOpenKoreanAirApp,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _alpha(color, 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label.characters.first,
            style: McTextStyles.bodyStrong.copyWith(color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: McTextStyles.bodyStrong,
          ),
        ),
        Text(
          '가능 $count편',
          style: McTextStyles.bodyStrong.copyWith(color: color),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _koreanAirNavy),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.sectionTitle,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: McTextStyles.micro.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(width: 6),
          action!,
        ],
      ],
    );
  }
}

class _SectionIconButton extends StatelessWidget {
  const _SectionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _alpha(_koreanAirBlue, 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: _koreanAirNavy),
          ),
        ),
      ),
    );
  }
}

class _SoftNotice extends StatelessWidget {
  const _SoftNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alpha(_warningColor, 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _alpha(_warningColor, 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: _warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: McTextStyles.meta.copyWith(color: _warningColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _koreanAirBlue),
          const SizedBox(height: 14),
          Text(
            '보너스석 현황을 불러오는 중입니다.',
            style: McTextStyles.body.copyWith(color: McColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: McColors.muted, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: McTextStyles.bodyStrong,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardInsightSelection {
  const _AwardInsightSelection({
    required this.routeIndex,
    required this.isOutbound,
    required this.date,
    required this.showBusiness,
    required this.showFirst,
  });

  factory _AwardInsightSelection.fromDayItem(
    _AwardDayInsightItem item,
    _AwardInsightMode mode,
  ) {
    return _AwardInsightSelection(
      routeIndex: item.routeIndex,
      isOutbound: item.isOutbound,
      date: item.day.date,
      showBusiness: mode != _AwardInsightMode.firstClass,
      showFirst: mode != _AwardInsightMode.business,
    );
  }

  final int routeIndex;
  final bool isOutbound;
  final DateTime date;
  final bool showBusiness;
  final bool showFirst;
}

class _AwardDayInsightItem {
  const _AwardDayInsightItem({
    required this.routeIndex,
    required this.route,
    required this.direction,
    required this.day,
    required this.isOutbound,
  });

  final int routeIndex;
  final KoreanAirAwardRouteItem route;
  final KoreanAirAwardDirection direction;
  final KoreanAirAwardDay day;
  final bool isOutbound;
}

class _AwardRouteInsightItem {
  const _AwardRouteInsightItem({
    required this.routeIndex,
    required this.route,
    required this.nearest,
    required this.nearestBusiness,
    required this.nearestFirst,
  });

  final int routeIndex;
  final KoreanAirAwardRouteItem route;
  final _AwardDayInsightItem? nearest;
  final _AwardDayInsightItem? nearestBusiness;
  final _AwardDayInsightItem? nearestFirst;
}

List<_AwardDayInsightItem> _awardDayItems(
  KoreanAirAwardDashboardData data,
  _AwardInsightMode mode,
) {
  final items = <_AwardDayInsightItem>[];

  for (var routeIndex = 0; routeIndex < data.routes.length; routeIndex++) {
    final route = data.routes[routeIndex];
    items
      ..addAll(_directionDayItems(
        routeIndex: routeIndex,
        route: route,
        direction: route.outbound,
        isOutbound: true,
        business: mode == _AwardInsightMode.business,
        first: mode == _AwardInsightMode.firstClass,
      ))
      ..addAll(_directionDayItems(
        routeIndex: routeIndex,
        route: route,
        direction: route.inbound,
        isOutbound: false,
        business: mode == _AwardInsightMode.business,
        first: mode == _AwardInsightMode.firstClass,
      ));
  }

  items.sort((a, b) => _compareUpcomingDates(a.day.date, b.day.date));
  return items;
}

List<_AwardRouteInsightItem> _awardRouteItems(
  KoreanAirAwardDashboardData data,
) {
  final items = <_AwardRouteInsightItem>[];

  for (var routeIndex = 0; routeIndex < data.routes.length; routeIndex++) {
    final route = data.routes[routeIndex];
    if (route.premiumDateCount == 0) continue;
    items.add(_AwardRouteInsightItem(
      routeIndex: routeIndex,
      route: route,
      nearest: _nearestInsightDayForRoute(
        routeIndex: routeIndex,
        route: route,
        business: true,
        first: true,
      ),
      nearestBusiness: _nearestInsightDayForRoute(
        routeIndex: routeIndex,
        route: route,
        business: true,
        first: false,
      ),
      nearestFirst: _nearestInsightDayForRoute(
        routeIndex: routeIndex,
        route: route,
        business: false,
        first: true,
      ),
    ));
  }

  items.sort((a, b) {
    final left = a.nearest?.day.date;
    final right = b.nearest?.day.date;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return _compareUpcomingDates(left, right);
  });
  return items;
}

List<_AwardDayInsightItem> _directionDayItems({
  required int routeIndex,
  required KoreanAirAwardRouteItem route,
  required KoreanAirAwardDirection direction,
  required bool isOutbound,
  required bool business,
  required bool first,
}) {
  return direction.days
      .where((day) => day.matches(business: business, first: first))
      .map((day) => _AwardDayInsightItem(
            routeIndex: routeIndex,
            route: route,
            direction: direction,
            day: day,
            isOutbound: isOutbound,
          ))
      .toList();
}

_AwardDayInsightItem? _nearestInsightDayForRoute({
  required int routeIndex,
  required KoreanAirAwardRouteItem route,
  required bool business,
  required bool first,
}) {
  final candidates = <_AwardDayInsightItem>[
    ..._directionDayItems(
      routeIndex: routeIndex,
      route: route,
      direction: route.outbound,
      isOutbound: true,
      business: business,
      first: first,
    ),
    ..._directionDayItems(
      routeIndex: routeIndex,
      route: route,
      direction: route.inbound,
      isOutbound: false,
      business: business,
      first: first,
    ),
  ]..sort((a, b) => _compareUpcomingDates(a.day.date, b.day.date));

  return candidates.isEmpty ? null : candidates.first;
}

int _compareUpcomingDates(DateTime left, DateTime right) {
  final today = DateUtils.dateOnly(DateTime.now());
  final leftDate = DateUtils.dateOnly(left);
  final rightDate = DateUtils.dateOnly(right);
  final leftPast = leftDate.isBefore(today);
  final rightPast = rightDate.isBefore(today);
  if (leftPast != rightPast) return leftPast ? 1 : -1;
  if (leftPast && rightPast) return rightDate.compareTo(leftDate);
  return leftDate.compareTo(rightDate);
}

int _seatCountForMode(KoreanAirAwardDay day, _AwardInsightMode mode) {
  switch (mode) {
    case _AwardInsightMode.business:
      return day.businessCount;
    case _AwardInsightMode.firstClass:
      return day.firstCount;
    case _AwardInsightMode.routes:
      return day.businessCount + day.firstCount;
  }
}

class _RouteDayCandidate {
  const _RouteDayCandidate({
    required this.day,
    required this.directionLabel,
  });

  final KoreanAirAwardDay day;
  final String directionLabel;
}

_RouteDayCandidate? _nearestRouteDay(
  KoreanAirAwardRouteItem route, {
  bool business = false,
  bool first = false,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final candidates = <_RouteDayCandidate>[
    ...route.outbound.days
        .where((day) => day.matches(business: business, first: first))
        .map((day) => _RouteDayCandidate(day: day, directionLabel: '가는편')),
    ...route.inbound.days
        .where((day) => day.matches(business: business, first: first))
        .map((day) => _RouteDayCandidate(day: day, directionLabel: '오는편')),
  ]..sort((a, b) => a.day.date.compareTo(b.day.date));

  if (candidates.isEmpty) return null;
  return candidates.firstWhere(
    (candidate) => !candidate.day.date.isBefore(today),
    orElse: () => candidates.first,
  );
}

String _formatRouteDay(_RouteDayCandidate candidate) {
  return '${candidate.day.date.month}/${candidate.day.date.day} ${candidate.directionLabel}';
}

String _formatFullDate(DateTime date) {
  return '${date.year}년 ${date.month}월 ${date.day}일';
}

String _formatCompactDate(DateTime date) {
  return '${date.month}/${date.day}(${_weekdayLabel(date)})';
}

String _formatMonthLabel(DateTime date) {
  return '${date.year}년 ${date.month}월';
}

String _weekdayLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return weekdays[date.weekday - 1];
}

String _relativeDayLabel(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final target = DateUtils.dateOnly(date);
  final difference = target.difference(today).inDays;
  if (difference == 0) return '오늘';
  if (difference == 1) return '내일';
  if (difference > 1) return 'D-$difference';
  if (difference == -1) return '어제';
  return '${difference.abs()}일 전';
}

String _formatShortTimestampKey(String key) {
  if (key.length < 10) return '정보 없음';
  final month = int.tryParse(key.substring(4, 6));
  final day = int.tryParse(key.substring(6, 8));
  final hour = int.tryParse(key.substring(8, 10));
  if (month == null || day == null || hour == null) return '정보 없음';
  return '$month/$day $hour시';
}

String _formatTimestampKey(String key) {
  if (key.length < 10) return '업데이트 정보 없음';
  final year = int.tryParse(key.substring(0, 4));
  final month = int.tryParse(key.substring(4, 6));
  final day = int.tryParse(key.substring(6, 8));
  final hour = key.substring(8, 10);
  if (year == null || month == null || day == null) {
    return '업데이트 정보 없음';
  }
  return '$year년 $month월 $day일 $hour시';
}

DateTime _monthOnly(DateTime date) {
  return DateTime(date.year, date.month);
}
