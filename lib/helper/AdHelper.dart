import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716';
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
  static String get rewardsAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) {
        return 'cca-app-pub-8549606613390169/5296908148';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-8549606613390169/4146643856';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    } else {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5354046379';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/6978759866';
      } else {
        throw new UnsupportedError('Unsupported platform');
      }
    }
  }
}