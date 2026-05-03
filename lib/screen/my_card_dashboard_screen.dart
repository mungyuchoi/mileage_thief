import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../branch/card_manage.dart';
import '../services/card_transaction_service.dart';

class MyCardDashboardScreen extends StatefulWidget {
  const MyCardDashboardScreen({super.key});

  @override
  State<MyCardDashboardScreen> createState() => _MyCardDashboardScreenState();
}

class _MyCardDashboardScreenState extends State<MyCardDashboardScreen> {
  final CardTransactionService _service = CardTransactionService();
  final NumberFormat _won = NumberFormat('#,###');
  final DateFormat _monthLabel = DateFormat('yyyy년 M월');
  late DateTime _visibleMonth;
  Future<CardDashboardData>? _future;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _reload();
  }

  void _reload() {
    final uid = _uid;
    if (uid == null) {
      _future = null;
      return;
    }
    _future = _loadDashboard(uid);
  }

  Future<CardDashboardData> _loadDashboard(String uid) async {
    await _service.syncGiftLotsForMonth(uid: uid, month: _visibleMonth);
    return _service.loadDashboardData(uid: uid, month: _visibleMonth);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _reload();
    });
  }

  Future<void> _openCardSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CardManagePage()),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _openManualSheet(CardDashboardData data) async {
    final uid = _uid;
    if (uid == null) return;
    if (data.cards.isEmpty) {
      Fluttertoast.showToast(msg: '카드를 먼저 추가해주세요.');
      await _openCardSettings();
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualTransactionSheet(
        cards: data.cards,
        service: _service,
        uid: uid,
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _openCardDetail(CardDashboardCardSummary summary) async {
    final uid = _uid;
    if (uid == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CardDetailScreen(
          uid: uid,
          month: _visibleMonth,
          cardId: summary.card.id,
          service: _service,
        ),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F6),
      appBar: AppBar(
        title: const Text(
          '내 카드',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
        actions: [
          IconButton(
            tooltip: '내 카드 설정',
            onPressed: uid == null ? null : _openCardSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: uid == null
          ? _LoginRequired(onRetry: () => setState(_reload))
          : FutureBuilder<CardDashboardData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF74512D),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: '카드 현황을 불러오지 못했습니다.',
                    onRetry: () => setState(_reload),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return _ErrorState(
                    message: '표시할 카드 데이터가 없습니다.',
                    onRetry: () => setState(_reload),
                  );
                }
                return _buildContent(data);
              },
            ),
    );
  }

  Widget _buildContent(CardDashboardData data) {
    final summary = data.summary;
    return RefreshIndicator(
      onRefresh: () async {
        setState(_reload);
        await _future;
      },
      color: const Color(0xFF74512D),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _MonthSwitcher(
            label: _monthLabel.format(_visibleMonth),
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: 12),
          _SummaryPanel(
            cardCount: summary.cardCount,
            performanceAmount: _won.format(summary.performanceAmountKRW),
            rewardMiles: _won.format(summary.rewardMiles),
            excludedAmount: _won.format(summary.excludedAmountKRW),
            needsReviewCount: summary.needsReviewCount,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openCardSettings,
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: Text(data.cards.isEmpty ? '카드 추가' : '카드 설정'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openManualSheet(data),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('수동 입력'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF74512D),
                    side: const BorderSide(color: Color(0xFF74512D)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.cards.isEmpty)
            _EmptyCards(onAdd: _openCardSettings)
          else ...[
            const Text(
              '카드별 현황',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...data.cardSummaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CardSummaryTile(
                  summary: summary,
                  won: _won,
                  onTap: () => _openCardDetail(summary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardDetailScreen extends StatefulWidget {
  const _CardDetailScreen({
    required this.uid,
    required this.month,
    required this.cardId,
    required this.service,
  });

  final String uid;
  final DateTime month;
  final String cardId;
  final CardTransactionService service;

  @override
  State<_CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<_CardDetailScreen> {
  final NumberFormat _won = NumberFormat('#,###');
  final DateFormat _date = DateFormat('M.d');
  late Future<CardDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.service.loadDashboardData(
      uid: widget.uid,
      month: widget.month,
    );
  }

  Future<void> _openOverride(
    CardTransactionRecord transaction,
    UserCardRecord card,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionOverrideSheet(
        uid: widget.uid,
        card: card,
        transaction: transaction,
        service: widget.service,
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final summary = data?.cardSummaries.firstWhere(
          (item) => item.card.id == widget.cardId,
          orElse: () => CardDashboardCardSummary(
            card: UserCardRecord(
              id: widget.cardId,
              name: widget.cardId,
              creditPerMileKRW: 0,
              checkPerMileKRW: 0,
              targetSpendKRW: 0,
              raw: const {},
            ),
            transactions: const [],
            performanceAmountKRW: 0,
            rewardMiles: 0,
            excludedAmountKRW: 0,
            targetSpendKRW: 0,
            remainingSpendKRW: 0,
            progress: 0,
            needsReviewCount: 0,
          ),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F6),
          appBar: AppBar(
            title: Text(
              summary?.card.name ?? '카드 상세',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.4,
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
                  data == null
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF74512D)),
                )
              : summary == null
                  ? const Center(child: Text('카드 정보를 찾을 수 없습니다.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        _CardDetailHeader(summary: summary, won: _won),
                        const SizedBox(height: 16),
                        const Text(
                          '거래건',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (summary.transactions.isEmpty)
                          const _EmptyTransactions()
                        else
                          ...summary.transactions.map(
                            (transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TransactionTile(
                                transaction: transaction,
                                won: _won,
                                date: _date,
                                onTap: () => _openOverride(
                                  transaction,
                                  summary.card,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}

class _ManualTransactionSheet extends StatefulWidget {
  const _ManualTransactionSheet({
    required this.cards,
    required this.service,
    required this.uid,
  });

  final List<UserCardRecord> cards;
  final CardTransactionService service;
  final String uid;

  @override
  State<_ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<_ManualTransactionSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _categoryController =
      TextEditingController(text: 'general');
  late String _cardId;
  late DateTime _occurredAt;
  bool _performanceEligible = true;
  bool _rewardEligible = true;
  bool _saving = false;

  UserCardRecord get _selectedCard =>
      widget.cards.firstWhere((card) => card.id == _cardId);

  int get _defaultRule => _selectedCard.defaultMileRuleKRW;

  @override
  void initState() {
    super.initState();
    _cardId = widget.cards.first.id;
    _occurredAt = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF74512D)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (amount <= 0) {
      Fluttertoast.showToast(msg: '금액을 입력해주세요.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.createManualTransaction(
        uid: widget.uid,
        cardId: _cardId,
        occurredAt: _occurredAt,
        amountKRW: amount,
        merchantName: _merchantController.text,
        category: _categoryController.text,
        performanceEligible: _performanceEligible,
        rewardEligible: _rewardEligible,
        mileRuleUsedPerMileKRW: _defaultRule,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      Fluttertoast.showToast(msg: '저장 실패: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '수동 거래 입력',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _cardId,
                decoration: const InputDecoration(labelText: '카드'),
                items: widget.cards
                    .map(
                      (card) => DropdownMenuItem(
                        value: card.id,
                        child: Text(card.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _cardId = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '이용금액'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(labelText: '사용처'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('이용일'),
                subtitle: Text(DateFormat('yyyy.MM.dd').format(_occurredAt)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('실적 인정'),
                value: _performanceEligible,
                activeThumbColor: const Color(0xFF74512D),
                onChanged: (value) =>
                    setState(() => _performanceEligible = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '마일 적립${_defaultRule > 0 ? ' ($_defaultRule원/마일)' : ''}'),
                value: _rewardEligible,
                activeThumbColor: const Color(0xFF74512D),
                onChanged: (value) => setState(() => _rewardEligible = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_saving ? '저장 중' : '저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionOverrideSheet extends StatefulWidget {
  const _TransactionOverrideSheet({
    required this.uid,
    required this.card,
    required this.transaction,
    required this.service,
  });

  final String uid;
  final UserCardRecord card;
  final CardTransactionRecord transaction;
  final CardTransactionService service;

  @override
  State<_TransactionOverrideSheet> createState() =>
      _TransactionOverrideSheetState();
}

class _TransactionOverrideSheetState extends State<_TransactionOverrideSheet> {
  late bool _performanceEligible;
  late bool _rewardEligible;
  late bool _applyToFuture;
  late final TextEditingController _ruleController;
  late final TextEditingController _memoController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _performanceEligible = widget.transaction.performanceEligible;
    _rewardEligible = widget.transaction.rewardEligible;
    _applyToFuture = false;
    final rule = widget.transaction.rewardMileRuleKRW > 0
        ? widget.transaction.rewardMileRuleKRW
        : widget.card.defaultMileRuleKRW;
    _ruleController = TextEditingController(text: rule > 0 ? '$rule' : '');
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _ruleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rule =
        int.tryParse(_ruleController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
    if (_rewardEligible && rule <= 0) {
      Fluttertoast.showToast(msg: '마일 적립 기준을 입력해주세요.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.saveTransactionOverride(
        uid: widget.uid,
        transaction: widget.transaction,
        performanceEligible: _performanceEligible,
        rewardEligible: _rewardEligible,
        mileRuleUsedPerMileKRW: rule,
        applyToFuture: _applyToFuture,
        memo: _memoController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      Fluttertoast.showToast(msg: '저장 실패: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transaction.merchantName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,###').format(widget.transaction.amountKRW)}원',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('실적 인정'),
                value: _performanceEligible,
                activeThumbColor: const Color(0xFF74512D),
                onChanged: (value) =>
                    setState(() => _performanceEligible = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마일 적립'),
                value: _rewardEligible,
                activeThumbColor: const Color(0xFF74512D),
                onChanged: (value) => setState(() => _rewardEligible = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ruleController,
                enabled: _rewardEligible,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '1마일 적립 기준(원)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '메모'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('이 사용처에 계속 적용'),
                value: _applyToFuture,
                activeColor: const Color(0xFF74512D),
                onChanged: (value) =>
                    setState(() => _applyToFuture = value ?? false),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_saving ? '저장 중' : '보정 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.cardCount,
    required this.performanceAmount,
    required this.rewardMiles,
    required this.excludedAmount,
    required this.needsReviewCount,
  });

  final int cardCount;
  final String performanceAmount;
  final String rewardMiles;
  final String excludedAmount;
  final int needsReviewCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E2DC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '보유 카드',
                  value: '$cardCount장',
                  icon: Icons.credit_card_rounded,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '실적 인정',
                  value: '$performanceAmount원',
                  icon: Icons.task_alt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '예상 마일',
                  value: '$rewardMiles마일',
                  icon: Icons.stars_rounded,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '제외/보정',
                  value: '$excludedAmount원 · $needsReviewCount건',
                  icon: Icons.rule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF74512D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF74512D), size: 19),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardSummaryTile extends StatelessWidget {
  const _CardSummaryTile({
    required this.summary,
    required this.won,
    required this.onTap,
  });

  final CardDashboardCardSummary summary;
  final NumberFormat won;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTarget = summary.targetSpendKRW > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E2DC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: Color(0xFF74512D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.card.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: hasTarget ? summary.progress : 0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF74512D),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '실적 ${won.format(summary.performanceAmountKRW)}원',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  hasTarget
                      ? '남은 ${won.format(summary.remainingSpendKRW)}원'
                      : '목표 미설정',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusPill(
                  text: '마일 ${won.format(summary.rewardMiles)}',
                  color: const Color(0xFF74512D),
                ),
                _StatusPill(
                  text: '거래 ${summary.transactions.length}건',
                  color: Colors.blueGrey,
                ),
                if (summary.excludedAmountKRW > 0)
                  _StatusPill(
                    text: '제외 ${won.format(summary.excludedAmountKRW)}원',
                    color: Colors.deepOrange,
                  ),
                if (summary.needsReviewCount > 0)
                  _StatusPill(
                    text: '보정 필요 ${summary.needsReviewCount}',
                    color: Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailHeader extends StatelessWidget {
  const _CardDetailHeader({required this.summary, required this.won});

  final CardDashboardCardSummary summary;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.card.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: summary.targetSpendKRW > 0 ? summary.progress : 0,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            color: const Color(0xFF74512D),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                text: '실적 ${won.format(summary.performanceAmountKRW)}원',
                color: const Color(0xFF74512D),
              ),
              _StatusPill(
                text: '예상 ${won.format(summary.rewardMiles)}마일',
                color: Colors.indigo,
              ),
              _StatusPill(
                text: summary.targetSpendKRW > 0
                    ? '목표 ${won.format(summary.targetSpendKRW)}원'
                    : '목표 미설정',
                color: Colors.blueGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.won,
    required this.date,
    required this.onTap,
  });

  final CardTransactionRecord transaction;
  final NumberFormat won;
  final DateFormat date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E2DC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transaction.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${won.format(transaction.amountKRW)}원',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${date.format(transaction.occurredAt)} · ${_sourceLabel(transaction.source)} · ${transaction.category}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(
                  text: transaction.performanceEligible ? '실적 인정' : '실적 제외',
                  color: transaction.performanceEligible
                      ? const Color(0xFF74512D)
                      : Colors.deepOrange,
                ),
                _StatusPill(
                  text: transaction.rewardEligible
                      ? '마일 ${won.format(transaction.rewardMiles)}'
                      : '적립 제외',
                  color:
                      transaction.rewardEligible ? Colors.indigo : Colors.grey,
                ),
                if (transaction.performanceOverridden ||
                    transaction.rewardOverridden)
                  const _StatusPill(text: '보정됨', color: Colors.green),
                if (transaction.needsReview)
                  const _StatusPill(text: '확인 필요', color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card_off_rounded,
              size: 42, color: Colors.black38),
          const SizedBox(height: 10),
          const Text(
            '등록된 카드가 없습니다.',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '카드를 추가하면 상품권 구매와 수동 입력 거래를 한곳에서 볼 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('카드 추가'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          '이번 달 거래건이 없습니다.',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 42, color: Colors.black38),
            const SizedBox(height: 12),
            const Text(
              '로그인이 필요합니다.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('다시 확인')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline_rounded,
                size: 42, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

String _sourceLabel(String source) {
  switch (source) {
    case 'gift_lot':
      return '상품권';
    case 'manual':
      return '수동';
    case 'csv':
      return 'CSV';
    case 'mydata':
      return '연동';
    default:
      return source;
  }
}
