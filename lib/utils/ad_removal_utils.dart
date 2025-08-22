import 'package:shared_preferences/shared_preferences.dart';

class AdRemovalUtils {
  static const String _adRemovalExpiryKey = 'ad_removal_expiry_time';
  
  /// 현재 광고 없애기가 활성화되어 있는지 확인
  static Future<bool> isAdRemovalActive() async {
    final prefs = await SharedPreferences.getInstance();
    String? expiryTimeString = prefs.getString(_adRemovalExpiryKey);
    
    if (expiryTimeString == null) {
      return false; // 광고 없애기 기능을 사용한 적 없음
    }
    
    try {
      DateTime expiryTime = DateTime.parse(expiryTimeString);
      DateTime now = DateTime.now();
      
      return now.isBefore(expiryTime); // 현재 시간이 만료 시간 전이면 true
    } catch (e) {
      // 시간 파싱 오류 시 false 반환
      return false;
    }
  }
  
  /// 광고 없애기 기능을 24시간 동안 활성화
  static Future<void> activateAdRemoval() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    DateTime expiryTime = now.add(Duration(hours: 24)); // 현재 시간 + 24시간
    String expiryTimeString = expiryTime.toIso8601String();
    
    await prefs.setString(_adRemovalExpiryKey, expiryTimeString);
  }
  
  /// 광고 없애기 만료 시간 가져오기 (팝업 표시용)
  static Future<DateTime?> getAdRemovalExpiryTime() async {
    final prefs = await SharedPreferences.getInstance();
    String? expiryTimeString = prefs.getString(_adRemovalExpiryKey);
    
    if (expiryTimeString == null) {
      return null;
    }
    
    try {
      return DateTime.parse(expiryTimeString);
    } catch (e) {
      return null;
    }
  }
  
  /// 광고 없애기 기능 제거 (테스트용)
  static Future<void> clearAdRemoval() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_adRemovalExpiryKey);
  }
  
  /// 광고 없애기 남은 시간을 사용자 친화적 문자열로 반환
  static Future<String?> getRemainingTimeString() async {
    DateTime? expiryTime = await getAdRemovalExpiryTime();
    if (expiryTime == null) return null;
    
    DateTime now = DateTime.now();
    if (now.isAfter(expiryTime)) return null;
    
    Duration remaining = expiryTime.difference(now);
    
    if (remaining.inHours > 0) {
      return '${remaining.inHours}시간 ${remaining.inMinutes % 60}분 남음';
    } else {
      return '${remaining.inMinutes}분 남음';
    }
  }
}
