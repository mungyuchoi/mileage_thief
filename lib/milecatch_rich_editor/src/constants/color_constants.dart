import 'package:flutter/material.dart';

class ColorConstants {
  // Milecatch 브랜드 색상
  static const Color milecatchBrown = Color(0xFF74512D);
  static const Color milecatchLightBrown = Color(0xFF8B6F3A);
  static const Color milecatchDarkBrown = Color(0xFF5A3F23);

  // 기본 색상 팔레트 (12개)
  static const List<Color> basicColors = [
    Color(0xFF000000), // 검정
    Color(0xFF424242), // 진회색
    Color(0xFF757575), // 회색
    Color(0xFFE53935), // 빨강
    Color(0xFFD81B60), // 분홍
    Color(0xFF8E24AA), // 보라
    Color(0xFF3949AB), // 남색
    Color(0xFF1E88E5), // 파랑
    Color(0xFF00ACC1), // 청록
    Color(0xFF00897B), // 틸
    Color(0xFF43A047), // 초록
    Color(0xFF7CB342), // 라임
  ];

  // 확장 색상 팔레트 (24개)
  static const List<Color> extendedColors = [
    Color(0xFF000000), Color(0xFF424242), Color(0xFF757575), Color(0xFFBDBDBD),
    Color(0xFFE53935), Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFC107),
    Color(0xFFD81B60), Color(0xFFE91E63), Color(0xFFFF4081), Color(0xFFFF80AB),
    Color(0xFF8E24AA), Color(0xFF9C27B0), Color(0xFFBA68C8), Color(0xFFE1BEE7),
    Color(0xFF3949AB), Color(0xFF3F51B5), Color(0xFF7986CB), Color(0xFFC5CAE9),
    Color(0xFF1E88E5), Color(0xFF2196F3), Color(0xFF64B5F6), Color(0xFFBBDEFB),
  ];

  // 다크 모드 색상
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF8B6F3A);

  // 텍스트 색상
  static const Color primaryText = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF757575);
  static const Color disabledText = Color(0xFFBDBDBD);

  // 배경 색상
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);

  // 상태 색상
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // 에디터용 색상 조합
  static List<Color> get editorColors {
    return [...basicColors, ...extendedColors.skip(4)];
  }
}

