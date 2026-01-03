import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/deal_notification_service.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../utils/deal_image_utils.dart';
import 'widgets/city_selection_modal.dart';
import 'widgets/departure_airport_modal.dart';
import 'widgets/step_indicator.dart';

class DealNotificationRegisterScreen extends StatefulWidget {
  const DealNotificationRegisterScreen({super.key});

  @override
  State<DealNotificationRegisterScreen> createState() => _DealNotificationRegisterScreenState();
}

class _DealNotificationRegisterScreenState extends State<DealNotificationRegisterScreen> {
  int _currentStep = 1;
  final int _totalSteps = 4;

  // Step 1: 출발지
  String? _selectedOriginAirport;
  bool _isAllOriginAirports = false;

  // Step 2: 도착지
  List<String> _selectedAirports = [];
  List<String> _selectedCountries = [];
  String _selectedRegion = '';

  // Step 3: 가격
  final TextEditingController _priceController = TextEditingController();
  int? _maxPrice;

  // Step 4: 기간
  int _selectedDays = 7;

  // 땅콩 관련
  int _userPeanutCount = 0;

  // 지역별 도시 데이터 (CitySelectionModal과 동일)
  final Map<String, List<Map<String, dynamic>>> _citiesByRegion = {
    '일본': [
      {'code': 'JP', 'city': '나가사키', 'airport': 'NGS', 'country': '일본'},
      {'code': 'JP', 'city': '후쿠오카', 'airport': 'FUK', 'country': '일본'},
      {'code': 'JP', 'city': '오사카(간사이)', 'airport': 'KIX', 'country': '일본'},
      {'code': 'JP', 'city': '나고야', 'airport': 'NGO', 'country': '일본'},
      {'code': 'JP', 'city': '도쿄(나리타)', 'airport': 'NRT', 'country': '일본'},
      {'code': 'JP', 'city': '도쿄(하네다)', 'airport': 'HND', 'country': '일본'},
      {'code': 'JP', 'city': '쿠마모토', 'airport': 'KMJ', 'country': '일본'},
      {'code': 'JP', 'city': '삿포로(치토세)', 'airport': 'CTS', 'country': '일본'},
      {'code': 'JP', 'city': '마츠야마', 'airport': 'MYJ', 'country': '일본'},
      {'code': 'JP', 'city': '오키나와', 'airport': 'OKA', 'country': '일본'},
      {'code': 'JP', 'city': '가고시마', 'airport': 'KOJ', 'country': '일본'},
      {'code': 'JP', 'city': '우베', 'airport': 'UBJ', 'country': '일본'},
      {'code': 'JP', 'city': '사가', 'airport': 'HSG', 'country': '일본'},
      {'code': 'JP', 'city': '시즈오카', 'airport': 'FSZ', 'country': '일본'},
      {'code': 'JP', 'city': '다카마쓰', 'airport': 'TAK', 'country': '일본'},
    ],
    '아시아': [
      {'code': 'TH', 'city': '방콕(돈무앙)', 'airport': 'DMK', 'country': '태국'},
      {'code': 'TH', 'city': '방콕(수완나폼)', 'airport': 'BKK', 'country': '태국'},
      {'code': 'TH', 'city': '치앙마이', 'airport': 'CNX', 'country': '태국'},
      {'code': 'TH', 'city': '푸켓', 'airport': 'HKT', 'country': '태국'},
      {'code': 'PH', 'city': '세부', 'airport': 'CEB', 'country': '필리핀'},
      {'code': 'PH', 'city': '마닐라', 'airport': 'MNL', 'country': '필리핀'},
      {'code': 'PH', 'city': '칼리보(보라카이)', 'airport': 'KLO', 'country': '필리핀'},
      {'code': 'PH', 'city': '클락', 'airport': 'CRK', 'country': '필리핀'},
      {'code': 'PH', 'city': '보홀', 'airport': 'TAG', 'country': '필리핀'},
      {'code': 'VN', 'city': '다낭', 'airport': 'DAD', 'country': '베트남'},
      {'code': 'VN', 'city': '하노이', 'airport': 'HAN', 'country': '베트남'},
      {'code': 'VN', 'city': '호치민', 'airport': 'SGN', 'country': '베트남'},
      {'code': 'VN', 'city': '나트랑(깜랑)', 'airport': 'CXR', 'country': '베트남'},
      {'code': 'VN', 'city': '푸꾸옥', 'airport': 'PQC', 'country': '베트남'},
      {'code': 'MY', 'city': '쿠알라룸푸르', 'airport': 'KUL', 'country': '말레이시아'},
      {'code': 'MY', 'city': '코타키나발루', 'airport': 'BKI', 'country': '말레이시아'},
      {'code': 'ID', 'city': '발리(덴파사)', 'airport': 'DPS', 'country': '인도네시아'},
      {'code': 'ID', 'city': '마나도', 'airport': 'MDC', 'country': '인도네시아'},
      {'code': 'ID', 'city': '바탐', 'airport': 'BTH', 'country': '인도네시아'},
      {'code': 'SG', 'city': '싱가포르(창이공항)', 'airport': 'SIN', 'country': '싱가포르'},
      {'code': 'HK', 'city': '홍콩', 'airport': 'HKG', 'country': '홍콩'},
      {'code': 'TW', 'city': '대만(타이페이)', 'airport': 'TPE', 'country': '대만'},
      {'code': 'BN', 'city': '반다르세리베가완(브루나이)', 'airport': 'BWN', 'country': '브루나이'},
    ],
    '중국': [
      {'code': 'CN', 'city': '제남', 'airport': 'TNA', 'country': '중국'},
      {'code': 'TW', 'city': '가오슝', 'airport': 'KHH', 'country': '대만'},
      {'code': 'CN', 'city': '상해(푸동)', 'airport': 'PVG', 'country': '중국'},
      {'code': 'TW', 'city': '송산', 'airport': 'TSA', 'country': '대만'},
      {'code': 'CN', 'city': '청도', 'airport': 'TAO', 'country': '중국'},
      {'code': 'TW', 'city': '타이중', 'airport': 'RMQ', 'country': '대만'},
      {'code': 'TW', 'city': '타이페이', 'airport': 'TPE', 'country': '대만'},
      {'code': 'CN', 'city': '하문', 'airport': 'XMN', 'country': '중국'},
      {'code': 'HK', 'city': '홍콩', 'airport': 'HKG', 'country': '홍콩'},
      {'code': 'MO', 'city': '마카오', 'airport': 'MFM', 'country': '마카오'},
    ],
    '남태평양': [
      {'code': 'AU', 'city': '시드니', 'airport': 'SYD', 'country': '호주'},
      {'code': 'AU', 'city': '브리즈번', 'airport': 'BNE', 'country': '호주'},
      {'code': 'GU', 'city': '괌', 'airport': 'GUM', 'country': '괌'},
      {'code': 'MP', 'city': '사이판', 'airport': 'SPN', 'country': '사이판'},
    ],
    '유럽': [
      {'code': 'IT', 'city': '로마(레오나르도다빈치)', 'airport': 'FCO', 'country': '이탈리아'},
      {'code': 'PT', 'city': '리스본', 'airport': 'LIS', 'country': '포르투갈'},
      {'code': 'IT', 'city': '밀라노(말펜사)', 'airport': 'MXP', 'country': '이탈리아'},
      {'code': 'ES', 'city': '바르셀로나', 'airport': 'BCN', 'country': '스페인'},
      {'code': 'GR', 'city': '아테네', 'airport': 'ATH', 'country': '그리스'},
      {'code': 'TR', 'city': '이스탄불', 'airport': 'IST', 'country': '터키'},
      {'code': 'CH', 'city': '취리히', 'airport': 'ZRH', 'country': '스위스'},
      {'code': 'DK', 'city': '코펜하겐', 'airport': 'CPH', 'country': '덴마크'},
      {'code': 'DE', 'city': '프랑크푸르트', 'airport': 'FRA', 'country': '독일'},
      {'code': 'FI', 'city': '헬싱키', 'airport': 'HEL', 'country': '핀란드'},
      {'code': 'GB', 'city': '런던', 'airport': 'LHR', 'country': '영국'},
      {'code': 'FR', 'city': '파리', 'airport': 'CDG', 'country': '프랑스'},
      {'code': 'ES', 'city': '마드리드', 'airport': 'MAD', 'country': '스페인'},
    ],
    '중동/아프리카': [
      {'code': 'AE', 'city': '두바이', 'airport': 'DXB', 'country': 'UAE'},
      {'code': 'AE', 'city': '아부다비', 'airport': 'AUH', 'country': 'UAE'},
      {'code': 'EG', 'city': '카이로', 'airport': 'CAI', 'country': '이집트'},
      {'code': 'MA', 'city': '카사블랑카', 'airport': 'CMN', 'country': '모로코'},
    ],
    '아메리카': [
      {'code': 'US', 'city': '뉴욕', 'airport': 'JFK', 'country': '미국'},
      {'code': 'US', 'city': '로스앤젤레스', 'airport': 'LAX', 'country': '미국'},
      {'code': 'US', 'city': '하와이', 'airport': 'HNL', 'country': '미국'},
      {'code': 'AM', 'city': '예레반', 'airport': 'EVN', 'country': '아르메니아'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadUserPeanutCount();
    _priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPeanutCount() async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      try {
        final userData = await UserService.getUserFromFirestoreWithLimit(currentUser.uid);
        setState(() {
          _userPeanutCount = userData?['peanutCount'] ?? 0;
        });
      } catch (e) {
        print('땅콩 개수 로드 오류: $e');
      }
    }
  }

  void _onPriceChanged() {
    final text = _priceController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isNotEmpty) {
      setState(() {
        _maxPrice = int.tryParse(text);
      });
    } else {
      setState(() {
        _maxPrice = null;
      });
    }
  }

