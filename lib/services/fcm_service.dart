import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'user_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_token';

  // FCM 토큰 초기화 및 권한 요청
  static Future<void> initialize() async {
    // 알림 권한 요청
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('FCM 알림 권한 허용됨');
      await _setupTokenHandling();
    } else {
      print('FCM 알림 권한 거부됨');
    }
  }

  // 토큰 처리 설정
  static Future<void> _setupTokenHandling() async {
    // 현재 토큰 가져오기
    String? token = await _messaging.getToken();
    if (token != null) {
      await _handleTokenUpdate(token);
    }

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen(_handleTokenUpdate);
  }

  // 토큰 업데이트 처리
  static Future<void> _handleTokenUpdate(String token) async {
    try {
      // 로컬에 저장
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      // 로그인된 사용자가 있으면 Firestore에도 저장
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await UserService.updateFcmToken(currentUser.uid, token);
      }

      print('FCM 토큰 업데이트됨: $token');
    } catch (e) {
      print('FCM 토큰 업데이트 오류: $e');
    }
  }

  // 현재 토큰 가져오기
  static Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('FCM 토큰 가져오기 오류: $e');
      return null;
    }
  }

  // 로컬에 저장된 토큰 가져오기
  static Future<String?> getStoredToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('저장된 FCM 토큰 가져오기 오류: $e');
      return null;
    }
  }
} 