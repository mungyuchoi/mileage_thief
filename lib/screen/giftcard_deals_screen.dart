import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/giftcard_deal_model.dart';
import '../services/branch_service.dart';
import '../services/giftcard_deal_service.dart';
import '../const/colors.dart';

const Color _giftDealAccent = McColors.accent;
const Color _giftDealAccentSoft = McColors.accentSoft;
const Color _giftDealAccentBorder = Color(0xFFB89B7C);

class GiftcardDealsScreen extends StatefulWidget {
  const GiftcardDealsScreen({super.key});

  @override
  State<GiftcardDealsScreen> createState() => _GiftcardDealsScreenState();
}

Future<void> showGiftcardDealAlertEditor(
  BuildContext context, {
  List<GiftcardDeal>? deals,
  GiftcardDeal? deal,
  GiftcardDealAlert? alert,
}) async {
  if (FirebaseAuth.instance.currentUser == null) {
    Fluttertoast.showToast(msg: '로그인 후 알림을 설정할 수 있습니다.');
    return;
  }

  final loadedDeals =
      deals ?? await GiftcardDealService.loadTopDeals(limit: 80);
  final editorDeals = <GiftcardDeal>[
    if (deal != null && !loadedDeals.any((item) => item.id == deal.id)) deal,
    ...loadedDeals,
  ];

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: _GiftcardAlertEditor(
          deals: editorDeals,
          initialDeal: deal,
          alert: alert,
        ),
      );
    },
  );
}

