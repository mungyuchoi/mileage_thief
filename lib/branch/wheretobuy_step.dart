import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WhereToBuyStepPage extends StatefulWidget {
  final String? editWhereToBuyId;
  const WhereToBuyStepPage({super.key, this.editWhereToBuyId});

  @override
  State<WhereToBuyStepPage> createState() => _WhereToBuyStepPageState();
}

class _WhereToBuyStepPageState extends State<WhereToBuyStepPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String? _error;
  bool _saving = false;
  bool get _isEdit => widget.editWhereToBuyId != null;

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
    final id = widget.editWhereToBuyId!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('where_to_buy')
        .doc(id)
        .get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _idController.text = id;
      _nameController.text = (data['name'] as String?) ?? '';
      _memoController.text = (data['memo'] as String?) ?? '';
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() {
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    final whereToBuyId = _isEdit ? widget.editWhereToBuyId! : _idController.text.trim();
    final name = _nameController.text.trim();

    if (whereToBuyId.isEmpty || (!_isEdit && !RegExp(r'^[a-z0-9_]+$').hasMatch(whereToBuyId))) {
      setState(() {
        _error = 'whereToBuyId는 소문자/숫자/_ 만 사용하세요.';
      });
      return;
    }
    if (name.isEmpty) {
      setState(() {
        _error = '구매처 이름을 입력하세요.';
      });
      return;
    }

    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('where_to_buy')
          .doc(whereToBuyId)
          .set({
        'name': name,
        'memo': _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Fluttertoast.showToast(msg: '구매처가 저장되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
      setState(() {
        _error = '저장 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
        title: Text(_isEdit ? '구매처 수정' : '구매처 생성', style: const TextStyle(color: Colors.black, fontSize: 16)),
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
              child: Text('구매처 정보를\n입력해주세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
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
                        Text('whereToBuyId', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('(소문자, 숫자, _ 만 사용 가능)', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _idController,
                      readOnly: _isEdit,
                      decoration: InputDecoration(
                        hintText: '예: thingsharp',
                        filled: true,
                        fillColor: Colors.white,
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
                        Text('구매처 이름', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '예: 지마켓/띵샵/삼카쇼',
                        filled: true,
                        fillColor: Colors.white,
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
                        filled: true,
                        fillColor: Colors.white,
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


