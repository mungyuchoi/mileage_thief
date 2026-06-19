import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/opensky_live_service.dart';
import '../services/world_share_service.dart';
import 'hotel_quiz_manage_screen.dart';

/// milecatch 웹(세계지도 게임)을 임베드하는 탭.
///
/// 설계: docs/world-travel-game-design.md §11
/// 웹은 flutter_inappwebview JS 브리지로 네이티브 기능을 빌려 쓴다:
///   auth.requestToken / share.openSheet / haptic.tap / nav.exitToNative
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  /// milecatch 웹(운영) — mileagethief 프로젝트 커스텀 도메인.
  /// 새 /explore 게임 코드는 milecatch 웹을 rebuild + `firebase deploy --only hosting`
  /// 해야 라이브에 반영된다.
  static const String webUrl = 'https://milecatch.com/explore';

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

    // share.image → 웹에서 만든 이미지(dataURL PNG)를 네이티브 공유 시트로 공유
    controller.addJavaScriptHandler(
      handlerName: 'share.image',
      callback: (args) async {
        try {
          final payload = (args.isNotEmpty && args.first is Map)
              ? Map<String, dynamic>.from(args.first as Map)
              : <String, dynamic>{};
          final dataUrl = (payload['dataUrl'] ?? '').toString();
          final fileName = (payload['fileName'] ?? 'milecatch.png').toString();
          final text = (payload['text'] ?? '').toString();

          final comma = dataUrl.indexOf(',');
          if (comma < 0) return {'ok': false, 'error': 'invalid dataUrl'};
          final bytes = base64Decode(dataUrl.substring(comma + 1));

          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);

          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], text: text),
          );
          return {'ok': true};
        } catch (e) {
          debugPrint('[WorldMap] share.image 실패: $e');
          return {'ok': false, 'error': e.toString()};
        }
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

    // liveFlights.fetch → 디바이스에서 OpenSky 직접 조회.
    // 웹은 { bbox: {lamin,lomin,lamax,lomax}, key } 를 넘긴다.
    // 결과를 Firestore(flightsLive/{key})에 단일 JSON으로 캐시하고 웹에 반환.
    controller.addJavaScriptHandler(
      handlerName: 'liveFlights.fetch',
      callback: (args) async {
        try {
          final payload = (args.isNotEmpty && args.first is Map)
              ? Map<String, dynamic>.from(args.first as Map)
              : <String, dynamic>{};
          final bbox = (payload['bbox'] is Map)
              ? Map<String, dynamic>.from(payload['bbox'] as Map)
              : <String, dynamic>{};
          final key = (payload['key'] ?? '').toString();

          int asInt(dynamic v) =>
              (v is num) ? v.round() : int.tryParse('$v') ?? 0;

          final docRef = key.isEmpty
              ? null
              : FirebaseFirestore.instance.collection('flightsLive').doc(key);

          // 10분 가드 + 동시 호출 디듀프:
          // 여러 유저가 거의 동시에 불러도, 직전에 누군가 10분 내 갱신했으면
          // OpenSky를 부르지 않고 캐시를 그대로 반환한다.
          const freshMs = 10 * 60 * 1000;
          if (docRef != null) {
            try {
              final existing = await docRef.get();
              final data = existing.data();
              final ts = data?['updatedAt'];
              if (data != null && ts is Timestamp) {
                final ageMs =
                    DateTime.now().difference(ts.toDate()).inMilliseconds;
                if (ageMs < freshMs) {
                  final cachedStr = (data['flights'] ?? '[]').toString();
                  return {
                    'flights': jsonDecode(cachedStr),
                    'time': data['time'],
                    'cached': true,
                  };
                }
              }
            } catch (e) {
              debugPrint('[WorldMap] flightsLive 신선도 확인 실패: $e');
            }
          }

          final result = await OpenSkyLiveService.fetchStates(
            lamin: asInt(bbox['lamin']),
            lomin: asInt(bbox['lomin']),
            lamax: asInt(bbox['lomax']),
            lomax: asInt(bbox['lomax']),
          );
          final flights = (result['flights'] as List?) ?? const [];

          // Firestore 캐시(웹 전용 유저가 read). 단일 JSON 문자열 → write 1회.
          if (key.isNotEmpty) {
            try {
              await FirebaseFirestore.instance
                  .collection('flightsLive')
                  .doc(key)
                  .set({
                'flights': jsonEncode(flights),
                'count': flights.length,
                'time': result['time'],
                'bbox': {
                  'lamin': asInt(bbox['lamin']),
                  'lomin': asInt(bbox['lomin']),
                  'lamax': asInt(bbox['lamax']),
                  'lomax': asInt(bbox['lomax']),
                },
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              debugPrint('[WorldMap] flightsLive 캐시 write 실패: $e');
            }
          }

          return {
            'flights': flights,
            'time': result['time'],
            if (result['error'] != null) 'error': result['error'],
          };
        } catch (e) {
          debugPrint('[WorldMap] liveFlights.fetch 실패: $e');
          return {'flights': <dynamic>[], 'error': e.toString()};
        }
      },
    );

    // hotelQuiz.manage → 웹뷰를 벗어나지 않고 네이티브 퀴즈 관리 시트를 띄움
    // (리스트/수정/삭제 + OX·객관식·주관식 작성). 지도는 시트 뒤에 그대로 유지.
    controller.addJavaScriptHandler(
      handlerName: 'hotelQuiz.manage',
      callback: (args) async {
        if (!mounted) return {'ok': false};
        final payload = (args.isNotEmpty && args.first is Map)
            ? Map<String, dynamic>.from(args.first as Map)
            : <String, dynamic>{};
        final hotelId = (payload['hotelId'] ?? '').toString();
        final hotelName = (payload['hotelName'] ?? '').toString();
        if (hotelId.isEmpty) return {'ok': false};
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 44,
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: HotelQuizManageScreen(
                hotelId: hotelId,
                hotelName: hotelName,
              ),
            ),
          ),
        );
        return {'ok': true};
      },
    );
  }
}
