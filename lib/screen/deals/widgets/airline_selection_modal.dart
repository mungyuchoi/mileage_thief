import 'package:flutter/material.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';
import '../../../utils/deal_image_utils.dart';

class AirlineSelectionModal extends StatefulWidget {
  final List<String> selectedAirlines;
  final Function(List<String>) onConfirm;

  const AirlineSelectionModal({
    super.key,
    required this.selectedAirlines,
    required this.onConfirm,
  });

  @override
  State<AirlineSelectionModal> createState() => _AirlineSelectionModalState();
}

class _AirlineSelectionModalState extends State<AirlineSelectionModal> {
  late List<String> _selectedAirlines;
  final TextEditingController _searchController = TextEditingController();

  // 항공사 목록
  final List<Map<String, String>> _airlines = [
    {'code': '7C', 'name': '제주항공'},
    {'code': 'KE', 'name': '대한항공'},
    {'code': 'OZ', 'name': '아시아나항공'},
    {'code': 'LJ', 'name': '진에어'},
    {'code': 'TW', 'name': '티웨이항공'},
    {'code': 'BX', 'name': '에어부산'},
    {'code': 'ZE', 'name': '이스타항공'},
    {'code': 'RS', 'name': '에어서울'},
    {'code': 'YP', 'name': '에어프레미아'},
    {'code': 'RF', 'name': '에어로케이항공'},
    {'code': 'NH', 'name': '전일본공수'},
    {'code': 'JL', 'name': '일본항공'},
    {'code': 'MM', 'name': '피치항공'},
    {'code': 'GK', 'name': '제트스타재팬'},
    {'code': 'SL', 'name': '타이라이항공'},
    {'code': '5J', 'name': '세부퍼시픽항공'},
    {'code': 'PR', 'name': '필리핀항공'},
    {'code': 'AK', 'name': '에어아시아'},
    {'code': 'D7', 'name': '에어아시아X'},
    {'code': 'OD', 'name': '바틱에어 말레이시아'},
    {'code': 'JQ', 'name': '젯스타항공'},
    {'code': 'VN', 'name': '베트남항공'},
    {'code': 'VJ', 'name': '비엣젯항공'},
    {'code': 'VZ', 'name': '타이 비엣젯항공'},
    {'code': 'TR', 'name': '스쿠트항공'},
    {'code': 'WE', 'name': '파라타항공'},
    {'code': 'CX', 'name': '캐세이퍼시픽'},
    {'code': 'HX', 'name': '홍콩항공'},
    {'code': 'CI', 'name': '중화항공'},
    {'code': 'BI', 'name': '로열브루나이항공'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedAirlines = List.from(widget.selectedAirlines);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAirlines = _airlines.where((airline) {
      if (_searchController.text.isEmpty) return true;
      final query = _searchController.text.toLowerCase();
      return airline['name']!.toLowerCase().contains(query) ||
          airline['code']!.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          // 타이틀
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '항공사 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorConstants.milecatchBrown,
              ),
            ),
          ),
          // 검색바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '항공사명 또는 코드로 검색',
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
          ),
          const SizedBox(height: 16),
          // 항공사 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredAirlines.length,
              itemBuilder: (context, index) {
                final airline = filteredAirlines[index];
                final isSelected = _selectedAirlines.contains(airline['code']!);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedAirlines.remove(airline['code']!);
                        } else {
                          _selectedAirlines.add(airline['code']!);
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
                          DealImageUtils.getAirlineLogo(
                            airline['code']!,
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  airline['name']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? ColorConstants.milecatchBrown
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  airline['code']!,
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
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
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
                        _selectedAirlines.clear();
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
                      widget.onConfirm(_selectedAirlines);
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
}

