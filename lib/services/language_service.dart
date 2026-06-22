import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_locale.dart';

/// 언어 설정 로드/저장.
/// - 저장 위치: users/{uid}.language (ISO 2자리: ko/en) + 로컬 캐시(SharedPreferences)
/// - milecatch 웹도 동일한 users/{uid}.language 값을 읽어 분기한다.
class LanguageService {
  LanguageService._();

  static const String _prefsKey = 'app_language';

  /// 앱 시작 시 호출: 캐시 즉시 적용 → 로그인 시 Firestore 동기화.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.isNotEmpty) {
        appLanguage.value = normalizeLanguage(cached);
      }
    } catch (_) {/* 캐시 실패 무시 */}
    await syncFromFirestore();
  }

  /// 로그인 사용자의 users/{uid}.language 로 전역 언어 동기화.
  static Future<void> syncFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final lang = snap.data()?['language'];
      if (lang is String && lang.isNotEmpty) {
        final norm = normalizeLanguage(lang);
        appLanguage.value = norm;
        await _cache(norm);
      }
    } catch (_) {/* 네트워크 실패 무시 */}
  }

  /// 언어 변경: 전역 적용 + 캐시 + Firestore 저장.
  static Future<void> setLanguage(String code) async {
    final norm = normalizeLanguage(code);
    appLanguage.value = norm;
    await _cache(norm);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(<String, dynamic>{'language': norm}, SetOptions(merge: true));
      } catch (_) {/* 저장 실패 무시(로컬은 이미 반영) */}
    }
  }

  static Future<void> _cache(String norm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, norm);
    } catch (_) {}
  }
}
