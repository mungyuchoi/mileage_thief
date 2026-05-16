import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../models/card_product_model.dart';
import '../services/card_catalog_service.dart';
import 'card_catalog_screen.dart';

const Color _hubInk = McColors.ink;
const Color _hubMuted = McColors.muted;
const Color _hubLine = McColors.line;
const Color _hubPage = McColors.background;
const Color _hubAccent = McColors.accent;
const Color _hubSecondaryAccent = McColors.inkSoft;
const Color _hubSoftSurface = McColors.field;
const Color _hubThumbSurface = McColors.field;

const Map<String, String> _spendCategoryLabels = {
  'general': '일반',
  'overseas': '해외',
  'onlineShopping': '온라인/쇼핑',
  'mart': '마트',
  'telecomSubscription': '통신/구독',
  'travel': '여행',
  'giftcard': '상품권',
};

class CardHubScreen extends StatefulWidget {
  final VoidCallback? onRequireLogin;

  const CardHubScreen({
    super.key,
    this.onRequireLogin,
  });

  @override
  State<CardHubScreen> createState() => _CardHubScreenState();
}

class _CardHubScreenState extends State<CardHubScreen> {
  final CardCatalogService _service = CardCatalogService();

  Future<void> _openDetail(CatalogCardProduct product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardProductDetailScreen(
          cardId: product.id,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  Future<void> _openDetailCommunity(CatalogCardProduct product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardProductDetailScreen(
          cardId: product.id,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  Future<void> _openIssuerCards(
    String issuerName,
    CardIssuer? issuer,
    List<CatalogCardProduct> products,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _IssuerCardListScreen(
          issuerName: issuerName,
          issuer: issuer,
          products: products,
          service: _service,
          onOpenCard: _openDetail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _hubPage,
        appBar: AppBar(
          title: const Text(
            '카드',
            style: McTextStyles.appBarTitle,
          ),
          backgroundColor: Colors.white,
          foregroundColor: _hubInk,
          elevation: 0.4,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: _hubAccent,
            unselectedLabelColor: _hubMuted,
            labelStyle: McTextStyles.tabSelected,
            unselectedLabelStyle: McTextStyles.tab,
            indicatorColor: _hubAccent,
            tabs: [
              Tab(text: '전체 카드'),
              Tab(text: '추천'),
              Tab(text: '랭킹'),
              Tab(text: '카드사'),
              Tab(text: '이벤트'),
            ],
          ),
        ),
        body: StreamBuilder<List<CatalogCardProduct>>(
          stream: _service.watchProducts(),
          initialData: _service.peekProducts(),
          builder: (context, snapshot) {
            final products = snapshot.data ?? const <CatalogCardProduct>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                products.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: _hubAccent),
              );
            }
            if (snapshot.hasError && products.isEmpty) {
              return _HubEmptyState(
                icon: Icons.error_outline,
                title: '카드 데이터를 불러오지 못했습니다.',
                message: '${snapshot.error}',
              );
            }
            return TabBarView(
              children: [
                CardCatalogScreen(
                  onRequireLogin: widget.onRequireLogin,
                  showAppBar: false,
                  products: products,
                ),
                _RecommendTab(
                  products: products,
                  service: _service,
                  onOpenCard: _openDetail,
                  onOpenCommunity: _openDetailCommunity,
                  onRequireLogin: widget.onRequireLogin,
                ),
                _RankingTab(
                  products: products,
                  service: _service,
                  onOpenCard: _openDetail,
                ),
                _IssuerTab(
                  products: products,
                  service: _service,
                  onOpenCard: _openDetail,
                  onOpenIssuer: _openIssuerCards,
                ),
                _EventTab(
                  products: products,
                  service: _service,
                  onOpenCard: _openDetail,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecommendTab extends StatefulWidget {
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;
  final ValueChanged<CatalogCardProduct> onOpenCommunity;
  final VoidCallback? onRequireLogin;

  const _RecommendTab({
    required this.products,
    required this.service,
    required this.onOpenCard,
    required this.onOpenCommunity,
    required this.onRequireLogin,
  });

  @override
  State<_RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<_RecommendTab> {
  CardPreferenceProfile _profile = CardPreferenceProfile.defaults();
  Future<CardRecommendationDashboard>? _dashboardFuture;
  bool _loadedSavedProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedProfileOnce();
  }

  @override
  void didUpdateWidget(covariant _RecommendTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dashboardFuture == null && widget.products.isNotEmpty) {
      _dashboardFuture = Future.value(
        _localRecommendationDashboard(widget.products, _profile),
      );
    }
  }

  Future<void> _loadSavedProfileOnce() async {
    if (_loadedSavedProfile) return;
    _loadedSavedProfile = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _dashboardFuture = Future.value(
        _localRecommendationDashboard(widget.products, _profile),
      );
      if (mounted) setState(() {});
      return;
    }
    try {
      final saved = await widget.service.loadCardPreferenceProfile(uid: uid);
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _dashboardFuture = _calculateDashboard(saved);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboardFuture = Future.value(
          _localRecommendationDashboard(widget.products, _profile),
        );
      });
    }
  }

  Future<CardRecommendationDashboard> _calculateDashboard(
    CardPreferenceProfile profile,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await widget.service
          .saveCardPreferenceProfile(uid: uid, profile: profile);
    }
    try {
      final dashboard = await widget.service.calculateCardMatches(
        profile: profile,
        limit: 12,
      );
      if (dashboard.sections.isNotEmpty ||
          dashboard.comparisonRows.isNotEmpty) {
        return dashboard;
      }
    } catch (_) {
      // Cloud Functions가 아직 배포되지 않은 로컬/개발 환경에서는 앱 안에서 계산한다.
    }
    return _localRecommendationDashboard(widget.products, profile);
  }

  void _updateProfile(CardPreferenceProfile profile) {
    setState(() {
      _profile = profile;
      _dashboardFuture = _calculateDashboard(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallbackDashboard =
        _localRecommendationDashboard(widget.products, _profile);
    return RefreshIndicator(
      color: _hubAccent,
      backgroundColor: Colors.white,
      onRefresh: () async {
        setState(() => _dashboardFuture = _calculateDashboard(_profile));
        await _dashboardFuture;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _MatchIntroPanel(
            profile: _profile,
            onChanged: _updateProfile,
          ),
          const SizedBox(height: 12),
          FutureBuilder<CardRecommendationDashboard>(
            future: _dashboardFuture,
            initialData: fallbackDashboard,
            builder: (context, snapshot) {
              final dashboard = snapshot.data ?? fallbackDashboard;
              if (dashboard.sections.isEmpty &&
                  dashboard.comparisonRows.isEmpty) {
                return const _HubEmptyState(
                  icon: Icons.credit_card_off_outlined,
                  title: '추천할 카드가 아직 없습니다.',
                  message: '카드 정보를 가져오거나 새 카드를 요청해보세요.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecommendationSummaryPanel(dashboard: dashboard),
                  const SizedBox(height: 14),
                  const _SectionHeader(
                    title: '추천 묶음',
                    subtitle: '마일리지, 상테크, 여행, 검증 신호를 따로 비교합니다.',
                    action: null,
                  ),
                  for (final section in dashboard.sections) ...[
                    _RecommendationRailSection(
                      section: section,
                      products: widget.products,
                      service: widget.service,
                      onOpenCard: widget.onOpenCard,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _SectionHeader(
                    title: '카드별 예상 비교',
                    subtitle: '추천 후보를 표로 놓고 월 마일, 가치, 조건을 봅니다.',
                  ),
                  _ComparisonTable(
                    rows: dashboard.comparisonRows,
                    products: widget.products,
                    onOpenCard: widget.onOpenCard,
                    onOpenCommunity: widget.onOpenCommunity,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingTab extends StatelessWidget {
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _RankingTab({
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardRanking>>(
      stream: service.watchRankings(),
      builder: (context, snapshot) {
        final remoteRankings = snapshot.data ?? const <CardRanking>[];
        final liveRankings = _liveProductRankings(products);
        final isInitialLoading =
            snapshot.connectionState == ConnectionState.waiting &&
                products.isEmpty &&
                !snapshot.hasData;
        final hasBlockingError = snapshot.hasError && products.isEmpty;
        final rankings = _rankingsForDisplay(remoteRankings, liveRankings);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const _SectionHeader(
              title: '마일캐치 랭킹',
              subtitle: '조회, 좋아요, 댓글과 마일리지/여행 키워드를 함께 봅니다.',
            ),
            if (isInitialLoading) ...[
              const LinearProgressIndicator(
                minHeight: 2,
                color: _hubAccent,
                backgroundColor: _hubLine,
              ),
              const SizedBox(height: 14),
            ],
            if (hasBlockingError) ...[
              _HubEmptyState(
                icon: Icons.error_outline,
                title: '랭킹 데이터를 불러오지 못했습니다.',
                message: '${snapshot.error}',
              ),
              const SizedBox(height: 14),
            ],
            if (!hasBlockingError) ...[
              if (!isInitialLoading && rankings.isEmpty)
                const _HubEmptyState(
                  icon: Icons.leaderboard_outlined,
                  title: '랭킹에 표시할 카드가 없습니다.',
                  message: '조회, 좋아요, 댓글이 쌓이면 실시간 랭킹이 표시됩니다.',
                )
              else
                for (final ranking in rankings.take(5)) ...[
                  _RankingSection(
                    ranking: ranking,
                    products: products,
                    service: service,
                    onOpenCard: onOpenCard,
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _IssuerTab extends StatelessWidget {
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;
  final void Function(
    String issuerName,
    CardIssuer? issuer,
    List<CatalogCardProduct> products,
  ) onOpenIssuer;

  const _IssuerTab({
    required this.products,
    required this.service,
    required this.onOpenCard,
    required this.onOpenIssuer,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardIssuer>>(
      stream: service.watchIssuers(),
      builder: (context, snapshot) {
        final issuers = snapshot.data ?? const <CardIssuer>[];
        final issuerNames = {
          ...issuers.map((issuer) => issuer.nameKo),
          ...products.map((product) => product.issuerName),
        }.where((name) => name.trim().isNotEmpty).toList()
          ..sort();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const _SectionHeader(
              title: '카드사별 보기',
              subtitle: '카드사별 대표 카드, 마일리지 카드, 진행 이벤트를 빠르게 봅니다.',
            ),
            if (issuerNames.isEmpty)
              const _HubEmptyState(
                icon: Icons.account_balance_outlined,
                title: '카드사 정보가 없습니다.',
                message: '관리자 수집 후 카드사관이 채워집니다.',
              )
            else
              for (final issuerName in issuerNames) ...[
                Builder(builder: (context) {
                  final issuer = _issuerByName(issuers, issuerName);
                  final issuerProducts = products
                      .where((product) => product.issuerName == issuerName)
                      .toList();
                  return _IssuerGroupTile(
                    issuerName: issuerName,
                    issuer: issuer,
                    products: issuerProducts,
                    service: service,
                    onOpenCard: onOpenCard,
                    onOpenIssuer: () => onOpenIssuer(
                      issuerName,
                      issuer,
                      issuerProducts,
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _EventTab extends StatelessWidget {
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _EventTab({
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardEvent>>(
      stream: service.watchEvents(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <CardEvent>[];
        final fallback = _eventsFromProducts(products);
        final visibleEvents = events.isEmpty ? fallback : events;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const _SectionHeader(
              title: '캐시백/이벤트',
              subtitle: '외부 신청 링크는 출처로 연결하고, 마일캐치에서는 조건을 비교합니다.',
            ),
            if (visibleEvents.isEmpty)
              const _HubEmptyState(
                icon: Icons.local_offer_outlined,
                title: '진행중인 이벤트가 없습니다.',
                message: '카드 상세의 이벤트 요약 또는 관리자 동기화 후 표시됩니다.',
              )
            else
              for (final event in visibleEvents.take(40)) ...[
                _EventTile(
                  event: event,
                  products: products,
                  service: service,
                  onOpenCard: onOpenCard,
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _MatchIntroPanel extends StatefulWidget {
  final CardPreferenceProfile profile;
  final ValueChanged<CardPreferenceProfile> onChanged;

  const _MatchIntroPanel({
    required this.profile,
    required this.onChanged,
  });

  @override
  State<_MatchIntroPanel> createState() => _MatchIntroPanelState();
}

class _MatchIntroPanelState extends State<_MatchIntroPanel> {
  late String _airline;
  late double _monthlySpend;
  late bool _overseas;
  late bool _lounge;
  late bool _giftcard;
  late double _annualFee;
  late double _previousSpend;
  late Map<String, double> _spendCategories;
  bool _showDetailed = false;

  @override
  void initState() {
    super.initState();
    _setFromProfile(widget.profile);
  }

  @override
  void didUpdateWidget(covariant _MatchIntroPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _setFromProfile(widget.profile);
  }

  void _setFromProfile(CardPreferenceProfile profile) {
    _airline = profile.preferredAirline;
    _monthlySpend = profile.monthlySpendKRW.toDouble().clamp(300000, 5000000);
    _overseas = profile.usesOverseas;
    _lounge = profile.wantsLounge;
    _giftcard = profile.usesGiftcard;
    _annualFee = profile.maxAnnualFeeKRW.toDouble().clamp(0, 500000);
    _previousSpend =
        profile.maxPreviousMonthSpendKRW.toDouble().clamp(0, 2000000);
    _spendCategories = _profileSpendCategories(profile);
  }

  void _emit() {
    final categories = <String>{
      'mileage',
      if (_overseas) 'travel',
      if (_lounge) 'lounge',
      if (_giftcard) 'giftcard',
    }.toList();
    final detailedTotal = _spendCategories.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final monthlySpend = _showDetailed && detailedTotal > 0
        ? detailedTotal.round()
        : _monthlySpend.round();
    final spendPayload = _currentSpendCategoryPayload(monthlySpend);
    widget.onChanged(CardPreferenceProfile(
      preferredAirline: _airline,
      monthlySpendKRW: monthlySpend,
      spendCategories: spendPayload,
      usesOverseas: _overseas,
      wantsLounge: _lounge,
      usesGiftcard: _giftcard,
      benefitCategoryIds: categories,
      maxAnnualFeeKRW: _annualFee.round(),
      maxPreviousMonthSpendKRW: _previousSpend.round(),
      mileValueKRW: widget.profile.mileValueKRW,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final detailedTotal = _spendCategories.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final displayedMonthly =
        _showDetailed && detailedTotal > 0 ? detailedTotal : _monthlySpend;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: _hubAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '마일캐치 추천',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '소비 패턴, 항공 마일, 라운지, 상품권 루틴을 함께 비교합니다.',
            style: TextStyle(color: _hubMuted, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: ['대한항공', '아시아나', 'LCC/외항사', '상관없음'].map((airline) {
              return ChoiceChip(
                label: Text(airline),
                selected: _airline == airline,
                backgroundColor: Colors.white,
                selectedColor: _hubAccent,
                surfaceTintColor: Colors.white,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _airline == airline ? Colors.white : _hubInk,
                  fontWeight: FontWeight.w400,
                ),
                side: BorderSide(
                  color: _airline == airline ? _hubAccent : _hubLine,
                ),
                onSelected: (_) => setState(() {
                  _airline = airline;
                  _emit();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (!_showDetailed)
            _SliderRow(
              label: '월 사용액',
              valueLabel: '${won.format(displayedMonthly.round())}원',
              value: _monthlySpend,
              min: 300000,
              max: 5000000,
              divisions: 47,
              onChanged: (value) => setState(() => _monthlySpend = value),
              onChangeEnd: (_) => _emit(),
            ),
          _SliderRow(
            label: '허용 연회비',
            valueLabel: '${won.format(_annualFee.round())}원',
            value: _annualFee,
            min: 0,
            max: 500000,
            divisions: 50,
            onChanged: (value) => setState(() => _annualFee = value),
            onChangeEnd: (_) => _emit(),
          ),
          _SliderRow(
            label: '허용 전월실적',
            valueLabel: '${won.format(_previousSpend.round())}원',
            value: _previousSpend,
            min: 0,
            max: 2000000,
            divisions: 40,
            onChanged: (value) => setState(() => _previousSpend = value),
            onChangeEnd: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('해외/여행'),
                selected: _overseas,
                backgroundColor: Colors.white,
                selectedColor: _hubAccent,
                surfaceTintColor: Colors.white,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _overseas ? Colors.white : _hubInk,
                  fontWeight: FontWeight.w400,
                ),
                side: BorderSide(color: _overseas ? _hubAccent : _hubLine),
                onSelected: (value) => setState(() {
                  _overseas = value;
                  _emit();
                }),
              ),
              FilterChip(
                label: const Text('라운지'),
                selected: _lounge,
                backgroundColor: Colors.white,
                selectedColor: _hubAccent,
                surfaceTintColor: Colors.white,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _lounge ? Colors.white : _hubInk,
                  fontWeight: FontWeight.w400,
                ),
                side: BorderSide(color: _lounge ? _hubAccent : _hubLine),
                onSelected: (value) => setState(() {
                  _lounge = value;
                  _emit();
                }),
              ),
              FilterChip(
                label: const Text('상테크'),
                selected: _giftcard,
                backgroundColor: Colors.white,
                selectedColor: _hubAccent,
                surfaceTintColor: Colors.white,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _giftcard ? Colors.white : _hubInk,
                  fontWeight: FontWeight.w400,
                ),
                side: BorderSide(color: _giftcard ? _hubAccent : _hubLine),
                onSelected: (value) => setState(() {
                  _giftcard = value;
                  _emit();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _hubAccent,
                side: const BorderSide(color: _hubAccent),
                textStyle: const TextStyle(fontWeight: FontWeight.w400),
              ),
              onPressed: () {
                setState(() {
                  _showDetailed = !_showDetailed;
                  if (_showDetailed) {
                    final currentTotal = _spendCategories.values.fold<double>(
                      0,
                      (sum, value) => sum + value,
                    );
                    if ((currentTotal - _monthlySpend).abs() > 1000) {
                      _spendCategories = _defaultSpendCategoriesForMonthly(
                        _monthlySpend.round(),
                      ).map((key, value) => MapEntry(key, value.toDouble()));
                    }
                  }
                });
                _emit();
              },
              icon: Icon(
                _showDetailed ? Icons.keyboard_arrow_up : Icons.tune_outlined,
                size: 18,
              ),
              label: Text(_showDetailed ? '상세 입력 닫기' : '상세 입력'),
            ),
          ),
          if (_showDetailed) ...[
            const SizedBox(height: 10),
            _DetailedSpendPanel(
              spendCategories: _spendCategories,
              totalLabel: '${won.format(detailedTotal.round())}원',
              onChanged: (key, value) {
                setState(() {
                  _spendCategories = {
                    ..._spendCategories,
                    key: value,
                  };
                  _monthlySpend = _spendCategories.values.fold<double>(
                    0,
                    (sum, item) => sum + item,
                  );
                });
              },
              onChangeEnd: _emit,
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _currentSpendCategoryPayload(int monthlySpend) {
    if (!_showDetailed) return _defaultSpendCategoriesForMonthly(monthlySpend);
    return _spendCategories.map(
      (key, value) => MapEntry(key, value.round()),
    );
  }
}

Map<String, double> _profileSpendCategories(CardPreferenceProfile profile) {
  final source = profile.spendCategories.isEmpty
      ? _defaultSpendCategoriesForMonthly(profile.monthlySpendKRW)
      : profile.spendCategories;
  return {
    for (final key in _spendCategoryLabels.keys)
      key: (source[key] ?? 0).toDouble().clamp(0, 5000000).toDouble(),
  };
}

Map<String, int> _defaultSpendCategoriesForMonthly(int monthlySpend) {
  final safeMonthlySpend = monthlySpend <= 0 ? 1000000 : monthlySpend;
  int portion(double ratio) => (safeMonthlySpend * ratio).round();
  return {
    'general': portion(0.50),
    'overseas': portion(0.10),
    'onlineShopping': portion(0.15),
    'mart': portion(0.10),
    'telecomSubscription': portion(0.10),
    'travel': portion(0.05),
    'giftcard': 0,
  };
}

class _DetailedSpendPanel extends StatelessWidget {
  final Map<String, double> spendCategories;
  final String totalLabel;
  final void Function(String key, double value) onChanged;
  final VoidCallback onChangeEnd;

  const _DetailedSpendPanel({
    required this.spendCategories,
    required this.totalLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hubLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '항목별 소비',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              Text(
                totalLabel,
                style: const TextStyle(
                  color: _hubAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in _spendCategoryLabels.entries)
            _SliderRow(
              label: entry.value,
              valueLabel:
                  '${won.format((spendCategories[entry.key] ?? 0).round())}원',
              value: (spendCategories[entry.key] ?? 0)
                  .clamp(0, 2000000)
                  .toDouble(),
              min: 0,
              max: entry.key == 'giftcard' ? 3000000 : 2000000,
              divisions: entry.key == 'giftcard' ? 60 : 40,
              onChanged: (value) => onChanged(entry.key, value),
              onChangeEnd: (_) => onChangeEnd(),
            ),
        ],
      ),
    );
  }
}

class _RecommendationSummaryPanel extends StatelessWidget {
  final CardRecommendationDashboard dashboard;

  const _RecommendationSummaryPanel({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final top = dashboard.comparisonRows.isEmpty
        ? null
        : dashboard.comparisonRows.first;
    final bestAnnualValue = dashboard.comparisonRows.fold<int>(
      0,
      (maxValue, match) => math.max(maxValue, match.estimatedAnnualValueKRW),
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추천 요약',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  label: '대표 카드',
                  value: top?.product?.name ?? top?.cardId ?? '-',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardMetric(
                  label: '추천 묶음',
                  value: '${dashboard.sections.length}개',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  label: '최대 연 가치',
                  value: bestAnnualValue <= 0
                      ? '검증 필요'
                      : '${won.format(bestAnnualValue)}원',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardMetric(
                  label: '비교 후보',
                  value: '${dashboard.comparisonRows.length}장',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DashboardMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _hubSoftSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hubLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _hubMuted, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _hubInk),
          ),
        ],
      ),
    );
  }
}

class _RecommendationRailSection extends StatelessWidget {
  final CardRecommendationSection section;
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _RecommendationRailSection({
    required this.section,
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  @override
  Widget build(BuildContext context) {
    final matches = section.matches.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                section.subtitle,
                style: const TextStyle(color: _hubMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final match = matches[index];
              final product = _productForMatch(match, products);
              return SizedBox(
                width: 330,
                child: _MatchCardTile(
                  match: match,
                  product: product,
                  service: service,
                  onTap: () => onOpenCard(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<CardMatchResult> rows;
  final List<CatalogCardProduct> products;
  final ValueChanged<CatalogCardProduct> onOpenCard;
  final ValueChanged<CatalogCardProduct> onOpenCommunity;

  const _ComparisonTable({
    required this.rows,
    required this.products,
    required this.onOpenCard,
    required this.onOpenCommunity,
  });

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    if (rows.isEmpty) {
      return const _HubEmptyState(
        icon: Icons.table_chart_outlined,
        title: '비교할 카드가 없습니다.',
        message: '카드 데이터가 쌓이면 예상 비교표가 표시됩니다.',
      );
    }
    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 40,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('카드')),
            DataColumn(label: Text('예상 월 마일')),
            DataColumn(label: Text('연 환산 가치')),
            DataColumn(label: Text('전월실적')),
            DataColumn(label: Text('연회비')),
            DataColumn(label: Text('라운지')),
            DataColumn(label: Text('이벤트')),
            DataColumn(label: Text('검증글')),
          ],
          rows: rows.take(14).map((match) {
            final product = _productForMatch(match, products);
            return DataRow(
              onSelectChanged: (_) => onOpenCard(product),
              cells: [
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(
                  match.estimatedMonthlyMiles <= 0
                      ? '계산 불가'
                      : '${won.format(match.estimatedMonthlyMiles)}마일',
                )),
                DataCell(Text(
                  match.estimatedAnnualValueKRW <= 0
                      ? '검증 필요'
                      : '${won.format(match.estimatedAnnualValueKRW)}원',
                )),
                DataCell(
                    Text(_shortCellText(product.previousMonthSpendSummary))),
                DataCell(Text(_shortCellText(product.annualFeeSummary))),
                DataCell(Text(
                  product.loungeSummaryText.isEmpty
                      ? '-'
                      : _shortCellText(product.loungeSummaryText),
                )),
                DataCell(Text(
                  product.eventSummaryText.isEmpty
                      ? '-'
                      : _shortCellText(product.eventSummaryText),
                )),
                DataCell(
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _hubAccent),
                    onPressed: () => onOpenCommunity(product),
                    child: Text('${product.commentsCount}개'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: _hubAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: _hubAccent,
          inactiveColor: _hubLine,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

class _RankingSection extends StatelessWidget {
  final CardRanking ranking;
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _RankingSection({
    required this.ranking,
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {
      for (final product in products.where(_isRankableProduct))
        product.id: product
    };
    final ranked = ranking.cardIds
        .map((id) => byId[id])
        .whereType<CatalogCardProduct>()
        .toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ranking.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 3),
          Text(
            '${ranking.periodLabel} · ${ranking.basis}',
            style:
                const TextStyle(color: _hubMuted, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 12),
          if (ranked.isEmpty)
            const Text(
              '랭킹에 표시할 카드가 없습니다.',
              style: TextStyle(color: _hubMuted, fontWeight: FontWeight.w400),
            )
          else
            for (int i = 0; i < ranked.take(5).length; i++) ...[
              _CompactCardRow(
                rank: i + 1,
                product: ranked[i],
                service: service,
                onTap: () => onOpenCard(ranked[i]),
              ),
              if (i < ranked.take(5).length - 1) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _IssuerGroupTile extends StatelessWidget {
  final String issuerName;
  final CardIssuer? issuer;
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;
  final VoidCallback onOpenIssuer;

  const _IssuerGroupTile({
    required this.issuerName,
    required this.issuer,
    required this.products,
    required this.service,
    required this.onOpenCard,
    required this.onOpenIssuer,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortIssuerProducts(products);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenIssuer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  _IssuerLogo(issuer: issuer, issuerName: issuerName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issuerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '${products.length}개 카드 · ${products.where((p) => p.isMileageCard).length}개 마일리지',
                          style: const TextStyle(
                            color: _hubMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (issuer?.eventEnabled == true) ...[
                    const _StatusPill(
                      label: '이벤트',
                      color: _hubSecondaryAccent,
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Icon(Icons.chevron_right, color: Color(0xFFC0C5CF)),
                ],
              ),
            ),
          ),
          if (sorted.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (int i = 0; i < sorted.take(3).length; i++) ...[
              _CompactCardRow(
                rank: i + 1,
                product: sorted[i],
                service: service,
                onTap: () => onOpenCard(sorted[i]),
              ),
              if (i < sorted.take(3).length - 1) const Divider(height: 18),
            ],
          ],
        ],
      ),
    );
  }
}

class _IssuerCardListScreen extends StatelessWidget {
  final String issuerName;
  final CardIssuer? issuer;
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _IssuerCardListScreen({
    required this.issuerName,
    required this.issuer,
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortIssuerProducts(products);
    final mileageCount =
        sorted.where((product) => product.isMileageCard).length;
    return Scaffold(
      backgroundColor: _hubPage,
      appBar: AppBar(
        title: Text(
          issuerName,
          style: McTextStyles.appBarTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: _hubInk,
        elevation: 0.4,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _Panel(
            child: Row(
              children: [
                _IssuerLogo(issuer: issuer, issuerName: issuerName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issuerName,
                        style: const TextStyle(
                          color: _hubInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sorted.length}개 카드 · $mileageCount개 마일리지',
                        style: const TextStyle(
                          color: _hubMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '카드 목록',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  const Text(
                    '표시할 카드가 없습니다.',
                    style: TextStyle(
                      color: _hubMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                else
                  for (int i = 0; i < sorted.length; i++) ...[
                    _CompactCardRow(
                      rank: i + 1,
                      product: sorted[i],
                      service: service,
                      onTap: () => onOpenCard(sorted[i]),
                    ),
                    if (i < sorted.length - 1) const Divider(height: 18),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CardEvent event;
  final List<CatalogCardProduct> products;
  final CardCatalogService service;
  final ValueChanged<CatalogCardProduct> onOpenCard;

  const _EventTile({
    required this.event,
    required this.products,
    required this.service,
    required this.onOpenCard,
  });

  Future<void> _openApply() async {
    final url = event.applyUrl ?? event.sourceUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final linked = products
        .where((product) => event.cardIds.contains(product.id))
        .toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: _hubSecondaryAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.issuerName} · ${event.displayBenefit}',
                      style: const TextStyle(
                        color: _hubMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusPill(
                label: event.type.toUpperCase(),
                color: _hubAccent,
              ),
              if (event.endsAt != null)
                _StatusPill(
                  label: '${DateFormat('M.d').format(event.endsAt!)}까지',
                  color: _hubSecondaryAccent,
                ),
            ],
          ),
          if (linked.isNotEmpty) ...[
            const Divider(height: 22),
            for (final product in linked.take(2))
              _CompactCardRow(
                product: product,
                service: service,
                onTap: () => onOpenCard(product),
              ),
          ],
          if ((event.applyUrl ?? event.sourceUrl)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _hubAccent),
                onPressed: _openApply,
                icon: const Icon(Icons.open_in_new_outlined, size: 18),
                label: const Text('출처 보기'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchCardTile extends StatelessWidget {
  final CardMatchResult match;
  final CatalogCardProduct product;
  final CardCatalogService service;
  final VoidCallback? onTap;

  const _MatchCardTile({
    required this.match,
    required this.product,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    return _Panel(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardThumb(product: product, service: service, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScoreBadge(score: match.score),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.issuerName} · ${product.cardTypeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _hubMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (match.estimatedMonthlyMiles > 0)
                        _StatusPill(
                          label:
                              '월 ${won.format(match.estimatedMonthlyMiles)}마일',
                          color: _hubAccent,
                        ),
                      if (match.estimatedAnnualValueKRW > 0)
                        _StatusPill(
                          label:
                              '연 ${won.format(match.estimatedAnnualValueKRW)}원 가치',
                          color: _hubSecondaryAccent,
                        ),
                      if (product.loungeSummaryText.isNotEmpty)
                        _StatusPill(
                          label: product.loungeSummaryText,
                          color: _hubSecondaryAccent,
                        ),
                    ],
                  ),
                  if (match.reasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      match.reasons.take(3).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCardRow extends StatelessWidget {
  final int? rank;
  final CatalogCardProduct product;
  final CardCatalogService service;
  final VoidCallback onTap;

  const _CompactCardRow({
    required this.product,
    required this.service,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: _hubAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
          _CardThumb(product: product, service: service, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.issuerName} · 좋아요 ${product.likesCount} · 댓글 ${product.commentsCount} · 조회 ${product.viewsCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _hubMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFC0C5CF)),
        ],
      ),
    );
  }
}

class _CardThumb extends StatelessWidget {
  final CatalogCardProduct product;
  final CardCatalogService service;
  final double size;

  const _CardThumb({
    required this.product,
    required this.service,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = product.mainDownloadUrl;
    if (url != null && url.isNotEmpty) {
      return _NetworkThumb(url: url, size: size);
    }
    final path = product.mainStoragePath;
    if (path == null || path.isEmpty) return _PlaceholderThumb(size: size);
    return FutureBuilder<String?>(
      future: service.downloadUrlForStoragePath(path),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null || resolved.isEmpty) {
          return _PlaceholderThumb(size: size);
        }
        return _NetworkThumb(url: resolved, size: size);
      },
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;
  final double size;

  const _NetworkThumb({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _hubThumbSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hubLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _PlaceholderThumb(size: size),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final double size;

  const _PlaceholderThumb({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _hubThumbSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hubLine),
      ),
      child: Icon(Icons.credit_card, color: _hubMuted, size: size * 0.48),
    );
  }
}

class _IssuerLogo extends StatelessWidget {
  final CardIssuer? issuer;
  final String issuerName;

  const _IssuerLogo({required this.issuer, required this.issuerName});

  @override
  Widget build(BuildContext context) {
    final url = issuer?.logoUrl;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _hubThumbSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hubLine),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? Text(
              issuerName.isEmpty ? '?' : issuerName.substring(0, 1),
              style: const TextStyle(fontWeight: FontWeight.w400),
            )
          : Image.network(url, fit: BoxFit.contain),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _hubAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _hubLine),
        ),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _hubInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _hubMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

class _HubEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HubEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, size: 38, color: _hubMuted),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _hubMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

CardRecommendationDashboard _localRecommendationDashboard(
  List<CatalogCardProduct> products,
  CardPreferenceProfile profile,
) {
  final matches = _localMatches(products, profile);
  final sections = _buildRecommendationSections(matches);
  final comparisonRows = _comparisonRowsForSections(sections);
  return CardRecommendationDashboard.fromMatches(
    profile: profile,
    sections: sections,
    comparisonRows: comparisonRows,
  );
}

List<CardMatchResult> _localMatches(
  List<CatalogCardProduct> products,
  CardPreferenceProfile profile,
) {
  final matches = products.map((product) {
    var baseScore = 25;
    final reasons = <String>[];
    final searchable = product.searchableText;
    final giftcardSpend = profile.spendCategories['giftcard'] ?? 0;
    final overseasSpend = profile.spendCategories['overseas'] ?? 0;
    final travelSpend = profile.spendCategories['travel'] ?? 0;
    final communityScore = math.min(
      100,
      product.commentsCount * 12 +
          product.likesCount * 5 +
          product.viewsCount ~/ 10,
    );
    var mileageScore = product.isMileageCard ? 42 : 0;
    var sangtechScore = 10;
    var travelScore = product.isTravelCard ? 38 : 0;

    if (product.isMileageCard) {
      baseScore += 18;
      reasons.add('마일리지 적립 성향');
    }
    if (profile.preferredAirline.contains('대한') &&
        (searchable.contains('대한') || searchable.contains('skypass'))) {
      baseScore += 16;
      mileageScore += 24;
      reasons.add('대한항공 선호와 맞음');
    }
    if (profile.preferredAirline.contains('아시아나') &&
        searchable.contains('아시아나')) {
      baseScore += 16;
      mileageScore += 24;
      reasons.add('아시아나 선호와 맞음');
    }
    if (profile.usesOverseas && product.isTravelCard) {
      baseScore += 12;
      travelScore += overseasSpend > 0 ? 18 : 10;
      reasons.add('해외/여행 혜택');
    }
    if (profile.wantsLounge &&
        (product.loungeSummaryText.isNotEmpty || searchable.contains('라운지'))) {
      baseScore += 12;
      travelScore += 22;
      reasons.add('라운지 활용 가능');
    }
    if (profile.usesGiftcard &&
        (searchable.contains('실적') ||
            searchable.contains('무실적') ||
            product.previousMonthSpendSummary != '-')) {
      baseScore += 7;
      sangtechScore += 28;
      reasons.add('상테크 검토 대상');
    }
    if (giftcardSpend > 0 &&
        (searchable.contains('실적') ||
            searchable.contains('무실적') ||
            searchable.contains('상품권') ||
            searchable.contains('상테크'))) {
      sangtechScore += 18;
    }
    if (product.eventSummaryText.isNotEmpty) sangtechScore += 10;
    if (travelSpend > 0 && product.isTravelCard) travelScore += 12;
    final annualFee = _extractFirstNumber(product.annualFeeSummary);
    if (annualFee > 0 && annualFee <= profile.maxAnnualFeeKRW) {
      baseScore += 5;
      reasons.add('연회비 허용 범위');
    }
    final previousSpend =
        _extractFirstNumber(product.previousMonthSpendSummary);
    if (previousSpend > 0 &&
        previousSpend <= profile.maxPreviousMonthSpendKRW) {
      baseScore += 5;
      sangtechScore += 10;
      reasons.add('전월실적 허용 범위');
    }
    baseScore += math.min(10, product.likesCount);
    baseScore += math.min(8, product.commentsCount * 2);
    baseScore += math.min(8, product.viewsCount ~/ 20);

    final perMile = _estimatedPerMileKRW(product);
    final monthlyMiles = perMile > 0
        ? math.max(0, (profile.monthlySpendKRW / perMile).round())
        : 0;
    final mileValue = profile.mileValueKRW <= 0 ? 15 : profile.mileValueKRW;
    final annualValue = monthlyMiles * 12 * mileValue;
    final annualFeeKRW = annualFee > 0 ? annualFee : null;
    final annualNetValue =
        annualFeeKRW == null ? null : annualValue - annualFeeKRW;
    final breakEvenMonthlySpend = annualFeeKRW == null || perMile <= 0
        ? null
        : (annualFeeKRW * perMile / (12 * mileValue)).round();
    mileageScore += math.min(20, monthlyMiles ~/ 50);
    sangtechScore += math.min(18, annualValue ~/ 60000);
    travelScore += math.min(10, (overseasSpend + travelSpend) ~/ 100000);
    mileageScore = mileageScore.clamp(0, 100).toInt();
    sangtechScore = sangtechScore.clamp(0, 100).toInt();
    travelScore = travelScore.clamp(0, 100).toInt();
    final overallScore = (baseScore.clamp(0, 100) * 0.38 +
            sangtechScore * 0.27 +
            mileageScore * 0.20 +
            travelScore * 0.10 +
            communityScore * 0.05)
        .round()
        .clamp(0, 100)
        .toInt();
    return CardMatchResult(
      cardId: product.id,
      score: overallScore,
      overallScore: overallScore,
      sangtechScore: sangtechScore,
      mileageScore: mileageScore,
      travelScore: travelScore,
      communityScore: communityScore,
      estimatedMonthlyMiles: monthlyMiles,
      estimatedAnnualValueKRW: annualValue,
      annualFeeKRW: annualFeeKRW,
      estimatedAnnualNetValueKRW: annualNetValue,
      breakEvenMonthlySpendKRW: breakEvenMonthlySpend,
      reasons: reasons.isEmpty ? ['마일캐치 인기 카드'] : reasons,
      product: product,
      raw: const <String, dynamic>{'source': 'local'},
    );
  }).toList();
  matches.sort((a, b) => b.overallScore.compareTo(a.overallScore));
  return matches;
}

List<CardRecommendationSection> _buildRecommendationSections(
  List<CardMatchResult> matches,
) {
  List<CardMatchResult> by(int Function(CardMatchResult match) score) {
    return matches.toList()..sort((a, b) => score(b).compareTo(score(a)));
  }

  final eventMatches = matches
      .where((match) => (match.product?.eventSummaryText ?? '').isNotEmpty)
      .toList()
    ..sort((a, b) => b.sangtechScore.compareTo(a.sangtechScore));
  return [
    CardRecommendationSection(
      key: 'overall',
      title: '내 소비 기준 TOP',
      subtitle: '입력한 소비 패턴과 카드 기본 효율을 함께 봅니다.',
      matches: by((match) => match.overallScore).take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
    CardRecommendationSection(
      key: 'sangtech',
      title: '상테크 효율 TOP',
      subtitle: '상품권/실적 루틴과 예상 마일 가치를 우선했습니다.',
      matches: by((match) => match.sangtechScore).take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
    CardRecommendationSection(
      key: 'mileage',
      title: '항공 마일리지 TOP',
      subtitle: '항공사 선호와 월 예상 마일을 기준으로 정렬했습니다.',
      matches: by((match) => match.mileageScore).take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
    CardRecommendationSection(
      key: 'travel',
      title: '라운지/트래블 TOP',
      subtitle: '해외결제, 여행, 라운지 활용도를 반영했습니다.',
      matches: by((match) => match.travelScore).take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
    CardRecommendationSection(
      key: 'event',
      title: '이벤트 캐시백 추천',
      subtitle: '진행 이벤트 요약이 있는 카드를 먼저 보여줍니다.',
      matches: eventMatches.take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
    CardRecommendationSection(
      key: 'community',
      title: '커뮤니티 검증 카드',
      subtitle: '댓글, 좋아요, 조회 기반으로 실제 검증 신호를 봅니다.',
      matches: by((match) => match.communityScore).take(10).toList(),
      raw: const <String, dynamic>{'source': 'local'},
    ),
  ].where((section) => section.matches.isNotEmpty).toList();
}

List<CardMatchResult> _comparisonRowsForSections(
  List<CardRecommendationSection> sections,
) {
  final seen = <String>{};
  final rows = <CardMatchResult>[];
  for (final section in sections) {
    for (final match in section.matches.take(4)) {
      if (seen.add(match.cardId)) rows.add(match);
      if (rows.length >= 14) return rows;
    }
  }
  return rows;
}

List<CardRanking> _rankingsForDisplay(
  List<CardRanking> remoteRankings,
  List<CardRanking> liveRankings,
) {
  if (liveRankings.isEmpty) return remoteRankings;
  final defaultIds = liveRankings.map((ranking) => ranking.id).toSet();
  return [
    ...liveRankings,
    ...remoteRankings.where((ranking) => !defaultIds.contains(ranking.id)),
  ];
}

List<CardRanking> _liveProductRankings(List<CatalogCardProduct> products) {
  final rankable = products.where(_isRankableProduct).toList();
  if (rankable.isEmpty) return const <CardRanking>[];

  final popular = rankable.toList()
    ..sort((a, b) => _compareByScore(a, b, _popularityScore));
  final mileage = rankable.where((product) => product.isMileageCard).toList()
    ..sort((a, b) => _compareByScore(a, b, _mileageRankingScore));
  final travel = rankable.where((product) => product.isTravelCard).toList()
    ..sort((a, b) => _compareByScore(a, b, _travelRankingScore));

  return [
    CardRanking(
      id: 'popular',
      title: '마일캐치 인기순',
      basis: '댓글 12점 + 좋아요 6점 + 조회 1점',
      periodLabel: '실시간',
      cardIds: popular.map((product) => product.id).take(30).toList(),
      raw: const <String, dynamic>{'source': 'liveProducts'},
    ),
    if (mileage.isNotEmpty)
      CardRanking(
        id: 'mileage',
        title: '항공마일리지 TOP',
        basis: '마일리지 적합도 + 실시간 반응',
        periodLabel: '실시간',
        cardIds: mileage.map((product) => product.id).take(30).toList(),
        raw: const <String, dynamic>{'source': 'liveProducts'},
      ),
    if (travel.isNotEmpty)
      CardRanking(
        id: 'travel',
        title: '라운지/트래블 TOP',
        basis: '여행/라운지 적합도 + 실시간 반응',
        periodLabel: '실시간',
        cardIds: travel.map((product) => product.id).take(30).toList(),
        raw: const <String, dynamic>{'source': 'liveProducts'},
      ),
  ];
}

bool _isRankableProduct(CatalogCardProduct product) {
  return product.status == 'active' || product.status == 'pending';
}

List<CatalogCardProduct> _sortIssuerProducts(
  List<CatalogCardProduct> products,
) {
  return products.toList()
    ..sort((a, b) {
      final bScore = b.likesCount * 2 + b.viewsCount + b.commentsCount * 4;
      final aScore = a.likesCount * 2 + a.viewsCount + a.commentsCount * 4;
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.name.compareTo(b.name);
    });
}

int _popularityScore(CatalogCardProduct product) {
  return product.commentsCount * 12 +
      product.likesCount * 6 +
      product.viewsCount;
}

int _mileageRankingScore(CatalogCardProduct product) {
  return _keywordScore(product.searchableText, const [
            '마일',
            'mileage',
            'skypass',
            '스카이패스',
            '대한항공',
            '아시아나',
          ]) *
          1000 +
      _popularityScore(product);
}

int _travelRankingScore(CatalogCardProduct product) {
  return _keywordScore(product.searchableText, const [
            '여행',
            '트래블',
            'travel',
            '해외',
            '라운지',
            'lounge',
            '항공',
            '호텔',
          ]) *
          1000 +
      _popularityScore(product);
}

int _keywordScore(String text, List<String> keywords) {
  var score = 0;
  for (final keyword in keywords) {
    if (text.contains(keyword.toLowerCase())) score += 1;
  }
  return score;
}

int _compareByScore(
  CatalogCardProduct a,
  CatalogCardProduct b,
  int Function(CatalogCardProduct product) score,
) {
  final scoreCompare = score(b).compareTo(score(a));
  if (scoreCompare != 0) return scoreCompare;
  final updatedCompare = _updatedAtMillis(b).compareTo(_updatedAtMillis(a));
  if (updatedCompare != 0) return updatedCompare;
  return a.name.compareTo(b.name);
}

int _updatedAtMillis(CatalogCardProduct product) {
  return product.updatedAt?.millisecondsSinceEpoch ??
      product.createdAt?.millisecondsSinceEpoch ??
      0;
}

List<CardEvent> _eventsFromProducts(List<CatalogCardProduct> products) {
  return products
      .where((product) => product.eventSummaryText.isNotEmpty)
      .map((product) => CardEvent.fromMap('summary_${product.id}', {
            'title': product.name,
            'issuerName': product.issuerName,
            'type': 'summary',
            'cardIds': [product.id],
            'summary': product.eventSummaryText,
            'isVisible': true,
            'isLive': true,
          }))
      .toList();
}

CatalogCardProduct _fallbackProduct(String cardId) {
  return CatalogCardProduct.fromMap(cardId, {
    'name': cardId,
    'issuerName': '카드사 미입력',
    'cardType': 'unknown',
    'status': 'active',
    'sourceType': 'fallback',
  });
}

CatalogCardProduct _productForMatch(
  CardMatchResult match,
  List<CatalogCardProduct> products,
) {
  if (match.product != null) return match.product!;
  return products.firstWhere(
    (product) => product.id == match.cardId,
    orElse: () => _fallbackProduct(match.cardId),
  );
}

String _shortCellText(String value) {
  final text = value.trim();
  if (text.isEmpty || text == '-') return '-';
  return text.length <= 18 ? text : '${text.substring(0, 18)}...';
}

int _extractFirstNumber(String text) {
  final match =
      RegExp(r'([0-9][0-9,]*)').firstMatch(text.replaceAll('만원', '0000'));
  if (match == null) return 0;
  return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
}

int _estimatedPerMileKRW(CatalogCardProduct product) {
  for (final value in [
    product.raw['mileRuleUsedPerMileKRW'],
    product.raw['creditPerMileKRW'],
    product.raw['checkPerMileKRW'],
    product.raw['perMileKRW'],
    product.raw['milePerKRW'],
  ]) {
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed > 0) return parsed;
    }
  }
  final haystack = [
    product.rewardProgram,
    product.detailSummary,
    ...product.primaryBenefits.map(displayValue),
  ].whereType<String>().join(' ');
  final match = RegExp(r'([0-9,]+)\s*원당\s*([0-9,]+)\s*마일').firstMatch(haystack);
  if (match != null) {
    final krw = int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
    final miles = int.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0;
    if (krw > 0 && miles > 0) return (krw / miles).round();
  }
  return 0;
}

CardIssuer? _issuerByName(List<CardIssuer> issuers, String issuerName) {
  for (final issuer in issuers) {
    if (issuer.nameKo == issuerName) return issuer;
  }
  return null;
}