  int _calculatePeanuts() {
    return DealNotificationService.calculatePeanuts(
      airportCount: _selectedAirports.length,
      days: _selectedDays,
      hasOriginAirport: !_isAllOriginAirports && _selectedOriginAirport != null,
      isAllOriginAirports: _isAllOriginAirports,
      hasPrice: _maxPrice != null && _maxPrice! > 0,
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 1:
        return true; // 출발지는 선택사항
      case 2:
        return _selectedAirports.isNotEmpty;
      case 3:
        return _maxPrice != null && _maxPrice! > 0;
      case 4:
        return _calculatePeanuts() <= _userPeanutCount;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_canProceedToNextStep() && _currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showOriginAirportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepartureAirportModal(
        selectedAirport: _selectedOriginAirport,
        onSelect: (airport) {
          setState(() {
            _selectedOriginAirport = airport;
            _isAllOriginAirports = false;
          });
        },
      ),
    );
  }

  void _showCitySelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CitySelectionModal(
        selectedCities: _selectedAirports,
        onConfirm: (airports) {
          setState(() {
            _selectedAirports = airports;
            // 국가 코드 추출
            _selectedCountries = [];
            for (final airport in airports) {
              for (final region in _citiesByRegion.values) {
                for (final city in region) {
                  if (city['airport'] == airport) {
                    final countryCode = city['code'] as String;
                    if (!_selectedCountries.contains(countryCode)) {
                      _selectedCountries.add(countryCode);
                    }
                    break;
                  }
                }
              }
            }
            // 대표 지역 찾기
            _selectedRegion = DealNotificationService.getMainRegion(
              airports,
              _citiesByRegion,
            );
          });
        },
      ),
    );
  }

  Future<void> _registerNotification() async {
    if (!_canProceedToNextStep()) {
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: ColorConstants.milecatchBrown,
          ),
        ),
      );

      final peanutUsed = _calculatePeanuts();

      await DealNotificationService.saveDealSubscription(
        uid: currentUser.uid,
        originAirport: _isAllOriginAirports ? null : _selectedOriginAirport,
        airports: _selectedAirports,
        countries: _selectedCountries,
        region: _selectedRegion,
        maxPrice: _maxPrice!,
        days: _selectedDays,
        peanutUsed: peanutUsed,
      );

      // 로딩 닫기
      Navigator.of(context).pop();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('특가 알림이 등록되었습니다! (땅콩 $peanutUsed개 소모)'),
          backgroundColor: ColorConstants.milecatchBrown,
        ),
      );

      // 페이지 닫기
      Navigator.of(context).pop();
    } catch (e) {
      // 로딩 닫기
      Navigator.of(context).pop();

      // 에러 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('등록 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '출발지 선택 (선택사항)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '출발지를 선택하지 않으면 모든 출발지에서 특가를 알림받습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          // 모든 출발지 선택
          InkWell(
            onTap: () {
              setState(() {
                _isAllOriginAirports = true;
                _selectedOriginAirport = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isAllOriginAirports
                      ? ColorConstants.milecatchBrown
                      : Colors.grey[300]!,
                  width: _isAllOriginAirports ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAllOriginAirports
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _isAllOriginAirports
                        ? ColorConstants.milecatchBrown
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '모든 출발지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 특정 출발지 선택
          InkWell(
            onTap: _showOriginAirportModal,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: !_isAllOriginAirports && _selectedOriginAirport != null
                      ? ColorConstants.milecatchBrown
                      : Colors.grey[300]!,
                  width: !_isAllOriginAirports && _selectedOriginAirport != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_isAllOriginAirports && _selectedOriginAirport != null
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: !_isAllOriginAirports && _selectedOriginAirport != null
                        ? ColorConstants.milecatchBrown
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedOriginAirport == null
                          ? '출발지 선택'
                          : _getAirportName(_selectedOriginAirport!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedOriginAirport == null
                            ? Colors.grey[600]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '도착지 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '알림을 받을 도착지를 선택하세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _showCitySelectionModal,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedAirports.isNotEmpty
                      ? ColorConstants.milecatchBrown
                      : Colors.grey[300]!,
                  width: _selectedAirports.isNotEmpty ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: _selectedAirports.isNotEmpty
                        ? ColorConstants.milecatchBrown
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedAirports.isEmpty
                          ? '도착지 검색...'
                          : '${_selectedAirports.length}개 도시 선택됨',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedAirports.isEmpty
                            ? Colors.grey[500]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (_selectedAirports.isNotEmpty)
                    Text(
                      _selectedRegion,
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorConstants.milecatchBrown,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (_selectedAirports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAirports.map((airport) {
                final cityData = _findCityData(airport);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ColorConstants.milecatchBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ColorConstants.milecatchBrown),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DealImageUtils.getCountryFlag(
                        cityData?['code'] ?? '',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cityData?['city'] ?? airport,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColorConstants.milecatchBrown,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가격 조건 설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이 가격 이하일 때 알림을 받습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '최대 가격 (원)',
              hintText: '예: 700000',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: ColorConstants.milecatchBrown,
                  width: 2,
                ),
              ),
            ),
          ),
          if (_maxPrice != null && _maxPrice! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorConstants.milecatchBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ColorConstants.milecatchBrown,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${NumberFormat('#,###').format(_maxPrice)}원 이하의 특가를 알림받습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorConstants.milecatchBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '알림 기간 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '알림을 받을 기간을 선택하세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildPeriodButton(7, '7일'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPeriodButton(14, '14일'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPeriodButton(30, '30일'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '만료일: ${DateFormat('yyyy.MM.dd').format(DateTime.now().add(Duration(days: _selectedDays)))}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(int days, String label) {
    final isSelected = _selectedDays == days;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDays = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? ColorConstants.milecatchBrown
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? ColorConstants.milecatchBrown
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // 현재 단계에서 추가되는 땅콩 계산
    int currentStepPeanuts = 0;
    
    // Step 1: 출발지 선택
    if (_currentStep == 1) {
      if (_isAllOriginAirports) {
        currentStepPeanuts = 20;
      } else if (_selectedOriginAirport != null) {
        currentStepPeanuts = 1;
      }
    }
    
    // Step 2: 도착지 선택
    if (_currentStep == 2) {
      currentStepPeanuts = _selectedAirports.length * 5;
    }
    
    // Step 3: 가격 설정
    if (_currentStep == 3) {
      if (_maxPrice != null && _maxPrice! > 0) {
        currentStepPeanuts = 10;
      }
    }
    
    // Step 4: 기간 선택
    if (_currentStep == 4) {
      if (_selectedDays == 7) {
        currentStepPeanuts = 10;
      } else if (_selectedDays == 14) {
        currentStepPeanuts = 15;
      } else {
        currentStepPeanuts = 20;
      }
    }
    
    // 전체 누적 합계 계산
    int totalPeanuts = 0;
    
    // Step 1: 출발지 선택
    if (_currentStep >= 1) {
      if (_isAllOriginAirports) {
        totalPeanuts += 20;
      } else if (_selectedOriginAirport != null) {
        totalPeanuts += 1;
      }
    }
    
    // Step 2: 도착지 선택
    if (_currentStep >= 2) {
      totalPeanuts += _selectedAirports.length * 5;
    }
    
    // Step 3: 가격 설정
    if (_currentStep >= 3) {
      if (_maxPrice != null && _maxPrice! > 0) {
        totalPeanuts += 10;
      }
    }
    
    // Step 4: 기간 선택
    if (_currentStep >= 4) {
      if (_selectedDays == 7) {
        totalPeanuts += 10;
      } else if (_selectedDays == 14) {
        totalPeanuts += 15;
      } else {
        totalPeanuts += 20;
      }
    }
    
    final canProceed = _canProceedToNextStep();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 땅콩 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '소모 땅콩: $currentStepPeanuts개',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: totalPeanuts > _userPeanutCount
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                    if (totalPeanuts > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '합계: $totalPeanuts개',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '보유 땅콩: $_userPeanutCount개',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (totalPeanuts > _userPeanutCount) ...[
              const SizedBox(height: 8),
              Text(
                '땅콩이 부족합니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 버튼
            Row(
              children: [
                if (_currentStep > 1)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorConstants.milecatchBrown),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '이전',
                        style: TextStyle(
                          color: ColorConstants.milecatchBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 1) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: canProceed
                        ? (_currentStep == _totalSteps
                            ? _registerNotification
                            : _nextStep)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.milecatchBrown,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentStep == _totalSteps ? '등록하기' : '다음',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _findCityData(String airportCode) {
    for (final cities in _citiesByRegion.values) {
      for (final city in cities) {
        if (city['airport'] == airportCode) {
          return city;
        }
      }
    }
    return null;
  }

  String _getAirportName(String code) {
    final airports = {
      'ICN': '인천국제공항',
      'GMP': '김포국제공항',
      'PUS': '김해국제공항',
      'CJU': '제주국제공항',
      'TAE': '대구국제공항',
      'CJJ': '청주국제공항',
    };
    return airports[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('특가 알림 등록'),
        backgroundColor: ColorConstants.milecatchBrown,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 스텝 인디케이터
          StepIndicator(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
          ),
          // 스텝 컨텐츠
          Expanded(
            child: SingleChildScrollView(
              child: _buildStepContent(),
            ),
          ),
          // 하단 바
          _buildBottomBar(),
        ],
      ),
    );
  }
}

