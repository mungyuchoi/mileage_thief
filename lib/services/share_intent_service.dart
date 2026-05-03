import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

class ShareIntentService {
  static const MethodChannel _channel = MethodChannel('milecatch/share_intent');
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedContent') {
        await _openPostCreateFromSharedContent(call.arguments);
      }
    });

    try {
      final initialContent =
          await _channel.invokeMethod<dynamic>('getInitialSharedContent');
      await _openPostCreateFromSharedContent(initialContent);
      await _channel.invokeMethod<void>('clearInitialSharedContent');
    } catch (e) {
      debugPrint('ShareIntentService init error: $e');
    }
  }

  static Future<void> _openPostCreateFromSharedContent(
      dynamic rawContent) async {
    final args = _buildRouteArguments(rawContent);
    if (args == null) return;

    Future<void> pushWhenReady([int attempt = 0]) async {
      final navigator = NotificationService.navigatorKey.currentState;
      if (navigator == null) {
        if (attempt >= 8) return;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        return pushWhenReady(attempt + 1);
      }

      navigator.pushNamed('/community/create_v3', arguments: args);
    }

    unawaited(pushWhenReady());
  }

  static Map<String, dynamic>? _buildRouteArguments(dynamic rawContent) {
    if (rawContent is! Map) return null;

    final text = (rawContent['text'] ?? '').toString().trim();
    final subject = (rawContent['subject'] ?? '').toString().trim();
    final imagePaths = (rawContent['imagePaths'] as List?)
            ?.whereType<String>()
            .where((path) => path.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    if (text.isEmpty && subject.isEmpty && imagePaths.isEmpty) return null;

    return {
      'initialBoardId': 'free',
      'initialBoardName': '자유게시판',
      'sharedText': text,
      'sharedSubject': subject,
      'sharedImagePaths': imagePaths,
    };
  }
}
