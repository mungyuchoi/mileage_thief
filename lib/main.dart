import 'package:flutter/material.dart';
import 'package:mileage_thief/screen/search_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/fcm_service.dart';

// 전역 NavigatorKey 추가
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  
  // FCM 초기화
  await FCMService.initialize();
  
  MobileAds.instance.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool value = prefs.getBool('notification') ?? true;
  if (value) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('MQ! User granted permission: ${settings.authorizationStatus}');
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');

      // GlobalKey를 통해 context 접근
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false, // 팝업 외부 터치로 닫히지 않음
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.flight_takeoff, color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.notification!.title ?? '취소표 알림',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.notification!.body ?? '',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  if (message.data.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.data['fromAirport'] != null && message.data['toAirport'] != null)
                            Text(
                              '노선: ${message.data['fromAirport']} → ${message.data['toAirport']}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          if (message.data['dates'] != null)
                            Text(
                              '날짜: ${message.data['dates']}',
                              style: TextStyle(fontSize: 14),
                            ),
                          if (message.data['seatClasses'] != null)
                            Text(
                              '좌석: ${message.data['seatClasses']}',
                              style: TextStyle(fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  });
  final fcmToken = await FirebaseMessaging.instance.getToken();
  await initializeDateFormatting();
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'NanumGothic',
    ),
    routes: {
      '/': (context) => SearchScreen(),
      // '/search': (context) => SearchScreen(),
    },
  ));
}
