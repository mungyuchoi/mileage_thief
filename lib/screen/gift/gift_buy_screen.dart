import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../../services/card_transaction_service.dart';

class GiftBuyScreen extends StatefulWidget {
  final String? editLotId;
  const GiftBuyScreen({super.key, this.editLotId});

  @override
  State<GiftBuyScreen> createState() => _GiftBuyScreenState();
}

class _GiftBuyScreenState extends State<GiftBuyScreen> {
  final TextEditingController _faceValueController =
      TextEditingController(text: '100000');
  final TextEditingController _buyUnitController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _memoController = TextEditingController();
  int get _totalBuy =>
      (int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0) *
      (int.tryParse(
              _buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0);

  String? _selectedGiftcardId;
  String? _selectedCardId;
  String? _selectedWhereToBuyId;
  String _payType = '신용';
  DateTime _buyDate = DateTime.now();
  final List<int> _faceValueOptions = [10000, 50000, 100000, 500000];
  int? _selectedFaceValue = 100000;

  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _giftcards = [];
  List<Map<String, dynamic>> _whereToBuys = [];
  Map<String, dynamic>? _existingLot;
  List<Map<String, dynamic>> _templates = [];
  bool _templatesLoading = false;
  String _priceInputMode = 'buyUnit';
  bool _updatingPriceInputs = false;
  final DateFormat _templateNameFormat = DateFormat('yyyyMMdd');

  @override
  void initState() {
    super.initState();
    _loadCardsAndGiftcards();
    _loadWhereToBuys();
    _loadTemplates();
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
        .collection('users')
        .doc(uid)
        .collection('lots')
        .doc(widget.editLotId)
        .get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final faceValue = (data['faceValue'] as num?)?.toInt() ?? 100000;
    setState(() {
      _existingLot = {'id': doc.id, ...data};
      _selectedGiftcardId = data['giftcardId'] as String?;
      _selectedCardId = data['cardId'] as String?;
      _selectedWhereToBuyId = data['whereToBuyId'] as String?;
      _payType = (data['payType'] as String?) ?? '신용';
      final ts = data['buyDate'];
      if (ts is Timestamp) {
        _buyDate = ts.toDate();
      }
      _priceInputMode = 'buyUnit';
      _selectedFaceValue =
          _faceValueOptions.contains(faceValue) ? faceValue : 100000;
      _faceValueController.text = _selectedFaceValue.toString();
      _qtyController.text = ((data['qty'] as num?)?.toInt() ?? 1).toString();
      _buyUnitController.text =
          ((data['buyUnit'] as num?)?.toInt() ?? 0).toString();
      _discountController.text =
          ((data['discount'] as num?)?.toDouble() ?? 0).toString();
      _memoController.text = (data['memo'] as String?) ?? '';
    });
  }

  Future<void> _loadCardsAndGiftcards() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final cardsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cards')
          .get();
      final giftsSnap =
          await FirebaseFirestore.instance.collection('giftcards').get();
      setState(() {
        _cards = cardsSnap.docs
            .map((d) => {'cardId': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
        _giftcards = giftsSnap.docs
            .map((d) => {'giftcardId': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => ((a['sortOrder'] ?? 999) as int)
              .compareTo((b['sortOrder'] ?? 999) as int));

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

  Future<void> _loadWhereToBuys() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('where_to_buy')
          .get();
      setState(() {
        _whereToBuys = snap.docs
            .map((d) => {'whereToBuyId': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
        if (_selectedWhereToBuyId != null &&
            !_whereToBuys
                .any((w) => w['whereToBuyId'] == _selectedWhereToBuyId)) {
          _selectedWhereToBuyId = null;
        }
      });
    } catch (_) {}
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String)
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0;
    return 0;
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _hasTemplateReference(
      List<Map<String, dynamic>> list, String key, String? id) {
    if (id == null || id.isEmpty) return false;
    return list.any((item) => (item[key] as String?) == id);
  }

  String? _templateNameById(
      List<Map<String, dynamic>> list, String key, String? id) {
    if (id == null || id.isEmpty) return null;
    final found = list.firstWhere(
      (item) => (item[key] as String?) == id,
      orElse: () => <String, dynamic>{},
    );
    if (found.isEmpty) return null;
    return _asString(found['name']) ?? id;
  }

  CollectionReference<Map<String, dynamic>> _templateCollection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gift_templates');
  }

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  void _sortTemplates() {
    _templates.sort((a, b) {
      final bool aPinned = a['pinned'] == true;
      final bool bPinned = b['pinned'] == true;
      if (aPinned != bPinned) return aPinned ? -1 : 1;

      final int aUsed = _timestampMillis(a['lastUsedAt']);
      final int bUsed = _timestampMillis(b['lastUsedAt']);
      if (aUsed != bUsed) return bUsed.compareTo(aUsed);

      final String aName = _asString(a['name'])?.toLowerCase() ?? '';
      final String bName = _asString(b['name'])?.toLowerCase() ?? '';
      return aName.compareTo(bName);
    });
  }

  List<Map<String, dynamic>> _pinnedTemplates() {
    return _templates.where((template) => template['pinned'] == true).toList();
  }

  Future<void> _loadTemplates() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _templatesLoading = true;
    });
    try {
      final snap = await _templateCollection(uid).get();
      final list =
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      if (!mounted) return;
      setState(() {
        _templates = list;
        _templatesLoading = false;
        _sortTemplates();
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _templatesLoading = false;
        });
    }
  }

  String _formatTemplateSummary(Map<String, dynamic> template) {
    final payload = (template['payload'] is Map)
        ? Map<String, dynamic>.from(template['payload'] as Map)
        : <String, dynamic>{};
    final giftcardId = _asString(payload['giftcardId']);
    final cardId = _asString(payload['cardId']);
    final whereToBuyId = _asString(payload['whereToBuyId']);
    final qty = _asInt(payload['qty']);
    final faceValue = _asInt(payload['faceValue']);
    final buyUnit = _asInt(payload['buyUnit']);
    final discount = _asDouble(payload['discount']);
    final payType = _asString(payload['payType']) ?? _payType;
    final mode = _asString(payload['priceInputMode']) == 'discount'
        ? 'discount'
        : 'buyUnit';
    final giftName =
        _templateNameById(_giftcards, 'giftcardId', giftcardId) ?? '상품권 미확인';
    final cardName = _templateNameById(_cards, 'cardId', cardId) ?? '카드 미확인';
    final whereName =
        _templateNameById(_whereToBuys, 'whereToBuyId', whereToBuyId);
    final priceText = mode == 'discount'
        ? '할인율 ${discount.toStringAsFixed(2)}%'
        : '매입가 ${buyUnit.toString()}원';
    final memo = _asString(payload['memo'])?.trim();
    final locationText = whereName == null ? '' : ' / $whereName';
    final memoText = (memo == null || memo.isEmpty)
        ? ''
        : ' / ${memo.length > 12 ? '${memo.substring(0, 12)}...' : memo}';
    return '$giftName / $cardName / $priceText / $qty장 / $payType / ${faceValue.toString()}원$locationText$memoText';
  }

  Map<String, dynamic> _buildTemplatePayloadFromCurrentForm() {
    final faceValue =
        _asInt(_faceValueController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final buyUnit =
        _asInt(_buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final discount = _asDouble(_discountController.text);
    final qty = _asInt(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return {
      'giftcardId': _selectedGiftcardId,
      'cardId': _selectedCardId,
      'whereToBuyId': _selectedWhereToBuyId,
      'payType': _payType,
      'faceValue': faceValue,
      'qty': qty,
      'priceInputMode': _priceInputMode,
      'buyUnit': buyUnit,
      'discount': double.parse(discount.toStringAsFixed(2)),
      'memo': _memoController.text.trim(),
      'buyDate': Timestamp.fromDate(_buyDate),
    };
  }

  Future<String?> _askTemplateName({
    required String title,
    String initialName = '',
  }) async {
    final nameController = TextEditingController(text: initialName);
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '템플릿명',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('저장',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTemplateFromCurrentForm() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final defaultName = '${_templateNameFormat.format(_buyDate)} 구매건';
    final name =
        await _askTemplateName(title: '템플릿 저장', initialName: defaultName);
    if (name == null || name.isEmpty) return;
    try {
      final payload = _buildTemplatePayloadFromCurrentForm();
      await _templateCollection(uid).add({
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
      Fluttertoast.showToast(msg: '템플릿이 저장되었습니다.');
      await _loadTemplates();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 저장 실패: $e');
    }
  }

  Future<void> _overwriteTemplateWithCurrentForm(
      Map<String, dynamic> template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final templateId = _asString(template['id']);
    if (uid == null || templateId == null || templateId.isEmpty) return;
    try {
      final int currentVersion = _asInt(template['version']);
      await _templateCollection(uid).doc(templateId).update({
        'payload': _buildTemplatePayloadFromCurrentForm(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      });
      Fluttertoast.showToast(msg: '템플릿이 현재 값으로 수정되었습니다.');
      await _loadTemplates();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 수정 실패: $e');
    }
  }

  Future<void> _renameTemplate(Map<String, dynamic> template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final templateId = _asString(template['id']);
    if (uid == null || templateId == null || templateId.isEmpty) return;
    final currentName = _asString(template['name']) ?? '템플릿';
    final nextName =
        await _askTemplateName(title: '템플릿 이름 수정', initialName: currentName);
    if (nextName == null || nextName.isEmpty) return;
    try {
      await _templateCollection(uid).doc(templateId).update({
        'name': nextName,
        'nameLower': nextName.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Fluttertoast.showToast(msg: '템플릿 이름이 수정되었습니다.');
      await _loadTemplates();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 이름 수정 실패: $e');
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final templateId = _asString(template['id']);
    if (uid == null || templateId == null || templateId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('삭제 확인',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: const Text('이 템플릿을 삭제하시겠습니까?',
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
            child: const Text('삭제',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _templateCollection(uid).doc(templateId).delete();
      Fluttertoast.showToast(msg: '템플릿이 삭제되었습니다.');
      await _loadTemplates();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 삭제 실패: $e');
    }
  }

  Future<void> _toggleTemplatePin(Map<String, dynamic> template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final templateId = _asString(template['id']);
    if (uid == null || templateId == null || templateId.isEmpty) return;
    final bool nextPin = !(template['pinned'] == true);
    try {
      await _templateCollection(uid).doc(templateId).update({
        'pinned': nextPin,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadTemplates();
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 고정 실패: $e');
    }
  }

  Future<void> _applyTemplate(Map<String, dynamic> template) async {
    final payload = (template['payload'] is Map)
        ? Map<String, dynamic>.from(template['payload'] as Map)
        : <String, dynamic>{};
    final giftcardId = _asString(payload['giftcardId']);
    final cardId = _asString(payload['cardId']);
    final whereToBuyId = _asString(payload['whereToBuyId']);
    final faceValue = _asInt(payload['faceValue']);
    final qty = _asInt(payload['qty']);
    final buyUnit = _asInt(payload['buyUnit']);
    final discount = _asDouble(payload['discount']);
    final String payType = _asString(payload['payType']) == '체크' ? '체크' : '신용';
    final String mode = _asString(payload['priceInputMode']) == 'discount'
        ? 'discount'
        : 'buyUnit';
    final String memo = _asString(payload['memo']) ?? '';
    final DateTime dateValue = _asDate(payload['buyDate']) ?? _buyDate;

    final List<String> cleared = [];
    final String? giftcardValue = (giftcardId != null &&
            _hasTemplateReference(_giftcards, 'giftcardId', giftcardId))
        ? giftcardId
        : null;
    final String? cardValue =
        (cardId != null && _hasTemplateReference(_cards, 'cardId', cardId))
            ? cardId
            : null;
    final String? whereValue = (whereToBuyId != null &&
            _hasTemplateReference(_whereToBuys, 'whereToBuyId', whereToBuyId))
        ? whereToBuyId
        : null;
    if (giftcardId != null && giftcardId.isNotEmpty && giftcardValue == null)
      cleared.add('상품권');
    if (cardId != null && cardId.isNotEmpty && cardValue == null)
      cleared.add('카드');
    if (whereToBuyId != null && whereToBuyId.isNotEmpty && whereValue == null)
      cleared.add('구매처');

    if (!mounted) return;
    setState(() {
      _selectedGiftcardId = giftcardValue;
      _selectedCardId = cardValue;
      _selectedWhereToBuyId = whereValue;
      _payType = payType;

      if (faceValue > 0 && !_faceValueOptions.contains(faceValue)) {
        _faceValueOptions.add(faceValue);
        _faceValueOptions.sort();
      }
      _selectedFaceValue = (faceValue > 0 ? faceValue : null);

      _qtyController.text = qty > 0 ? qty.toString() : '1';
      _buyDate = dateValue;
      _priceInputMode = mode;

      _updatingPriceInputs = true;
      _faceValueController.text = (faceValue > 0 ? faceValue : 0).toString();
      _buyUnitController.text = (buyUnit >= 0 ? buyUnit : 0).toString();
      _discountController.text = discount.toStringAsFixed(2);
      _memoController.text = memo;
      _updatingPriceInputs = false;
    });

    if (cleared.isNotEmpty) {
      Fluttertoast.showToast(
          msg: '삭제된 참조 정리: ${cleared.join(', ')} 선택값이 비워졌습니다.');
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final templateId = _asString(template['id']);
      if (uid != null && templateId != null && templateId.isNotEmpty) {
        await _templateCollection(uid).doc(templateId).update({
          'useCount': FieldValue.increment(1),
          'lastUsedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _loadTemplates();
      }
      Fluttertoast.showToast(msg: '템플릿이 적용되었습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '템플릿 사용 기록 갱신 실패: $e');
    }
  }

  Future<void> _openTemplateSheet() async {
    await _loadTemplates();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '템플릿',
                          style: TextStyle(
                            color: Color(0xFF1F1F28),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _createTemplateFromCurrentForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74512D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: const Text('현재값 저장',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_templatesLoading)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (_templates.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('저장된 템플릿이 없습니다.',
                            style: TextStyle(color: Colors.black54)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _templates.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0x1F000000)),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          final bool isPinned = template['pinned'] == true;
                          final String name =
                              _asString(template['name']) ?? '이름 없음';
                          return ListTile(
                            dense: true,
                            title: Text(name,
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              _formatTemplateSummary(template),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '적용',
                                  icon: const Icon(Icons.check,
                                      color: Colors.black54),
                                  onPressed: () async {
                                    Navigator.pop(sheetContext);
                                    await _applyTemplate(template);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  tooltip: '관리',
                                  icon: const Icon(Icons.more_vert,
                                      size: 18, color: Colors.black54),
                                  color: Colors.white,
                                  surfaceTintColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: Color(0x14000000)),
                                  ),
                                  elevation: 6,
                                  onSelected: (value) async {
                                    Navigator.pop(sheetContext);
                                    if (value == 'overwrite') {
                                      await _overwriteTemplateWithCurrentForm(
                                          template);
                                    } else if (value == 'rename') {
                                      await _renameTemplate(template);
                                    } else if (value == 'pin') {
                                      await _toggleTemplatePin(template);
                                    } else if (value == 'delete') {
                                      await _deleteTemplate(template);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'overwrite',
                                      child: Text(
                                        '현재 값으로 수정',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text(
                                        '이름 수정',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(
                                        isPinned ? '핀 해제' : '핀 고정',
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        '삭제',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _applyTemplate(template);
                            },
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

  void _onBuyUnitChanged() {
    if (_updatingPriceInputs) return;
    _priceInputMode = 'buyUnit';
    final face = int.tryParse(
            _faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final unit =
        int.tryParse(_buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (unit == null || face == 0) return;
    final disc = 100 * (1 - (unit / face));
    final str = disc.toStringAsFixed(2);
    if (_discountController.text != str) {
      _discountController.removeListener(_onDiscountChanged);
      _updatingPriceInputs = true;
      _discountController.text = str;
      _updatingPriceInputs = false;
      _discountController.addListener(_onDiscountChanged);
      setState(() {});
    }
  }

  void _onDiscountChanged() {
    if (_updatingPriceInputs) return;
    _priceInputMode = 'discount';
    final face = int.tryParse(
            _faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final disc = double.tryParse(_discountController.text);
    if (disc == null || face == 0) return;
    final unit = (face * (1 - disc / 100)).round();
    final str = unit.toString();
    if (_buyUnitController.text != str) {
      _buyUnitController.removeListener(_onBuyUnitChanged);
      _updatingPriceInputs = true;
      _buyUnitController.text = str;
      _updatingPriceInputs = false;
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
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF74512D))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _buyDate = picked);
  }

  Future<int> _loadRulePerMile(
      String uid, String cardId, String payType) async {
    final cardDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cards')
        .doc(cardId)
        .get();
    if (!cardDoc.exists) return 0;
    final data = cardDoc.data() as Map<String, dynamic>;
    final int val = (payType == '신용')
        ? (data['creditPerMileKRW'] as num?)?.toInt() ?? 0
        : (data['checkPerMileKRW'] as num?)?.toInt() ?? 0;
    return val;
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (_cards.isEmpty || _selectedCardId == null) {
      setState(() {
        _error = '카드가 없습니다. 카드 생성부터 진행해주세요.';
      });
      return;
    }
    if (_selectedGiftcardId == null) {
      setState(() {
        _error = '상품권을 선택하세요.';
      });
      return;
    }
    final faceValue = int.tryParse(
            _faceValueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final buyUnit = int.tryParse(
            _buyUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    final qty =
        int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
    if (faceValue <= 0 || buyUnit <= 0 || qty <= 0) {
      setState(() {
        _error = '금액과 수량을 올바르게 입력하세요.';
      });
      return;
    }

    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      final lotsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots');
      final targetId =
          widget.editLotId ?? 'lot_${DateTime.now().millisecondsSinceEpoch}';
      final String status = _existingLot?['status'] ?? 'open';

      // 기존 lot에 스냅샷이 있으면 유지하고, 없을 때만 현재 카드 규칙으로 보정한다.
      final int? existingMilePerKRW =
          (_existingLot?['mileRuleUsedPerMileKRW'] as num?)?.toInt();
      final String cardId = _selectedCardId as String;
      final int milePerKRW =
          existingMilePerKRW ?? await _loadRulePerMile(uid, cardId, _payType);
      final int buyTotal = buyUnit * qty;
      final int? existingMiles = (_existingLot?['miles'] as num?)?.toInt();
      final int miles = existingMiles ??
          (milePerKRW == 0 ? 0 : (buyTotal / milePerKRW).round());

      final data = {
        'faceValue': faceValue,
        'buyDate': Timestamp.fromDate(_buyDate),
        'payType': _payType,
        'buyUnit': buyUnit,
        'discount': double.parse(discount.toStringAsFixed(2)),
        'qty': qty,
        'cardId': _selectedCardId,
        'mileRuleUsedPerMileKRW': milePerKRW,
        'miles': miles,
        'status': status,
        'giftcardId': _selectedGiftcardId,
        'whereToBuyId': _selectedWhereToBuyId,
        'memo': _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // status가 'sold'면 trade는 true, 아니면 기존 trade 값 유지 (없으면 false)
      if (status == 'sold') {
        data['trade'] = true;
      } else if (widget.editLotId != null &&
          _existingLot?.containsKey('trade') == true) {
        // 편집 시 기존 trade 값 유지
        data['trade'] = _existingLot!['trade'];
      }
      if (widget.editLotId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await lotsRef.doc(targetId).set(data, SetOptions(merge: true));
      await CardTransactionService().upsertGiftLotTransaction(
        uid: uid,
        lotId: targetId,
        lotData: Map<String, dynamic>.from(data),
      );

      // status가 sold인 경우, 연결된 sales의 buyTotal도 업데이트
      if (status == 'sold' && widget.editLotId != null) {
        final salesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sales');
        final salesQuery =
            await salesRef.where('lotId', isEqualTo: targetId).get();

        // 새로운 buyTotal 계산: buyUnit * qty
        final newBuyTotal = buyUnit * qty;

        // 연결된 모든 sales 문서의 buyTotal 업데이트
        final batch = FirebaseFirestore.instance.batch();
        for (final saleDoc in salesQuery.docs) {
          final saleData = saleDoc.data();
          final saleQty = (saleData['qty'] as num?)?.toInt() ?? qty;
          final sellTotal = (saleData['sellTotal'] as num?)?.toDouble() ?? 0.0;

          // sales의 qty에 맞춰 buyTotal 계산 (lot의 buyUnit * sale의 qty)
          final saleBuyTotal = buyUnit * saleQty;
          final profit = sellTotal - saleBuyTotal;
          final milePerKRW =
              (saleData['mileRuleUsedPerMileKRW'] as num?)?.toDouble() ?? 0.0;
          final miles =
              milePerKRW == 0 ? 0 : (saleBuyTotal / milePerKRW).round();
          final costPerMile = miles == 0 ? 0 : (-profit / miles);

          batch.update(saleDoc.reference, {
            'buyTotal': saleBuyTotal,
            'profit': profit,
            'miles': miles,
            'costPerMile': costPerMile,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      Fluttertoast.showToast(
          msg: widget.editLotId == null ? '구매가 저장되었습니다.' : '구매가 수정되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
        });
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
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .doc(widget.editLotId)
          .delete();
      await CardTransactionService().deleteGiftLotTransaction(
        uid: uid,
        lotId: widget.editLotId!,
      );
      Fluttertoast.showToast(msg: '구매 내역이 삭제되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '삭제 실패: $e');
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
        });
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
    final pinnedTemplates = _pinnedTemplates();
    final hasCards = _cards.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.editLotId == null ? '상품권 구매' : '상품권 구매 수정',
            style: const TextStyle(color: Colors.black, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _openTemplateSheet,
            icon: const Icon(Icons.menu_book_outlined, color: Colors.black54),
            label: const Text('템플릿',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
            ),
          ),
        ],
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
                child: const Text('카드 규칙이 없습니다. 카드 생성 메뉴에서 먼저 카드를 추가하세요.',
                    style: TextStyle(color: Colors.black87)),
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
                      if (pinnedTemplates.isNotEmpty) ...[
                        const Text('고정 템플릿',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pinnedTemplates.map((template) {
                            final name = _asString(template['name']) ?? '템플릿';
                            return ActionChip(
                              backgroundColor: const Color(0xFFF7F8FC),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: const BorderSide(
                                      color: Color(0xFFCFD3DD))),
                              label: Text(name),
                              onPressed: () => _applyTemplate(template),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('상품권',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _giftcards.isEmpty
                            ? null
                            : () async {
                                FocusScope.of(context).unfocus();
                                final selectedId =
                                    await showModalBottomSheet<String>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (context) {
                                    return SafeArea(
                                      top: false,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 12, 16, 16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 40,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE1E4EC),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              '상품권 선택',
                                              style: TextStyle(
                                                color: Color(0xFF1F1F28),
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Flexible(
                                              child: GridView.builder(
                                                itemCount: _giftcards.length,
                                                shrinkWrap: true,
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 8,
                                                  mainAxisSpacing: 8,
                                                  childAspectRatio: 2.45,
                                                ),
                                                itemBuilder: (context, index) {
                                                  final gift =
                                                      _giftcards[index];
                                                  final giftcardId =
                                                      gift['giftcardId']
                                                          as String;
                                                  final giftcardName =
                                                      (gift['name']
                                                              as String?) ??
                                                          giftcardId;
                                                  final isSelected =
                                                      giftcardId ==
                                                          _selectedGiftcardId;
                                                  return InkWell(
                                                    onTap: () => Navigator.pop(
                                                        context, giftcardId),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFF7F8FC),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF74512D)
                                                              : const Color(
                                                                  0xFFE8ECF4),
                                                          width: isSelected
                                                              ? 1.5
                                                              : 1,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            giftcardName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF74512D)
                                                                  : const Color(
                                                                      0xFF1F1F28),
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
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
                                    );
                                  },
                                );
                                if (selectedId != null && mounted) {
                                  setState(
                                      () => _selectedGiftcardId = selectedId);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCFD3DD)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _giftcards.isEmpty
                                      ? '등록된 상품권이 없습니다.'
                                      : ((_giftcards.firstWhere(
                                            (g) =>
                                                g['giftcardId'] ==
                                                _selectedGiftcardId,
                                            orElse: () => _giftcards.first,
                                          )['name'] as String?) ??
                                          _selectedGiftcardId ??
                                          '상품권 선택'),
                                  style: TextStyle(
                                    color: _giftcards.isEmpty
                                        ? const Color(0xFF9AA0AF)
                                        : const Color(0xFF1F1F28),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF757B88)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('카드',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      if (!hasCards)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '등록된 카드가 없습니다.',
                            style: TextStyle(
                              color: Color(0xFF6E7483),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _cards.map((c) {
                            final cardId = c['cardId'] as String;
                            final cardName = (((c['name'] as String?) ?? '')
                                    .trim()
                                    .isNotEmpty
                                ? (c['name'] as String).trim()
                                : (((c['cardId'] as String?) ?? '')
                                        .trim()
                                        .isNotEmpty
                                    ? (c['cardId'] as String).trim()
                                    : '카드'));
                            final isSelected = cardId == _selectedCardId;
                            return ChoiceChip(
                              label: Text(cardName),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: const Color(0xFF74512D),
                              backgroundColor: const Color(0xFFF7F8FC),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF74512D)
                                    : const Color(0xFFE8ECF4),
                                width: isSelected ? 1.5 : 1,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1F1F28),
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedCardId = cardId),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      const Text('구매처 (선택)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedWhereToBuyId ?? '',
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black),
                        iconEnabledColor: Colors.black54,
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('선택 안 함',
                                style: TextStyle(color: Colors.black54)),
                          ),
                          ..._whereToBuys.map((w) => DropdownMenuItem<String>(
                                value: w['whereToBuyId'] as String,
                                child: Text(
                                  (w['name'] as String?) ??
                                      (w['whereToBuyId'] as String),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ))
                        ],
                        onChanged: (v) => setState(() => _selectedWhereToBuyId =
                            (v == null || v.isEmpty) ? null : v),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.black87, width: 1.5)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('결제 수단',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('신용'),
                            selected: _payType == '신용',
                            selectedColor: const Color(0xFF74512D),
                            labelStyle: TextStyle(
                                color: _payType == '신용'
                                    ? Colors.white
                                    : Colors.black87),
                            onSelected: (v) => setState(() => _payType = '신용'),
                          ),
                          ChoiceChip(
                            label: const Text('체크'),
                            selected: _payType == '체크',
                            selectedColor: const Color(0xFF74512D),
                            labelStyle: TextStyle(
                                color: _payType == '체크'
                                    ? Colors.white
                                    : Colors.black87),
                            onSelected: (v) => setState(() => _payType = '체크'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('구매일',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
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
                              items: _faceValueOptions.map((value) {
                                final formatted = value
                                    .toString()
                                    .replaceAllMapped(
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
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedFaceValue = value;
                                    _faceValueController.text =
                                        value.toString();
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: '액면가(원)',
                                filled: true,
                                fillColor: Colors.white,
                                enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.black26)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color(0xFF74512D), width: 2)),
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(color: Colors.black54),
                                floatingLabelStyle:
                                    TextStyle(color: Color(0xFF74512D)),
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
                                enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.black26)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color(0xFF74512D), width: 2)),
                                labelStyle: TextStyle(color: Colors.black54),
                                floatingLabelStyle:
                                    TextStyle(color: Color(0xFF74512D)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _buyUnitController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black),
                        cursorColor: const Color(0xFF74512D),
                        decoration: const InputDecoration(
                          labelText: '매입가(권당, 원)',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF74512D), width: 2)),
                          labelStyle: TextStyle(color: Colors.black54),
                          floatingLabelStyle:
                              TextStyle(color: Color(0xFF74512D)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black),
                        cursorColor: const Color(0xFF74512D),
                        decoration: const InputDecoration(
                          labelText: '할인율(%)',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF74512D), width: 2)),
                          labelStyle: TextStyle(color: Colors.black54),
                          floatingLabelStyle:
                              TextStyle(color: Color(0xFF74512D)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('합계: ${_totalBuy.toString()}원',
                            style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      const Text('메모',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _memoController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: const Color(0xFF74512D),
                        decoration: const InputDecoration(
                          hintText: '메모를 입력하세요',
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF74512D), width: 2)),
                          labelStyle: TextStyle(color: Colors.black54),
                          floatingLabelStyle:
                              TextStyle(color: Color(0xFF74512D)),
                          hintStyle: TextStyle(color: Colors.black38),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('수정',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('수정',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('삭제',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('저장',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
        ),
      ),
    );
  }
}
