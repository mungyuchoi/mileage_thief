import 'package:flutter/material.dart';

class FontConstants {
  // 기본 폰트 패밀리
  static const String defaultFontFamily = 'NanumGothic';
  static const String fallbackFontFamily = 'sans-serif';

  // 폰트 크기
  static const int extraSmallFontSize = 10;
  static const int smallFontSize = 12;
  static const int normalFontSize = 14;
  static const int mediumFontSize = 16;
  static const int largeFontSize = 18;
  static const int extraLargeFontSize = 20;
  static const int hugeFontSize = 24;
  static const int title1FontSize = 28;
  static const int title2FontSize = 32;
  static const int title3FontSize = 36;

  // 사용 가능한 폰트 크기 목록
  static const List<int> availableFontSizes = [
    10, 12, 14, 16, 18, 20, 24, 28, 32, 36,
  ];

  // 폰트 크기 라벨
  static const Map<int, String> fontSizeLabels = {
    10: '아주 작게',
    12: '작게',
    14: '보통',
    16: '중간',
    18: '크게',
    20: '더 크게',
    24: '매우 크게',
    28: '제목1',
    32: '제목2',
    36: '제목3',
  };

  // 폰트 굵기
  static const FontWeight lightFontWeight = FontWeight.w300;
  static const FontWeight normalFontWeight = FontWeight.w400;
  static const FontWeight mediumFontWeight = FontWeight.w500;
  static const FontWeight semiBoldFontWeight = FontWeight.w600;
  static const FontWeight boldFontWeight = FontWeight.w700;
  static const FontWeight extraBoldFontWeight = FontWeight.w800;
  static const FontWeight blackFontWeight = FontWeight.w900;

  // 사용 가능한 폰트 굵기 목록
  static const List<FontWeight> availableFontWeights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];

  // 폰트 굵기 라벨
  static const Map<FontWeight, String> fontWeightLabels = {
    FontWeight.w300: '가늘게',
    FontWeight.w400: '보통',
    FontWeight.w500: '중간',
    FontWeight.w600: '반굵게',
    FontWeight.w700: '굵게',
    FontWeight.w800: '매우 굵게',
    FontWeight.w900: '극굵게',
  };

  // 사용 가능한 폰트 패밀리
  static const List<String> availableFontFamilies = [
    'NanumGothic',
    'Ssuk',
    'Oneprettynight',
    'Ohsquareair',
    'Ssuround',
    'SsuroundAir',
    'Arial',
    'Times New Roman',
    'Helvetica',
    'Georgia',
  ];

  // 폰트 패밀리 표시명
  static const Map<String, String> fontFamilyDisplayNames = {
    'NanumGothic': '나눔고딕',
    'Ssuk': '카페24 쑥쑥',
    'Oneprettynight': '카페24 온어프리티나잇',
    'Ohsquareair': '카페24 오스퀘어에어',
    'Ssuround': '카페24 써라운드',
    'SsuroundAir': '카페24 써라운드에어',
    'Arial': 'Arial',
    'Times New Roman': 'Times New Roman',
    'Helvetica': 'Helvetica',
    'Georgia': 'Georgia',
  };

  // 텍스트 스타일
  static const TextStyle extraSmallTextStyle = TextStyle(
    fontSize: extraSmallFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle smallTextStyle = TextStyle(
    fontSize: smallFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle normalTextStyle = TextStyle(
    fontSize: normalFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle mediumTextStyle = TextStyle(
    fontSize: mediumFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle largeTextStyle = TextStyle(
    fontSize: largeFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle extraLargeTextStyle = TextStyle(
    fontSize: extraLargeFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle hugeTextStyle = TextStyle(
    fontSize: hugeFontSize + 0.0,
    fontFamily: defaultFontFamily,
  );

  static const TextStyle title1TextStyle = TextStyle(
    fontSize: title1FontSize + 0.0,
    fontFamily: defaultFontFamily,
    fontWeight: boldFontWeight,
  );

  static const TextStyle title2TextStyle = TextStyle(
    fontSize: title2FontSize + 0.0,
    fontFamily: defaultFontFamily,
    fontWeight: boldFontWeight,
  );

  static const TextStyle title3TextStyle = TextStyle(
    fontSize: title3FontSize + 0.0,
    fontFamily: defaultFontFamily,
    fontWeight: boldFontWeight,
  );

  // 줄 간격
  static const double defaultLineHeight = 1.4;
  static const double compactLineHeight = 1.2;
  static const double spaciousLineHeight = 1.6;

  // 자간
  static const double defaultLetterSpacing = 0.0;
  static const double tightLetterSpacing = -0.5;
  static const double wideLetterSpacing = 0.5;

  // 유틸리티 메서드
  static double getRecommendedLineHeight(int fontSize) {
    if (fontSize <= 12) return 1.3;
    if (fontSize <= 16) return 1.4;
    if (fontSize <= 20) return 1.5;
    return 1.6;
  }

  static bool isValidFontSize(int fontSize) {
    return availableFontSizes.contains(fontSize);
  }

  static FontWeight getFontWeightFromValue(int value) {
    switch (value) {
      case 300: return FontWeight.w300;
      case 400: return FontWeight.w400;
      case 500: return FontWeight.w500;
      case 600: return FontWeight.w600;
      case 700: return FontWeight.w700;
      case 800: return FontWeight.w800;
      case 900: return FontWeight.w900;
      default: return FontWeight.w400;
    }
  }

  static int getFontWeightValue(FontWeight fontWeight) {
    switch (fontWeight) {
      case FontWeight.w300: return 300;
      case FontWeight.w400: return 400;
      case FontWeight.w500: return 500;
      case FontWeight.w600: return 600;
      case FontWeight.w700: return 700;
      case FontWeight.w800: return 800;
      case FontWeight.w900: return 900;
      default: return 400;
    }
  }

  static TextStyle createTextStyle({
    int fontSize = normalFontSize,
    FontWeight fontWeight = normalFontWeight,
    String fontFamily = defaultFontFamily,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      color: color,
      letterSpacing: letterSpacing ?? defaultLetterSpacing,
      height: height ?? getRecommendedLineHeight(fontSize),
    );
  }
}