class _GiftcardDealsScreenState extends State<GiftcardDealsScreen> {
  String _brandFilter = '전체';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GiftcardDeal>>(
      stream: GiftcardDealService.watchDeals(),
      initialData: GiftcardDealService.peekDeals(),
      builder: (context, snapshot) {
        final deals = snapshot.data ?? const <GiftcardDeal>[];
        final availableBrands = deals
            .map((deal) => deal.brandName)
            .where((name) => name.isNotEmpty)
            .toSet();
        final preferredBrands =
            ['현대', '롯데', '신세계'].where(availableBrands.contains).toList();
        final otherBrands = availableBrands
            .where((brand) => !preferredBrands.contains(brand))
            .toList()
          ..sort();
        final brands = ['전체', ...preferredBrands, ...otherBrands];
        final filtered = deals
            .where((deal) =>
                _brandFilter == '전체' || deal.brandName == _brandFilter)
            .toList()
          ..sort((a, b) {
            final rate = b.discountRate.compareTo(a.discountRate);
            if (rate != 0) return rate;
            return a.priceKRW.compareTo(b.priceKRW);
          });

        return RefreshIndicator(
          onRefresh: () async =>
              Future<void>.delayed(const Duration(milliseconds: 350)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _GiftcardDealHeader(
                  bestDeal: filtered.isNotEmpty ? filtered.first : null,
                  totalCount: filtered.length,
                  onCreateAlert: () => _showAlertSheet(context, deals: deals),
                  onManageAlerts: () =>
                      _showAlertManageSheet(context, deals: deals),
                  onRequestSite: () =>
                      _showSiteRequestSheet(context, deals: deals),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final brand = brands[index];
                      final selected = brand == _brandFilter;
                      return ChoiceChip(
                        label: Text(brand),
                        selected: selected,
                        onSelected: (_) => setState(() => _brandFilter = brand),
                        selectedColor: _giftDealAccentSoft,
                        checkmarkColor: _giftDealAccent,
                        labelStyle: TextStyle(
                          color: selected
                              ? _giftDealAccent
                              : const Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? _giftDealAccentBorder
                              : const Color(0xFFE5E7EB),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: brands.length,
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  deals.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: _GiftcardDealEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) => _GiftcardDealCard(
                      deal: filtered[index],
                      onOpenDetail: () =>
                          _showDealDetail(context, filtered[index]),
                      onShare: () => _shareDeal(filtered[index]),
                      onBuy: () => _openBuyUrl(filtered[index]),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: filtered.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBuyUrl(GiftcardDeal deal) async {
    final uri = Uri.tryParse(deal.buyUrl);
    if (uri == null) {
      Fluttertoast.showToast(msg: '구매 링크가 올바르지 않습니다.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Fluttertoast.showToast(msg: '구매 링크를 열 수 없습니다.');
    }
  }

  Future<void> _shareDeal(GiftcardDeal deal) async {
    final link = await BranchService().createGiftcardDealShareLink(
      dealId: deal.id,
      title: deal.displayTitle,
      description:
          '${deal.merchantName} ${_formatWon(deal.priceKRW)} · ${deal.discountRate.toStringAsFixed(2)}%',
    );
    final shareLink = link ?? deal.buyUrl;
    await SharePlus.instance.share(
      ShareParams(
        text: '[마일캐치 상품권 특가]\n'
            '${deal.displayTitle}\n'
            '${deal.merchantName} · ${_formatWon(deal.priceKRW)} · '
            '${deal.discountRate.toStringAsFixed(2)}% 할인\n'
            '$shareLink',
      ),
    );
  }

  Future<void> _showAlertSheet(
    BuildContext context, {
    required List<GiftcardDeal> deals,
    GiftcardDeal? deal,
    GiftcardDealAlert? alert,
  }) async {
    await showGiftcardDealAlertEditor(
      context,
      deals: deals,
      deal: deal,
      alert: alert,
    );
  }

  Future<void> _showAlertManageSheet(
    BuildContext context, {
    required List<GiftcardDeal> deals,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 알림을 관리할 수 있습니다.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: _GiftcardAlertManager(
            deals: deals,
            onEdit: (alert) {
              Navigator.of(sheetContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showAlertSheet(this.context, deals: deals, alert: alert);
              });
            },
          ),
        );
      },
    );
  }

  Future<void> _showSiteRequestSheet(
    BuildContext context, {
    required List<GiftcardDeal> deals,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 사이트를 요청할 수 있습니다.');
      return;
    }

    var sources = const <GiftcardDealSource>[];
    try {
      sources = await GiftcardDealService.loadSources();
    } catch (_) {
      sources = const <GiftcardDealSource>[];
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: _GiftcardSourceRequestSheet(
            deals: deals,
            sources: sources,
          ),
        );
      },
    );
  }

  void _showDealDetail(BuildContext context, GiftcardDeal deal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _GiftcardDealDetailSheet(deal: deal),
    );
  }
}

class GiftcardDealDetailScreen extends StatelessWidget {
  const GiftcardDealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        title: const Text('상품권 특가', style: McTextStyles.appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
        shadowColor: McColors.line,
      ),
      body: StreamBuilder<GiftcardDeal?>(
        stream: GiftcardDealService.watchDeal(dealId),
        builder: (context, snapshot) {
          final deal = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              deal == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (deal == null) {
            return const Center(child: Text('상품권 특가 정보를 찾을 수 없습니다.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _GiftcardDealDetailBody(deal: deal),
          );
        },
      ),
    );
  }
}

class _GiftcardDealHeader extends StatelessWidget {
  const _GiftcardDealHeader({
    required this.bestDeal,
    required this.totalCount,
    required this.onCreateAlert,
    required this.onManageAlerts,
    required this.onRequestSite,
  });

  final GiftcardDeal? bestDeal;
  final int totalCount;
  final VoidCallback onCreateAlert;
  final VoidCallback onManageAlerts;
  final VoidCallback onRequestSite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '상품권 특가 알림',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRequestSite,
                style: TextButton.styleFrom(
                  foregroundColor: _giftDealAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('사이트 요청'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bestDeal == null
                ? '관리자가 등록한 구매 링크를 매일 추적합니다.'
                : '오늘 최고 할인 ${bestDeal!.merchantName} · ${bestDeal!.discountRate.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeaderMetric(label: '추적 딜', value: '$totalCount개'),
              const SizedBox(width: 10),
              _HeaderMetric(
                label: '최고 할인',
                value: bestDeal == null
                    ? '-'
                    : '${bestDeal!.discountRate.toStringAsFixed(2)}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _giftDealAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onCreateAlert,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('맞춤 알림 설정'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _giftDealAccent,
                  side: const BorderSide(color: _giftDealAccentBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: onManageAlerts,
                icon: const Icon(Icons.notifications_none_rounded, size: 18),
                label: const Text('내 알림'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: McColors.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: McColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: McTextStyles.micro,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: McTextStyles.cardTitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftOption {
  const _GiftOption(this.id, this.name);

  final String id;
  final String name;
}

class _GiftcardSourceRequestSheet extends StatefulWidget {
  const _GiftcardSourceRequestSheet({
    required this.deals,
    required this.sources,
  });

  final List<GiftcardDeal> deals;
  final List<GiftcardDealSource> sources;

  @override
  State<_GiftcardSourceRequestSheet> createState() =>
      _GiftcardSourceRequestSheetState();
}

class _GiftcardSourceRequestSheetState
    extends State<_GiftcardSourceRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  String _merchantName = '';
  String _brandName = '';
  int _denominationKRW = 0;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final merchantOptions = _requestMerchantNames(widget.deals, widget.sources);
    final brandOptions = _requestBrandNames(widget.deals, widget.sources);
    final denominationOptions =
        _requestDenominationOptions(widget.deals, widget.sources);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _giftDealAccentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_link_rounded,
                      color: _giftDealAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '상품권 특가 사이트 요청',
                      style: McTextStyles.sectionTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '닫기',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  const Text(
                    '상품권 판매 페이지를 알려주시면 관리자가 확인 후 특가 수집 목록에 추가합니다.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _AlertSection(
                    title: '구매처',
                    child: DropdownButtonFormField<String>(
                      initialValue: _merchantName,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('모름'),
                        ),
                        for (final name in merchantOptions)
                          DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                              setState(() => _merchantName = value ?? ''),
                    ),
                  ),
                  _AlertSection(
                    title: '상품권',
                    child: DropdownButtonFormField<String>(
                      initialValue: _brandName,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.card_giftcard_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('모름'),
                        ),
                        for (final name in brandOptions)
                          DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _brandName = value ?? ''),
                    ),
                  ),
                  _AlertSection(
                    title: '권종',
                    child: DropdownButtonFormField<int>(
                      initialValue: _denominationKRW,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('모름'),
                        ),
                        for (final amount in denominationOptions)
                          DropdownMenuItem(
                            value: amount,
                            child: Text(_formatDenomination(amount)),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                              setState(() => _denominationKRW = value ?? 0),
                    ),
                  ),
                  _AlertSection(
                    title: 'URL',
                    child: TextFormField(
                      controller: _urlController,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'URL을 붙여넣어주세요.';
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      '구매처나 권종을 모르시면 모름으로 보내주세요. 관리자가 확인해서 수정 후 반영합니다.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _giftDealAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_saving ? '요청 중' : '요청'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await GiftcardDealService.createSourceRequest(
        url: _urlController.text,
        merchantName: _merchantName,
        brandName: _brandName,
        denominationKRW: _denominationKRW,
      );
      if (mounted) Navigator.of(context).pop();
      Fluttertoast.showToast(msg: '상품권 특가 사이트를 요청했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '요청 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _GiftcardAlertEditor extends StatefulWidget {
  const _GiftcardAlertEditor({
    required this.deals,
    this.initialDeal,
    this.alert,
  });

  final List<GiftcardDeal> deals;
  final GiftcardDeal? initialDeal;
  final GiftcardDealAlert? alert;

  @override
  State<_GiftcardAlertEditor> createState() => _GiftcardAlertEditorState();
}

class _GiftcardAlertEditorState extends State<_GiftcardAlertEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _discountController;
  late final TextEditingController _priceController;
  late Set<String> _selectedDealIds;
  late Set<String> _selectedBrandIds;
  late Set<String> _selectedMerchantIds;
  late Set<int> _selectedDenominations;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    final deal = widget.initialDeal;
    _selectedDealIds = {
      if (alert != null) ...alert.dealIds else if (deal != null) deal.id,
    };
    _selectedBrandIds = {
      if (alert != null)
        ...alert.brandIds
      else if (deal != null && deal.brandId.isNotEmpty)
        deal.brandId,
    };
    _selectedMerchantIds = {
      if (alert != null)
        ...alert.merchantIds
      else if (deal != null && deal.merchantId.isNotEmpty)
        deal.merchantId,
    };
    _selectedDenominations = {
      if (alert != null)
        ...alert.denominationsKRW
      else if (deal != null && _dealAmount(deal) > 0)
        _dealAmount(deal),
    };
    _nameController = TextEditingController(
      text: alert?.name.isNotEmpty == true
          ? alert!.name
          : deal == null
              ? '상품권 맞춤 알림'
              : '${deal.displayTitle} 알림',
    );
    _discountController = TextEditingController(
      text: alert != null
          ? _formatRateInput(alert.minDiscountRate)
          : deal != null && deal.discountRate > 0
              ? _formatRateInput(deal.discountRate)
              : '2.0',
    );
    _priceController = TextEditingController(
      text: alert != null && alert.maxPriceKRW > 0
          ? alert.maxPriceKRW.toString()
          : deal != null && deal.priceKRW > 0
              ? deal.priceKRW.toString()
              : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final brandOptions = _brandOptions(widget.deals);
    final merchantOptions = _merchantOptions(widget.deals);
    final denominationOptions = _denominationOptions(widget.deals);
    final dealChipWidth = MediaQuery.sizeOf(context).width - 84;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _giftDealAccentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: _giftDealAccent,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '상품권 맞춤 알림',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '닫기',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                const Text(
                  '조건에 맞는 상품권이 처음 나오거나 더 좋아질 때만 알려드려요.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 16),
                _AlertSection(
                  title: '빠른 추천',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresetChip(
                        label: '현대 2% 이상',
                        onTap: () => _applyBrandPreset('현대', 2),
                      ),
                      _PresetChip(
                        label: '신세계 10만원권',
                        onTap: () => _applyBrandPreset(
                          '신세계',
                          2,
                          denominations: const {100000},
                        ),
                      ),
                      _PresetChip(
                        label: '롯데/현대 50만원권',
                        onTap: _applyDepartmentStorePreset,
                      ),
                      if (widget.initialDeal != null)
                        _PresetChip(
                          label: '현재 딜만',
                          onTap: _applyCurrentDealPreset,
                        ),
                    ],
                  ),
                ),
                _AlertSection(
                  title: '알림 이름',
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: '예: 현대 10만원권 2% 알림',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_notifications_outlined),
                    ),
                  ),
                ),
                _AlertSection(
                  title: '상품권',
                  child: _OptionWrap(
                    options: brandOptions,
                    selectedIds: _selectedBrandIds,
                    onToggle: _toggleBrand,
                  ),
                ),
                _AlertSection(
                  title: '권종',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amount in denominationOptions)
                        FilterChip(
                          label: Text(_formatDenomination(amount)),
                          selected: _selectedDenominations.contains(amount),
                          onSelected: (_) => setState(() {
                            _selectedDealIds.clear();
                            if (!_selectedDenominations.add(amount)) {
                              _selectedDenominations.remove(amount);
                            }
                          }),
                          backgroundColor: Colors.white,
                          selectedColor: _giftDealAccentSoft,
                          checkmarkColor: _giftDealAccent,
                          side: BorderSide(
                            color: _selectedDenominations.contains(amount)
                                ? _giftDealAccentBorder
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                    ],
                  ),
                ),
                _AlertSection(
                  title: '상점',
                  child: _OptionWrap(
                    options: merchantOptions,
                    selectedIds: _selectedMerchantIds,
                    onToggle: _toggleMerchant,
                  ),
                ),
                _AlertSection(
                  title: '특정 딜',
                  child: widget.deals.isEmpty
                      ? const Text(
                          '수집된 딜이 생기면 특정 딜만 골라 알림을 받을 수 있습니다.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final deal in widget.deals.take(12))
                              FilterChip(
                                label: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: dealChipWidth,
                                  ),
                                  child: Text(
                                    deal.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                selected: _selectedDealIds.contains(deal.id),
                                onSelected: (_) => _toggleDeal(deal),
                                backgroundColor: Colors.white,
                                selectedColor: _giftDealAccentSoft,
                                checkmarkColor: _giftDealAccent,
                                side: BorderSide(
                                  color: _selectedDealIds.contains(deal.id)
                                      ? _giftDealAccentBorder
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                          ],
                        ),
                ),
                _AlertSection(
                  title: '조건',
                  child: Column(
                    children: [
                      TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '최소 할인율(%)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.percent_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '최대 구매가(원)',
                          hintText: '선택 사항',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                _AlertSection(
                  title: '알림 방식',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _giftDealAccentSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _giftDealAccentBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.trending_down_rounded,
                          color: _giftDealAccent,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '처음 조건을 만족하면 알려주고, 이후에는 가격이나 할인율이 더 좋아질 때만 다시 알려줍니다.',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _giftDealAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(widget.alert == null ? '맞춤 알림 저장' : '알림 수정'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBrand(String id) {
    setState(() {
      _selectedDealIds.clear();
      if (!_selectedBrandIds.add(id)) {
        _selectedBrandIds.remove(id);
      }
    });
  }

  void _toggleMerchant(String id) {
    setState(() {
      _selectedDealIds.clear();
      if (!_selectedMerchantIds.add(id)) {
        _selectedMerchantIds.remove(id);
      }
    });
  }

  void _toggleDeal(GiftcardDeal deal) {
    setState(() {
      if (!_selectedDealIds.add(deal.id)) {
        _selectedDealIds.remove(deal.id);
        return;
      }
      if (deal.brandId.isNotEmpty) _selectedBrandIds.add(deal.brandId);
      if (deal.merchantId.isNotEmpty) _selectedMerchantIds.add(deal.merchantId);
      final amount = _dealAmount(deal);
      if (amount > 0) _selectedDenominations.add(amount);
    });
  }

  void _applyBrandPreset(
    String brandName,
    double minRate, {
    Set<int> denominations = const <int>{},
  }) {
    final brand = _brandOptions(widget.deals).where(
      (option) => option.name.contains(brandName),
    );
    setState(() {
      _selectedDealIds.clear();
      _selectedBrandIds = brand.map((option) => option.id).toSet();
      _selectedMerchantIds.clear();
      _selectedDenominations = {...denominations};
      _discountController.text = _formatRateInput(minRate);
      _priceController.clear();
      _nameController.text = denominations.isEmpty
          ? '$brandName 상품권 ${_formatRateInput(minRate)}% 알림'
          : '$brandName ${_formatDenomination(denominations.first)} 알림';
    });
  }

  void _applyDepartmentStorePreset() {
    final ids = _brandOptions(widget.deals)
        .where((option) =>
            option.name.contains('롯데') || option.name.contains('현대'))
        .map((option) => option.id)
        .toSet();
    setState(() {
      _selectedDealIds.clear();
      _selectedBrandIds = ids;
      _selectedMerchantIds.clear();
      _selectedDenominations = {500000};
      _discountController.text = '1.0';
      _priceController.clear();
      _nameController.text = '롯데/현대 50만원권 알림';
    });
  }

  void _applyCurrentDealPreset() {
    final deal = widget.initialDeal;
    if (deal == null) return;
    setState(() {
      _selectedDealIds = {deal.id};
      _selectedBrandIds = {
        if (deal.brandId.isNotEmpty) deal.brandId,
      };
      _selectedMerchantIds = {
        if (deal.merchantId.isNotEmpty) deal.merchantId,
      };
      _selectedDenominations = {
        if (_dealAmount(deal) > 0) _dealAmount(deal),
      };
      _discountController.text =
          deal.discountRate > 0 ? _formatRateInput(deal.discountRate) : '2.0';
      _priceController.text = deal.priceKRW > 0 ? deal.priceKRW.toString() : '';
      _nameController.text = '${deal.displayTitle} 알림';
    });
  }

  Future<void> _save() async {
    final discount = double.tryParse(
          _discountController.text.replaceAll('%', '').trim(),
        ) ??
        0;
    final price = int.tryParse(
          _priceController.text.replaceAll(',', '').trim(),
        ) ??
        0;
    final hasScope = _selectedDealIds.isNotEmpty ||
        _selectedBrandIds.isNotEmpty ||
        _selectedMerchantIds.isNotEmpty ||
        _selectedDenominations.isNotEmpty;
    if (!hasScope && discount <= 0 && price <= 0) {
      Fluttertoast.showToast(msg: '알림 조건을 하나 이상 선택해주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      await GiftcardDealService.saveCustomAlert(
        alertId: widget.alert?.id ??
            (_selectedDealIds.length == 1 ? _selectedDealIds.first : null),
        name: _nameController.text,
        scopeType: _scopeType(),
        dealIds: _selectedDealIds.toList(),
        brandIds: _selectedBrandIds.toList(),
        merchantIds: _selectedMerchantIds.toList(),
        denominationsKRW: _selectedDenominations.toList(),
        minDiscountRate: discount,
        maxPriceKRW: price,
        dealTitle: widget.initialDeal?.displayTitle,
        merchantName: widget.initialDeal?.merchantName,
        brandName: widget.initialDeal?.brandName,
      );
      if (mounted) Navigator.of(context).pop();
      Fluttertoast.showToast(msg: '상품권 맞춤 알림을 저장했습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '알림 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _scopeType() {
    if (_selectedDealIds.isNotEmpty) return 'deal';
    if (_selectedBrandIds.length == 1 &&
        _selectedMerchantIds.isEmpty &&
        _selectedDenominations.isEmpty) {
      return 'brand';
    }
    if (_selectedBrandIds.isEmpty &&
        _selectedMerchantIds.isEmpty &&
        _selectedDenominations.isEmpty) {
      return 'all';
    }
    return 'custom';
  }
}

class _GiftcardAlertManager extends StatelessWidget {
  const _GiftcardAlertManager({
    required this.deals,
    required this.onEdit,
  });

  final List<GiftcardDeal> deals;
  final ValueChanged<GiftcardDealAlert> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '내 상품권 알림',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: '닫기',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GiftcardDealAlert>>(
            stream: GiftcardDealService.watchAlerts(),
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? const <GiftcardDealAlert>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  alerts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (alerts.isEmpty) {
                return const _GiftcardAlertEmptyState();
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemBuilder: (context, index) => _GiftcardAlertCard(
                  alert: alerts[index],
                  deals: deals,
                  onEdit: () => onEdit(alerts[index]),
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: alerts.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GiftcardAlertCard extends StatelessWidget {
  const _GiftcardAlertCard({
    required this.alert,
    required this.deals,
    required this.onEdit,
  });

  final GiftcardDealAlert alert;
  final List<GiftcardDeal> deals;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.name.isEmpty ? '상품권 맞춤 알림' : alert.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Switch(
                value: alert.enabled,
                activeThumbColor: _giftDealAccent,
                onChanged: (enabled) async {
                  await GiftcardDealService.setAlertEnabled(
                    alert.id,
                    enabled,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _alertSummary(alert, deals),
            style: const TextStyle(color: Color(0xFF6B7280), height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _giftDealAccent),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('수정'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
                onPressed: () => _deleteAlert(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAlert(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 삭제'),
        content: const Text('이 상품권 맞춤 알림을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GiftcardDealService.deleteAlert(alert.id);
    Fluttertoast.showToast(msg: '상품권 알림을 삭제했습니다.');
  }
}

class _GiftcardAlertEmptyState extends StatelessWidget {
  const _GiftcardAlertEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Text(
              '저장된 맞춤 알림이 없습니다.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 6),
            Text(
              '브랜드, 권종, 상점, 할인율을 골라 원하는 특가만 받아보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertSection extends StatelessWidget {
  const _AlertSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: _giftDealAccentSoft,
      side: const BorderSide(color: _giftDealAccentBorder),
      labelStyle: const TextStyle(
        color: _giftDealAccent,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  const _OptionWrap({
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<_GiftOption> options;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.name),
            selected: selectedIds.contains(option.id),
            onSelected: (_) => onToggle(option.id),
            backgroundColor: Colors.white,
            selectedColor: _giftDealAccentSoft,
            checkmarkColor: _giftDealAccent,
            side: BorderSide(
              color: selectedIds.contains(option.id)
                  ? _giftDealAccentBorder
                  : const Color(0xFFE5E7EB),
            ),
          ),
      ],
    );
  }
}

class _GiftcardDealCard extends StatelessWidget {
  const _GiftcardDealCard({
    required this.deal,
    required this.onOpenDetail,
    required this.onShare,
    required this.onBuy,
  });

  final GiftcardDeal deal;
  final VoidCallback onOpenDetail;
  final VoidCallback onShare;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _giftDealAccentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: _giftDealAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${deal.merchantName} · ${_formatWon(deal.faceValueKRW)}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _DealStatPill(
                    icon: Icons.local_offer_outlined,
                    label: '${deal.discountRate.toStringAsFixed(2)}%',
                    color: _giftDealAccent,
                  ),
                  const SizedBox(width: 8),
                  _DealStatPill(
                    icon: Icons.payments_outlined,
                    label: _formatWon(deal.priceKRW),
                    color: _giftDealAccent,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _giftDealAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: onBuy,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('구매'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    style: IconButton.styleFrom(
                      foregroundColor: _giftDealAccent,
                      side: const BorderSide(color: _giftDealAccentBorder),
                    ),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded),
                    tooltip: '공유',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealStatPill extends StatelessWidget {
  const _DealStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftcardDealDetailSheet extends StatelessWidget {
  const _GiftcardDealDetailSheet({required this.deal});

  final GiftcardDeal deal;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: _GiftcardDealDetailBody(deal: deal),
      ),
    );
  }
}

class _GiftcardDealDetailBody extends StatelessWidget {
  const _GiftcardDealDetailBody({required this.deal});

  final GiftcardDeal deal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                deal.displayTitle,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: '닫기',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DealStatPill(
              icon: Icons.storefront_outlined,
              label: deal.merchantName,
              color: _giftDealAccent,
            ),
            _DealStatPill(
              icon: Icons.local_offer_outlined,
              label: '${deal.discountRate.toStringAsFixed(2)}% 할인',
              color: _giftDealAccent,
            ),
            _DealStatPill(
              icon: Icons.payments_outlined,
              label: _formatWon(deal.priceKRW),
              color: _giftDealAccent,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          '최근 30일 추이',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: GiftcardDealPriceChart(
            dealId: deal.id,
            currentPriceKRW: deal.priceKRW,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _giftDealAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final uri = Uri.tryParse(deal.buyUrl);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('구매 페이지 열기'),
          ),
        ),
      ],
    );
  }
}

class GiftcardDealPriceChart extends StatelessWidget {
  const GiftcardDealPriceChart({
    super.key,
    required this.dealId,
    required this.currentPriceKRW,
  });

  final String dealId;
  final int currentPriceKRW;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: GiftcardDealService.watchPriceHistory(dealId, limit: 30),
      builder: (context, snapshot) {
        final rows =
            (snapshot.data ?? const <Map<String, dynamic>>[]).reversed.toList();
        if (snapshot.connectionState == ConnectionState.waiting &&
            rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rows.isEmpty && currentPriceKRW <= 0) {
          return const Center(child: Text('아직 가격 이력이 없습니다.'));
        }
        final values = <int>[
          for (final row in rows) _asInt(row['priceKRW']),
          if (currentPriceKRW > 0) currentPriceKRW,
        ].where((value) => value > 0).toList();
        if (values.isEmpty) {
          return const Center(child: Text('차트에 표시할 가격이 없습니다.'));
        }
        final minPrice = values.reduce((a, b) => a < b ? a : b);
        final maxPrice = values.reduce((a, b) => a > b ? a : b);
        final padding =
            ((maxPrice - minPrice) * 0.12).round().clamp(500, 10000);
        final minY = (minPrice - padding).clamp(0, minPrice).toDouble();
        final maxY = (maxPrice + padding).toDouble();
        final spots = <FlSpot>[];
        for (var i = 0; i < rows.length; i++) {
          final price = _asInt(rows[i]['priceKRW']);
          if (price > 0) spots.add(FlSpot(i.toDouble(), price.toDouble()));
        }
        if (currentPriceKRW > 0) {
          spots.add(FlSpot(rows.length.toDouble(), currentPriceKRW.toDouble()));
        }
        if (spots.isEmpty) {
          return const Center(child: Text('차트에 표시할 가격이 없습니다.'));
        }
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: spots.last.x,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => const FlLine(
                color: Color(0xFFE5E7EB),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, meta) => Text(
                    _shortWon(value.round()),
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval:
                      spots.length <= 6 ? 1 : (spots.length / 4).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index == rows.length && currentPriceKRW > 0) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('현재', style: TextStyle(fontSize: 10)),
                      );
                    }
                    if (index < 0 || index >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    final date = _asDate(rows[index]['crawledAt']);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        date == null
                            ? rows[index]['id'].toString()
                            : DateFormat('MM.dd').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: _giftDealAccent,
                barWidth: 3,
                isCurved: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: _giftDealAccent.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GiftcardDealEmptyState extends StatelessWidget {
  const _GiftcardDealEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text(
              '등록된 상품권 특가가 없습니다.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              '관리자 페이지에서 추적할 구매 URL을 추가하면 이곳에 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatWon(int value) {
  if (value <= 0) return '-';
  return '${NumberFormat('#,###').format(value)}원';
}

String _shortWon(int value) {
  if (value >= 10000) {
    final man = value / 10000;
    return '${man.toStringAsFixed(man == man.roundToDouble() ? 0 : 1)}만';
  }
  return NumberFormat('#,###').format(value);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    return int.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
  return 0;
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _dealAmount(GiftcardDeal deal) {
  if (deal.faceValueKRW > 0) return deal.faceValueKRW;
  return deal.denominationKRW;
}

String _formatRateInput(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _formatDenomination(int value) {
  if (value >= 10000 && value % 10000 == 0) {
    return '${value ~/ 10000}만원권';
  }
  return _formatWon(value);
}

List<_GiftOption> _brandOptions(List<GiftcardDeal> deals) {
  final byId = <String, String>{};
  for (final name in const ['현대', '롯데', '신세계', 'SSG', 'GS25']) {
    byId[_giftDealSlug(name)] = name;
  }
  for (final deal in deals) {
    if (deal.brandId.isNotEmpty && deal.brandName.isNotEmpty) {
      byId[deal.brandId] = deal.brandName;
    }
  }
  final options =
      byId.entries.map((entry) => _GiftOption(entry.key, entry.value)).toList();
  options.sort((a, b) {
    final preferred = ['현대', '롯데', '신세계'];
    final aRank = preferred.indexWhere((name) => a.name.contains(name));
    final bRank = preferred.indexWhere((name) => b.name.contains(name));
    if (aRank != -1 || bRank != -1) {
      return (aRank == -1 ? 99 : aRank).compareTo(bRank == -1 ? 99 : bRank);
    }
    return a.name.compareTo(b.name);
  });
  return options;
}

List<_GiftOption> _merchantOptions(List<GiftcardDeal> deals) {
  final byId = <String, String>{};
  for (final name in const [
    'G마켓',
    '옥션',
    'SSG',
    '롯데ON',
    '띵샵',
    '삼성카드쇼핑',
    '네이버스토어',
    '11번가',
  ]) {
    byId[_giftDealSlug(name)] = name;
  }
  for (final deal in deals) {
    if (deal.merchantId.isNotEmpty && deal.merchantName.isNotEmpty) {
      byId[deal.merchantId] = deal.merchantName;
    }
  }
  final options = byId.entries
      .map((entry) => _GiftOption(entry.key, entry.value))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return options;
}

List<int> _denominationOptions(List<GiftcardDeal> deals) {
  final values = <int>{
    10000,
    30000,
    50000,
    100000,
    300000,
    500000,
  };
  for (final deal in deals) {
    final amount = _dealAmount(deal);
    if (amount > 0) values.add(amount);
  }
  return values.toList()..sort();
}

List<String> _requestMerchantNames(
  List<GiftcardDeal> deals,
  List<GiftcardDealSource> sources,
) {
  return _mergeRequestNames(
    const ['G마켓', '옥션', '11번가', 'SSG.COM', 'GS샵', '롯데ON'],
    [
      ...sources.map((source) => source.merchantName),
      ...deals.map((deal) => deal.merchantName),
    ],
  );
}

List<String> _requestBrandNames(
  List<GiftcardDeal> deals,
  List<GiftcardDealSource> sources,
) {
  return _mergeRequestNames(
    const ['신세계', '롯데', '현대', 'GS25', '해피머니', '컬쳐랜드'],
    [
      ...sources.map((source) => source.brandName),
      ...deals.map((deal) => deal.brandName),
    ],
  );
}

List<int> _requestDenominationOptions(
  List<GiftcardDeal> deals,
  List<GiftcardDealSource> sources,
) {
  final values = <int>{
    10000,
    30000,
    50000,
    100000,
    300000,
    500000,
    ...sources
        .map((source) => source.faceValueKRW > 0
            ? source.faceValueKRW
            : source.denominationKRW)
        .where((amount) => amount > 0),
    ...deals.map(_dealAmount).where((amount) => amount > 0),
  };
  return values.toList()..sort();
}

List<String> _mergeRequestNames(
  List<String> defaults,
  Iterable<String> discovered,
) {
  final result = <String>[];
  final seen = <String>{};
  void add(String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    final key = name.toLowerCase();
    if (seen.add(key)) result.add(name);
  }

  for (final name in defaults) {
    add(name);
  }
  final extra = discovered
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty && !seen.contains(name.toLowerCase()))
      .toSet()
      .toList()
    ..sort();
  for (final name in extra) {
    add(name);
  }
  return result;
}

String _alertSummary(GiftcardDealAlert alert, List<GiftcardDeal> deals) {
  final dealById = {
    for (final deal in deals) deal.id: deal,
  };
  final brandById = {
    for (final option in _brandOptions(deals)) option.id: option.name,
  };
  final merchantById = {
    for (final option in _merchantOptions(deals)) option.id: option.name,
  };
  final parts = <String>[];
  if (alert.dealIds.isNotEmpty) {
    if (alert.dealIds.length == 1 && dealById[alert.dealIds.first] != null) {
      parts.add(dealById[alert.dealIds.first]!.displayTitle);
    } else {
      parts.add('${alert.dealIds.length}개 딜');
    }
  }
  if (alert.brandIds.isNotEmpty) {
    parts
        .add(alert.brandIds.map((id) => brandById[id] ?? id).take(3).join('/'));
  }
  if (alert.denominationsKRW.isNotEmpty) {
    parts
        .add(alert.denominationsKRW.map(_formatDenomination).take(3).join('/'));
  }
  if (alert.merchantIds.isNotEmpty) {
    parts.add(alert.merchantIds
        .map((id) => merchantById[id] ?? id)
        .take(3)
        .join('/'));
  }
  if (alert.minDiscountRate > 0) {
    parts.add('${_formatRateInput(alert.minDiscountRate)}% 이상');
  }
  if (alert.maxPriceKRW > 0) {
    parts.add('${_formatWon(alert.maxPriceKRW)} 이하');
  }
  if (parts.isEmpty) {
    parts.add('전체 상품권');
  }
  return parts.join(' · ');
}

String _giftDealSlug(String input) {
  final text = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final isAsciiLetter = rune >= 97 && rune <= 122;
    final isDigit = rune >= 48 && rune <= 57;
    if (isAsciiLetter || isDigit) {
      buffer.write(char);
    } else if (rune >= 0xAC00 && rune <= 0xD7A3) {
      buffer.write(char);
    } else if (buffer.isNotEmpty && !buffer.toString().endsWith('_')) {
      buffer.write('_');
    }
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
