import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  static String get asianaMarketUrl {
    if(Platform.isAndroid) {
      return 'market://details?id=com.ssm.asiana';
    } else {
      return 'itms-apps://apps.apple.com/kr/app/%EC%95%84%EC%8B%9C%EC%95%84%EB%82%98%ED%95%AD%EA%B3%B5/id373932237';
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
}
