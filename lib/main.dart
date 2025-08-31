import 'package:flutter/material.dart';
import 'package:mileage_thief/screen/search_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/notification_service.dart';
import 'services/branch_service.dart';
import 'screen/community_board_select_screen.dart';
import 'screen/community_detail_screen.dart';
import 'screen/community_post_create_screen_v3.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';

// 전역 NavigatorKey (NotificationService에서 사용)
final GlobalKey<NavigatorState> navigatorKey = NotificationService.navigatorKey;

// 백그라운드 알림 생성 함수
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
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
  final androidImplementation = localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
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
  }
  
  // 알림 데이터 추출
  final data = message.data;
  final type = data['type'];
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
    default:
      return '';
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    print("Firebase initialization error in background handler: $e");
  }
  
  print("Handling a background message: ${message.messageId}");
  
  // 개별 알림 설정 확인
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final type = message.data['type'];
  bool specificNotificationEnabled = true;
  
  switch (type) {
    case 'post_like':
      specificNotificationEnabled = prefs.getBool('post_like_notification') ?? true;
      break;
    case 'post_comment':
      specificNotificationEnabled = prefs.getBool('post_comment_notification') ?? true;
      break;
    case 'comment_reply':
      specificNotificationEnabled = prefs.getBool('comment_reply_notification') ?? true;
      break;
    case 'comment_like':
      specificNotificationEnabled = prefs.getBool('comment_like_notification') ?? true;
      break;
  }
  
  if (!specificNotificationEnabled) {
    print('$type 알림이 꺼져있어서 백그라운드 알림을 생성하지 않습니다.');
    return;
  }
  
  // 알림 생성
  await _showBackgroundNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("Firebase already initialized: $e");
  }

  // 백그라운드 메시지 핸들러는 항상 등록 (핸들러 내에서 설정값 확인)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 첫 프레임을 먼저 그리도록 runApp을 우선 호출
  runApp(const MyApp());

  // 나머지 경량 초기화는 병렬/비차단으로 수행
  unawaited(_postFirstFrameInitializations());
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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 프레임 이후에 무거운 초기화 실행 (앱 진입 지연 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService().initialize();
        NotificationService().setupTokenRefresh();
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
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NanumGothic',
      ),
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
        '/': (context) => SearchScreen(),
        '/community_board_select': (context) => const CommunityBoardSelectScreen(),
        '/community/detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CommunityDetailScreen(
            postId: args['postId'],
            dateString: args['dateString'],
            boardId: args['boardId'] ?? 'free',
            boardName: args['boardName'] ?? '자유게시판',
            scrollToCommentId: args['scrollToCommentId'],
          );
        },
        '/community/create_v3': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CommunityPostCreateScreenV3(
            initialBoardId: args?['initialBoardId'],
            initialBoardName: args?['initialBoardName'],
            isEditMode: args?['isEditMode'] ?? false,
            postId: args?['postId'],
            dateString: args?['dateString'],
            editTitle: args?['editTitle'],
            editContentHtml: args?['editContentHtml'],
          );
        },
      },
    );
  }
}
