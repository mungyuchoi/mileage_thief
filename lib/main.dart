import 'package:flutter/material.dart';
import 'package:mileage_thief/screen/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/notification_service.dart';
import 'services/notification_preference_service.dart';
import 'services/branch_service.dart';
import 'services/share_intent_service.dart';
import 'services/analytics_service.dart';
import 'services/language_service.dart';
import 'l10n/app_locale.dart';
import 'screen/splash_screen.dart';
import 'screen/community_board_select_screen.dart';
import 'screen/community_chat_screen.dart';
import 'screen/community_detail_screen.dart';
import 'screen/community_post_create_screen_v3.dart';
import 'screen/card_catalog_screen.dart';
import 'screen/card_hub_screen.dart';
import 'screen/giftcard_deals_screen.dart';
import 'screen/my_card_dashboard_screen.dart';
import 'screen/point_stay_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'const/colors.dart';

// 전역 NavigatorKey (NotificationService에서 사용)
final GlobalKey<NavigatorState> navigatorKey = NotificationService.navigatorKey;
late final Future<void> _firebaseInitialization;

// 백그라운드 알림 생성 함수
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  // 로컬 알림 초기화
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await localNotifications.initialize(initializationSettings);

  // 알림 채널 생성
  final androidImplementation =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'post_like_notifications',
        '게시글 좋아요 알림',
        description: '내 게시글에 좋아요가 눌렸을 때 알림을 받습니다.',
        importance: Importance.high,
      ),
    );
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'post_comment_notifications',
        '게시글 댓글 알림',
        description: '내 게시글에 댓글이 달렸을 때 알림을 받습니다.',
        importance: Importance.high,
      ),
    );
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'comment_reply_notifications',
        '대댓글 알림',
        description: '내 댓글에 대댓글이 달렸을 때 알림을 받습니다.',
        importance: Importance.high,
      ),
    );
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'comment_like_notifications',
        '댓글 좋아요 알림',
        description: '내 댓글에 좋아요가 눌렸을 때 알림을 받습니다.',
        importance: Importance.high,
      ),
    );
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'radar_notifications',
        '마일캐치 레이더 알림',
        description: '저장한 레이더 조건에 맞는 좌석/특가/혜택 알림을 받습니다.',
        importance: Importance.high,
      ),
    );
  }

  // 알림 데이터 추출
  final data = message.data;
  final notificationTitle = data['notificationTitle'] ?? '알림';
  final notificationBody = data['notificationBody'] ?? '';

  // 알림 타입에 따른 채널 ID 선택
  final channelId = data['channelId'] ?? 'post_like_notifications';

  // 알림 ID 생성
  final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // 알림 생성
  await localNotifications.show(
    notificationId,
    notificationTitle,
    notificationBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(data),
  );
}

// 채널 이름 매핑
String _getChannelName(String channelId) {
  switch (channelId) {
    case 'post_like_notifications':
      return '게시글 좋아요 알림';
    case 'post_comment_notifications':
      return '게시글 댓글 알림';
    case 'comment_reply_notifications':
      return '대댓글 알림';
    case 'comment_like_notifications':
      return '댓글 좋아요 알림';
    case 'radar_notifications':
      return '마일캐치 레이더 알림';
    default:
      return '알림';
  }
}

// 채널 설명 매핑
String _getChannelDescription(String channelId) {
  switch (channelId) {
    case 'post_like_notifications':
      return '내 게시글에 좋아요가 눌렸을 때 알림을 받습니다.';
    case 'post_comment_notifications':
      return '내 게시글에 댓글이 달렸을 때 알림을 받습니다.';
    case 'comment_reply_notifications':
      return '내 댓글에 대댓글이 달렸을 때 알림을 받습니다.';
    case 'comment_like_notifications':
      return '내 댓글에 좋아요가 눌렸을 때 알림을 받습니다.';
    case 'radar_notifications':
      return '저장한 레이더 조건에 맞는 좌석/특가/혜택 알림을 받습니다.';
    default:
      return '';
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint("Firebase initialization error in background handler: $e");
  }

  debugPrint("Handling a background message: ${message.messageId}");

  final type = message.data['type'];
  final specificNotificationEnabled =
      await NotificationPreferenceService.isLocalEnabledForRemoteMessage(
    message.data,
  );

  if (!specificNotificationEnabled) {
    debugPrint('$type 알림이 꺼져있어서 백그라운드 알림을 생성하지 않습니다.');
    return;
  }

  // 알림 생성
  await _showBackgroundNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 백그라운드 메시지 핸들러는 항상 등록 (핸들러 내에서 설정값 확인)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  _firebaseInitialization = _initializeFirebase();

  // 스플래시 첫 프레임을 최대한 빨리 그린 뒤, Firebase는 뒤에서 준비한다.
  runApp(const MyApp());

  // 나머지 경량 초기화는 병렬/비차단으로 수행
  unawaited(_postFirstFrameInitializations());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase already initialized: $e");
  }
}

