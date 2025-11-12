import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
// import 'package:mileage_thief/screen/dan_screen.dart';
import 'package:mileage_thief/screen/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../screen/community_screen.dart';
import '../services/remote_config_service.dart';
import 'giftcard_map_screen.dart';
import '../services/notice_preference_service.dart';
// import 'package:mileage_thief/screen/asiana_screen.dart' as asiana;
import 'giftcard_info_screen.dart';
import '../widgets/gift_action_pill.dart';
import '../branch/card_manage.dart';
import '../branch/card_step.dart';
import '../branch/wheretobuy_manage.dart';
import '../branch/wheretobuy_step.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';
import 'branch/branch_step1.dart';

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



class _SearchScreenState extends State<SearchScreen> {
    // GlobalKey for old AirportScreen removed
  int _currentIndex = 0;
  final DatabaseReference _versionReference =
  FirebaseDatabase.instance.ref("VERSION");
  bool _giftFabOpen = false;
  bool _isScrolling = false; // 스크롤 중인지 여부
  final GlobalKey<State<GiftcardInfoScreen>> _giftcardInfoKey = GlobalKey<State<GiftcardInfoScreen>>();
  
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
    getVersion();
    _loadVersionFirebase();
    _loadCommunityNoticeTitle();
    _loadNotificationSettings();
    _checkForceUpdateAndNotice();
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
    if (_currentIndex == 1) {
      // 상품권 탭 전용: 상단 TabBar(지도/정보) + FAB
      return WillPopScope(
        onWillPop: _onWillPop,
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
            appBar: AppBar(
              title: const Text('상품권', style: TextStyle(color: Colors.black, fontSize: 16)),
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
                      appLink = 'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
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
                Builder(builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black54),
                      color: Colors.white,
                      onSelected: (value) async {
                        if (value == 'manage_cards') {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CardManagePage()));
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'manage_cards',
                          child: Text('카드 관리'),
                        ),
                      ],
                    );
                  }
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('where_to_buy')
                        .limit(1)
                        .snapshots(),
                    builder: (context, snap) {
                      final hasWhereToBuy = snap.hasData && snap.data!.docs.isNotEmpty;
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.black54),
                        color: Colors.white,
                        onSelected: (value) async {
                          switch (value) {
                            case 'manage_cards':
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CardManagePage()));
                              break;
                            case 'manage_where_to_buy':
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const WhereToBuyManagePage()));
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'manage_cards',
                            child: Text('카드 관리'),
                          ),
                          if (hasWhereToBuy)
                            const PopupMenuItem(
                              value: 'manage_where_to_buy',
                              child: Text('구매처 관리'),
                            ),
                        ],
                      );
                    },
                  );
                }),
              ],
              bottom: TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                onTap: (idx) {
                  if (idx != 0 && _giftFabOpen) {
                    setState(() { _giftFabOpen = false; });
                  }
                },
                tabs: const [
                  Tab(text: '정보'),
                  Tab(text: '지도'),
                ],
              ),
            ),
            body: Stack(
              children: [
                TabBarView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    GiftcardInfoScreen(
                      key: _giftcardInfoKey,
                      onScrollChanged: (isScrolling) {
                        setState(() {
                          _isScrolling = isScrolling;
                        });
                      },
                    ),
                    GiftcardMapScreen(),
                  ],
                ),
                if (_giftFabOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _giftFabOpen = false),
                      child: Container(color: Colors.black.withOpacity(0.05)),
                    ),
                  ),
                if (_giftFabOpen)
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GiftActionPill(
                          icon: Icons.store_mall_directory_outlined,
                          label: '지점 생성',
                          onTap: () {
                            setState(() => _giftFabOpen = false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BranchStep1Page()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        GiftActionPill(
                          icon: Icons.credit_card_outlined,
                          label: '카드 생성',
                          onTap: () {
                            setState(() => _giftFabOpen = false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CardStepPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        GiftActionPill(
                          icon: Icons.storefront_outlined,
                          label: '구매처 생성',
                          onTap: () {
                            setState(() => _giftFabOpen = false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WhereToBuyStepPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        GiftActionPill(
                          icon: Icons.shopping_cart_outlined,
                          label: '상품권 구매',
                          onTap: () async {
                            setState(() => _giftFabOpen = false);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GiftBuyScreen()),
                            );
                            // 저장 성공 시 데이터 새로고침
                            if (result == true && _giftcardInfoKey.currentState != null) {
                              final state = _giftcardInfoKey.currentState;
                              if (state != null && state is State<GiftcardInfoScreen>) {
                                (state as dynamic).refresh();
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        GiftActionPill(
                          icon: Icons.attach_money_outlined,
                          label: '상품권 판매',
                          onTap: () async {
                            setState(() => _giftFabOpen = false);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GiftSellScreen()),
                            );
                            // 저장 성공 시 데이터 새로고침
                            if (result == true && _giftcardInfoKey.currentState != null) {
                              final state = _giftcardInfoKey.currentState;
                              if (state != null && state is State<GiftcardInfoScreen>) {
                                (state as dynamic).refresh();
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            floatingActionButton: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                if (controller == null) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final showFab = controller.index == 0;
                    if (!showFab) return const SizedBox.shrink();
                    
                    // 스크롤 중이면 FAB 숨김
                    if (_isScrolling) return const SizedBox.shrink();

                    final user = FirebaseAuth.instance.currentUser;
                    // 로그인 안된 경우: 로그인 유도 FAB 노출
                    if (user == null) {
                      return FloatingActionButton(
                        backgroundColor: const Color(0xFF74512D),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Icon(Icons.login, color: Colors.white),
                      );
                    }

                    // 로그인 된 경우: 차단 상태를 구독하여 차단이면 FAB 숨김
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final banned = (snap.data?.data()?['isBanned'] as bool?) ?? false;
                        if (banned) return const SizedBox.shrink();
                        return FloatingActionButton(
                          backgroundColor: const Color(0xFF74512D),
                          onPressed: () => setState(() => _giftFabOpen = !_giftFabOpen),
                          child: Icon(_giftFabOpen ? Icons.close : Icons.add, color: Colors.white),
                        );
                      },
                    );
                  },
                );
              },
            ),
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
                      Icon(Icons.card_giftcard),
                      SizedBox(height: 2),
                      Text('상품권', style: TextStyle(fontSize: 12)),
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
        ),
      );
    }

    // 기본 케이스 (상품권 외 탭)
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? '${_communityNoticeTitle.isNotEmpty ? ' $_communityNoticeTitle' : ''}'
              : _currentIndex == 1
                  ? '상품권'
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
          if (_currentIndex != 1) ...[
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
        ],
      ),
      body: buildPage(_currentIndex),
      floatingActionButton: null,
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
                Icon(Icons.card_giftcard),
                SizedBox(height: 2),
                Text('상품권', style: TextStyle(fontSize: 12)),
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
        return const GiftcardMapScreen();
      case 2:
        return buildSettingsWidget();
      default:
        return const CommunityScreen();
    }
  }

  void _showGiftcardActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.store_mall_directory_outlined),
                title: const Text('지점 생성'),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('카드 생성'),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
                      ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: const Text('구매처 생성'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WhereToBuyStepPage()),
                          );
                        },
                      ),
              ListTile(
                leading: const Icon(Icons.call_made_outlined),
                title: const Text('상품권 구매'),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_made_outlined),
                title: const Text('상품권 판매'),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateBranchDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController linkController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('새 지점 요청', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.black),
                cursorColor: Color(0xFF74512D),
                decoration: const InputDecoration(
                  labelText: '지점 이름',
                  hintText: '예: 강남점',
                  labelStyle: TextStyle(color: Color(0xFF74512D)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF74512D), width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: Colors.black),
                cursorColor: Color(0xFF74512D),
                decoration: const InputDecoration(
                  labelText: '네이버 링크',
                  hintText: '예: https://map.naver.com/...',
                  labelStyle: TextStyle(color: Color(0xFF74512D)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF74512D), width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                final String name = nameController.text.trim();
                final String link = linkController.text.trim();
                if (name.isEmpty) {
                  Fluttertoast.showToast(msg: '지점 이름을 입력해주세요.');
                  return;
                }
                if (link.isEmpty) {
                  Fluttertoast.showToast(msg: '네이버 링크를 입력해주세요.');
                  return;
                }
                // Firestore에 요청 저장
                try {
                  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
                  FirebaseFirestore.instance.collection('branches_request').add({
                    'createdByUid': uid,
                    'title': name,
                    'naverLink': link,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(msg: '1~2일 정도 운영진 검토하에 지도 및 상품권 판매정보에 추가됩니다.');
                } catch (e) {
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(msg: '요청 저장 중 오류가 발생했습니다.');
                }
              },
              child: const Text('요청', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 대한항공/아시아나 관련 위젯은 제거되었습니다


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

  // Google Mobile Ads 초기화는 현재 사용하지 않습니다

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

