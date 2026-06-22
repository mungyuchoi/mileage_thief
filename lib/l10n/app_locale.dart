import 'package:flutter/foundation.dart';

/// 앱 전역 언어(ISO 2자리). 기본 'ko', 'en' 지원.
/// 변경 시 main.dart의 ValueListenableBuilder가 앱 전체를 재빌드한다.
final ValueNotifier<String> appLanguage = ValueNotifier<String>('ko');

const List<String> kSupportedLanguages = <String>['ko', 'en'];

/// 지원 언어로 정규화. 알 수 없으면 'ko'.
String normalizeLanguage(String? code) {
  final c = (code ?? '').toLowerCase().trim();
  return kSupportedLanguages.contains(c) ? c : 'ko';
}

/// 다국어 리소스 테이블. 키 단위로 점진 이관한다.
/// 새 문자열은 ko/en 양쪽에 키를 추가하고, 화면에서 L10n.t('key')로 사용.
class L10n {
  L10n._();

  static const Map<String, Map<String, String>> _table =
      <String, Map<String, String>>{
    'ko': <String, String>{
      // 공통
      'common.save': '저장',
      'common.cancel': '취소',
      'common.confirm': '확인',
      'common.close': '닫기',
      // 설정 · 언어
      'settings.language': '언어',
      'settings.language.sub': '앱 표시 언어를 선택합니다.',
      'language.title': '언어 설정',
      'language.subtitle': '앱에 표시할 언어를 선택하세요.',
      'language.korean': '한국어',
      'language.english': 'English',
      'language.changed': '언어가 변경되었어요.',
      // 세계지도(핵심 화면 시드)
      'explore.layer.explore': '탐험',
      'explore.layer.flight': '항공',
      'explore.layer.hotel': '호텔',
      'passport.tab.country': '나라',
      'passport.tab.city': '도시',
      'passport.tab.record': '내 여행기록',
      'stat.world': '세계 탐험',
      'stat.countries': '방문국',
      'stat.cities': '해제 도시',
      'stat.continents': '대륙',
      'stat.flights': '항공 기록',
      'stat.photos': '올린 사진',
      'stat.stamps': '스탬프',
      'stat.peanut': '땅콩',
      'stat.hotelStars': '호텔 별',
    },
    'en': <String, String>{
      'common.save': 'Save',
      'common.cancel': 'Cancel',
      'common.confirm': 'OK',
      'common.close': 'Close',
      'settings.language': 'Language',
      'settings.language.sub': 'Choose the app display language.',
      'language.title': 'Language',
      'language.subtitle': 'Choose the language to display in the app.',
      'language.korean': '한국어',
      'language.english': 'English',
      'language.changed': 'Language changed.',
      'explore.layer.explore': 'Explore',
      'explore.layer.flight': 'Flights',
      'explore.layer.hotel': 'Hotels',
      'passport.tab.country': 'Countries',
      'passport.tab.city': 'Cities',
      'passport.tab.record': 'My Trips',
      'stat.world': 'World',
      'stat.countries': 'Countries',
      'stat.cities': 'Cities',
      'stat.continents': 'Continents',
      'stat.flights': 'Flights',
      'stat.photos': 'Photos',
      'stat.stamps': 'Stamps',
      'stat.peanut': 'Peanuts',
      'stat.hotelStars': 'Hotel stars',
    },
  };

  /// 현재 언어 문자열. 없으면 ko 폴백, 그래도 없으면 key 그대로.
  static String t(String key) => of(key, appLanguage.value);

  static String of(String key, String lang) {
    final l = normalizeLanguage(lang);
    return _table[l]?[key] ?? _table['ko']?[key] ?? key;
  }
}