Future<void> _postFirstFrameInitializations() async {
  try {
    await initializeDateFormatting();
  } catch (_) {}
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 로그인되면 사용자의 언어 설정으로 동기화.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(LanguageService.syncFromFirestore());
      }
    });
    // 프레임 이후에 무거운 초기화 실행 (앱 진입 지연 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ShareIntentService.initialize();
      } catch (e) {
        debugPrint('ShareIntentService init error: $e');
      }
      try {
        await _firebaseInitialization;
        await AnalyticsService.instance.startUserTracking();
        unawaited(AnalyticsService.instance.logAction('app_open'));
        await NotificationService().initialize();
        NotificationService().setupTokenRefresh();
        // 앱 진입 시 최근 접속 시간 기록 (관리자 정렬용)
        _touchLastActive();
        // 언어 설정 로드(캐시 → users/{uid}.language)
        unawaited(LanguageService.init());
      } catch (e) {
        debugPrint('NotificationService init error: $e');
      }
      try {
        await BranchService().initialize();
      } catch (e) {
        debugPrint('BranchService init error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 백그라운드에서 포그라운드로 복귀할 때 최근 접속 시간 갱신.
    // 화면/네비게이션 스택은 건드리지 않는다(상태 보존).
    if (state == AppLifecycleState.resumed) {
      _touchLastActive();
    }
  }

  void _touchLastActive() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      unawaited(UserService.updateLastActive(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => _buildApp(lang),
    );
  }

  Widget _buildApp(String lang) {
    return MaterialApp(
      locale: Locale(lang),
      navigatorKey: navigatorKey,
      navigatorObservers: [AnalyticsService.routeObserver],
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/splash'),
          builder: (_) => SplashScreen(
            startupReady: _firebaseInitialization,
          ),
        ),
      ],
      theme: MileageTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
      ],
      routes: {
        '/splash': (context) => SplashScreen(
              startupReady: _firebaseInitialization,
            ),
        '/': (context) => const HomeScreen(),
        '/community_board_select': (context) =>
            const CommunityBoardSelectScreen(),
        '/community/detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return CommunityDetailScreen(
            postId: args['postId'],
            dateString: args['dateString'],
            boardId: args['boardId'] ?? 'free',
            boardName: args['boardName'] ?? '자유게시판',
            scrollToCommentId: args['scrollToCommentId'],
          );
        },
        '/community/create_v3': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CommunityPostCreateScreenV3(
            initialBoardId: args?['initialBoardId'],
            initialBoardName: args?['initialBoardName'],
            isEditMode: args?['isEditMode'] ?? false,
            postId: args?['postId'],
            dateString: args?['dateString'],
            editTitle: args?['editTitle'],
            editContentHtml: args?['editContentHtml'],
            editReadRestriction: args?['editReadRestriction'],
            sharedText: args?['sharedText'],
            sharedSubject: args?['sharedSubject'],
            sharedImagePaths: (args?['sharedImagePaths'] as List?)
                    ?.whereType<String>()
                    .toList() ??
                const <String>[],
            initialTitle: args?['initialTitle'],
            entityRefs: Map<String, dynamic>.from(
              (args?['entityRefs'] as Map?) ?? const <String, dynamic>{},
            ),
            initialLabels: (args?['labels'] as List?)
                    ?.whereType<Map>()
                    .map((map) => Map<String, dynamic>.from(map))
                    .toList() ??
                const <Map<String, dynamic>>[],
          );
        },
        '/community/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CommunityChatScreen(
            roomId: args?['roomId']?.toString() ?? 'global',
          );
        },
        '/cards': (context) => const CardHubScreen(),
        '/card': (context) => const CardHubScreen(),
        '/my-cards': (context) => const MyCardDashboardScreen(),
        '/card/detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CardProductDetailScreen(
            cardId: args?['cardId']?.toString() ?? '',
          );
        },
        '/point-stay': (context) => const PointStayScreen(),
        '/giftcard/deal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return GiftcardDealDetailScreen(
            dealId: args?['dealId']?.toString() ?? '',
          );
        },
      },
    );
  }
}
