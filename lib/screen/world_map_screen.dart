import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/world_share_service.dart';

/// milecatch 웹(세계지도 게임)을 임베드하는 탭.
///
/// 설계: docs/world-travel-game-design.md §11
/// 웹은 flutter_inappwebview JS 브리지로 네이티브 기능을 빌려 쓴다:
///   auth.requestToken / share.openSheet / haptic.tap / nav.exitToNative
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  /// TODO: 배포 후 milecatch 웹 스테이징/운영 URL로 교체.
  ///  - Firebase Hosting(mileagethief) 배포 URL 예: https://mileagethief.web.app/explore
  static const String webUrl = 'https://mileagethief.web.app/explore';

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(WorldMapScreen.webUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
              // 파일 input(<input type=file>) + 카메라 업로드 핵심
              useOnDownloadStart: true,
              supportZoom: false,
            ),
            onWebViewCreated: _registerHandlers,
            onLoadStop: (_, __) {
              if (mounted) setState(() => _loading = false);
            },
            // 웹의 getUserMedia / 파일 선택 권한 승인
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _registerHandlers(InAppWebViewController controller) {
    _controller = controller;

    // auth.requestToken → customToken 반환 (signInWithCustomToken용)
    controller.addJavaScriptHandler(
      handlerName: 'auth.requestToken',
      callback: (args) async {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return {'token': ''};
          // TODO: 'createWebViewCustomToken' Cloud Function 배포 필요
          // (admin.auth().createCustomToken(uid) 반환).
          final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('createWebViewCustomToken');
          final result = await callable.call();
          final token = (result.data?['token'] ?? '').toString();
          return {'token': token};
        } catch (e) {
          debugPrint('[WorldMap] auth.requestToken 실패: $e');
          return {'token': '', 'error': e.toString()};
        }
      },
    );

    // share.openSheet → 커뮤니티 글 생성 + Branch 공유 시트
    controller.addJavaScriptHandler(
      handlerName: 'share.openSheet',
      callback: (args) async {
        final payload = (args.isNotEmpty && args.first is Map)
            ? Map<String, dynamic>.from(args.first as Map)
            : <String, dynamic>{};
        final postId = await WorldShareService.shareRecordToCommunity(
          title: (payload['title'] ?? '').toString(),
          description: (payload['description'] ?? '').toString(),
          boardId: (payload['boardId'] ?? 'review').toString(),
          boardName: (payload['boardName'] ?? '항공 리뷰').toString(),
          imageUrl: (payload['imageUrl'] ?? '').toString(),
          countryNameKo: (payload['countryNameKo'] ?? '').toString(),
        );
        return {'ok': postId != null, 'postId': postId ?? ''};
      },
    );

    // haptic.tap → 가벼운 진동
    controller.addJavaScriptHandler(
      handlerName: 'haptic.tap',
      callback: (args) async {
        HapticFeedback.lightImpact();
        return {'ok': true};
      },
    );

    // nav.exitToNative → 네이티브 이전 탭 복귀 (현재는 no-op, 탭 컨테이너가 처리)
    controller.addJavaScriptHandler(
      handlerName: 'nav.exitToNative',
      callback: (args) async => {'ok': true},
    );
  }
}
