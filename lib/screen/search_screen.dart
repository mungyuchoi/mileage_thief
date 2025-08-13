import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/dan_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail__round_screen.dart';
import 'package:mileage_thief/screen/detail/search_detail_one_way_screen.dart';
import 'package:mileage_thief/screen/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../model/search_history.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../screen/community_screen.dart';
import '../services/remote_config_service.dart';
import '../services/notice_preference_service.dart';

// NoticePopupDialog
class NoticePopupDialog extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback onConfirm;

  const NoticePopupDialog({
    super.key,
    required this.title,
    required this.content,
    required this.buttonText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      content: Text(content, style: const TextStyle(color: Colors.black)),
      actions: [
        TextButton(
          onPressed: onConfirm,
          child: Text(buttonText, style: const TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class ForceUpdateDialog extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final String url;

  const ForceUpdateDialog({
    super.key,
    required this.title,
    required this.content,
    required this.buttonText,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      content: Text(content, style: const TextStyle(color: Colors.black)),
      actions: [
        TextButton(
          onPressed: () async {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
          child: Text(buttonText, style: const TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class SearchScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SearchScreenState();
}

const double width = 150.0;
const double height = 50.0;
const double loginAlign = -1;
const double signInAlign = 1;
const Color selectedColor = Colors.white;
const Color normalColor = Colors.white;

class _SearchScreenState extends State<SearchScreen> with WidgetsBindingObserver {
  GlobalKey<_AirportScreenState> airportScreenKey = GlobalKey();
  int _currentIndex = 0;
  final DatabaseReference _versionReference =
  FirebaseDatabase.instance.ref("VERSION");
  
  // 공지사항 제목을 저장할 변수
  String _communityNoticeTitle = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final NoticePreferenceService _noticePref = NoticePreferenceService();

  // 뒤로가기 버튼 처리 관련 변수
  DateTime? _lastBackPressTime;
  final Duration _backPressTimeLimit = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getVersion();
    _loadVersionFirebase();
    _loadCommunityNoticeTitle();
    _loadNotificationSettings();
    _checkForceUpdateAndNotice();
    _checkAuthState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('앱이 포그라운드로 돌아옴 - 로그인 상태 확인');
      _checkAuthState();
    }
  }

  Future<void> _checkAuthState() async {
    try {
      // Firebase Auth 상태 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('앱 시작 시 로그인된 사용자 발견: ${user.email}');
        // 사용자 토큰 새로고침
        await user.getIdToken(true);
        print('사용자 토큰 새로고침 완료');
        
        // SharedPreferences에 로그인 상태 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_login_email', user.email ?? '');
        await prefs.setBool('is_logged_in', true);
      } else {
        print('앱 시작 시 로그인된 사용자 없음');
        
        // SharedPreferences에서 로그인 상태 확인
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
        final lastLoginEmail = prefs.getString('last_login_email');
        
        if (isLoggedIn && lastLoginEmail != null) {
          print('SharedPreferences에서 로그인 상태 발견: $lastLoginEmail');
          // Firebase Auth 상태 복원 시도
          try {
            await FirebaseAuth.instance.authStateChanges().first;
            print('Firebase Auth 상태 복원 시도 완료');
          } catch (e) {
            print('Firebase Auth 상태 복원 실패: $e');
            // 로그인 상태 초기화
            await prefs.setBool('is_logged_in', false);
            await prefs.remove('last_login_email');
          }
        }
      }
    } catch (e) {
      print('Firebase Auth 상태 확인 오류: $e');
    }
  }

  Future<void> _checkForceUpdateAndNotice() async {
    await _remoteConfig.initialize();
    print('[강업] RemoteConfig initialized');
    print('[강업] forceUpdateEnabled: ${_remoteConfig.forceUpdateEnabled}');
    if (_remoteConfig.forceUpdateEnabled) {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final isAndroid = Platform.isAndroid;
      final requiredVersion = isAndroid
          ? _remoteConfig.forceUpdateVersionAndroid
          : _remoteConfig.forceUpdateVersionIos;
      print('[강업] currentVersion: $currentVersion, requiredVersion: $requiredVersion');
      final isLower = _isVersionLower(currentVersion, requiredVersion);
      print('[강업] _isVersionLower: $isLower');
      if (isLower) {
        if (!mounted) {
          print('[강업] 위젯이 이미 dispose됨');
          return;
        }
        print('[강업] 강제 업데이트 다이얼로그 진입');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ForceUpdateDialog(
            title: _remoteConfig.forceUpdateTitle,
            content: _remoteConfig.forceUpdateContent,
            buttonText: _remoteConfig.forceUpdateButtonText,
            url: isAndroid
                ? _remoteConfig.forceUpdateUrlAndroid
                : _remoteConfig.forceUpdateUrlIos,
          ),
        );
        return;
      }
    }
    print('[강업] 공지사항 팝업 체크로 이동');
    _checkAndShowNotice();
  }

  bool _isVersionLower(String current, String required) {
    try {
      final cur = current.split('.').map(int.parse).toList();
      final req = required.split('.').map(int.parse).toList();
      print('[강업] 버전 배열 current: $cur, required: $req');
      for (int i = 0; i < req.length; i++) {
        if (cur.length <= i || cur[i] < req[i]) return true;
        if (cur[i] > req[i]) return false;
      }
      return false;
    } catch (e) {
      print('[강업] 버전 비교 오류: $e');
      return false;
    }
  }

  Future<void> _checkAndShowNotice() async {
    await _remoteConfig.initialize();
    if (!_remoteConfig.noticePopupEnabled) return;
    final version = _remoteConfig.noticePopupVersion;
    final hasSeen = await _noticePref.hasSeenNotice(version);
    if (_remoteConfig.noticePopupShowOnce && hasSeen) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NoticePopupDialog(
        title: _remoteConfig.noticePopupTitle,
        content: _remoteConfig.noticePopupContent,
        buttonText: _remoteConfig.noticePopupButtonText,
        onConfirm: () async {
          await _noticePref.markNoticeAsSeen(version);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  // 뒤로가기 버튼 처리 메서드
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    final difference = _lastBackPressTime == null 
        ? const Duration(seconds: 3) 
        : now.difference(_lastBackPressTime!);
    
    if (difference >= _backPressTimeLimit) {
      _lastBackPressTime = now;
      
      // 토스트 메시지 표시
      Fluttertoast.showToast(
        msg: "'뒤로' 버튼을 한번 더 누르면 종료됩니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
      );
      
      return false; // 앱 종료 방지
    } else {
      return true; // 앱 종료 허용
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? '${_communityNoticeTitle.isNotEmpty ? ' $_communityNoticeTitle' : ''}'
              : _currentIndex == 1
                  ? '대한항공 마일리지 찾기'
                  : _currentIndex == 2
                      ? '아시아나 마일리지 찾기'
                      : '설정',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Image.asset(
              'asset/img/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black54),
            onPressed: () {
              String appLink = '';
              if (Platform.isAndroid) {
                appLink =
                    'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
              } else {
                appLink = 'https://apps.apple.com/app/myapp/6446247689';
              }
              String description = "마일리지 항공 앱을 공유해보세요! $appLink";
              SharePlus.instance.share(ShareParams(text: description));
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.black54),
            onPressed: _launchOpenChat,
          ),
        ],
      ),
      body: buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[200],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black, // kPrimaryDarkColor 대체
        unselectedItemColor: Colors.black, // kPrimaryDarkColor 대체
        type: BottomNavigationBarType.fixed, // 아이콘과 텍스트가 항상 함께 보임
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.people_outline_sharp),
                SizedBox(height: 2),
                Text('커뮤니티', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.airlines),
                SizedBox(height: 2),
                Text('대한항공', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.airlines),
                SizedBox(height: 2),
                Text('아시아나', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.settings),
                SizedBox(height: 2),
                Text('설정', style: TextStyle(fontSize: 12)),
              ],
            ),
            label: '',
          ),
        ],
      ),
      ),
    );
  }

  Widget buildPage(int index) {
    switch (index) {
      case 0:
        return const CommunityScreen();
      case 1:
        return buildDanWidget();
      case 2:
        return buildAsianaWidget();
      case 3:
        return buildSettingsWidget();
      default:
        return const CommunityScreen();
    }
  }

  Widget buildAsianaWidget() {
    return Stack(
      children: [
        // 1. 기존 UI 흐릿하게 보이도록
        SingleChildScrollView(
          child: AirportScreen(key: airportScreenKey),
        ),
        // 2. 반투명 안개 레이어
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white.withOpacity(0.85),
        ),
        // 3. 안내 문구
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud, size: 60, color: Colors.black54),
              SizedBox(height: 24),
              Text(
                '아시아나 기능은 안정화된 이후에 오픈됩니다.',
                style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildDanWidget() {
    return FutureBuilder<InitializationStatus>(
      future: _initGoogleMobileAds(),
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        return const SingleChildScrollView(
          child: SearchDanScreen(),
        );
      },
    );
  }


  bool _postLikeNotification = true;
  bool _postCommentNotification = true;
  bool _commentReplyNotification = true;
  bool _commentLikeNotification = true;
  String _version = '';
  String _latestVersion = '';

  Widget buildSettingsWidget() {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          return SettingsList(
            platform: DevicePlatform.iOS,
            sections: [
              SettingsSection(
                title: const Text('알림 설정'),
                tiles: [

                  SettingsTile.switchTile(
                    initialValue: _postLikeNotification,
                    onToggle: (bool value) {
                      setPostLikeNotification(value);
                      setState(() {
                        _postLikeNotification = value;
                      });
                    },
                    title: const Text('게시글 좋아요 알림'),
                    leading: const Icon(Icons.thumb_up_outlined),
                    activeSwitchColor: Colors.black54,
                  ),
                  SettingsTile.switchTile(
                    initialValue: _postCommentNotification,
                    onToggle: (bool value) {
                      setPostCommentNotification(value);
                      setState(() {
                        _postCommentNotification = value;
                      });
                    },
                    title: const Text('게시글 댓글 알림'),
                    leading: const Icon(Icons.comment_outlined),
                    activeSwitchColor: Colors.black54,
                  ),
                  SettingsTile.switchTile(
                    initialValue: _commentReplyNotification,
                    onToggle: (bool value) {
                      setCommentReplyNotification(value);
                      setState(() {
                        _commentReplyNotification = value;
                      });
                    },
                    title: const Text('대댓글 알림'),
                    leading: const Icon(Icons.reply_outlined),
                    activeSwitchColor: Colors.black54,
                  ),
                  SettingsTile.switchTile(
                    initialValue: _commentLikeNotification,
                    onToggle: (bool value) {
                      setCommentLikeNotification(value);
                      setState(() {
                        _commentLikeNotification = value;
                      });
                    },
                    title: const Text('댓글 좋아요 알림'),
                    leading: const Icon(Icons.favorite_border_outlined),
                    activeSwitchColor: Colors.black54,
                  ),
                ],
              ),
              SettingsSection(
                title: const Text('계정'),
                tiles: [
                  SettingsTile(
                    onPressed: (context) => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      )
                    },
                    title: Text(user == null ? '로그인' : '내 정보'),
                    description: Text(user == null 
                      ? '로그인하여 땅콩을 클라우드에 저장하세요'
                      : '${user.displayName ?? user.email ?? "사용자"}님, 안녕하세요!'),
                    leading: Icon(user == null ? Icons.login : Icons.account_circle_outlined),
                  ),
                  SettingsTile(
                    onPressed: (context) => {
                      _launchMileageThief(AdHelper.mileageTheifMarketUrl)
                    },
                    title: const Text("스토어로 이동"),
                    leading: const Icon(Icons.info_outline),
                  ),
                  SettingsTile(
                    onPressed: (context) async {
                      final info = await PackageInfo.fromPlatform();
                      final deviceInfoPlugin = DeviceInfoPlugin();
                      String os = '';
                      String model = '';
                      if (Platform.isAndroid) {
                        final androidInfo = await deviceInfoPlugin.androidInfo;
                        os = 'Android ${androidInfo.version.release}';
                        model = androidInfo.model ?? '';
                      } else if (Platform.isIOS) {
                        final iosInfo = await deviceInfoPlugin.iosInfo;
                        os = 'iOS ${iosInfo.systemVersion}';
                        model = iosInfo.utsname.machine ?? '';
                      }
                      final body = Uri.encodeComponent('문의내역:\n버전: ${info.version}\nOS: $os\n모델명: $model');
                      final uri = Uri.parse('mailto:skylife927@gmail.com?subject=FAQ 문의&body=$body');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        Fluttertoast.showToast(msg: '이메일 앱을 열 수 없습니다.');
                      }
                    },
                    title: const Text('FAQ'),
                    leading: const Icon(Icons.question_answer_outlined),
                  ),
                  SettingsTile(
                    onPressed: (context) => {
                      _version == _latestVersion
                          ? Fluttertoast.showToast(
                              msg: "최신버전입니다.",
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 5,
                              backgroundColor: Colors.grey[800],
                              fontSize: 16,
                              textColor: Colors.white,
                              toastLength: Toast.LENGTH_SHORT,
                            )
                          : Fluttertoast.showToast(
                              msg: "최신버전이 아닙니다. 업데이트 부탁드립니다.",
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 5,
                              backgroundColor: Colors.grey[800],
                              fontSize: 16,
                              textColor: Colors.white,
                              toastLength: Toast.LENGTH_SHORT,
                            )
                    },
                    title: const Text('버전 정보'),
                    description: Text(_version == _latestVersion
                        ? 'Version: $_version (최신버전입니다.)'
                        : 'Version: $_version (최신버전이 아닙니다.)'),
                    leading: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<InitializationStatus> _initGoogleMobileAds() {
    return MobileAds.instance.initialize();
  }

  Future<void> getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  void _launchOpenChat() async {
    const url = 'https://open.kakao.com/o/grMdcJ7e';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }



  void setPostLikeNotification(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('post_like_notification', value);
    Fluttertoast.showToast(
      msg: value ? "게시글 좋아요 알림을 켰습니다." : "게시글 좋아요 알림을 껐습니다.",
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.black38,
      fontSize: 16,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void setPostCommentNotification(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('post_comment_notification', value);
    Fluttertoast.showToast(
      msg: value ? "게시글 댓글 알림을 켰습니다." : "게시글 댓글 알림을 껐습니다.",
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.black38,
      fontSize: 16,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void setCommentReplyNotification(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('comment_reply_notification', value);
    Fluttertoast.showToast(
      msg: value ? "대댓글 알림을 켰습니다." : "대댓글 알림을 껐습니다.",
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.black38,
      fontSize: 16,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void setCommentLikeNotification(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('comment_like_notification', value);
    Fluttertoast.showToast(
      msg: value ? "댓글 좋아요 알림을 켰습니다." : "댓글 좋아요 알림을 껐습니다.",
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.black38,
      fontSize: 16,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _loadVersionFirebase() {
    _versionReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        if (Platform.isAndroid && values.containsKey('androidLatest')) {
          _latestVersion = values['androidLatest'];
        } else if (Platform.isIOS && values.containsKey('iosLatest')) {
          _latestVersion = values['iosLatest'];
        } else {
          _latestVersion = '';
        }
        setState(() {});
      }
    });
  }

  void _loadCommunityNoticeTitle() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notice')
          .doc('community')
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _communityNoticeTitle = data['title'] ?? '';
        });
      }
    } catch (e) {
      print('공지사항 제목 로드 실패: $e');
    }
  }

  void _loadNotificationSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
  
      _postLikeNotification = prefs.getBool('post_like_notification') ?? true;
      _postCommentNotification = prefs.getBool('post_comment_notification') ?? true;
      _commentReplyNotification = prefs.getBool('comment_reply_notification') ?? true;
      _commentLikeNotification = prefs.getBool('comment_like_notification') ?? true;
    });
  }

  _launchMileageThief(String mileageTheifMarketUrl) async {
    String appLink;
    if (Platform.isAndroid) {
      appLink = 'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
    } else {
      appLink = 'https://apps.apple.com/app/myapp/6446247689';
    }
    
    if (await canLaunch(appLink)) {
      await launch(appLink);
    } else {
      throw '마켓을 열 수 없습니다: $appLink';
    }
  }
}

