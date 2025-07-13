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

  bool get noticePopupEnabled => _remoteConfig.getBool('notice_popup_enabled');
  String get noticePopupTitle => _remoteConfig.getString('notice_popup_title');
  String get noticePopupContent => _remoteConfig.getString('notice_popup_content');
  String get noticePopupVersion => _remoteConfig.getString('notice_popup_version');
  bool get noticePopupForceShow => _remoteConfig.getBool('notice_popup_force_show');
  bool get noticePopupShowOnce => _remoteConfig.getBool('notice_popup_show_once');
  String get noticePopupButtonText => _remoteConfig.getString('notice_popup_button_text');
} 