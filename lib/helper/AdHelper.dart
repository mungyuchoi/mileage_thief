import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
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
