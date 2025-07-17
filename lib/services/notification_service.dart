import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // 전역 네비게이션 키 (앱 전체에서 사용)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 알림 채널들 설정
  static const AndroidNotificationChannel postLikeChannel = AndroidNotificationChannel(
    'post_like_notifications',
    '게시글 좋아요 알림',
    description: '내 게시글에 좋아요가 눌렸을 때 알림을 받습니다.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel postCommentChannel = AndroidNotificationChannel(
    'post_comment_notifications',
    '게시글 댓글 알림',
    description: '내 게시글에 댓글이 달렸을 때 알림을 받습니다.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel commentReplyChannel = AndroidNotificationChannel(
    'comment_reply_notifications',
    '대댓글 알림',
    description: '내 댓글에 대댓글이 달렸을 때 알림을 받습니다.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel commentLikeChannel = AndroidNotificationChannel(
    'comment_like_notifications',
    '댓글 좋아요 알림',
    description: '내 댓글에 좋아요가 눌렸을 때 알림을 받습니다.',
    importance: Importance.high,
  );

  /// FCM 초기화
  Future<void> initialize() async {
    // 권한 요청
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('FCM 권한 승인됨');
    } else {
      print('FCM 권한 거부됨');
    }

    // 로컬 알림 초기화
    await _initializeLocalNotifications();

    // 포그라운드 메시지 핸들러
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드 메시지 핸들러 (앱이 백그라운드에서 알림 클릭)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // 앱이 종료된 상태에서 알림 클릭으로 앱 실행
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleInitialMessage(initialMessage);
    }

    // FCM 토큰 저장
    await _saveFCMToken();
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // 알림 채널들 생성 (Android만 해당)
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(postLikeChannel);
      await androidImplementation.createNotificationChannel(postCommentChannel);
      await androidImplementation.createNotificationChannel(commentReplyChannel);
      await androidImplementation.createNotificationChannel(commentLikeChannel);
    }
  }

  /// 포그라운드 메시지 처리 (앱이 열려있을 때)
  void _handleForegroundMessage(RemoteMessage message) async {
    print('포그라운드 메시지 수신: ${message.data}');
    
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
    
    if (specificNotificationEnabled) {
      // 개별 알림이 켜져있을 때만 로컬 알림 생성
      _showLocalNotification(message);
    } else {
      print('$type 알림이 꺼져있어서 포그라운드 알림을 생성하지 않습니다.');
    }
  }

  /// 로컬 알림 생성
  void _showLocalNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final notificationTitle = data['notificationTitle'] ?? '알림';
    final notificationBody = data['notificationBody'] ?? '';
    
    // 알림 타입에 따라 적절한 채널 선택
    final channelId = data['channelId'] ?? 'post_like_notifications';
    
    // 알림 ID 생성 (중복 방지)
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    _localNotifications.show(
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
      payload: jsonEncode(data), // 딥링크 데이터를 JSON으로 직렬화
    );
  }

  /// 백그라운드 메시지 처리 (앱이 백그라운드에서 알림 클릭)
  void _handleBackgroundMessage(RemoteMessage message) {
    print('백그라운드 메시지 클릭: ${message.data}');
    _handleDeepLink(message.data);
  }

  /// 초기 메시지 처리 (앱이 종료된 상태에서 알림 클릭으로 실행)
  void _handleInitialMessage(RemoteMessage message) {
    print('초기 메시지: ${message.data}');
    // 앱이 완전히 로드된 후 딥링크 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeepLink(message.data);
    });
  }

  /// 로컬 알림 클릭 처리
  void _onLocalNotificationTapped(NotificationResponse response) {
    print('로컬 알림 클릭: ${response.payload}');
    
    if (response.payload != null) {
      try {
        // payload에서 딥링크 데이터 파싱
        final payloadString = response.payload!;
        final data = _parsePayloadToMap(payloadString);
        
        if (data.isNotEmpty) {
          _handleDeepLink(data);
        }
      } catch (e) {
        print('로컬 알림 payload 파싱 오류: $e');
      }
    }
  }

  /// payload 문자열을 Map으로 파싱
  Map<String, dynamic> _parsePayloadToMap(String payload) {
    try {
      // payload를 JSON으로 파싱
      return Map<String, dynamic>.from(
        jsonDecode(payload) as Map,
      );
    } catch (e) {
      print('payload 파싱 오류: $e');
      return {};
    }
  }

  /// 딥링크 처리
  void _handleDeepLink(Map<String, dynamic> data) {
    final type = data['type'];
    final postId = data['postId'];
    final date = data['date'];
    final boardId = data['boardId'] ?? 'free'; // 게시판 ID
    final boardName = data['boardName'] ?? '자유게시판'; // 게시판 이름

    if (type == null || postId == null || date == null) {
      print('딥링크 데이터 누락: $data');
      _showErrorToast('유효하지 않은 알림입니다.');
      return;
    }

    print('딥링크 처리: type=$type, postId=$postId, date=$date, boardId=$boardId, boardName=$boardName');

    switch (type) {
      case 'post_like':
        _navigateToPostDetail(postId, date, boardId, boardName);
        break;
      case 'post_comment':
        final commentId = data['commentId'];
        _navigateToPostDetailWithComment(postId, date, boardId, boardName, commentId);
        break;
      case 'comment_reply':
        final commentId = data['commentId'];
        _navigateToPostDetailWithComment(postId, date, boardId, boardName, commentId);
        break;
      case 'comment_like':
        final commentId = data['commentId'];
        _navigateToPostDetailWithComment(postId, date, boardId, boardName, commentId);
        break;
      default:
        print('알 수 없는 알림 타입: $type');
        _showErrorToast('알 수 없는 알림 타입입니다.');
    }
  }

  /// 게시글 상세 페이지로 이동 (좋아요 알림)
  void _navigateToPostDetail(String postId, String date, String boardId, String boardName) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(
        '/community/detail',
        arguments: {
          'postId': postId,
          'dateString': date,
          'boardId': boardId,
          'boardName': boardName,
        },
      );
    }
  }

  /// 게시글 상세 페이지로 이동 + 특정 댓글 스크롤
  void _navigateToPostDetailWithComment(String postId, String date, String boardId, String boardName, String? commentId) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(
        '/community/detail',
        arguments: {
          'postId': postId,
          'dateString': date,
          'boardId': boardId,
          'boardName': boardName,
          'scrollToCommentId': commentId, // 댓글 스크롤용
        },
      );
    }
  }

  /// FCM 토큰 저장
  Future<void> _saveFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
          print('FCM 토큰 저장 완료: $token');
        }
      }
    } catch (e) {
      print('FCM 토큰 저장 오류: $e');
    }
  }

  /// FCM 토큰 갱신 처리
  void setupTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('FCM 토큰 갱신 완료: $token');
      }
    });
  }

  /// 에러 토스트 메시지 표시
  void _showErrorToast(String message) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 채널 이름 가져오기
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

  /// 채널 설명 가져오기
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
        return '알림';
    }
  }
} 