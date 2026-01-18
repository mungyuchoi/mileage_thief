import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../models/shopping_mall_model.dart';

class ShoppingMallService {
  static const String _countdownPrefix = 'shopping_mall_countdown_';
  static const int _countdownDurationHours = 24;

  /// 쇼핑몰 클릭 시 카운트다운 시작 시간 저장
  static Future<void> startCountdown(String mallId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('$_countdownPrefix$mallId', now.toIso8601String());
  }

  /// 쇼핑몰의 카운트다운 시작 시간 가져오기
  static Future<DateTime?> getCountdownStartTime(String mallId) async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('$_countdownPrefix$mallId');
    if (timeString == null) return null;
    try {
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// 카운트다운이 완료되었는지 확인
  static Future<bool> isCountdownComplete(String mallId) async {
    final startTime = await getCountdownStartTime(mallId);
    if (startTime == null) return true; // 카운트다운이 시작되지 않았으면 완료로 간주

    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    return elapsed.inHours >= _countdownDurationHours;
  }

  /// 남은 시간을 Duration으로 반환
  static Future<Duration?> getRemainingTime(String mallId) async {
    final startTime = await getCountdownStartTime(mallId);
    if (startTime == null) return null;

    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    final remaining = Duration(hours: _countdownDurationHours) - elapsed;

    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  /// 시간을 HH:mm 형식으로 변환
  static String formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// 쇼핑몰 클릭 처리 및 땅콩 적립
  static Future<bool> handleMallClick(String mallId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // 카운트다운이 완료되었는지 확인
    final isComplete = await isCountdownComplete(mallId);
    
    if (isComplete) {
      // 땅콩 적립
      final mall = ShoppingMall.getShoppingMalls().firstWhere(
        (m) => m.id == mallId,
        orElse: () => ShoppingMall.getShoppingMalls().first,
      );

      try {
        final userData = await UserService.getUserFromFirestore(user.uid);
        final currentPeanuts = userData?['peanutCount'] ?? 0;
        final newPeanuts = currentPeanuts + mall.peanutReward;

        await UserService.updatePeanutCount(user.uid, newPeanuts);

        // SharedPreferences도 업데이트
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('counter', newPeanuts);

        // 카운트다운 시작
        await startCountdown(mallId);

        return true;
      } catch (e) {
        print('땅콩 적립 오류: $e');
        return false;
      }
    } else {
      // 카운트다운이 아직 진행 중이면 땅콩 적립 없음 (카운트다운은 유지)
      return false;
    }
  }

  /// 카운트다운 리셋 (테스트용)
  static Future<void> resetCountdown(String mallId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_countdownPrefix$mallId');
  }
}
