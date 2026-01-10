import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../models/deal_model.dart';
import '../../services/deals_service.dart';
import 'widgets/deal_card.dart';
import 'widgets/departure_airport_modal.dart';
import 'widgets/departure_month_modal.dart';
import 'widgets/travel_duration_modal.dart';
import 'widgets/city_selection_modal.dart';
import 'widgets/airline_selection_modal.dart';
import 'widgets/agency_selection_modal.dart';
import 'widgets/schedule_selection_modal.dart';
import 'deal_notification_screen.dart';

class FlightDealsScreen extends StatefulWidget {
  const FlightDealsScreen({super.key});

  @override
  State<FlightDealsScreen> createState() => _FlightDealsScreenState();
}

class _FlightDealsScreenState extends State<FlightDealsScreen> {
  static const String _kPriceChangeSortDialogDontShowKey = 'deals_price_change_sort_dialog_dont_show';
  
  String? _selectedOriginAirport = 'ICN'; // 기본값: 인천국제공항
  bool _isAllCitiesMode = false;
  List<String> _selectedDestAirports = []; // 선택된 도착지 공항들
  List<int> _selectedMonths = [];
  DateTime? _selectedDepartureDate; // 특정 출발일(필터)
  List<int> _selectedTravelDurations = [];
  List<String> _selectedAirlines = []; // 선택된 항공사
  List<String> _selectedAgencies = []; // 선택된 여행사
  String _sortBy = 'price'; // 기본: 가격 낮은순
  final TextEditingController _destinationSearchController = TextEditingController();
  
