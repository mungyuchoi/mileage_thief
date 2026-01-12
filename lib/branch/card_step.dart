import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CardStepPage extends StatefulWidget {
  final String? editCardId;
  const CardStepPage({super.key, this.editCardId});

  @override
  State<CardStepPage> createState() => _CardStepPageState();
}

class _CardStepPageState extends State<CardStepPage> {
  final TextEditingController _cardIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _creditPerMileController = TextEditingController();
  final TextEditingController _checkPerMileController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String? _error;
  bool _saving = false;
  String? _cardType; // 'credit' 또는 'check'
  bool get _isEdit => widget.editCardId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final id = widget.editCardId!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).collection('cards').doc(id).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final creditValue = (data['creditPerMileKRW'] as num?)?.toInt() ?? 0;
    final checkValue = (data['checkPerMileKRW'] as num?)?.toInt() ?? 0;
    setState(() {
      _cardIdController.text = id;
      _nameController.text = (data['name'] as String?) ?? '';
      _creditPerMileController.text = creditValue.toString();
      _checkPerMileController.text = checkValue.toString();
      _memoController.text = (data['memo'] as String?) ?? '';
      // 기존 데이터가 있으면 둘 중 값이 있는 것을 선택, 둘 다 있으면 신용카드 기본 선택
      if (creditValue > 0 && checkValue > 0) {
        _cardType = 'credit'; // 기본값
      } else if (creditValue > 0) {
        _cardType = 'credit';
      } else if (checkValue > 0) {
        _cardType = 'check';
      }
    });
  }

  @override
  void dispose() {
    _cardIdController.dispose();
    _nameController.dispose();
    _creditPerMileController.dispose();
    _checkPerMileController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  int? _parseInt(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    try {
      return int.parse(digits);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onSubmit() async {
    setState(() { _error = null; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final cardId = (_isEdit ? widget.editCardId! : _cardIdController.text.trim());
    final name = _nameController.text.trim();
    final credit = _parseInt(_creditPerMileController.text.trim());
    final check = _parseInt(_checkPerMileController.text.trim());

    if (cardId.isEmpty || !_isEdit && !RegExp(r'^[a-z0-9_]+$').hasMatch(cardId)) {
      setState(() { _error = 'cardId는 소문자/숫자/_ 만 사용하세요.'; });
      return;
    }
    if (name.isEmpty) {
      setState(() { _error = '카드(사) 이름을 입력하세요.'; });
      return;
    }
    if (_cardType == null) {
      setState(() { _error = '카드 타입을 선택하세요.'; });
      return;
    }
    if (_cardType == 'credit' && (credit == null || credit <= 0)) {
      setState(() { _error = '신용카드 1마일당 원가를 정수로 입력하세요.'; });
      return;
    }
    if (_cardType == 'check' && (check == null || check <= 0)) {
      setState(() { _error = '체크카드 1마일당 원가를 정수로 입력하세요.'; });
      return;
    }

    if (_saving) return;
    setState(() { _saving = true; });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc(cardId)
          .set({
        'name': name,
        'creditPerMileKRW': _cardType == 'credit' ? credit : 0,
        'checkPerMileKRW': _cardType == 'check' ? check : 0,
        'memo': _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 사용자 문서에 hasGift 필드가 없으면 true로 세팅 (있으면 패스)
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final snap = await userRef.get();
        final Map<String, dynamic>? userData = snap.data() as Map<String, dynamic>?;
        final bool hasField = userData != null && userData.containsKey('hasGift');
        if (!hasField) {
          await userRef.set({
            'hasGift': true,
          }, SetOptions(merge: true));
        }
      } catch (_) {}

      Fluttertoast.showToast(msg: '카드가 저장되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
      setState(() { _error = '저장 중 오류가 발생했습니다.'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(_isEdit ? '카드 수정' : '카드 생성', style: const TextStyle(color: Colors.black, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFF74512D), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('카드 정보를\n입력해주세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('cardId', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        SizedBox(width: 8),
                        Expanded(child: Text('(소문자, 숫자, _ 만 사용 가능)', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cardIdController,
                      readOnly: _isEdit,
                      decoration: InputDecoration(
                        hintText: '예: lotte_basic',
                        filled: true, fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Text('카드/카드사 이름', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '예: 롯데',
                        filled: true, fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text('카드 타입', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('신용카드'),
                            value: 'credit',
                            groupValue: _cardType,
                            activeColor: const Color(0xFF74512D),
                            onChanged: (String? value) {
                              setState(() {
                                _cardType = value;
                                if (value == 'check') {
                                  _creditPerMileController.clear();
                                } else if (value == 'credit') {
                                  _checkPerMileController.clear();
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('체크카드'),
                            value: 'check',
                            groupValue: _cardType,
                            activeColor: const Color(0xFF74512D),
                            onChanged: (String? value) {
                              setState(() {
                                _cardType = value;
                                if (value == 'check') {
                                  _creditPerMileController.clear();
                                } else if (value == 'credit') {
                                  _checkPerMileController.clear();
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '신용카드: 1마일 원가(원)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _cardType == 'credit' ? Colors.black : Colors.black54,
                          ),
                        ),
                        if (_cardType == 'credit') ...[
                          const SizedBox(width: 4),
                          const Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ] else if (_cardType == 'check') ...[
                          const SizedBox(width: 4),
                          const Text('선택', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _creditPerMileController,
                      enabled: _cardType != 'check',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 1000',
                        filled: true,
                        fillColor: _cardType == 'check' ? Colors.grey[100] : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '체크카드: 1마일 원가(원)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _cardType == 'check' ? Colors.black : Colors.black54,
                          ),
                        ),
                        if (_cardType == 'check') ...[
                          const SizedBox(width: 4),
                          const Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ] else if (_cardType == 'credit') ...[
                          const SizedBox(width: 4),
                          const Text('선택', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _checkPerMileController,
                      enabled: _cardType != 'credit',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 1500',
                        filled: true,
                        fillColor: _cardType == 'credit' ? Colors.grey[100] : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('메모 (선택)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _memoController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '메모를 입력하세요 (선택)',
                        filled: true, fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF74512D), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('저장', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


