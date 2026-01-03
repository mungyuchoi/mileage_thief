import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../models/deal_model.dart';
import '../../services/deals_service.dart';
import 'widgets/deal_card.dart';
import 'widgets/departure_airport_modal.dart';
import 'widgets/departure_month_modal.dart';
import 'widgets/travel_duration_modal.dart';
import 'widgets/city_selection_modal.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String? _selectedOriginAirport = 'ICN'; // 기본값: 인천국제공항
  bool _isAllCitiesMode = false;
  List<String> _selectedDestAirports = []; // 선택된 도착지 공항들
  List<int> _selectedMonths = [];
  List<int> _selectedTravelDurations = [];
  String _sortBy = 'price_change'; // 기본: 가격 변동순

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 필터 섹션
          _buildFilterSection(),
          // 업데이트 정보
          _buildUpdateInfo(),
          // 리스트
          Expanded(
            child: _buildDealsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 출발지 탭
          Row(
            children: [
              Expanded(
                child: _buildAirportTab(
                  label: '인천국제공항',
                  icon: Icons.flight_takeoff,
                  isSelected: !_isAllCitiesMode,
                  onTap: () {
                    setState(() {
                      _isAllCitiesMode = false;
                      _selectedOriginAirport = 'ICN';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAirportTab(
                  label: '전체 도시',
                  icon: Icons.flight_takeoff,
                  isSelected: _isAllCitiesMode,
                  onTap: () {
                    _showCitySelectionModal();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 필터 버튼들
          Row(
            children: [
              // 출발 공항 선택 (전체 도시 모드가 아닐 때만)
              if (!_isAllCitiesMode)
                Expanded(
                  child: _buildFilterButton(
                    label: _getAirportName(_selectedOriginAirport ?? 'ICN'),
                    icon: Icons.arrow_drop_down,
                    onTap: () => _showDepartureAirportModal(),
                  ),
                ),
              if (!_isAllCitiesMode) const SizedBox(width: 8),
              // 도착지 선택 (전체 도시 모드일 때)
              if (_isAllCitiesMode && _selectedDestAirports.isNotEmpty)
                Expanded(
                  child: _buildFilterButton(
                    label: '${_selectedDestAirports.length}개 도시',
                    icon: Icons.arrow_drop_down,
                    onTap: () => _showCitySelectionModal(),
                  ),
                ),
              if (_isAllCitiesMode && _selectedDestAirports.isEmpty)
                Expanded(
                  child: _buildFilterButton(
                    label: '도착지 선택',
                    icon: Icons.arrow_drop_down,
                    onTap: () => _showCitySelectionModal(),
                  ),
                ),
              if (_isAllCitiesMode) const SizedBox(width: 8),
              // 출발월 필터
              Expanded(
                child: _buildFilterButton(
                  label: _getMonthFilterLabel(),
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showDepartureMonthModal(),
                ),
              ),
              const SizedBox(width: 8),
              // 여행 기간 필터
              Expanded(
                child: _buildFilterButton(
                  label: _getTravelDurationLabel(),
                  icon: Icons.arrow_drop_down,
                  onTap: () => _showTravelDurationModal(),
                ),
              ),
              const SizedBox(width: 8),
              // 정렬 버튼
              _buildSortButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAirportTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorConstants.milecatchBrown
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
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

  Widget _buildSortButton() {
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortBy == 'price_change') {
            _sortBy = 'price';
          } else {
            _sortBy = 'price_change';
          }
        });
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
            Icon(
              Icons.swap_vert,
              size: 18,
              color: ColorConstants.milecatchBrown,
            ),
            const SizedBox(width: 4),
            Text(
              '가격 변동순',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColorConstants.milecatchBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '표시된 가격은 상시 변동될 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealsList() {
    return StreamBuilder<List<DealModel>>(
      stream: DealsService.getDealsStream(
        originAirport: _isAllCitiesMode ? null : _selectedOriginAirport,
        destAirports: _selectedDestAirports.isEmpty ? null : _selectedDestAirports,
        selectedMonths: _selectedMonths.isEmpty ? null : _selectedMonths,
        travelDurations: _selectedTravelDurations.isEmpty ? null : _selectedTravelDurations,
        sortBy: _sortBy,
        limit: 200,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.milecatchBrown),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '데이터를 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final deals = snapshot.data ?? [];

        if (deals.isEmpty) {
          return Center(
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
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: deals.length,
          itemBuilder: (context, index) {
            return DealCard(
              deal: deals[index],
              index: index + 1,
            );
          },
        );
      },
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
        },
      ),
    );
  }

  void _showDepartureMonthModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepartureMonthModal(
        selectedMonths: _selectedMonths,
        onConfirm: (months) {
          setState(() {
            _selectedMonths = months;
          });
        },
      ),
    );
  }

  void _showTravelDurationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TravelDurationModal(
        selectedDurations: _selectedTravelDurations,
        onConfirm: (durations) {
          setState(() {
            _selectedTravelDurations = durations;
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
        selectedCities: _selectedDestAirports,
        onConfirm: (cities) {
          setState(() {
            _selectedDestAirports = cities;
            _isAllCitiesMode = cities.isNotEmpty;
            if (_isAllCitiesMode) {
              _selectedOriginAirport = null;
            }
          });
        },
      ),
    );
  }
}
