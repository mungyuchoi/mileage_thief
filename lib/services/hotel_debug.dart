import 'package:flutter/foundation.dart';

/// 호텔 특가 기능 디버깅 로그 (디버그 모드에서만 출력)
void hotelLog(Object? message) {
  if (kDebugMode) {
    debugPrint('[HOTEL] $message');
  }
}


