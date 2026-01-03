import 'package:flutter/material.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final stepNumber = index + 1;
          final isActive = stepNumber <= currentStep;
          final isCurrent = stepNumber == currentStep;

          return Expanded(
            child: Row(
              children: [
                // 스텝 원
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? ColorConstants.milecatchBrown
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isActive
                        ? Icon(
                            isCurrent ? Icons.radio_button_checked : Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            '$stepNumber',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                // 연결선
                if (index < totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stepNumber < currentStep
                          ? ColorConstants.milecatchBrown
                          : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

