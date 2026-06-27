import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/giftcard_settlement_calculator.dart';
import '../services/analytics_service.dart';

class GiftcardSettlementScreen extends StatefulWidget {
  final String? initialSettlementId;
  final bool? _showTrustNotice;
  final bool? _showHistory;
  final bool? _popOnSave;

  const GiftcardSettlementScreen({
    super.key,
    this.initialSettlementId,
    bool? showTrustNotice,
    bool? showHistory,
    bool? popOnSave,
  })  : _showTrustNotice = showTrustNotice,
        _showHistory = showHistory,
        _popOnSave = popOnSave;

  bool get showTrustNotice => _showTrustNotice ?? true;
  bool get showHistory => _showHistory ?? true;
  bool get popOnSave => _popOnSave ?? false;

  @override
  State<GiftcardSettlementScreen> createState() =>
      _GiftcardSettlementScreenState();
}

class GiftcardSettlementDetailScreen extends StatelessWidget {
  final String settlementId;

  const GiftcardSettlementDetailScreen({
    super.key,
    required this.settlementId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text('정산 기록', style: McTextStyles.appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.5,
        shadowColor: McColors.line,
      ),
      body: GiftcardSettlementScreen(
        initialSettlementId: settlementId,
        showTrustNotice: false,
        showHistory: false,
        popOnSave: true,
      ),
    );
  }
}

class _GiftcardSettlementScreenState extends State<GiftcardSettlementScreen> {
  static const String _noBranchOptionId = '__no_branch__';
  static const String _noBranchLabel = '지점 선택안함';

