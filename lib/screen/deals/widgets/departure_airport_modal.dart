import 'package:flutter/material.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';

class DepartureAirportModal extends StatelessWidget {
  final String? selectedAirport;
  final Function(String) onSelect;

  const DepartureAirportModal({
    super.key,
    required this.selectedAirport,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final airports = [
      {'code': 'ICN', 'name': '인천국제공항'},
      {'code': 'GMP', 'name': '김포국제공항'},
      {'code': 'PUS', 'name': '김해국제공항(부산)'},
      {'code': 'CJU', 'name': '제주국제공항'},
      {'code': 'TAE', 'name': '대구국제공항'},
      {'code': 'CJJ', 'name': '청주국제공항'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              '출발 공항 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorConstants.milecatchBrown,
              ),
            ),
          ),
          // 공항 리스트
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: airports.length,
              itemBuilder: (context, index) {
                final airport = airports[index];
                final isSelected = selectedAirport == airport['code'];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  title: Text(
                    airport['name']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? ColorConstants.milecatchBrown : Colors.black87,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: ColorConstants.milecatchBrown,
                        )
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                  onTap: () {
                    onSelect(airport['code']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          SizedBox(
            height: 20 + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }
}

