import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  static String get asianaMarketUrl {
    if(Platform.isAndroid) {
      return 'market://details?id=com.ssm.asiana';
    } else {
      return 'https://apps.apple.com/us/app/asiana-airlines/id373932237';
    }
  }

  static String get danMarketUrl {
    if(Platform.isAndroid) {
      return 'market://details?id=com.koreanair.passenger';
    } else {
      return 'https://apps.apple.com/us/app/korean-air-my/id1512918989';
    }
  }

  static String get mileageTheifMarketUrl {
    if(Platform.isAndroid) {
      return 'market://details?id=com.mungyu.mileage_thief';
    } else {
      return 'https://apps.apple.com/kr/app/%EC%95%84%EC%8B%9C%EC%95%84%EB%82%98%ED%95%AD%EA%B3%B5/id373932237';
    }
  }

  static String get bannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/3659488883';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/9487079377';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2934735716';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6300978111';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  static String get frontBannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/9941114138';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/7314950794';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  static String get rewardedAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/2269529369';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/4045645464';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return "ca-app-pub-3940256099942544/5224354917";
      } else if (Platform.isIOS) {
        return "ca-app-pub-3940256099942544/1712485313";
      } else {
        throw new UnsupportedError("Unsupported platform");
      }
    }
  }

  static String get bannerDanAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/5241222692';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/9048605764';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2934735716';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6300978111';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  static String get frontBannerDanAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/5899644342';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/7396558849';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  static String get rewardedDanAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/7208894573';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/8853110748';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return "ca-app-pub-3940256099942544/5224354917";
      } else if (Platform.isIOS) {
        return "ca-app-pub-3940256099942544/1712485313";
      } else {
        throw new UnsupportedError("Unsupported platform");
      }
    }
  }

  // 게시글 상세 - 프로필/스카이이펙트/닉네임 아래 배너 광고
  static String get postDetailProfileBannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/5003324282'; // 실제 Android 광고 ID로 교체 필요
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/3365457915'; // 실제 iOS 광고 ID로 교체 필요
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2934735716'; // 테스트 광고 ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 광고 ID
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  // 게시글 상세 - 게시글과 댓글 사이 배너 광고
  static String get postDetailContentBannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/1314526567'; // 실제 Android 광고 ID로 교체 필요
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/7688363224'; // 실제 iOS 광고 ID로 교체 필요
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2934735716'; // 테스트 광고 ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 광고 ID
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }

  // 마이페이지 - 스카이이펙트와 탭바 사이 배너 광고
  static String get myPageBannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-8549606613390169/2801501072'; // 실제 Android 광고 ID로 교체 필요
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/5368804727'; // 실제 iOS 광고 ID로 교체 필요
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/2934735716'; // 테스트 광고 ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 광고 ID
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }
}
