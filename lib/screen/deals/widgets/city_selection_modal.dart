import 'package:flutter/material.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../../utils/deal_image_utils.dart';

class CitySelectionModal extends StatefulWidget {
  final List<String> selectedCities;
  final Function(List<String>) onConfirm;

  const CitySelectionModal({
    super.key,
    required this.selectedCities,
    required this.onConfirm,
  });

  @override
  State<CitySelectionModal> createState() => _CitySelectionModalState();
}

class _CitySelectionModalState extends State<CitySelectionModal> {
  late List<String> _selectedCities;
  String _selectedRegion = '일본';
  final TextEditingController _searchController = TextEditingController();

  // 지역별 도시 데이터
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
    _selectedCities = List.from(widget.selectedCities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regions = ['일본', '아시아', '중국', '남태평양', '유럽', '중동/아프리카', '아메리카'];
    final cities = _citiesByRegion[_selectedRegion] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '국가, 도시, 공항 검색',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.milecatchBrown,
                  ),
                ),
                const SizedBox(height: 12),
                // 검색바
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '도시명 또는 공항 코드로 검색',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          // 선택된 도시 태그
          if (_selectedCities.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCities.map((airportCode) {
                  final cityData = _findCityData(airportCode);
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
                        Text(
                          cityData?['city'] ?? airportCode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorConstants.milecatchBrown,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCities.remove(airportCode);
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: ColorConstants.milecatchBrown,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          // 지역 탭
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: regions.length,
              itemBuilder: (context, index) {
                final region = regions[index];
                final isSelected = _selectedRegion == region;
                final citiesInRegion = _citiesByRegion[region] ?? [];
                final allCitiesSelected = citiesInRegion.isNotEmpty &&
                    citiesInRegion.every((city) => 
                        _selectedCities.contains(city['airport'] as String));
                final someCitiesSelected = citiesInRegion.isNotEmpty &&
                    citiesInRegion.any((city) => 
                        _selectedCities.contains(city['airport'] as String));
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 지역 탭
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRegion = region;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected
                                    ? ColorConstants.milecatchBrown
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            region,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? ColorConstants.milecatchBrown
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      // 전체 선택 체크박스
                      if (isSelected && citiesInRegion.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (allCitiesSelected) {
                                  // 모두 선택되어 있으면 모두 해제
                                  for (final city in citiesInRegion) {
                                    _selectedCities.remove(city['airport'] as String);
                                  }
                                } else {
                                  // 일부만 선택되어 있거나 아무것도 선택 안 되어 있으면 모두 선택
                                  for (final city in citiesInRegion) {
                                    final airportCode = city['airport'] as String;
                                    if (!_selectedCities.contains(airportCode)) {
                                      _selectedCities.add(airportCode);
                                    }
                                  }
                                }
                              });
                            },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: allCitiesSelected
                                      ? ColorConstants.milecatchBrown
                                      : (someCitiesSelected
                                          ? ColorConstants.milecatchBrown.withOpacity(0.3)
                                          : Colors.transparent),
                                  border: Border.all(
                                    color: allCitiesSelected || someCitiesSelected
                                        ? ColorConstants.milecatchBrown
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: allCitiesSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : (someCitiesSelected
                                        ? Icon(
                                            Icons.remove,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : SizedBox(
                                            width: 16,
                                            height: 16,
                                          )),
                              ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 도시 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: cities.length,
              itemBuilder: (context, index) {
              final city = cities[index];
              final cityKey = city['airport'] as String; // 공항 코드만 사용
              final isSelected = _selectedCities.contains(cityKey);

                // 검색 필터
                if (_searchController.text.isNotEmpty) {
                  final searchText = _searchController.text.toLowerCase();
                  if (!city['city'].toString().toLowerCase().contains(searchText) &&
                      !city['airport'].toString().toLowerCase().contains(searchText)) {
                    return const SizedBox.shrink();
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCities.remove(cityKey);
                        } else {
                          if (!_selectedCities.contains(cityKey)) {
                            _selectedCities.add(cityKey);
                          }
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ColorConstants.milecatchBrown.withOpacity(0.1)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ColorConstants.milecatchBrown
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          DealImageUtils.getCountryFlag(
                            city['code'] as String,
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  city['city'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? ColorConstants.milecatchBrown
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${city['airport']} · ${city['country']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: ColorConstants.milecatchBrown,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 하단 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCities.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorConstants.milecatchBrown),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '초기화',
                      style: TextStyle(
                        color: ColorConstants.milecatchBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(_selectedCities);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.milecatchBrown,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findCityData(String cityKey) {
    for (final cities in _citiesByRegion.values) {
      for (final city in cities) {
        if (city['airport'] == cityKey) {
          return city;
        }
      }
    }
    return null;
  }
}

