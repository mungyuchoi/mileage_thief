import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// Firebase Auth 세션 유지 모니터.
///
/// 증상 추적용: "로그인했는데 앱을 껐다 켜면 로그아웃되어 있다"는 유저가
/// 실제로 얼마나/어느 플랫폼에서 발생하는지 측정한다.
///
/// 원리: 로그인 상태가 되면 uid 를 로컬에 기록해 두고,
/// 다음 앱 시작의 첫 auth 이벤트가 null 인데 기록이 남아 있으면
/// (= 의도한 로그아웃/탈퇴가 아님) `auth_session_lost` 이벤트를 남긴다.
class AuthSessionMonitor {
  AuthSessionMonitor._();

  static const String _lastUidKey = 'auth_last_known_uid';
  static bool _started = false;
  static bool _handledFirstEvent = false;

  /// Firebase.initializeApp 이후 1회 호출.
  static void start() {
    if (_started) return;
    _started = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_handleAuthEvent(user));
    });
  }

  static Future<void> _handleAuthEvent(User? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUid = prefs.getString(_lastUidKey);

      if (!_handledFirstEvent) {
        _handledFirstEvent = true;
        // 지난 세션에 로그인 상태였는데(기록 있음) 재시작 후 null
        // → 유저 의도와 무관한 세션 소실로 판단하고 기록.
        if (user == null && lastUid != null && lastUid.isNotEmpty) {
          unawaited(AnalyticsService.instance.logAction(
            'auth_session_lost',
            params: {
              'platform': Platform.isIOS ? 'ios' : 'android',
              'prev_uid': lastUid,
            },
          ));
          await prefs.remove(_lastUidKey);
        }
      }

      if (user != null && user.uid != lastUid) {
        await prefs.setString(_lastUidKey, user.uid);
      }
    } catch (_) {
      // 모니터링 실패는 앱 동작에 영향 주지 않음.
    }
  }

  /// 유저가 직접 로그아웃/탈퇴했을 때 호출 — 오탐 방지.
  static Future<void> markSignedOutIntentionally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUidKey);
    } catch (_) {}
  }
}