class AirportScreen extends StatefulWidget {
  const AirportScreen({super.key});

  @override
  State<StatefulWidget> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  double xAlign = 5.0;
  Color loginColor = Colors.black;
  Color signInColor = Colors.black;
  List<String> airportItems = [];
  String? dateSelectedValue = "전체";
  String? departureSelectedValue = "서울|인천-ICN";
  String? arrivalSelectedValue;
  bool _arrivalError = false;
  late BannerAd _banner;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  final DatabaseReference _countryReference =
      FirebaseDatabase.instance.ref("COUNTRY");
  int startMonth = DateTime.now().month, startYear = DateTime.now().year;
  int endMonth = DateTime.now().month, endYear = DateTime.now().year + 1;
  int firstEnableMonth = DateTime.now().month,
      lastEnableMonth = DateTime.now().month;
  int _counter = 3;
  bool isLoading = false;
  List<SearchHistory> searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadCounter();
    _loadCountryFirebase();
    xAlign = loginAlign;
    loginColor = selectedColor;
    signInColor = normalColor;

    _banner = BannerAd(
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError err) {
          FirebaseAnalytics.instance
              .logEvent(name: "banner", parameters: {'error': err.message});
        },
        onAdLoaded: (_) {},
      ),
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
    )..load();
    _loadRewardedAd();
  }

  _loadCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = (prefs.getInt('counter') ?? 3);
    });
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              setState(() {
                ad.dispose();
                _rewardedAd = null;
              });
              _loadRewardedAd();
            },
          );

          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
          print('Failed to load a rewarded ad: ${err.message}');
          FirebaseAnalytics.instance
              .logEvent(name: "rewards", parameters: {'error': err.message});
        },
      ),
    );
  }

  void _loadCountryFirebase() {
    print("loadCountryFirebase!");
    _countryReference.once().then((event) {
      final snapshot = event.snapshot;
      Map<dynamic, dynamic>? values = snapshot.value as Map<dynamic, dynamic>?;
      if (values != null) {
        airportItems.clear();
        values.forEach((key, value) {
          airportItems.add(key);
        });
        airportItems.remove("서울|인천-ICN");
        airportItems.insert(0, "서울|인천-ICN");
        setState(() {});
      }
    });
  }

  Future<void> showFrontAd() async {
    isLoading = true;
    setState(() {});
    InterstitialAd.load(
      adUnitId: AdHelper.frontBannerAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _incrementCounter(2);
              isLoading = false;
              setState(() {});
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              isLoading = false;
              setState(() {});
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          isLoading = false;
          setState(() {});
        },
      ),
    );
  }

  void showRewardsAd() {
    print("showRewardsAd _rewardedAd:$_rewardedAd");
    _rewardedAd?.show(onUserEarnedReward: (_, reward) {
      _incrementCounter(10);
    });
  }

  _incrementCounter(int peanuts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = (prefs.getInt('counter') ?? 0) + peanuts;
      prefs.setInt('counter', _counter);
      
      // 로그인 상태 확인 후 Firestore 업데이트
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        UserService.updatePeanutCount(currentUser.uid, _counter).catchError((error) {
          print('Firestore 업데이트 오류: $error');
        });
      }
      
      Fluttertoast.showToast(
        msg: "땅콩 $peanuts개를 얻었습니다.",
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 5,
        backgroundColor: Colors.black38,
        fontSize: 20,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );
    });
  }

  _decrementCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter--;
      prefs.setInt('counter', _counter);
    });
  }

  bool useCounter() {
    if (_counter <= 0) {
      Fluttertoast.showToast(
        msg: "땅콩(광고) 버튼을 선택하여 땅콩을 얻으세요!",
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black38,
        fontSize: 13,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
    setState(() {
      _decrementCounter();
    });
    return true;
  }

  @override
  void dispose() {
    _banner.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(top: 30),
          decoration: const BoxDecoration(
            color: Color(0x80D60815),
            borderRadius: BorderRadius.all(
              Radius.circular(50.0),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(xAlign, 0),
                duration: Duration(milliseconds: 300),
                child: Container(
                  width: width * 0.5,
                  height: height,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD60815),
                    borderRadius: BorderRadius.all(
                      Radius.circular(50.0),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = loginAlign;
                    loginColor = selectedColor;
                    signInColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(-1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '편도',
                      style: TextStyle(
                        color: loginColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = signInAlign;
                    signInColor = selectedColor;
                    loginColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '왕복',
                      style: TextStyle(
                        color: signInColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
            padding: const EdgeInsets.all(15),
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: ListView(
              padding: const EdgeInsets.all(4),
              children: <Widget>[
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(4)),
                Row(
                  children: [
                    Expanded(
                      child: CustomDropdownButton2(
                        hint: '어디서 가나요?',
                        dropdownWidth: 180,
                        dropdownItems: airportItems,
                        hintAlignment: Alignment.center,
                        value: departureSelectedValue,
                        scrollbarAlwaysShow: true,
                        scrollbarThickness: 10,
                        onChanged: (value) {
                          setState(() {
                            departureSelectedValue = value;
                          });
                        },
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    IconButton(
                      icon: const Icon(Icons.loop_sharp, color: Colors.black54),
                      onPressed: () {
                        setState(() {
                          var tempValue = departureSelectedValue;
                          departureSelectedValue = arrivalSelectedValue;
                          arrivalSelectedValue = tempValue;
                        });
                      },
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomDropdownButton2(
                            hint: '어디로 가나요?',
                            dropdownWidth: 180,
                            hintAlignment: Alignment.center,
                            dropdownItems: airportItems,
                            value: arrivalSelectedValue,
                            scrollbarAlwaysShow: true,
                            scrollbarThickness: 10,
                            onChanged: (value) {
                              setState(() {
                                arrivalSelectedValue = value;
                                _arrivalError = false;
                              });
                            },
                          ),
                          if (_arrivalError)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text(
                                '도착지를 선택하세요.',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(4)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                if (searchHistory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: searchHistory.map((h) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              departureSelectedValue = h.departure;
                              arrivalSelectedValue = h.arrival;
                              startYear = h.startYear;
                              startMonth = h.startMonth;
                              endYear = h.endYear;
                              endMonth = h.endMonth;
                            });
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${h.departure} - ${h.arrival}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                                      Text('${h.startYear}.${h.startMonth} ~ ${h.endYear}.${h.endMonth}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.black54),
                                splashRadius: 10,
                                onPressed: () {
                                  setState(() {
                                    searchHistory.remove(h);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.all(4)),
                  const Divider(
                    color: Colors.black,
                    thickness: 2,
                  ),
                ],
                const Padding(padding: EdgeInsets.all(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    ElevatedButton(
                        onPressed: () async {
                          final selected = await showMonthPicker(
                            context: context,
                            initialDate: DateTime(startYear, startMonth),
                            firstDate: DateTime(DateTime.now().year, 1),
                            lastDate: DateTime(DateTime.now().year + 1, 12),
                            monthPickerDialogSettings: MonthPickerDialogSettings(
                              dialogSettings: PickerDialogSettings(
                                dialogBackgroundColor: Colors.white,
                                locale: Locale('ko'),
                              ),
                              headerSettings: PickerHeaderSettings(
                                headerBackgroundColor: Color(0xFFD60815),
                              ),
                              dateButtonsSettings: PickerDateButtonsSettings(
                                unselectedMonthsTextColor: Colors.black,
                                selectedMonthTextColor: Colors.black,
                                currentMonthTextColor: Colors.black,
                              ),
                              actionBarSettings: PickerActionBarSettings(
                                confirmWidget: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                cancelWidget: Text(
                                  '취소',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              startYear = selected.year;
                              startMonth = selected.month;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Color(0x80D60815),
                            minimumSize: const Size(110, 40)),
                        child: Text(
                          "시작일 $startYear년 $startMonth월",
                          style: const TextStyle(fontSize: 13),
                        )),
                    const SizedBox(width: 10),
                    ElevatedButton(
                        onPressed: () async {
                          final selected = await showMonthPicker(
                            context: context,
                            initialDate: DateTime(endYear, endMonth),
                            firstDate: DateTime(DateTime.now().year, 1),
                            lastDate: DateTime(DateTime.now().year + 1, 12),
                            monthPickerDialogSettings: MonthPickerDialogSettings(
                              dialogSettings: PickerDialogSettings(
                                dialogBackgroundColor: Colors.white,
                                locale: Locale('ko'),
                              ),
                              headerSettings: PickerHeaderSettings(
                                headerBackgroundColor: Color(0xFFD60815),
                              ),
                              dateButtonsSettings: PickerDateButtonsSettings(
                                unselectedMonthsTextColor: Colors.black,
                                selectedMonthTextColor: Colors.black,
                                currentMonthTextColor: Colors.black,
                              ),
                              actionBarSettings: PickerActionBarSettings(
                                confirmWidget: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                cancelWidget: Text(
                                  '취소',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              endYear = selected.year;
                              endMonth = selected.month;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Color(0x80D60815),
                            minimumSize: const Size(110, 40)),
                        child: Text(
                          "종료일 $endYear년 $endMonth월",
                          style: const TextStyle(fontSize: 13),
                        )),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(4)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                Text(
                  '땅콩: $_counter개',
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const Padding(padding: EdgeInsets.all(3)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () async {
                        if (isLoading) {
                          Fluttertoast.showToast(
                            msg: "아직 준비되지 않았습니다. 조금 있다가 다시 시도해보세요",
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.black54,
                            textColor: Colors.white,
                          );
                          return;
                        }
                        await showFrontAd();
                      },
                      label: const Text("+ 2",
                          style: TextStyle(color: Colors.black87)),
                      backgroundColor: Colors.white,
                      elevation: 3,
                      icon: Image.asset(
                        'asset/img/peanut.png',
                        scale: 19,
                      ),
                    ),
                    FloatingActionButton.extended(
                      onPressed: () {
                        showRewardsAd();
                      },
                      label: const Text("+ 10",
                          style: TextStyle(color: Colors.black87)),
                      backgroundColor: Colors.white,
                      elevation: 3,
                      icon: Image.asset(
                        'asset/img/peanuts.png',
                        scale: 19,
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(3)),
                const Text("땅콩을 모아서 커뮤니티의 다양한 혜택을 누려보세요!", textAlign: TextAlign.center),
                const Padding(padding: EdgeInsets.all(3)),
                ElevatedButton(
                  onPressed: () {
                    if (arrivalSelectedValue == null || arrivalSelectedValue!.isEmpty) {
                      setState(() {
                        _arrivalError = true;
                      });
                      Fluttertoast.showToast(
                        msg: "도착지를 선택해주세요.",
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.black54,
                        textColor: Colors.white,
                      );
                      return;
                    }
                    if (departureSelectedValue == null || departureSelectedValue!.isEmpty) {
                      Fluttertoast.showToast(
                        msg: "출발지를 선택해주세요.",
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.black54,
                        textColor: Colors.white,
                      );
                      return;
                    }
                    if (xAlign == -1.0) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  SearchDetailScreen(SearchModel(
                                    isRoundTrip: xAlign == -1.0 ? true : false,
                                    departureAirport: departureSelectedValue,
                                    arrivalAirport: arrivalSelectedValue,
                                    seatClass: '',
                                    searchDate: dateSelectedValue,
                                    startMonth:
                                        startMonth.toString().padLeft(2, '0'),
                                    startYear: startYear.toString(),
                                    endMonth:
                                        endMonth.toString().padLeft(2, '0'),
                                    endYear: endYear.toString(),
                                  ))));
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SearchDetailRoundScreen(
                                  SearchModel(
                                      isRoundTrip:
                                          xAlign == -1.0 ? true : false,
                                      departureAirport: departureSelectedValue,
                                      arrivalAirport: arrivalSelectedValue,
                                      seatClass: '',
                                      searchDate: dateSelectedValue,
                                      startMonth:
                                          startMonth.toString().padLeft(2, '0'),
                                      startYear: startYear.toString(),
                                      endMonth:
                                          endMonth.toString().padLeft(2, '0'),
                                      endYear: endYear.toString()))));
                    }
                    // 히스토리 추가
                    final newHistory = SearchHistory(
                      departure: departureSelectedValue ?? '',
                      arrival: arrivalSelectedValue ?? '',
                      startYear: startYear,
                      startMonth: startMonth,
                      endYear: endYear,
                      endMonth: endMonth,
                    );
                    setState(() {
                      searchHistory.remove(newHistory); // 중복 제거
                      searchHistory.insert(0, newHistory); // 맨 앞에 추가
                      if (searchHistory.length > 3) {
                        searchHistory = searchHistory.sublist(0, 3);
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: const Color(0xFFD60815),
                      minimumSize: const Size.fromHeight(56.0)),
                  child: const Text(
                    "검색하기",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              ],
            )),
      ],
    );
  }
}
