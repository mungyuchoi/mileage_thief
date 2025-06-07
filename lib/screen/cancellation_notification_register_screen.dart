import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_database/firebase_database.dart';
import '../custom/CustomDropdownButton2.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class CancellationNotificationRegisterScreen extends StatefulWidget {
  const CancellationNotificationRegisterScreen({super.key});

  @override
  State<CancellationNotificationRegisterScreen> createState() => _CancellationNotificationRegisterScreenState();
}

class _CancellationNotificationRegisterScreenState extends State<CancellationNotificationRegisterScreen> {
  // 공항 데이터
  List<String> airportItems = [];
  String? departureSelectedValue = "서울|인천-ICN";
  String? arrivalSelectedValue;
  bool _arrivalError = false;

  // 좌석등급 체크박스
  bool isEconomySelected = false;
  bool isBusinessSelected = false;
  bool isFirstSelected = false;

  // 달력 관련
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  // Firebase 참조
  final DatabaseReference _countryReference = FirebaseDatabase.instance.ref("COUNTRY_DAN");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 땅콩 계산 관련
  int totalPeanuts = 0;
  int userPeanutCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCountryFirebase();
    _loadUserPeanutCount();
  }

  void _loadCountryFirebase() {
    _countryReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        airportItems.clear();
        
        // 우선순위 목록
        List<String> priorityOrder = [
          "뉴욕",
          "발리",
          "파리", 
          "LA",
          "하와이",
          "시드니",
          "바르셀로나",
          "프랑크푸르트",
          "런던",
          "방콕",
          "호찌민",
          "싱가포르",
          "벤쿠버",
          "브리즈번",
          "샌프란시스코"
        ];
        
        // 모든 공항 데이터를 임시 리스트에 저장
        List<String> allAirports = [];
        values.forEach((key, value) {
          allAirports.add(key);
        });
        
        // 서울|인천-ICN 제거 (나중에 맨 앞에 추가)
        allAirports.remove("서울|인천-ICN");
        
        // 우선순위에 따라 정렬
        List<String> priorityAirports = [];
        List<String> remainingAirports = [...allAirports];
        
        // 우선순위 공항들을 먼저 추가
        for (String priority in priorityOrder) {
          for (String airport in allAirports) {
            if (airport.contains(priority)) {
              priorityAirports.add(airport);
              remainingAirports.remove(airport);
              break; // 첫 번째 매칭만 사용
            }
          }
        }
        
        // 최종 순서: 서울|인천-ICN + 우선순위 공항들 + 나머지 공항들
        airportItems.add("서울|인천-ICN");
        airportItems.addAll(priorityAirports);
        airportItems.addAll(remainingAirports);
        
        setState(() {});
      }
    });
  }

  void _loadUserPeanutCount() async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      try {
        // Firestore에서 사용자의 peanutCount 가져오기
        final userData = await UserService.getUserFromFirestore(currentUser.uid);
        setState(() {
          userPeanutCount = userData?['peanutCount'] ?? 0;
        });
      } catch (error) {
        print('Firestore에서 peanutCount 로드 오류: $error');
        // Firestore 실패 시 SharedPreferences를 fallback으로 사용
        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          userPeanutCount = prefs.getInt('counter') ?? 0;
        });
      }
    } else {
      // 로그인하지 않은 경우 SharedPreferences 사용
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        userPeanutCount = prefs.getInt('counter') ?? 0;
      });
    }
  }

  void _calculatePeanuts() {
    int seatClassCost = 0;
    if (isEconomySelected) seatClassCost += 1;
    if (isBusinessSelected) seatClassCost += 2;
    if (isFirstSelected) seatClassCost += 5;

    int days = 1; // 기본값
    if (_rangeStart != null && _rangeEnd != null) {
      days = _rangeEnd!.difference(_rangeStart!).inDays + 1;
    } else if (_rangeStart != null) {
      days = 1;
    }

    setState(() {
      totalPeanuts = seatClassCost * days;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_rangeStart, selectedDay)) {
      setState(() {
        _focusedDay = focusedDay;
        _rangeStart = selectedDay;
        _rangeEnd = null;
      });
      _calculatePeanuts();
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
    });
    _calculatePeanuts();
  }

  String _getDateRangeText() {
    if (_rangeStart == null) return "날짜를 선택해주세요";
    
    DateFormat formatter = DateFormat('yyyy.MM.dd');
    if (_rangeEnd == null) {
      return "${formatter.format(_rangeStart!)} (1일)";
    } else {
      int days = _rangeEnd!.difference(_rangeStart!).inDays + 1;
      return "${formatter.format(_rangeStart!)} ~ ${formatter.format(_rangeEnd!)} ($days일)";
    }
  }

  bool _isFormValid() {
    return departureSelectedValue != null &&
           arrivalSelectedValue != null &&
           departureSelectedValue != arrivalSelectedValue &&
           (isEconomySelected || isBusinessSelected || isFirstSelected) &&
           _rangeStart != null &&
           userPeanutCount >= totalPeanuts;
  }

  bool _hasEnoughPeanuts() {
    return userPeanutCount >= totalPeanuts;
  }

  String _getSelectedSeatClasses() {
    List<String> selectedClasses = [];
    if (isEconomySelected) selectedClasses.add("이코노미");
    if (isBusinessSelected) selectedClasses.add("비즈니스");
    if (isFirstSelected) selectedClasses.add("퍼스트");
    return selectedClasses.join(", ");
  }

  String _extractAirportCode(String airportString) {
    // "서울|인천-ICN" → "ICN" 형태로 추출
    final parts = airportString.split('-');
    if (parts.length > 1) {
      return parts.last;
    }
    return airportString;
  }

  List<String> _getSelectedSeatClassCodes() {
    List<String> codes = [];
    if (isEconomySelected) codes.add('E');
    if (isBusinessSelected) codes.add('B');
    if (isFirstSelected) codes.add('F');
    return codes;
  }

  String _createRouteKey(String from, String to, List<String> seatClasses) {
    return '${from}-${to}_${seatClasses.join('')}';
  }

  Future<void> _saveSubscriptionToFirestore() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final fromCode = _extractAirportCode(departureSelectedValue!);
      final toCode = _extractAirportCode(arrivalSelectedValue!);
      final seatClasses = _getSelectedSeatClassCodes();
      final subscriptionId = const Uuid().v4();

      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));

      // 1. cancel_subscriptions/{uid}/items/{docId} 저장
      final subscriptionData = {
        'from': fromCode,
        'to': toCode,
        'seatClasses': seatClasses,
        'startDate': Timestamp.fromDate(_rangeStart!),
        'endDate': Timestamp.fromDate(_rangeEnd ?? _rangeStart!),
        'expiresAt': expiresAt,
        'createdAt': now,
        'peanutUsed': totalPeanuts,
        'autoRenew': false,
        'notifiedDates': [],
      };

      await _firestore
          .collection('cancel_subscriptions')
          .doc(currentUser.uid)
          .collection('items')
          .doc(subscriptionId)
          .set(subscriptionData);

      // 2. popular_subscriptions/{route}_{classes} 업데이트
      final routeKey = _createRouteKey(fromCode, toCode, seatClasses);
      final popularRef = _firestore.collection('popular_subscriptions').doc(routeKey);

      await _firestore.runTransaction((transaction) async {
        final popularDoc = await transaction.get(popularRef);
        
        if (popularDoc.exists) {
          transaction.update(popularRef, {
            'count': FieldValue.increment(1),
            'lastUpdated': now,
          });
        } else {
          transaction.set(popularRef, {
            'count': 1,
            'lastUpdated': now,
          });
        }
      });

      // 3. 사용자 땅콩 개수 차감
      final newPeanutCount = userPeanutCount - totalPeanuts;
      await UserService.updatePeanutCount(currentUser.uid, newPeanutCount);

      print('구독 정보 저장 완료: $subscriptionId');
      
    } catch (e) {
      print('구독 정보 저장 오류: $e');
      rethrow;
    }
  }

  void _processSubscription() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00256B),
          ),
        ),
      );

      await _saveSubscriptionToFirestore();

      // 로딩 닫기
      Navigator.of(context).pop();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('취소표 알림이 등록되었습니다! (땅콩 $totalPeanuts개 소모)'),
          backgroundColor: const Color(0xFF00256B),
        ),
      );

      // 페이지 닫기
      Navigator.pop(context);

    } catch (e) {
      // 로딩 닫기
      Navigator.of(context).pop();

      // 에러 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구독 등록 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '취소표 알림 구독 확인',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '다음 조건으로 취소표 알림을 구독하시겠습니까?',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _buildConfirmationRow('구간', '$departureSelectedValue → $arrivalSelectedValue'),
              const SizedBox(height: 8),
              _buildConfirmationRow('좌석등급', _getSelectedSeatClasses()),
              const SizedBox(height: 8),
              _buildConfirmationRow('알림기간', _getDateRangeText()),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00256B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(
                      '소모될 땅콩: $totalPeanuts개',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00256B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '구독 후 보유 땅콩: ${userPeanutCount - totalPeanuts}개',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processSubscription();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00256B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('취소표 알림 등록'),
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 출발지/도착지 선택
            const Text(
              '구간 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomDropdownButton2(
                    hint: '출발지',
                    dropdownWidth: 180,
                    dropdownItems: airportItems,
                    hintAlignment: Alignment.center,
                    value: departureSelectedValue,
                    scrollbarAlwaysShow: true,
                    scrollbarThickness: 10,
                    onChanged: (value) {
                      setState(() {
                        departureSelectedValue = value;
                        _calculatePeanuts();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.loop_sharp, color: Colors.black54),
                  onPressed: () {
                    setState(() {
                      var tempValue = departureSelectedValue;
                      departureSelectedValue = arrivalSelectedValue;
                      arrivalSelectedValue = tempValue;
                      _arrivalError = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomDropdownButton2(
                        hint: '도착지',
                        dropdownWidth: 180,
                        hintAlignment: Alignment.center,
                        dropdownItems: airportItems,
                        value: arrivalSelectedValue,
                        scrollbarAlwaysShow: true,
                        scrollbarThickness: 10,
                        onChanged: (value) {
                          setState(() {
                            arrivalSelectedValue = value;
                            _arrivalError = false;
                            _calculatePeanuts();
                          });
                        },
                      ),
                      if (_arrivalError)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0, top: 4.0),
                          child: Text(
                            '출발지와 도착지가 같을 수 없습니다.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 좌석등급 선택
            Row(
              children: [
                const Text(
                  '좌석등급 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Text(
                  '(반드시 1개 이상 선택 필수)',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Row(
                      children: [
                        const Text('이코노미 ('),
                        Image.asset(
                          'asset/img/peanut.png',
                          width: 16,
                          height: 16,
                        ),
                        const Text(' 1개)'),
                      ],
                    ),
                    value: isEconomySelected,
                    onChanged: (bool? value) {
                      setState(() {
                        isEconomySelected = value ?? false;
                        _calculatePeanuts();
                      });
                    },
                    activeColor: const Color(0xFF00256B),
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        const Text('비즈니스 ('),
                        Image.asset(
                          'asset/img/peanuts.png',
                          width: 16,
                          height: 16,
                        ),
                        const Text(' 2개)'),
                      ],
                    ),
                    value: isBusinessSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        isBusinessSelected = value ?? false;
                        _calculatePeanuts();
                      });
                    },
                    activeColor: const Color(0xFF00256B),
                  ),
                  CheckboxListTile(
                    title: Row(
                      children: [
                        const Text('퍼스트 ('),
                        Image.asset(
                          'asset/img/peanuts.png',
                          width: 16,
                          height: 16,
                        ),
                        const Text(' 5개)'),
                      ],
                    ),
                    value: isFirstSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        isFirstSelected = value ?? false;
                        _calculatePeanuts();
                      });
                    },
                    activeColor: const Color(0xFF00256B),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 날짜 선택
            const Text(
              '알림 기간 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _getDateRangeText(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  TableCalendar<DateTime>(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    rangeSelectionMode: _rangeSelectionMode,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    rangeStartDay: _rangeStart,
                    rangeEndDay: _rangeEnd,
                    locale: 'ko_KR',
                    onDaySelected: _onDaySelected,
                    onRangeSelected: _onRangeSelected,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: false,
                      rangeHighlightColor: Color(0x8000256B),
                      rangeStartDecoration: BoxDecoration(
                        color: Color(0xFF00256B),
                        shape: BoxShape.circle,
                      ),
                      rangeEndDecoration: BoxDecoration(
                        color: Color(0xFF00256B),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF00256B),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Color(0x8000256B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 땅콩 소모량 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00256B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '보유 땅콩',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$userPeanutCount개',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00256B),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '필요한 땅콩',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalPeanuts개',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _hasEnoughPeanuts() ? const Color(0xFF00256B) : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_hasEnoughPeanuts() && totalPeanuts > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        '땅콩이 ${totalPeanuts - userPeanutCount}개 부족합니다',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_hasEnoughPeanuts() && totalPeanuts > 0)
                    const Text(
                      '기본 7일간 알림이 제공됩니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 구독하기 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isFormValid() ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00256B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '구독하기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
} 