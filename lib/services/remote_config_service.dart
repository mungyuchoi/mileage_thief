import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await _remoteConfig.fetchAndActivate();
  }

  // 공지사항 팝업 관련
  bool get noticePopupEnabled => _remoteConfig.getBool('notice_popup_enabled');
  String get noticePopupTitle => _remoteConfig.getString('notice_popup_title');
  String get noticePopupContent => _remoteConfig.getString('notice_popup_content');
  String get noticePopupVersion => _remoteConfig.getString('notice_popup_version');
  bool get noticePopupForceShow => _remoteConfig.getBool('notice_popup_force_show');
  bool get noticePopupShowOnce => _remoteConfig.getBool('notice_popup_show_once');
  String get noticePopupButtonText => _remoteConfig.getString('notice_popup_button_text');

  // 강제 업데이트 관련
  bool get forceUpdateEnabled => _remoteConfig.getBool('force_update_enabled');
  String get forceUpdateVersionAndroid => _remoteConfig.getString('force_update_version_android');
  String get forceUpdateVersionIos => _remoteConfig.getString('force_update_version_ios');
  String get forceUpdateTitle => _remoteConfig.getString('force_update_title');
  String get forceUpdateContent => _remoteConfig.getString('force_update_content');
  String get forceUpdateButtonText => _remoteConfig.getString('force_update_button_text');
  String get forceUpdateUrlAndroid => _remoteConfig.getString('force_update_url_android');
  String get forceUpdateUrlIos => _remoteConfig.getString('force_update_url_ios');
} 