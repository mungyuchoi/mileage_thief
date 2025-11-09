import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BranchEditScreen extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic> branchData;

  const BranchEditScreen({
    super.key,
    required this.branchId,
    required this.branchData,
  });

  @override
  State<BranchEditScreen> createState() => _BranchEditScreenState();
}

class _BranchEditScreenState extends State<BranchEditScreen> {
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

  // 각 요일별 시간 저장
  final Map<String, TimeOfDay?> _dayOpenTime = {
    '월': null,
    '화': null,
    '수': null,
    '목': null,
    '금': null,
    '토': null,
    '일': null,
  };

  final Map<String, TimeOfDay?> _dayCloseTime = {
    '월': null,
    '화': null,
    '수': null,
    '목': null,
    '금': null,
    '토': null,
    '일': null,
  };

  String? _error;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final data = widget.branchData;
      
      _branchIdController.text = widget.branchId;
      _nameController.text = (data['name'] as String?) ?? '';
      _phoneController.text = (data['phone'] as String?) ?? '';
      _noticeController.text = (data['notice'] as String?) ?? '';

      // openingHours 파싱
      final openingHours = data['openingHours'];
      if (openingHours is Map) {
        _parseOpeningHours(Map<String, dynamic>.from(openingHours));
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다.';
        _loading = false;
      });
    }
  }

  void _parseOpeningHours(Map<String, dynamic> openingHours) {
    final dayNames = {'mon': '월', 'tue': '화', 'wed': '수', 'thu': '목', 'fri': '금', 'sat': '토', 'sun': '일'};
    final dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    for (final entry in openingHours.entries) {
      final key = entry.key;
      final value = entry.value.toString();
      
      if (value == '휴무') continue;

      // 시간 파싱 (예: "09:00-19:00")
      final parts = value.split('-');
      if (parts.length != 2) continue;

      final openTimeStr = parts[0].trim();
      final closeTimeStr = parts[1].trim();

      final openTime = _parseTimeString(openTimeStr);
      final closeTime = _parseTimeString(closeTimeStr);

      if (openTime == null || closeTime == null) continue;

      // 키에 해당하는 요일들 찾기
      List<String> days = [];
      
      if (key == 'monFri') {
        days = ['mon', 'tue', 'wed', 'thu', 'fri'];
      } else if (key == 'monSat') {
        days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
      } else if (key == 'monSun') {
        days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      } else if (key.length == 6 && dayOrder.contains(key.substring(0, 3)) && dayOrder.contains(key.substring(3, 6))) {
        // 조합된 키 (예: tueWed)
        final startDay = key.substring(0, 3);
        final endDay = key.substring(3, 6);
        final startIdx = dayOrder.indexOf(startDay);
        final endIdx = dayOrder.indexOf(endDay);
        if (startIdx != -1 && endIdx != -1) {
          days = dayOrder.sublist(startIdx, endIdx + 1);
        }
      } else if (dayOrder.contains(key)) {
        // 단일 요일
        days = [key];
      }

      // 각 요일에 시간 설정
      for (final day in days) {
        final dayKr = dayNames[day];
        if (dayKr != null) {
          setState(() {
            _dayOpen[dayKr] = true;
            _dayOpenTime[dayKr] = openTime;
            _dayCloseTime[dayKr] = closeTime;
          });
        }
      }
    }
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _branchIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String day, bool isOpen) async {
    final now = TimeOfDay.now();
    final currentTime = isOpen 
        ? _dayOpenTime[day] ?? now
        : _dayCloseTime[day] ?? now;
    
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
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
          _dayOpenTime[day] = picked;
        } else {
          _dayCloseTime[day] = picked;
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

    // 각 요일별 시간 검증
    final Map<String, String> dayTimeMap = {};
    final dayNames = {'월': 'mon', '화': 'tue', '수': 'wed', '목': 'thu', '금': 'fri', '토': 'sat', '일': 'sun'};
    
    for (final day in _dayOpen.keys) {
      if (_dayOpen[day] == true) {
        final openTime = _dayOpenTime[day];
        final closeTime = _dayCloseTime[day];
        if (openTime == null || closeTime == null) {
          setState(() { _error = '${day}요일의 영업 시간을 선택하세요.'; });
          return;
        }
        final timeRange = '${_formatTime(openTime)}-${_formatTime(closeTime)}';
        dayTimeMap[dayNames[day]!] = timeRange;
      }
    }

    // 동일한 시간을 가진 요일들을 그룹화
    final Map<String, String> openingHours = {};
    final Map<String, List<String>> timeGroupMap = {};
    
    // 시간별로 요일 그룹화
    for (final entry in dayTimeMap.entries) {
      final time = entry.value;
      if (!timeGroupMap.containsKey(time)) {
        timeGroupMap[time] = [];
      }
      timeGroupMap[time]!.add(entry.key);
    }

    // 각 시간 그룹을 처리
    for (final entry in timeGroupMap.entries) {
      final time = entry.key;
      final days = List<String>.from(entry.value);
      
      if (days.isEmpty) continue;
      
      // 요일 순서 정의
      final dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      
      // 요일 순서대로 정렬
      days.sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));
      
      // 연속된 요일 그룹 찾기
      int i = 0;
      while (i < days.length) {
        int startIdx = dayOrder.indexOf(days[i]);
        int endIdx = startIdx;
        
        // 연속된 요일 찾기
        while (i + 1 < days.length) {
          final nextIdx = dayOrder.indexOf(days[i + 1]);
          if (nextIdx == endIdx + 1) {
            endIdx = nextIdx;
            i++;
          } else {
            break;
          }
        }
        
        // 그룹 키 생성
        final startDay = dayOrder[startIdx];
        final endDay = dayOrder[endIdx];
        String groupKey;
        
        if (startIdx == endIdx) {
          // 단일 요일
          groupKey = startDay;
        } else {
          // 연속된 요일 그룹
          if (startDay == 'mon' && endDay == 'fri') {
            groupKey = 'monFri';
          } else if (startDay == 'mon' && endDay == 'sat') {
            groupKey = 'monSat';
          } else if (startDay == 'mon' && endDay == 'sun') {
            groupKey = 'monSun';
          } else {
            groupKey = '$startDay$endDay';
          }
        }
        
        openingHours[groupKey] = time;
        i++;
      }
    }

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

      // 지점 정보 업데이트 (createdByUid도 현재 사용자로 업데이트)
      await FirebaseFirestore.instance.collection('branches').doc(branchId).set({
        'branchId': branchId,
        'name': name,
        'phone': phone,
        'openingHours': openingHours,
        'notice': notice.isEmpty ? null : notice,
        'createdByUid': uid, // 수정한 사용자의 UID로 업데이트
      }, SetOptions(merge: true));

      if (!mounted) return;
      Fluttertoast.showToast(msg: '지점이 수정되었습니다.');
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
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('지점 수정', style: TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Text('branchId', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                        SizedBox(width: 8),
                        Expanded(child: Text('(수정 불가)', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _branchIdController,
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: '예: gangnam_main',
                        filled: true,
                        fillColor: Colors.grey[100],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE6E6E9)),
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
                        Text('영업 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Text('필수', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._dayOpen.keys.map((day) {
                      final selected = _dayOpen[day] == true;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ChoiceChip(
                                selected: selected,
                                label: Text(day),
                                selectedColor: const Color(0xFF74512D),
                                labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                                onSelected: (v) => setState(() {
                                  _dayOpen[day] = v;
                                  if (!v) {
                                    _dayOpenTime[day] = null;
                                    _dayCloseTime[day] = null;
                                  }
                                }),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _pickTime(day, true),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE6E6E9)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    child: Text(
                                      _formatTime(_dayOpenTime[day]),
                                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('~', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _pickTime(day, false),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE6E6E9)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    child: Text(
                                      _formatTime(_dayCloseTime[day]),
                                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    const Text('안내사항 (선택)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noticeController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '지점 이용 안내를 입력하세요 (선택)',
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE6E6E9)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF74512D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('수정 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