  // 페이지네이션 관련 변수
  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 20; // 초기 로드 개수
  bool _isLoadingMore = false; // 추가 로딩 중인지
  bool _hasMoreData = true; // 더 불러올 데이터가 있는지
  List<DealModel> _allDeals = []; // 모든 로드된 데이터
  StreamSubscription<List<DealModel>>? _dealsSubscription;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialDeals();
  }
  
  @override
  void dispose() {
    _destinationSearchController.dispose();
    _scrollController.dispose();
    _dealsSubscription?.cancel();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // 스크롤이 끝에서 200px 전에 도달하면 다음 페이지 로드
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreDeals();
      }
    }
  }
  
  void _loadInitialDeals() {
    _currentLimit = 20;
    _allDeals = [];
    _hasMoreData = true;
    _dealsSubscription?.cancel();
    
    _dealsSubscription = DealsService.getDealsStream(
      originAirport: _isAllCitiesMode ? null : _selectedOriginAirport,
      destAirports: _selectedDestAirports.isEmpty ? null : _selectedDestAirports,
      selectedMonths: _selectedMonths.isEmpty ? null : _selectedMonths,
      departureDate: _selectedDepartureDate,
      travelDurations: _selectedTravelDurations.isEmpty ? null : _selectedTravelDurations,
      airlines: _selectedAirlines.isEmpty ? null : _selectedAirlines,
      agencies: _selectedAgencies.isEmpty ? null : _selectedAgencies,
      sortBy: _sortBy,
      limit: _currentLimit,
    ).listen((deals) {
      if (mounted) {
        setState(() {
          _allDeals = deals;
          _hasMoreData = deals.length >= _currentLimit;
          _isLoadingMore = false;
        });
      }
    });
  }
  
  void _loadMoreDeals() {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentLimit += 20;
    });
    
    _dealsSubscription?.cancel();
    _dealsSubscription = DealsService.getDealsStream(
      originAirport: _isAllCitiesMode ? null : _selectedOriginAirport,
      destAirports: _selectedDestAirports.isEmpty ? null : _selectedDestAirports,
      selectedMonths: _selectedMonths.isEmpty ? null : _selectedMonths,
      departureDate: _selectedDepartureDate,
      travelDurations: _selectedTravelDurations.isEmpty ? null : _selectedTravelDurations,
      airlines: _selectedAirlines.isEmpty ? null : _selectedAirlines,
      agencies: _selectedAgencies.isEmpty ? null : _selectedAgencies,
      sortBy: _sortBy,
      limit: _currentLimit,
    ).listen((deals) {
      if (mounted) {
        setState(() {
          _allDeals = deals;
          _hasMoreData = deals.length >= _currentLimit;
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '특가 항공권',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadInitialDeals();
          // 데이터가 로드될 때까지 대기
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: ColorConstants.milecatchBrown,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 필터 섹션
            SliverToBoxAdapter(
              child: _buildFilterSection(),
            ),
            // 업데이트 정보
            SliverToBoxAdapter(
              child: _buildUpdateInfo(),
            ),
            // 리스트
            _buildDealsListSliver(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 출발지 및 도착지 검색
          Row(
            children: [
              // 출발지 버튼
              if (!_isAllCitiesMode)
                Expanded(
                  child: _buildFilterButton(
                    label: _getAirportName(_selectedOriginAirport ?? 'ICN'),
                    icon: Icons.arrow_drop_down,
                    onTap: () => _showDepartureAirportModal(),
                  ),
                ),
              if (!_isAllCitiesMode) const SizedBox(width: 8),
              // 도착지 검색 필드
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _showCitySelectionModal(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDestAirports.isEmpty
                                ? '도착지 검색...'
                                : '${_selectedDestAirports.length}개 선택',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedDestAirports.isEmpty
                                  ? Colors.grey[500]
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 필터 버튼들 (하단)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 알림 버튼
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DealNotificationScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_outlined, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        const Text(
                          '특가 알림',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 일정 선택
                _buildFilterButton(
                  label: _getScheduleLabel(),
                  icon: Icons.calendar_today,
                  onTap: () => _showScheduleSelectionModal(),
                ),
                const SizedBox(width: 8),
                // 가격 정렬
                _buildFilterButton(
                  label: _getSortLabel(),
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showSortModal(),
                ),
                const SizedBox(width: 8),
                // 모든 항공사
                _buildFilterButton(
                  label: _getAirlineLabel(),
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showAirlineSelectionModal(),
                ),
                const SizedBox(width: 8),
                // 모든 여행사
                _buildFilterButton(
                  label: _getAgencyLabel(),
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showAgencySelectionModal(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  String _getScheduleLabel() {
    if (_selectedMonths.isEmpty && _selectedTravelDurations.isEmpty && _selectedDepartureDate == null) {
      return '일정 선택';
    }
    final parts = <String>[];
    if (_selectedDepartureDate != null) {
      parts.add('${_selectedDepartureDate!.month}/${_selectedDepartureDate!.day}');
    }
    if (_selectedMonths.isNotEmpty) {
      parts.add(_getMonthFilterLabel());
    }
    if (_selectedTravelDurations.isNotEmpty) {
      parts.add(_getTravelDurationLabel());
    }
    return parts.join(', ');
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'price':
        return '가격 낮은순';
      case 'price_desc':
        return '가격 높은순';
      case 'price_change':
        return '가격 변동순';
      default:
        return '가격 낮은순';
    }
  }

  String _getAirlineLabel() {
    if (_selectedAirlines.isEmpty) {
      return '모든 항공사';
    }
    if (_selectedAirlines.length == 1) {
      return _selectedAirlines.first;
    }
    return '${_selectedAirlines.length}개 항공사';
  }

  String _getAgencyLabel() {
    if (_selectedAgencies.isEmpty) {
      return '모든 여행사';
    }
    if (_selectedAgencies.length == 1) {
      final agencyNames = {
        'hanatour': '하나투어',
        'modetour': '모두투어',
        'ttangdeal': '땡처리닷컴',
        'yellowtour': '노랑풍선',
        'onlinetour': '온라인투어',
      };
      return agencyNames[_selectedAgencies.first] ?? _selectedAgencies.first;
    }
    return '${_selectedAgencies.length}개 여행사';
  }

  Widget _buildUpdateInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 텍스트만 별도 위젯으로 분리 (리프레시 방지)
          _UpdateTimeText(),
          // 정렬 버튼 (기존 위치 유지)
          InkWell(
            onTap: () {
              _showSortModal();
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getSortIcon(),
                  size: 16,
                  color: ColorConstants.milecatchBrown,
                ),
                const SizedBox(width: 4),
                Text(
                  _getSortLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorConstants.milecatchBrown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSortIcon() {
    switch (_sortBy) {
      case 'price':
        return Icons.arrow_upward;
      case 'price_desc':
        return Icons.arrow_downward;
      case 'price_change':
        return Icons.swap_vert;
      default:
        return Icons.arrow_upward;
    }
  }

  Widget _buildDealsListSliver() {
    // 가격 변동순일 때 할인율이 있는 항목만 필터링
    final filteredDeals = _sortBy == 'price_change'
        ? _allDeals.where((deal) {
            final discountPercent = deal.priceChangePercent ?? deal.discountPercent;
            return discountPercent != null && discountPercent < 0;
          }).toList()
        : _allDeals;

    // 초기 로딩 중
    if (filteredDeals.isEmpty && _isLoadingMore) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.milecatchBrown),
          ),
        ),
      );
    }

    // 데이터가 없는 경우
    if (filteredDeals.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_takeoff,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                '조건에 맞는 특가 항공권이 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // 마지막 아이템이면 로딩 인디케이터 표시
          if (index == filteredDeals.length) {
            if (_isLoadingMore) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.milecatchBrown),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          
          return DealCard(
            deal: filteredDeals[index],
            index: index + 1,
          );
        },
        childCount: filteredDeals.length + (_isLoadingMore ? 1 : 0),
      ),
    );
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
    return airports[code] ?? '출발 공항';
  }

  String _getMonthFilterLabel() {
    if (_selectedMonths.isEmpty) {
      return '출발월';
    }
    if (_selectedMonths.length == 1) {
      return '${_selectedMonths.first}월';
    }
    return '${_selectedMonths.length}개 선택';
  }

  String _getTravelDurationLabel() {
    if (_selectedTravelDurations.isEmpty) {
      return '여행 기간';
    }
    if (_selectedTravelDurations.length == 1) {
      return '${_selectedTravelDurations.first}일';
    }
    return '${_selectedTravelDurations.length}개 선택';
  }

  void _showDepartureAirportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepartureAirportModal(
        selectedAirport: _selectedOriginAirport,
        onSelect: (airport) {
          setState(() {
            _selectedOriginAirport = airport;
          });
          _loadInitialDeals();
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
        selectedCities: _selectedDestAirports,
        onConfirm: (cities) {
          setState(() {
            _selectedDestAirports = cities;
            _isAllCitiesMode = cities.isNotEmpty;
            if (_isAllCitiesMode) {
              _selectedOriginAirport = null;
            }
          });
          _loadInitialDeals();
        },
      ),
    );
  }

  void _showScheduleSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleSelectionModal(
        selectedMonths: _selectedMonths,
        selectedDepartureDate: _selectedDepartureDate,
        selectedTravelDurations: _selectedTravelDurations,
        onConfirm: (months, durations, departureDate) {
          setState(() {
            _selectedMonths = months;
            _selectedTravelDurations = durations;
            _selectedDepartureDate = departureDate;
          });
          _loadInitialDeals();
        },
      ),
    );
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '정렬 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.milecatchBrown,
                  ),
                ),
              ),
              _buildSortOption('가격 낮은순', 'price', Icons.arrow_upward, setModalState),
              _buildSortOption('가격 높은순', 'price_desc', Icons.arrow_downward, setModalState),
              _buildSortOption('가격 변동순', 'price_change', Icons.swap_vert, setModalState),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon, StateSetter? setModalState) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? ColorConstants.milecatchBrown : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? ColorConstants.milecatchBrown : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: ColorConstants.milecatchBrown)
          : null,
      onTap: () async {
        if (_sortBy != value) {
          // 가격 변동순 선택 시 땅콩 소모 확인
          if (value == 'price_change') {
            final ok = await _confirmAndSpendPeanutsForPriceChange();
            if (!ok) {
              Navigator.pop(context);
              return;
            }
          }
          
          setState(() {
            _sortBy = value;
          });
          // 모달 상태도 업데이트
          setModalState?.call(() {});
          // 정렬 변경 시 즉시 데이터 재로드
          _loadInitialDeals();
        }
        Navigator.pop(context);
      },
    );
  }

  void _showAirlineSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AirlineSelectionModal(
        selectedAirlines: _selectedAirlines,
        onConfirm: (airlines) {
          setState(() {
            _selectedAirlines = airlines;
          });
          _loadInitialDeals();
        },
      ),
    );
  }

  void _showAgencySelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AgencySelectionModal(
        selectedAgencies: _selectedAgencies,
        onConfirm: (agencies) {
          setState(() {
            _selectedAgencies = agencies;
          });
          _loadInitialDeals();
        },
      ),
    );
  }

  Future<bool> _confirmAndSpendPeanutsForPriceChange() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: '땅콩이 모자랍니다.');
        return false;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final int peanuts = (doc.data()?['peanutCount'] as num?)?.toInt() ?? 0;
      if (peanuts < 10) {
        Fluttertoast.showToast(msg: '땅콩이 모자랍니다.');
        return false;
      }

      // "다시 보지 않기"가 설정되어 있는지 확인
      final prefs = await SharedPreferences.getInstance();
      final bool dontShowDialog =
          prefs.getBool(_kPriceChangeSortDialogDontShowKey) ?? false;

      bool proceed = false;
      if (!dontShowDialog) {
        bool localDontShow = false;
        final bool? dontShowNext = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text(
                    '안내',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '가격 변동순 정렬을 이용할 때마다 땅콩 10개가 소모됩니다.',
                        style: TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '다시 보지 않기',
                          style: TextStyle(color: Colors.black),
                        ),
                        value: localDontShow,
                        activeColor: const Color(0xFF74512D),
                        onChanged: (v) {
                          setState(() {
                            localDontShow = v ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(localDontShow),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (dontShowNext == null) {
          return false;
        }

        proceed = true;

        if (dontShowNext == true) {
          await prefs.setBool(_kPriceChangeSortDialogDontShowKey, true);
        }
      } else {
        proceed = true;
      }

      if (!proceed) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'peanutCount': FieldValue.increment(-10)});

      Fluttertoast.showToast(msg: '땅콩 10개가 사용되었습니다.');
      return true;
    } catch (_) {
      Fluttertoast.showToast(msg: '처리 중 오류가 발생했습니다.');
      return false;
    }
  }
}

