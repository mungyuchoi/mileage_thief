import 'package:shared_preferences/shared_preferences.dart';

class NoticePreferenceService {
  static const String _keyNoticeVersion = 'notice_popup_version';

  Future<bool> hasSeenNotice(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNoticeVersion) == version;
  }

  Future<void> markNoticeAsSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNoticeVersion, version);
  }
} 