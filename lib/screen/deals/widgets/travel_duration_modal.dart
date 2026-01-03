import 'package:flutter/material.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';

class TravelDurationModal extends StatefulWidget {
  final List<int> selectedDurations;
  final Function(List<int>) onConfirm;

  const TravelDurationModal({
    super.key,
    required this.selectedDurations,
    required this.onConfirm,
  });

  @override
  State<TravelDurationModal> createState() => _TravelDurationModalState();
}

class _TravelDurationModalState extends State<TravelDurationModal> {
  late List<int> _selectedDurations;

  @override
  void initState() {
    super.initState();
    _selectedDurations = List.from(widget.selectedDurations);
  }

  @override
  Widget build(BuildContext context) {
    final durations = [
      {'nights': 2, 'days': 3},
      {'nights': 3, 'days': 4},
      {'nights': 4, 'days': 5},
      {'nights': 5, 'days': 6},
      {'nights': 6, 'days': 7},
      {'nights': 7, 'days': 8},
      {'nights': 8, 'days': 9},
      {'nights': 9, 'days': 10},
      {'nights': 10, 'days': 11},
      {'nights': 11, 'days': 12},
      {'nights': 12, 'days': 13},
      {'nights': 13, 'days': 14},
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
              '여행 기간 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorConstants.milecatchBrown,
              ),
            ),
          ),
          // 기간 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3,
              ),
              itemCount: durations.length,
              itemBuilder: (context, index) {
                final duration = durations[index];
                final days = duration['days'] as int;
                final isSelected = _selectedDurations.contains(days);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDurations.remove(days);
                      } else {
                        _selectedDurations.add(days);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorConstants.milecatchBrown
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? ColorConstants.milecatchBrown
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${duration['nights']}박 ${duration['days']}일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDurations.clear();
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
                      widget.onConfirm(_selectedDurations);
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

