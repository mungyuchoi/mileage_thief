import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CardStepPage extends StatefulWidget {
  const CardStepPage({super.key});

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

    final cardId = _cardIdController.text.trim();
    final name = _nameController.text.trim();
    final credit = _parseInt(_creditPerMileController.text.trim());
    final check = _parseInt(_checkPerMileController.text.trim());

    if (cardId.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(cardId)) {
      setState(() { _error = 'cardId는 소문자/숫자/_ 만 사용하세요.'; });
      return;
    }
    if (name.isEmpty) {
      setState(() { _error = '카드(사) 이름을 입력하세요.'; });
      return;
    }
    if (credit == null || credit <= 0) {
      setState(() { _error = '신용카드 1마일당 원가를 정수로 입력하세요.'; });
      return;
    }
    if (check == null || check <= 0) {
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
        'creditPerMileKRW': credit,
        'checkPerMileKRW': check,
        'memo': _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
                    Row(
                      children: const [
                        Text('신용카드: 1마일 원가(원)', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _creditPerMileController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 1000',
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
                        Text('체크카드: 1마일 원가(원)', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _checkPerMileController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 1500',
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