  final NumberFormat _won = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final TextEditingController _actualDepositController =
      TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  List<_BranchOption> _branches = <_BranchOption>[];
  List<_GiftcardOption> _giftcards = <_GiftcardOption>[];
  List<_SettlementLineDraft> _lines = <_SettlementLineDraft>[];
  DateTime _settlementDate = DateTime.now();
  String? _selectedBranchId;
  String? _editingSettlementId;
  bool _loadingRefs = true;
  bool _saving = false;
  bool _completed = false;
  bool _recountChecked = false;
  bool _createSalesOnComplete = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(
      'giftcard_settlement',
      screenClass: 'GiftcardSettlementScreen',
      source: widget.initialSettlementId == null ? 'screen_init' : 'detail',
      parameters: {'entity_id': widget.initialSettlementId},
    );
    _lines = <_SettlementLineDraft>[_SettlementLineDraft()];
    _initialize();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _actualDepositController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    setState(() {
      _loadingRefs = true;
    });
    try {
      final branchesFuture = FirebaseFirestore.instance
          .collection('branches')
          .get()
          .then((snap) => snap.docs.map((doc) {
                final data = doc.data();
                return _BranchOption(
                  id: doc.id,
                  name: (data['name'] as String?) ?? doc.id,
                );
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name)));

      final giftcardsFuture = FirebaseFirestore.instance
          .collection('giftcards')
          .get()
          .then((snap) => snap.docs.map((doc) {
                final data = doc.data();
                return _GiftcardOption(
                  id: doc.id,
                  name: (data['name'] as String?) ?? doc.id,
                  sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 999,
                );
              }).toList()
                ..sort((a, b) {
                  final order = a.sortOrder.compareTo(b.sortOrder);
                  return order != 0 ? order : a.name.compareTo(b.name);
                }));

      final results = await Future.wait([branchesFuture, giftcardsFuture]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<_BranchOption>;
        _giftcards = results[1] as List<_GiftcardOption>;
        _loadingRefs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRefs = false;
      });
      Fluttertoast.showToast(msg: '계산기 정보를 불러오지 못했습니다.');
    }
  }

  Future<void> _initialize() async {
    await _loadReferenceData();
    final settlementId = widget.initialSettlementId;
    if (settlementId != null && mounted) {
      await _loadSettlementById(settlementId);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    }
    return 0;
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  String _formatWon(int value) => '${_won.format(value)}원';

  String _formatRate(double value) {
    final text = value.toStringAsFixed(2);
    if (text.endsWith('00')) return text.substring(0, text.length - 3);
    if (text.endsWith('0')) return text.substring(0, text.length - 1);
    return text;
  }

  _BranchOption? get _selectedBranch {
    final branchId = _selectedBranchId;
    if (branchId == null) return null;
    for (final branch in _branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  String _giftcardName(String? giftcardId) {
    if (giftcardId == null || giftcardId.isEmpty) return '';
    for (final giftcard in _giftcards) {
      if (giftcard.id == giftcardId) return giftcard.name;
    }
    return giftcardId;
  }

  List<GiftcardSettlementLineInput> _currentLineInputs() {
    final lines = <GiftcardSettlementLineInput>[];
    for (final line in _lines) {
      final giftcardId = line.giftcardId;
      final faceValue = line.faceValue;
      final qty = line.qty;
      final sellUnit = line.sellUnit;
      if (giftcardId == null || giftcardId.isEmpty) continue;
      if (faceValue <= 0 || qty <= 0 || sellUnit <= 0) continue;
      lines.add(
        GiftcardSettlementLineInput(
          lotId: line.lotId,
          giftcardId: giftcardId,
          giftcardName: _giftcardName(giftcardId),
          faceValue: faceValue,
          qty: qty,
          sellUnit: sellUnit,
          memo: line.memoController.text.trim(),
        ),
      );
    }
    return lines;
  }

  GiftcardSettlementSummary _currentSummary() {
    final actual = _completed ? _asInt(_actualDepositController.text) : null;
    return GiftcardSettlementCalculator.summarize(
      lines: _currentLineInputs(),
      actualDepositTotal: actual,
    );
  }

  bool _isCompleteLineDraft(_SettlementLineDraft line) {
    return line.giftcardId != null &&
        line.giftcardId!.isNotEmpty &&
        line.faceValue > 0 &&
        line.qty > 0 &&
        line.sellUnit > 0;
  }

  List<_SettlementLineDraft> _completeLineDrafts() {
    return _lines.where(_isCompleteLineDraft).toList();
  }

  List<_SettlementLineDraft> _saleLinkableLineDrafts() {
    return _completeLineDrafts()
        .where((line) => line.lotId != null && line.lotId!.isNotEmpty)
        .toList();
  }

  bool get _canCreateSalesWithCurrentLines {
    final completeLines = _completeLineDrafts();
    if (completeLines.isEmpty) return false;
    return completeLines.every(
      (line) => line.lotId != null && line.lotId!.isNotEmpty,
    );
  }

  int _saleCreationExpectedTotal(List<_SettlementLineDraft> lines) {
    var total = 0;
    for (final line in lines) {
      total += GiftcardSettlementCalculator.lineTotal(
        qty: line.qty,
        sellUnit: line.sellUnit,
      );
    }
    return total;
  }

  Future<void> _pickSettlementDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _settlementDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: GiftcardColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _settlementDate = picked;
      });
    }
  }

  Future<String?> _showSelectionSheet({
    required String title,
    required List<_PickerOption> options,
    required String? selectedId,
  }) async {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.72;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1E4EC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F1F28),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: options.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.45,
                      ),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.id == selectedId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, option.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? GiftcardColors.accent
                                    : const Color(0xFFE8ECF4),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? GiftcardColors.accent
                                        : const Color(0xFF1F1F28),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBranchSheet() async {
    if (_branches.isEmpty) return;
    final selectedId = await _showSelectionSheet(
      title: '지점 선택',
      options: [
        const _PickerOption(id: _noBranchOptionId, label: _noBranchLabel),
        for (final branch in _branches)
          _PickerOption(id: branch.id, label: branch.name),
      ],
      selectedId: _selectedBranchId ?? _noBranchOptionId,
    );
    if (selectedId == null || !mounted) return;
    setState(() {
      _selectedBranchId = selectedId == _noBranchOptionId ? null : selectedId;
    });
    if (_selectedBranchId == null) return;
    for (final line in _lines) {
      await _applyCurrentRate(line);
    }
  }

  Future<void> _openGiftcardSheet(_SettlementLineDraft line) async {
    if (_giftcards.isEmpty) return;
    final selectedId = await _showSelectionSheet(
      title: '상품권 선택',
      options: [
        for (final giftcard in _giftcards)
          _PickerOption(id: giftcard.id, label: giftcard.name),
      ],
      selectedId: line.giftcardId,
    );
    if (selectedId == null || !mounted) return;
    setState(() {
      if (line.giftcardId != selectedId) {
        line.lotId = null;
      }
      line.giftcardId = selectedId;
    });
    await _applyCurrentRate(line);
  }

  Future<int?> _fetchCurrentSellUnit(String? giftcardId) async {
    final branchId = _selectedBranchId;
    if (branchId == null ||
        branchId.isEmpty ||
        giftcardId == null ||
        giftcardId.isEmpty) {
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .collection('giftcardRates_current')
          .doc(giftcardId)
          .get();
      final price = (doc.data()?['sellPrice_general'] as num?)?.toInt();
      return price != null && price > 0 ? price : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyCurrentRate(
    _SettlementLineDraft line, {
    bool overwrite = false,
  }) async {
    final branchId = _selectedBranchId;
    final giftcardId = line.giftcardId;
    if (branchId == null || branchId.isEmpty) {
      if (overwrite) {
        Fluttertoast.showToast(msg: '지점을 선택하면 현재 시세를 불러올 수 있습니다.');
      }
      return;
    }
    if (giftcardId == null || giftcardId.isEmpty) {
      if (overwrite) {
        Fluttertoast.showToast(msg: '상품권을 먼저 선택해주세요.');
      }
      return;
    }
    if (!overwrite && line.sellUnit > 0) return;

    final price = await _fetchCurrentSellUnit(giftcardId);
    if (price == null) {
      if (overwrite) {
        Fluttertoast.showToast(msg: '현재 시세가 없습니다. 직접 입력해주세요.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      line.setSellUnit(price);
    });
  }

  Future<List<_PurchaseLotOption>> _loadOpenPurchaseLots() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const <_PurchaseLotOption>[];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('lots')
        .where('status', isEqualTo: 'open')
        .get();

    final lots = <_PurchaseLotOption>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final giftcardId = (data['giftcardId'] as String?) ?? '';
      final faceValue = _asInt(data['faceValue']);
      final qty = _asInt(data['qty']);
      final buyUnit = _asInt(data['buyUnit']);
      if (giftcardId.isEmpty || faceValue <= 0 || qty <= 0) continue;
      lots.add(
        _PurchaseLotOption(
          lotId: doc.id,
          giftcardId: giftcardId,
          giftcardName: _giftcardName(giftcardId),
          faceValue: faceValue,
          qty: qty,
          buyUnit: buyUnit,
          buyDate: _asDate(data['buyDate']),
          memo: ((data['memo'] as String?) ?? '').trim(),
          whereToBuyId: ((data['whereToBuyId'] as String?) ?? '').trim(),
        ),
      );
    }
    lots.sort((a, b) => b.buyDate.compareTo(a.buyDate));
    return lots;
  }

  Future<void> _openPurchaseLotSheet() async {
    FocusScope.of(context).unfocus();
    List<_PurchaseLotOption> lots;
    try {
      lots = await _loadOpenPurchaseLots();
    } catch (_) {
      Fluttertoast.showToast(msg: '구매목록을 불러오지 못했습니다.');
      return;
    }
    if (!mounted) return;
    if (lots.isEmpty) {
      Fluttertoast.showToast(msg: '아직 판매하지 않은 구매목록이 없습니다.');
      return;
    }

    final selected = await _showPurchaseLotSheet(lots);
    if (selected == null || !mounted) return;
    await _applyPurchaseLot(selected);
  }

  Future<_PurchaseLotOption?> _showPurchaseLotSheet(
    List<_PurchaseLotOption> lots,
  ) {
    return showModalBottomSheet<_PurchaseLotOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.72;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1E4EC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '구매목록 불러오기',
                    style: TextStyle(
                      color: Color(0xFF1F1F28),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '아직 판매하지 않은 상품권만 표시됩니다.',
                    style: McTextStyles.meta,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: lots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final lot = lots[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, lot),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE8ECF4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: GiftcardColors.accentSoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.card_giftcard_outlined,
                                        size: 18,
                                        color: GiftcardColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        lot.giftcardName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF1F1F28),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const _MiniPill(label: '미판매'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _dateFormat.format(lot.buyDate),
                                  style: McTextStyles.meta,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _SummaryPill(
                                      icon: Icons.confirmation_number_outlined,
                                      label: '권종 ${_formatWon(lot.faceValue)}',
                                    ),
                                    _SummaryPill(
                                      icon: Icons.inventory_2_outlined,
                                      label: '수량 ${lot.qty}장',
                                    ),
                                    if (lot.buyUnit > 0)
                                      _SummaryPill(
                                        icon: Icons.payments_outlined,
                                        label: '매입가 ${_formatWon(lot.buyUnit)}',
                                      ),
                                    if (lot.buyTotal > 0)
                                      _SummaryPill(
                                        icon: Icons.receipt_long_outlined,
                                        label: '합계 ${_formatWon(lot.buyTotal)}',
                                      ),
                                    if (lot.whereToBuyId.isNotEmpty)
                                      _SummaryPill(
                                        icon: Icons.storefront_outlined,
                                        label: '구매처 ${lot.whereToBuyId}',
                                      ),
                                    if (lot.memo.isNotEmpty)
                                      _SummaryPill(
                                        icon: Icons.note_alt_outlined,
                                        label: '메모 ${lot.memo}',
                                        maxLabelWidth:
                                            MediaQuery.of(context).size.width -
                                                118,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyPurchaseLot(_PurchaseLotOption lot) async {
    final currentSellUnit = await _fetchCurrentSellUnit(lot.giftcardId);
    if (!mounted) return;

    final emptyIndex = _lines.indexWhere((line) =>
        (line.giftcardId == null || line.giftcardId!.isEmpty) &&
        line.sellUnit <= 0 &&
        line.memoController.text.trim().isEmpty);
    final line = emptyIndex >= 0 ? _lines[emptyIndex] : _SettlementLineDraft();
    final sellUnit = currentSellUnit ?? lot.buyUnit;
    final memoParts = <String>[
      '구매목록',
      _dateFormat.format(lot.buyDate),
      if (lot.memo.isNotEmpty) lot.memo,
    ];

    setState(() {
      if (emptyIndex < 0) {
        _lines.add(line);
      }
      line.giftcardId = lot.giftcardId;
      line.lotId = lot.lotId;
      line.setFaceValue(lot.faceValue);
      line.qtyController.text = lot.qty.toString();
      if (sellUnit > 0) {
        line.setSellUnit(sellUnit);
      } else {
        line.sellUnitController.clear();
        line.sellRateController.clear();
      }
      line.memoController.text = memoParts.join(' · ');
    });
    Fluttertoast.showToast(msg: '구매목록을 계산 행에 불러왔습니다.');
  }

  void _addLine() {
    setState(() {
      _lines.add(_SettlementLineDraft());
    });
  }

  void _removeLine(_SettlementLineDraft line) {
    if (_lines.length == 1) {
      Fluttertoast.showToast(msg: '최소 1개 행이 필요합니다.');
      return;
    }
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  void _resetDraft() {
    for (final line in _lines) {
      line.dispose();
    }
    setState(() {
      _lines = <_SettlementLineDraft>[_SettlementLineDraft()];
      _settlementDate = DateTime.now();
      _selectedBranchId = null;
      _editingSettlementId = null;
      _completed = false;
      _recountChecked = false;
      _createSalesOnComplete = true;
      _actualDepositController.clear();
      _memoController.clear();
    });
  }

  Future<void> _loadSettlementById(String settlementId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('giftcard_settlements')
          .doc(settlementId)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (!doc.exists || data == null) {
        Fluttertoast.showToast(msg: '정산 기록을 찾지 못했습니다.');
        if (mounted && widget.popOnSave) {
          Navigator.pop(context);
        }
        return;
      }
      _loadSettlementData(doc.id, data);
    } catch (_) {
      Fluttertoast.showToast(msg: '정산 기록을 불러오지 못했습니다.');
      if (mounted && widget.popOnSave) {
        Navigator.pop(context);
      }
    }
  }

  void _loadSettlementData(String settlementId, Map<String, dynamic> data) {
    final rawItems =
        data['lineItems'] is List ? List<dynamic>.from(data['lineItems']) : [];
    final nextLines = <_SettlementLineDraft>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final line = _SettlementLineDraft(
        lotId: map['lotId'] as String?,
        giftcardId: map['giftcardId'] as String?,
        faceValue: _asInt(map['faceValue']),
        qty: _asInt(map['qty']),
        sellUnit: _asInt(map['sellUnit']),
        memo: (map['memo'] as String?) ?? '',
      );
      final storedRate = (map['sellRate'] as num?)?.toDouble();
      if (storedRate != null && storedRate > 0) {
        line.sellRateController.text = _formatRate(storedRate);
      }
      nextLines.add(line);
    }
    if (nextLines.isEmpty) {
      nextLines.add(_SettlementLineDraft());
    }

    for (final line in _lines) {
      line.dispose();
    }

    setState(() {
      _editingSettlementId = settlementId;
      _selectedBranchId = data['branchId'] as String?;
      _settlementDate = _asDate(data['settlementDate']);
      _completed = data['status'] == 'completed';
      _recountChecked = data['recountChecked'] == true;
      _createSalesOnComplete = data['createSalesOnComplete'] != false;
      _actualDepositController.text = data['actualDepositTotal'] == null
          ? ''
          : _asInt(data['actualDepositTotal']).toString();
      _memoController.text = (data['memo'] as String?) ?? '';
      _lines = nextLines;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final branch = _selectedBranch;

    final lineInputs = _currentLineInputs();
    if (lineInputs.isEmpty) {
      Fluttertoast.showToast(msg: '계산할 상품권 행을 입력해주세요.');
      return;
    }

    if (_completed && _asInt(_actualDepositController.text) <= 0) {
      Fluttertoast.showToast(msg: '실제 입금액을 입력해주세요.');
      return;
    }

    final saleLinkableLines = _saleLinkableLineDrafts();
    final shouldCreateSales = _completed &&
        _createSalesOnComplete &&
        _canCreateSalesWithCurrentLines;
    if (shouldCreateSales && branch == null) {
      Fluttertoast.showToast(msg: '판매 기록 생성을 위해 지점을 선택해주세요.');
      return;
    }
    if (shouldCreateSales) {
      final lotIds = saleLinkableLines.map((line) => line.lotId!).toSet();
      if (lotIds.length != saleLinkableLines.length) {
        Fluttertoast.showToast(msg: '같은 구매목록은 한 번만 판매 기록으로 만들 수 있습니다.');
        return;
      }
    }

    for (final line in _lines) {
      final hasTradeInput = line.giftcardId != null ||
          line.sellUnit > 0 ||
          line.memoController.text.trim().isNotEmpty;
      final isComplete = line.giftcardId != null &&
          line.faceValue > 0 &&
          line.qty > 0 &&
          line.sellUnit > 0;
      if (hasTradeInput && !isComplete) {
        Fluttertoast.showToast(msg: '입력 중인 행의 상품권, 수량, 판매가를 확인해주세요.');
        return;
      }
    }

    if (_saving) return;
    setState(() {
      _saving = true;
    });

    var didPopAfterSave = false;
    try {
      final summary = _currentSummary();
      final actualDepositTotal =
          _completed ? _asInt(_actualDepositController.text) : null;
      AnalyticsService.instance
          .logAction('giftcard_settlement_calculated', params: {
        'screen': 'giftcard_settlement',
        'mode': _editingSettlementId == null ? 'create' : 'edit',
        'status': _completed ? 'completed' : 'planned',
        'expected_total': summary.expectedTotal,
        'actual_deposit_total': actualDepositTotal,
        'qty_bucket': AnalyticsService.quantityBucket(summary.totalQuantity),
        'line_count_bucket': AnalyticsService.quantityBucket(_lines.length),
        'has_branch': branch != null,
      });
      final docId = _editingSettlementId ??
          'settlement_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('giftcard_settlements')
          .doc(docId);

      final payload = <String, dynamic>{
        'status': _completed ? 'completed' : 'planned',
        'tradeDirection': 'sell',
        'branchId': branch?.id,
        'branchNameSnapshot': branch?.name ?? _noBranchLabel,
        'settlementDate': Timestamp.fromDate(_settlementDate),
        'expectedTotal': summary.expectedTotal,
        'actualDepositTotal': actualDepositTotal,
        'difference': actualDepositTotal == null ? 0 : summary.difference,
        'totalQuantity': summary.totalQuantity,
        'createSalesOnComplete': shouldCreateSales,
        'lineItems': lineInputs
            .map(
              (line) => <String, dynamic>{
                'giftcardId': line.giftcardId,
                'lotId': line.lotId,
                'giftcardNameSnapshot': line.giftcardName,
                'faceValue': line.faceValue,
                'qty': line.qty,
                'sellUnit': line.sellUnit,
                'sellRate': double.parse(line.sellRate.toStringAsFixed(2)),
                'lineTotal': line.lineTotal,
                'memo': line.memo,
              },
            )
            .toList(),
        'recountChecked': _recountChecked,
        'memo': _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (_editingSettlementId == null)
          'createdAt': FieldValue.serverTimestamp(),
        if (_completed) 'completedAt': FieldValue.serverTimestamp(),
        if (!_completed) 'completedAt': FieldValue.delete(),
      };

      await ref.set(payload, SetOptions(merge: true));
      if (shouldCreateSales) {
        try {
          final saleIds = await _createSalesFromSettlement(
            uid: user.uid,
            settlementId: docId,
            branch: branch!,
            lines: saleLinkableLines,
          );
          await ref.set(
            <String, dynamic>{
              'salesLinked': true,
              'saleIds': saleIds,
              'salesLinkedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _editingSettlementId = docId;
          });
          Fluttertoast.showToast(msg: '정산은 저장했지만 판매 기록 생성에 실패했습니다: $e');
          return;
        }
      }
      AnalyticsService.instance.logAction('giftcard_settlement_saved', params: {
        'screen': 'giftcard_settlement',
        'entity_id': docId,
        'mode': _editingSettlementId == null ? 'create' : 'edit',
        'status': _completed ? 'completed' : 'planned',
        'expected_total': summary.expectedTotal,
        'sales_linked': shouldCreateSales,
        'qty_bucket': AnalyticsService.quantityBucket(summary.totalQuantity),
      });
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: shouldCreateSales
            ? '정산과 판매 기록이 저장되었습니다.'
            : _completed
                ? '정산 기록이 완료되었습니다.'
                : '정산 예정이 저장되었습니다.',
      );
      if (widget.popOnSave) {
        didPopAfterSave = true;
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _editingSettlementId = docId;
      });
    } catch (e) {
      AnalyticsService.instance.logResult(
        'giftcard_settlement_saved',
        result: 'failed',
        errorCode: e.runtimeType.toString(),
        params: {'screen': 'giftcard_settlement'},
      );
      Fluttertoast.showToast(msg: '저장 실패: $e');
    } finally {
      if (mounted && !didPopAfterSave) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _settlementSaleId(String settlementId, String lotId) {
    final raw = 'settlement_sale_${settlementId}_$lotId';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  Future<int> _loadRulePerMile(
    String uid,
    String cardId,
    String payType,
  ) async {
    if (cardId.isEmpty) return 0;
    final cardDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cards')
        .doc(cardId)
        .get();
    if (!cardDoc.exists) return 0;
    final data = cardDoc.data();
    if (data == null) return 0;
    return (payType == '신용')
        ? (data['creditPerMileKRW'] as num?)?.toInt() ?? 0
        : (data['checkPerMileKRW'] as num?)?.toInt() ?? 0;
  }

  Future<List<String>> _createSalesFromSettlement({
    required String uid,
    required String settlementId,
    required _BranchOption branch,
    required List<_SettlementLineDraft> lines,
  }) async {
    final saleIds = <String>[];
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final lotsRef = userRef.collection('lots');
    final salesRef = userRef.collection('sales');

    for (final line in lines) {
      final lotId = line.lotId;
      if (lotId == null || lotId.isEmpty) continue;

      final lotRef = lotsRef.doc(lotId);
      final saleId = _settlementSaleId(settlementId, lotId);
      final saleRef = salesRef.doc(saleId);

      final lotDoc = await lotRef.get();
      if (!lotDoc.exists || lotDoc.data() == null) {
        throw Exception('구매목록을 찾지 못했습니다.');
      }
      final lot = lotDoc.data()!;
      final saleDoc = await saleRef.get();
      final isNewSale = !saleDoc.exists;
      final status = (lot['status'] as String?) ?? 'open';
      if (isNewSale && status != 'open') {
        throw Exception('이미 판매된 구매목록이 포함되어 있습니다.');
      }

      final lotQty = _asInt(lot['qty']);
      final qty = line.qty;
      if (isNewSale && (lotQty <= 0 || qty > lotQty)) {
        throw Exception('판매 수량이 구매목록 수량보다 많습니다.');
      }

      final faceValue =
          line.faceValue > 0 ? line.faceValue : _asInt(lot['faceValue']);
      final buyUnit = _asInt(lot['buyUnit']);
      final sellUnit = line.sellUnit;
      final buyTotal = buyUnit * qty;
      final sellTotal = sellUnit * qty;
      final discount =
          faceValue <= 0 ? 0.0 : 100 * (1 - (sellUnit / faceValue));

      final cardId = (lot['cardId'] as String?) ?? '';
      final payType = (lot['payType'] as String?) ?? '신용';
      final storedMilePerKRW =
          (lot['mileRuleUsedPerMileKRW'] as num?)?.toInt() ?? 0;
      final milePerKRW = storedMilePerKRW > 0
          ? storedMilePerKRW
          : await _loadRulePerMile(uid, cardId, payType);
      final miles = milePerKRW == 0 ? 0 : (buyTotal / milePerKRW).round();
      final profit = sellTotal - buyTotal;
      final costPerMile = miles == 0 ? 0 : (-profit / miles);

      final salePayload = <String, dynamic>{
        'lotId': lotId,
        'settlementId': settlementId,
        'sellDate': Timestamp.fromDate(_settlementDate),
        'sellUnit': sellUnit,
        'discount': double.parse(discount.toStringAsFixed(2)),
        'sellTotal': sellTotal,
        'buyTotal': buyTotal,
        'qty': qty,
        'mileRuleUsedPerMileKRW': milePerKRW,
        'miles': miles,
        'profit': profit,
        'costPerMile': double.parse(costPerMile.toStringAsFixed(2)),
        'branchId': branch.id,
        'branchNameSnapshot': branch.name,
        'memo': line.memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNewSale) 'createdAt': FieldValue.serverTimestamp(),
      };
      await saleRef.set(salePayload, SetOptions(merge: true));

      if (isNewSale) {
        if (qty < lotQty) {
          final remainingQty = lotQty - qty;
          final remainingLotId = 'lot_${saleId}_remaining';
          final remainingMiles = milePerKRW == 0
              ? 0
              : ((buyUnit * remainingQty) / milePerKRW).round();

          await lotRef.update({
            'qty': qty,
            'mileRuleUsedPerMileKRW': milePerKRW,
            'miles': miles,
            'status': 'sold',
            'trade': true,
            'settlementId': settlementId,
            'settlementSaleId': saleId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          await lotsRef.doc(remainingLotId).set({
            'faceValue': faceValue,
            'buyDate': lot['buyDate'],
            'payType': payType,
            'buyUnit': buyUnit,
            'discount': (lot['discount'] as num?)?.toDouble() ?? 0,
            'qty': remainingQty,
            'cardId': cardId,
            'mileRuleUsedPerMileKRW': milePerKRW,
            'miles': remainingMiles,
            'status': 'open',
            'giftcardId': lot['giftcardId'],
            'memo': lot['memo'] ?? '',
            'whereToBuyId': lot['whereToBuyId'],
            'sourceLotId': lotId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await lotRef.update({
            'mileRuleUsedPerMileKRW': milePerKRW,
            'miles': miles,
            'status': 'sold',
            'trade': true,
            'settlementId': settlementId,
            'settlementSaleId': saleId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      saleIds.add(saleId);
    }

    return saleIds;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('giftcard_settlements')
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Future<void> _refreshData() async {
    await _loadReferenceData();
    final settlementId = widget.initialSettlementId;
    if (settlementId != null && mounted) {
      await _loadSettlementById(settlementId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRefs) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(GiftcardColors.accent),
        ),
      );
    }

    final stream = _historyStream();
    if (stream == null) {
      return const Center(
        child: Text('로그인 후 상품권 정산 계산기를 사용할 수 있습니다.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: GiftcardColors.accent,
      backgroundColor: Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          (widget.showHistory ? 120 : 24) +
              MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (widget.showTrustNotice) ...[
            _buildTrustNotice(),
            const SizedBox(height: 12),
          ],
          _buildEditor(),
          if (widget.showHistory) ...[
            const SizedBox(height: 16),
            _buildHistory(stream),
          ],
        ],
      ),
    );
  }

  Widget _buildTrustNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: GiftcardColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 19,
              color: GiftcardColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('판매 전, 내가 받을 금액을 먼저 확인하세요.',
                    style: McTextStyles.bodyStrong),
                SizedBox(height: 6),
                Text(
                  '이 계산은 실제 상품권 판매 기록과 관계없는 개인용 사전 계산입니다. 권종, 수량, 단가를 미리 정리해 현장에서 입금액을 차분히 확인하기 위한 도구예요.',
                  style: McTextStyles.meta,
                ),
                SizedBox(height: 6),
                Text(
                  '계산 히스토리는 개인 비공개 기록이며 지점 화면, 후기, 익명 통계에는 노출하지 않습니다.',
                  style: McTextStyles.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final summary = _currentSummary();
    final actual = _completed ? _asInt(_actualDepositController.text) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editingSettlementId == null ? '정산 계산' : '정산 기록 수정',
                  style: McTextStyles.sectionTitle,
                ),
              ),
              if (widget.showHistory)
                TextButton.icon(
                  onPressed: _resetDraft,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('새 계산'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '지점',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 6),
          _PickerField(
            text: _branches.isEmpty
                ? _noBranchLabel
                : (_selectedBranch?.name ?? _noBranchLabel),
            muted: _selectedBranch == null,
            onTap: _branches.isEmpty ? null : _openBranchSheet,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickSettlementDate,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(_dateFormat.format(_settlementDate)),
            style: OutlinedButton.styleFrom(
              foregroundColor: McColors.ink,
              side: const BorderSide(color: McColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openPurchaseLotSheet,
              icon: const Icon(Icons.playlist_add_check_outlined, size: 18),
              label: const Text('상품권 구매목록 불러오기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: GiftcardColors.accent,
                side: const BorderSide(color: McColors.line),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final line in _lines) ...[
            _buildLineEditor(line),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('행 추가'),
            ),
          ),
          const Divider(height: 24),
          _buildSummary(summary, actual),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _completed,
            activeThumbColor: GiftcardColors.accent,
            contentPadding: EdgeInsets.zero,
            title: const Text('정산 완료', style: McTextStyles.bodyStrong),
            subtitle:
                const Text('실제 입금액과 차액을 기록합니다.', style: McTextStyles.meta),
            onChanged: (value) {
              setState(() {
                _completed = value;
                if (value && _asInt(_actualDepositController.text) <= 0) {
                  _actualDepositController.text =
                      summary.expectedTotal.toString();
                }
              });
            },
          ),
          if (_completed) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _actualDepositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '실제 입금액',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            _buildRecountCheckRow(),
            if (_canCreateSalesWithCurrentLines)
              _buildSalesCreationOption(summary),
          ],
          TextField(
            controller: _memoController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? '저장 중' : '정산 기록 저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GiftcardColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecountCheckRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: _recountChecked,
            activeColor: GiftcardColors.accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) {
              setState(() {
                _recountChecked = value == true;
              });
            },
          ),
          const SizedBox(width: 4),
          const Text('재계수 확인', style: McTextStyles.bodyStrong),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '재계수 확인 안내',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.info_outline,
              size: 18,
              color: Colors.black87,
            ),
            onPressed: _showRecountInfoDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCreationOption(GiftcardSettlementSummary summary) {
    final lines = _saleLinkableLineDrafts();
    final expectedTotal = _saleCreationExpectedTotal(lines);
    final totalQty = lines.fold<int>(0, (total, line) => total + line.qty);
    final lotIdText = lines.map((line) => line.lotId!).join(', ');
    final branchName = _selectedBranch?.name ?? _noBranchLabel;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GiftcardColors.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: _createSalesOnComplete,
            activeThumbColor: GiftcardColors.accent,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '판매 기록도 함께 생성',
              style: McTextStyles.bodyStrong,
            ),
            subtitle: const Text(
              '구매목록을 판매 완료 처리하고 판매 내역에 저장합니다.',
              style: McTextStyles.meta,
            ),
            onChanged: (value) {
              setState(() {
                _createSalesOnComplete = value;
              });
            },
          ),
          if (_createSalesOnComplete) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryPill(
                  icon: Icons.receipt_long_outlined,
                  label: '판매 기록 ${lines.length}건',
                ),
                _SummaryPill(
                  icon: Icons.confirmation_number_outlined,
                  label: '총 $totalQty장',
                ),
                _SummaryPill(
                  icon: Icons.payments_outlined,
                  label: '예상 ${_formatWon(expectedTotal)}',
                ),
                _ActionSummaryPill(
                  icon: Icons.storefront_outlined,
                  label: branchName == _noBranchLabel
                      ? _noBranchLabel
                      : '지점 $branchName',
                  onTap: _branches.isEmpty ? null : _openBranchSheet,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '연결 lotId: $lotIdText',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.meta,
            ),
            if (summary.expectedTotal != expectedTotal) ...[
              const SizedBox(height: 6),
              const Text(
                '구매목록으로 불러온 행만 판매 기록으로 생성됩니다.',
                style: McTextStyles.meta,
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showRecountInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        title: const Text(
          '재계수 확인이란?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          '지점에서 상품권 장수와 권종을 다시 확인했는지 남기는 개인 체크입니다.\n\n'
          '계수기나 직원 계산만 믿기보다, 예상 금액과 실제 입금액이 맞는지 확인했다는 안전 기록이에요.\n\n'
          '실제 판매 데이터, 지점 통계, 후기에는 사용되지 않습니다.',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineEditor(_SettlementLineDraft line) {
    final lineTotal = GiftcardSettlementCalculator.lineTotal(
      qty: line.qty,
      sellUnit: line.sellUnit,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  text: _giftcards.isEmpty
                      ? '등록된 상품권이 없습니다.'
                      : (line.giftcardId == null
                          ? '상품권 선택'
                          : _giftcardName(line.giftcardId)),
                  muted: _giftcards.isEmpty || line.giftcardId == null,
                  onTap: _giftcards.isEmpty
                      ? null
                      : () => _openGiftcardSheet(line),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '행 삭제',
                onPressed: () => _removeLine(line),
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                      'face_${identityHashCode(line)}_${line.faceValue}'),
                  initialValue: _SettlementLineDraft.faceValueOptions
                          .contains(line.faceValue)
                      ? line.faceValue
                      : null,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(labelText: '권종'),
                  items: [
                    for (final value in _SettlementLineDraft.faceValueOptions)
                      DropdownMenuItem<int>(
                        value: value,
                        child: Text(_formatWon(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value != line.faceValue) {
                        line.lotId = null;
                      }
                      line.setFaceValue(value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: line.qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '수량'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.sellUnitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '판매가'),
                  onChanged: (_) {
                    setState(() {
                      line.syncRateFromUnit();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: line.sellRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '매입률(%)'),
                  onChanged: (_) {
                    setState(() {
                      line.syncUnitFromRate();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: line.memoController,
            decoration: const InputDecoration(
              labelText: '묶음/봉투 메모',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '소계 ${_formatWon(lineTotal)}',
                  style: McTextStyles.bodyStrong,
                ),
              ),
              TextButton.icon(
                onPressed: () => _applyCurrentRate(line, overwrite: true),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('현재시세'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(GiftcardSettlementSummary summary, int? actual) {
    final difference = actual == null ? 0 : actual - summary.expectedTotal;
    final diffColor = difference == 0
        ? McColors.muted
        : difference > 0
            ? Colors.blue
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryPill(
              icon: Icons.confirmation_number_outlined,
              label: '총 ${summary.totalQuantity}장',
            ),
            _SummaryPill(
              icon: Icons.payments_outlined,
              label: '예상 ${_formatWon(summary.expectedTotal)}',
            ),
            if (_completed)
              _SummaryPill(
                icon: Icons.compare_arrows_outlined,
                label: '차액 ${_formatWon(difference)}',
                color: diffColor,
              ),
          ],
        ),
        if (summary.subtotalByGiftcard.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in summary.subtotalByGiftcard.entries)
                _SummaryPill(
                  icon: Icons.card_giftcard_outlined,
                  label: '${entry.key} ${_formatWon(entry.value)}',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHistory(Stream<QuerySnapshot<Map<String, dynamic>>> stream) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return const Center(child: Text('정산 히스토리를 불러오지 못했습니다.'));
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('최근 정산 히스토리', style: McTextStyles.sectionTitle),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: McColors.line),
                ),
                child: const Text(
                  '아직 저장된 정산 기록이 없습니다.',
                  style: McTextStyles.body,
                ),
              )
            else
              for (final doc in docs) ...[
                _buildHistoryRow(doc),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Future<void> _openSettlementDetail(String settlementId) async {
    AnalyticsService.instance.logAction('giftcard_ledger_item_open', params: {
      'screen': 'giftcard_settlement',
      'entity_id': settlementId,
      'source': 'history',
    });
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'giftcard_settlement_detail'),
        builder: (_) => GiftcardSettlementDetailScreen(
          settlementId: settlementId,
        ),
      ),
    );
  }

  Map<String, int> _historySubtotalByGiftcard(Map<String, dynamic> data) {
    final rawItems = data['lineItems'];
    if (rawItems is! List) return const <String, int>{};

    final subtotalByGiftcard = <String, int>{};
    for (final item in rawItems) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = (map['giftcardNameSnapshot'] as String?) ??
          (map['giftcardId'] as String?) ??
          '상품권';
      final lineTotal = _asInt(map['lineTotal']);
      final fallbackTotal = _asInt(map['sellUnit']) * _asInt(map['qty']);
      final amount = lineTotal > 0 ? lineTotal : fallbackTotal;
      if (amount <= 0) continue;
      subtotalByGiftcard[name] = (subtotalByGiftcard[name] ?? 0) + amount;
    }
    return subtotalByGiftcard;
  }

  Widget _buildHistoryRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = (data['status'] as String?) ?? 'planned';
    final expectedTotal = _asInt(data['expectedTotal']);
    final totalQuantity = _asInt(data['totalQuantity']);
    final subtotalByGiftcard = _historySubtotalByGiftcard(data);
    final actualTotal = data['actualDepositTotal'] == null
        ? null
        : _asInt(data['actualDepositTotal']);
    final difference = _asInt(data['difference']);
    final date = _asDate(data['settlementDate']);
    final branchName = (data['branchNameSnapshot'] as String?) ??
        (data['branchId'] as String?) ??
        _noBranchLabel;
    final memo = ((data['memo'] as String?) ?? '').trim();

    return InkWell(
      onTap: () => _openSettlementDetail(doc.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branchName,
                    style: McTextStyles.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: status),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: '정산 기록 삭제',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onPressed: () => _confirmDeleteSettlement(doc),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _dateFormat.format(date),
              style: McTextStyles.meta,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryPill(
                  icon: Icons.confirmation_number_outlined,
                  label: '총 $totalQuantity장',
                ),
                _SummaryPill(
                  icon: Icons.payments_outlined,
                  label: '예상 ${_formatWon(expectedTotal)}',
                ),
                for (final entry in subtotalByGiftcard.entries)
                  _SummaryPill(
                    icon: Icons.card_giftcard_outlined,
                    label: '${entry.key} ${_formatWon(entry.value)}',
                  ),
                if (memo.isNotEmpty)
                  _SummaryPill(
                    icon: Icons.note_alt_outlined,
                    label: '메모 $memo',
                    maxLabelWidth: MediaQuery.of(context).size.width - 118,
                  ),
              ],
            ),
            if (status == 'completed' && actualTotal != null) ...[
              const SizedBox(height: 8),
              Text(
                '실입금 ${_formatWon(actualTotal)} · 차액 ${_formatWon(difference)}',
                style: McTextStyles.bodyStrong.copyWith(
                  color: difference == 0
                      ? McColors.ink
                      : difference > 0
                          ? Colors.blue
                          : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSettlement(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final branchName = (data['branchNameSnapshot'] as String?) ??
        (data['branchId'] as String?) ??
        _noBranchLabel;
    final date = _dateFormat.format(_asDate(data['settlementDate']));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        title: const Text(
          '정산 기록 삭제',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '$date · $branchName 기록을 정말로 삭제하시겠습니까?\n\n'
          '삭제한 계산 히스토리는 복구할 수 없습니다.',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black54,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await doc.reference.delete();
      if (!mounted) return;
      if (_editingSettlementId == doc.id) {
        _resetDraft();
      }
      Fluttertoast.showToast(msg: '정산 기록을 삭제했습니다.');
    } catch (_) {
      Fluttertoast.showToast(msg: '정산 기록을 삭제하지 못했습니다.');
    }
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final double? maxLabelWidth;

  const _SummaryPill({
    required this.icon,
    required this.label,
    this.color,
    this.maxLabelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? McColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: McColors.field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxLabelWidth ?? double.infinity,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.micro.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionSummaryPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: _SummaryPill(
          icon: icon,
          label: label,
          color: onTap == null ? McColors.muted : GiftcardColors.accent,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: GiftcardColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: McTextStyles.micro.copyWith(
          color: GiftcardColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String text;
  final bool muted;
  final VoidCallback? onTap;

  const _PickerField({
    required this.text,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCFD3DD)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      muted ? const Color(0xFF9AA0AF) : const Color(0xFF1F1F28),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF757B88),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final completed = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFEAF2FF) : GiftcardColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        completed ? '완료' : '예정',
        style: McTextStyles.micro.copyWith(
          color: completed ? Colors.blue : GiftcardColors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PickerOption {
  final String id;
  final String label;

  const _PickerOption({
    required this.id,
    required this.label,
  });
}

class _BranchOption {
  final String id;
  final String name;

  const _BranchOption({
    required this.id,
    required this.name,
  });
}

class _GiftcardOption {
  final String id;
  final String name;
  final int sortOrder;

  const _GiftcardOption({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
}

class _PurchaseLotOption {
  final String lotId;
  final String giftcardId;
  final String giftcardName;
  final int faceValue;
  final int qty;
  final int buyUnit;
  final DateTime buyDate;
  final String memo;
  final String whereToBuyId;

  const _PurchaseLotOption({
    required this.lotId,
    required this.giftcardId,
    required this.giftcardName,
    required this.faceValue,
    required this.qty,
    required this.buyUnit,
    required this.buyDate,
    required this.memo,
    required this.whereToBuyId,
  });

  int get buyTotal => buyUnit * qty;
}

class _SettlementLineDraft {
  static const List<int> faceValueOptions = <int>[10000, 50000, 100000, 500000];

  String? lotId;
  String? giftcardId;
  final TextEditingController faceValueController;
  final TextEditingController qtyController;
  final TextEditingController sellUnitController;
  final TextEditingController sellRateController;
  final TextEditingController memoController;

  _SettlementLineDraft({
    this.lotId,
    this.giftcardId,
    int faceValue = 100000,
    int qty = 1,
    int sellUnit = 0,
    String memo = '',
  })  : faceValueController = TextEditingController(text: faceValue.toString()),
        qtyController = TextEditingController(text: qty.toString()),
        sellUnitController = TextEditingController(
            text: sellUnit > 0 ? sellUnit.toString() : ''),
        sellRateController = TextEditingController(
          text: sellUnit > 0
              ? _formatRateStatic(
                  GiftcardSettlementCalculator.sellRateFromUnit(
                    faceValue: faceValue,
                    sellUnit: sellUnit,
                  ),
                )
              : '',
        ),
        memoController = TextEditingController(text: memo);

  int get faceValue =>
      int.tryParse(
          faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;

  int get qty =>
      int.tryParse(qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get sellUnit =>
      int.tryParse(sellUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;

  void setFaceValue(int value) {
    faceValueController.text = value.toString();
    if (sellRateController.text.trim().isNotEmpty) {
      syncUnitFromRate();
    } else if (sellUnit > 0) {
      syncRateFromUnit();
    }
  }

  void setSellUnit(int value) {
    sellUnitController.text = value.toString();
    syncRateFromUnit();
  }

  void syncRateFromUnit() {
    final unit = sellUnit;
    final face = faceValue;
    if (unit <= 0 || face <= 0) return;
    final rate = GiftcardSettlementCalculator.sellRateFromUnit(
      faceValue: face,
      sellUnit: unit,
    );
    sellRateController.text = _formatRateStatic(rate);
  }

  void syncUnitFromRate() {
    final rate = double.tryParse(sellRateController.text.trim());
    final face = faceValue;
    if (rate == null || face <= 0) return;
    final unit = GiftcardSettlementCalculator.sellUnitFromRate(
      faceValue: face,
      sellRate: rate,
    );
    sellUnitController.text = unit.toString();
  }

  void dispose() {
    faceValueController.dispose();
    qtyController.dispose();
    sellUnitController.dispose();
    sellRateController.dispose();
    memoController.dispose();
  }

  static String _formatRateStatic(double value) {
    final text = value.toStringAsFixed(2);
    if (text.endsWith('00')) return text.substring(0, text.length - 3);
    if (text.endsWith('0')) return text.substring(0, text.length - 1);
    return text;
  }
}
