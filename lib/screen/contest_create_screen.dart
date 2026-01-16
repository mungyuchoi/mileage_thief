import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

/// 콘테스트를 생성/편집하는 관리자 전용 화면
/// 컬렉션: contests
class ContestCreateScreen extends StatefulWidget {
  final String? contestId; // 편집 모드일 때 사용
  
  const ContestCreateScreen({super.key, this.contestId});

  @override
  State<ContestCreateScreen> createState() => _ContestCreateScreenState();
}

class _ContestCreateScreenState extends State<ContestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _dateStart;
  DateTime? _dateEnd;
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contestId != null) {
      _loadContestData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadContestData() async {
    if (widget.contestId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = (data['title'] as String?) ?? '';
        _descriptionController.text = (data['description'] as String?) ?? '';
        
        final startTs = data['postingDateStart'] as Timestamp?;
        final endTs = data['postingDateEnd'] as Timestamp?;
        
        if (startTs != null) {
          _dateStart = startTs.toDate();
        }
        if (endTs != null) {
          _dateEnd = endTs.toDate();
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '콘테스트 정보를 불러오는 중 오류가 발생했습니다: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart 
          ? (_dateStart ?? DateTime.now())
          : (_dateEnd ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateStart = picked;
          // 시작일이 종료일보다 늦으면 종료일도 조정
          if (_dateEnd != null && _dateStart!.isAfter(_dateEnd!)) {
            _dateEnd = _dateStart!.add(const Duration(days: 7));
          }
        } else {
          _dateEnd = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final DateTime baseDate = isStart 
        ? (_dateStart ?? DateTime.now())
        : (_dateEnd ?? DateTime.now());
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate),
    );
    
    if (picked != null) {
      setState(() {
        final DateTime newDateTime = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          picked.hour,
          picked.minute,
        );
        if (isStart) {
          _dateStart = newDateTime;
        } else {
          _dateEnd = newDateTime;
        }
      });
    }
  }

  Future<void> _saveContest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateStart == null || _dateEnd == null) {
      Fluttertoast.showToast(
        msg: '시작일과 종료일을 모두 선택해주세요.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    if (_dateStart!.isAfter(_dateEnd!)) {
      Fluttertoast.showToast(
        msg: '시작일은 종료일보다 이전이어야 합니다.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String contestId = widget.contestId ?? 
          'contest_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      
      final Map<String, dynamic> data = {
        'contestId': contestId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'postingDateStart': Timestamp.fromDate(_dateStart!),
        'postingDateEnd': Timestamp.fromDate(_dateEnd!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.contestId == null) {
        // 생성 모드
        data['participantCount'] = 0;
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('contests')
            .doc(contestId)
            .set(data);
        
        if (mounted) {
          Fluttertoast.showToast(
            msg: '콘테스트가 생성되었습니다.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } else {
        // 편집 모드 - participantCount는 유지
        await FirebaseFirestore.instance
            .collection('contests')
            .doc(contestId)
            .update(data);
        
        if (mounted) {
          Fluttertoast.showToast(
            msg: '콘테스트가 수정되었습니다.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '콘테스트 생성 중 오류가 발생했습니다: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '선택 안 함';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contestId == null ? '콘테스트 생성' : '콘테스트 편집',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            )
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '콘테스트 제목',
                  hintText: '예: 2025년 상반기 최고의 상테크 꿀팁 콘테스트',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '콘테스트 설명',
                  hintText: 'HTML 형식으로 작성 가능합니다.',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '설명을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 시작일 선택
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '제출 시작일시',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, true),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_formatDateTime(_dateStart).split(' ')[0]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _dateStart == null
                                  ? null
                                  : () => _selectTime(context, true),
                              icon: const Icon(Icons.access_time),
                              label: Text(_dateStart == null
                                  ? '시간 선택'
                                  : _formatDateTime(_dateStart).split(' ')[1]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 종료일 선택
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '제출 종료일시',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, false),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_formatDateTime(_dateEnd).split(' ')[0]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _dateEnd == null
                                  ? null
                                  : () => _selectTime(context, false),
                              icon: const Icon(Icons.access_time),
                              label: Text(_dateEnd == null
                                  ? '시간 선택'
                                  : _formatDateTime(_dateEnd).split(' ')[1]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveContest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF74512D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.contestId == null ? '콘테스트 생성' : '콘테스트 수정',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
