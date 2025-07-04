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
import 'package:flutter_localizations/flutter_localizations.dart';

// 전역 NavigatorKey (NotificationService에서 사용)
final GlobalKey<NavigatorState> navigatorKey = NotificationService.navigatorKey;

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
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("Firebase already initialized: $e");
  }

  // 알림 서비스 초기화
  await NotificationService().initialize();
  NotificationService().setupTokenRefresh();

  // Branch.io 초기화
  await BranchService().initialize();

  MobileAds.instance.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool value = prefs.getBool('notification') ?? true;
  if (value) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await initializeDateFormatting();
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'NanumGothic',
    ),
    localizationsDelegates: [
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
    },
  ));
}