/// 업데이트 시간 텍스트 위젯 (별도로 관리하여 리스트 리프레시 방지)
class _UpdateTimeText extends StatefulWidget {
  const _UpdateTimeText();

  @override
  State<_UpdateTimeText> createState() => _UpdateTimeTextState();
}

class _UpdateTimeTextState extends State<_UpdateTimeText> {
  bool _showUpdateTime = false;
  Timer? _updateTimeTimer;

  @override
  void initState() {
    super.initState();
    _startUpdateTimeTimer();
  }

  @override
  void dispose() {
    _updateTimeTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimeTimer() {
    // 5초마다 텍스트만 전환 (리스트는 리프레시되지 않음)
    _updateTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _showUpdateTime = !_showUpdateTime;
        });
      }
    });
  }

  String _getLastUpdateTimeText() {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // 업데이트 시간 목록: 6시부터 2시간 간격으로 22시까지
    final updateHours = [6, 8, 10, 12, 14, 16, 18, 20, 22];
    
    // 현재 시간보다 작거나 같은 가장 최근 업데이트 시간 찾기
    int? lastUpdateHour;
    for (int hour in updateHours.reversed) {
      if (hour <= currentHour) {
        lastUpdateHour = hour;
        break;
      }
    }
    
    // 현재 시간이 6시 이전이면 어제 22시로 설정
    if (lastUpdateHour == null) {
      final yesterday = now.subtract(const Duration(days: 1));
      return '최근 업데이트: ${yesterday.year}년 ${yesterday.month}월 ${yesterday.day}일 22시';
    }
    
    // 오늘 날짜로 표시
    return '최근 업데이트: ${now.year}년 ${now.month}월 ${now.day}일 ${lastUpdateHour}시';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _showUpdateTime ? _getLastUpdateTimeText() : '표시된 가격은 상시 변동될 수 있습니다.',
        key: ValueKey(_showUpdateTime),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}


