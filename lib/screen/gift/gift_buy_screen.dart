import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GiftBuyScreen extends StatefulWidget {
  final String? editLotId;
  const GiftBuyScreen({super.key, this.editLotId});

  @override
  State<GiftBuyScreen> createState() => _GiftBuyScreenState();
}

class _GiftBuyScreenState extends State<GiftBuyScreen> {
  final TextEditingController _faceValueController = TextEditingController(text: '100000');
  final TextEditingController _buyUnitController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _memoController = TextEditingController();
  int get _totalBuy => (int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) *
      (int.tryParse(_buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);

  String? _selectedGiftcardId;
  String? _selectedCardId;
  String _payType = '신용';
  DateTime _buyDate = DateTime.now();
  final List<int> _faceValueOptions = [10000, 50000, 100000, 500000];
  int? _selectedFaceValue = 100000;

  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _giftcards = [];
  Map<String, dynamic>? _existingLot;

  @override
  void initState() {
    super.initState();
    _loadCardsAndGiftcards();
    _buyUnitController.addListener(_onBuyUnitChanged);
    _discountController.addListener(_onDiscountChanged);
    _qtyController.addListener(() => setState(() {}));
    if (widget.editLotId != null) {
      _loadExistingLot();
    }
  }

  Future<void> _loadExistingLot() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.editLotId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('lots').doc(widget.editLotId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final faceValue = (data['faceValue'] as num?)?.toInt() ?? 100000;
    setState(() {
      _existingLot = {'id': doc.id, ...data};
      _selectedGiftcardId = data['giftcardId'] as String?;
      _selectedCardId = data['cardId'] as String?;
      _payType = (data['payType'] as String?) ?? '신용';
      final ts = data['buyDate'];
      if (ts is Timestamp) {
        _buyDate = ts.toDate();
      }
      _selectedFaceValue = _faceValueOptions.contains(faceValue) ? faceValue : 100000;
      _faceValueController.text = _selectedFaceValue.toString();
      _qtyController.text = ((data['qty'] as num?)?.toInt() ?? 1).toString();
      _buyUnitController.text = ((data['buyUnit'] as num?)?.toInt() ?? 0).toString();
      _discountController.text = ((data['discount'] as num?)?.toDouble() ?? 0).toString();
      _memoController.text = (data['memo'] as String?) ?? '';
    });
  }

  Future<void> _loadCardsAndGiftcards() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final cardsSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('cards').get();
      final giftsSnap = await FirebaseFirestore.instance
          .collection('giftcards').get();
      setState(() {
        _cards = cardsSnap.docs
            .map((d) => {'cardId': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        _giftcards = giftsSnap.docs
            .map((d) => {'giftcardId': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => ((a['sortOrder'] ?? 999) as int).compareTo((b['sortOrder'] ?? 999) as int));

        // 편집 모드에서 기존 값이 있으면 그대로 유지하고,
        // 없다면 목록의 첫 항목으로 기본 선택 설정
        if (_cards.isNotEmpty) {
          final bool hasExisting = _selectedCardId != null &&
              _cards.any((c) => c['cardId'] == _selectedCardId);
          if (!hasExisting) {
            _selectedCardId = _cards.first['cardId'] as String?;
          }
        } else {
          _selectedCardId = null;
        }

        if (_giftcards.isNotEmpty) {
          final bool hasExisting = _selectedGiftcardId != null &&
              _giftcards.any((g) => g['giftcardId'] == _selectedGiftcardId);
          if (!hasExisting) {
            _selectedGiftcardId = _giftcards.first['giftcardId'] as String?;
          }
        } else {
          _selectedGiftcardId = null;
        }
      });
    } catch (_) {}
  }

  void _onBuyUnitChanged() {
    final face = int.tryParse(_faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final unit = int.tryParse(_buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (unit == null || face == 0) return;
    final disc = 100 * (1 - (unit / face));
    final str = disc.toStringAsFixed(2);
    if (_discountController.text != str) {
      _discountController.removeListener(_onDiscountChanged);
      _discountController.text = str;
      _discountController.addListener(_onDiscountChanged);
      setState(() {});
    }
  }

  void _onDiscountChanged() {
    final face = int.tryParse(_faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final disc = double.tryParse(_discountController.text);
    if (disc == null || face == 0) return;
    final unit = (face * (1 - disc / 100)).round();
    final str = unit.toString();
    if (_buyUnitController.text != str) {
      _buyUnitController.removeListener(_onBuyUnitChanged);
      _buyUnitController.text = str;
      _buyUnitController.addListener(_onBuyUnitChanged);
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _buyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF74512D))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _buyDate = picked);
  }

  Future<void> _save() async {
    setState(() { _error = null; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (_cards.isEmpty || _selectedCardId == null) {
      setState(() { _error = '카드가 없습니다. 카드 생성부터 진행해주세요.'; });
      return;
    }
    if (_selectedGiftcardId == null) {
      setState(() { _error = '상품권을 선택하세요.'; });
      return;
    }
    final faceValue = int.tryParse(_faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final buyUnit = int.tryParse(_buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final qty = int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (faceValue <= 0 || buyUnit <= 0 || qty <= 0) {
      setState(() { _error = '금액과 수량을 올바르게 입력하세요.'; });
      return;
    }

    if (_saving) return;
    setState(() { _saving = true; });
    try {
      final lotsRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('lots');
      final targetId = widget.editLotId ?? 'lot_${DateTime.now().millisecondsSinceEpoch}';
      final data = {
        'faceValue': faceValue,
        'buyDate': Timestamp.fromDate(_buyDate),
        'payType': _payType,
        'buyUnit': buyUnit,
        'discount': double.parse(discount.toStringAsFixed(2)),
        'qty': qty,
        'cardId': _selectedCardId,
        'status': _existingLot?['status'] ?? 'open',
        'giftcardId': _selectedGiftcardId,
        'memo': _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.editLotId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await lotsRef.doc(targetId).set(data, SetOptions(merge: true));
      Fluttertoast.showToast(msg: widget.editLotId == null ? '구매가 저장되었습니다.' : '구매가 수정되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.editLotId == null) {
      Fluttertoast.showToast(msg: '삭제할 수 없습니다.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '삭제 확인',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '이 구매 내역을 삭제하시겠습니까?',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_saving) return;
    setState(() { _saving = true; });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .doc(widget.editLotId)
          .delete();
      Fluttertoast.showToast(msg: '구매 내역이 삭제되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '삭제 실패: $e');
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  void dispose() {
    _faceValueController.dispose();
    _buyUnitController.dispose();
    _discountController.dispose();
    _qtyController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCards = _cards.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.editLotId == null ? '상품권 구매' : '상품권 구매 수정', style: const TextStyle(color: Colors.black, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!hasCards)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD6B5)),
                ),
                child: const Text('카드 규칙이 없습니다. 카드 생성 메뉴에서 먼저 카드를 추가하세요.', style: TextStyle(color: Colors.black87)),
              ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // EditText가 아닌 곳을 클릭하면 키보드 숨기기
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('상품권', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedGiftcardId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      iconEnabledColor: Colors.black54,
                      items: _giftcards
                          .map((g) => DropdownMenuItem<String>(
                                value: g['giftcardId'] as String,
                                child: Text(
                                  (g['name'] as String?) ?? g['giftcardId'] as String,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGiftcardId = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.5)),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('카드', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCardId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      iconEnabledColor: Colors.black54,
                      items: _cards
                          .map((c) => DropdownMenuItem<String>(
                                value: c['cardId'] as String,
                                child: Text('${c['name'] ?? c['cardId']}', style: const TextStyle(color: Colors.black)),
                              ))
                          .toList(),
                      onChanged: hasCards ? (v) => setState(() => _selectedCardId = v) : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.5)),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('결제 수단', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('신용'),
                          selected: _payType == '신용',
                          selectedColor: const Color(0xFF74512D),
                          labelStyle: TextStyle(color: _payType == '신용' ? Colors.white : Colors.black87),
                          onSelected: (v) => setState(() => _payType = '신용'),
                        ),
                        ChoiceChip(
                          label: const Text('체크'),
                          selected: _payType == '체크',
                          selectedColor: const Color(0xFF74512D),
                          labelStyle: TextStyle(color: _payType == '체크' ? Colors.white : Colors.black87),
                          onSelected: (v) => setState(() => _payType = '체크'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('구매일', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black26),
                      ),
                      child: Text(
                        '${_buyDate.year}-${_buyDate.month.toString().padLeft(2, '0')}-${_buyDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedFaceValue,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Colors.black),
                            iconEnabledColor: Colors.black54,
                            items: _faceValueOptions
                                .map((value) {
                                  final formatted = value.toString().replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  );
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      '$formatted원',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFaceValue = value;
                                  _faceValueController.text = value.toString();
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: '액면가(원)',
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                              border: OutlineInputBorder(),
                              labelStyle: TextStyle(color: Colors.black54),
                              floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            cursorColor: const Color(0xFF74512D),
                            decoration: const InputDecoration(
                              labelText: '수량',
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                              labelStyle: TextStyle(color: Colors.black54),
                              floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _buyUnitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                      cursorColor: const Color(0xFF74512D),
                      decoration: const InputDecoration(
                        labelText: '매입가(권당, 원)',
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                        labelStyle: TextStyle(color: Colors.black54),
                        floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                      cursorColor: const Color(0xFF74512D),
                      decoration: const InputDecoration(
                        labelText: '할인율(%)',
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                        labelStyle: TextStyle(color: Colors.black54),
                        floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('합계: ${_totalBuy.toString()}원', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    const Text('메모', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _memoController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.black),
                      cursorColor: const Color(0xFF74512D),
                      decoration: const InputDecoration(
                        hintText: '메모를 입력하세요',
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                        labelStyle: TextStyle(color: Colors.black54),
                        floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                        hintStyle: TextStyle(color: Colors.black38),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: widget.editLotId != null
              ? ((_existingLot?['status'] as String?) == 'sold')
                  ? SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74512D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('수정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF74512D),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('수정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _delete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF74512D),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    )
              : SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF74512D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
        ),
      ),
    );
  }
}


