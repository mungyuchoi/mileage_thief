import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}

class PlatformUtils {
  // 플랫폼 확인
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;

  // 빌드 모드 확인
  static bool get isDebugMode => kDebugMode;
  static bool get isReleaseMode => kReleaseMode;
  static bool get isProfileMode => kProfileMode;

  /// 카메라 권한을 요청합니다
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Failed to request camera permission: $e');
      return false;
    }
  }

  /// 저장소 권한을 요청합니다
  static Future<bool> requestStoragePermission() async {
    try {
      if (isAndroid) {
        final status = await Permission.storage.request();
        return status == PermissionStatus.granted;
      } else if (isIOS) {
        final status = await Permission.photos.request();
        return status == PermissionStatus.granted;
      }
      return true; // 다른 플랫폼은 기본적으로 허용
    } catch (e) {
      print('Failed to request storage permission: $e');
      return false;
    }
  }

  /// 마이크 권한을 요청합니다
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Failed to request microphone permission: $e');
      return false;
    }
  }

  /// 특정 권한이 있는지 확인합니다
  static Future<bool> hasPermission(Permission permission) async {
    try {
      final status = await permission.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Failed to check permission: $e');
      return false;
    }
  }

  /// 앱 설정을 엽니다
  static Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      print('Failed to open app settings: $e');
      return false;
    }
  }

  /// 키보드를 숨깁니다
  static void hideKeyboard() {
    try {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (e) {
      print('Failed to hide keyboard: $e');
    }
  }

  /// 키보드를 표시합니다
  static void showKeyboard() {
    try {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } catch (e) {
      print('Failed to show keyboard: $e');
    }
  }

  /// 햅틱 피드백을 실행합니다
  static void hapticFeedback({HapticFeedbackType type = HapticFeedbackType.lightImpact}) {
    try {
      switch (type) {
        case HapticFeedbackType.lightImpact:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.mediumImpact:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavyImpact:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selectionClick:
          HapticFeedback.selectionClick();
          break;
        case HapticFeedbackType.vibrate:
          HapticFeedback.vibrate();
          break;
      }
    } catch (e) {
      print('Failed to perform haptic feedback: $e');
    }
  }

  /// 시스템 정보를 가져옵니다
  static Map<String, dynamic> getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'isPhysicalDevice': !kIsWeb,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'isWeb': isWeb,
      'isDebug': isDebugMode,
      'isRelease': isReleaseMode,
      'isProfile': isProfileMode,
    };
  }

  /// 앱 정보를 가져옵니다
  static Future<Map<String, String>> getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      print('Failed to get app info: $e');
      return {};
    }
  }

  /// 기기 정보를 가져옵니다
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'type': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'type': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else if (isWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return {
          'type': 'Web',
          'browserName': webInfo.browserName.name,
          'userAgent': webInfo.userAgent,
          'platform': webInfo.platform,
        };
      }
      
      return {'type': 'Unknown'};
    } catch (e) {
      print('Failed to get device info: $e');
      return {};
    }
  }

  /// 기기 방향을 설정합니다
  static Future<void> setDeviceOrientation(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } catch (e) {
      print('Failed to set device orientation: $e');
    }
  }

  /// 시스템 UI 오버레이 스타일을 설정합니다
  static void setSystemUIOverlayStyle({
    Color? statusBarColor,
    Brightness? statusBarBrightness,
    Brightness? statusBarIconBrightness,
    Color? systemNavigationBarColor,
    Brightness? systemNavigationBarIconBrightness,
  }) {
    try {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarBrightness: statusBarBrightness,
        statusBarIconBrightness: statusBarIconBrightness,
        systemNavigationBarColor: systemNavigationBarColor,
        systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
      ));
    } catch (e) {
      print('Failed to set system UI overlay style: $e');
    }
  }

  /// 클립보드에 텍스트를 복사합니다
  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      print('Failed to copy to clipboard: $e');
    }
  }

  /// 클립보드에서 텍스트를 가져옵니다
  static Future<String?> getFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      print('Failed to get from clipboard: $e');
      return null;
    }
  }

  /// 네트워크 연결 상태를 확인합니다 (간단한 구현)
  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
