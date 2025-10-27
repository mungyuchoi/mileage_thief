import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BranchStep2Page extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;
  final String detailAddress;

  const BranchStep2Page({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.detailAddress,
  });

  @override
  State<BranchStep2Page> createState() => _BranchStep2PageState();
}

class _BranchStep2PageState extends State<BranchStep2Page> {
  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noticeController = TextEditingController();

  final Map<String, bool> _dayOpen = {
    '월': false,
    '화': false,
    '수': false,
    '목': false,
    '금': false,
    '토': false,
    '일': false,
  };

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _branchIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isOpen) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF74512D)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _onSubmit() {
    setState(() { _error = null; });
    final id = _branchIdController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final idValid = RegExp(r'^[a-z0-9_]+$').hasMatch(id);
    if (id.isEmpty || !idValid) {
      setState(() { _error = 'branchId는 소문자/숫자/_(언더스코어)만 사용하세요.'; });
      return;
    }
    if (name.isEmpty) {
      setState(() { _error = '지점명을 입력하세요.'; });
      return;
    }
    if (phone.isEmpty) {
      setState(() { _error = '전화번호를 입력하세요.'; });
      return;
    }

    // 요일/시간 검증 및 openingHours 구성
    final bool anyDaySelected = _dayOpen.values.any((v) => v == true);
    if (!anyDaySelected) {
      setState(() { _error = '영업 요일을 선택하세요.'; });
      return;
    }
    if (_openTime == null || _closeTime == null) {
      setState(() { _error = '영업 시간을 선택하세요.'; });
      return;
    }
    final String timeRange = '${_formatTime(_openTime)}-${_formatTime(_closeTime)}';
    final bool mon = _dayOpen['월'] == true;
    final bool tue = _dayOpen['화'] == true;
    final bool wed = _dayOpen['수'] == true;
    final bool thu = _dayOpen['목'] == true;
    final bool fri = _dayOpen['금'] == true;
    final bool sat = _dayOpen['토'] == true;
    final bool sun = _dayOpen['일'] == true;

    final bool allWeekdays = mon && tue && wed && thu && fri;

    final Map<String, String> openingHours = {
      'monFri': allWeekdays ? timeRange : '휴무',
      'sat': sat ? timeRange : '휴무',
      'sun': sun ? timeRange : '휴무',
    };

    _saveToFirestore(
      branchId: id,
      name: name,
      phone: phone,
      openingHours: openingHours,
      notice: _noticeController.text.trim(),
    );
  }

  Future<void> _saveToFirestore({
    required String branchId,
    required String name,
    required String phone,
    required Map<String, String> openingHours,
    required String notice,
  }) async {
    if (_saving) return;
    setState(() { _saving = true; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final String fullAddress = (widget.detailAddress.trim().isEmpty)
          ? widget.address
          : '${widget.address} ${widget.detailAddress.trim()}';

      await FirebaseFirestore.instance.collection('branches').doc(branchId).set({
        'branchId': branchId,
        'name': name,
        'phone': phone,
        'openingHours': openingHours,
        'notice': notice.isEmpty ? null : notice,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'address': fullAddress,
        'createdByUid': uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Fluttertoast.showToast(msg: '지점이 저장되었습니다.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '저장 중 오류가 발생했습니다.'; });
      Fluttertoast.showToast(msg: '저장 실패: $e');
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
                  const SizedBox(width: 6),
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
              child: Text('상품권 지점의\n정보를 알려주세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
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
                        Text('branchId', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        SizedBox(width: 8),
                        Expanded(child: Text('(소문자, 숫자, _ 만 사용 가능)', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _branchIdController,
                      decoration: InputDecoration(
                        hintText: '예: gangnam_main',
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
                        Text('지점명', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '예: 강남점',
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
                        Text('전화번호', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '예: 031-123-1234',
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
                        Text('영업 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _dayOpen.keys.map((day) {
                        final selected = _dayOpen[day] == true;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(day),
                          selectedColor: const Color(0xFF74512D),
                          labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                          onSelected: (v) => setState(() => _dayOpen[day] = v),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickTime(true),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE6E6E9)),
                            ),
                            child: Text(_formatTime(_openTime), style: const TextStyle(color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('~'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickTime(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE6E6E9)),
                            ),
                            child: Text(_formatTime(_closeTime), style: const TextStyle(color: Colors.black87)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('안내사항 (선택)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noticeController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '지점 이용 안내를 입력하세요 (선택)',
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE6E6E9)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('이전', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF74512D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


