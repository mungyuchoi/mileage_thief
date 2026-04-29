import 'dart:io';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/screen/login_screen.dart';
import 'package:mileage_thief/screen/my_page_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../screen/community_screen.dart';
import '../services/remote_config_service.dart';
import 'giftcard_map_screen.dart';
import 'giftcard_rates_screen.dart';
import '../services/notice_preference_service.dart';
// import 'package:mileage_thief/screen/asiana_screen.dart' as asiana;
import 'giftcard_info_screen.dart';
import 'useful_info_screen.dart';
import '../widgets/gift_action_pill.dart';
import '../widgets/segment_tab_bar.dart';
import '../branch/card_manage.dart';
import '../branch/card_step.dart';
import '../branch/wheretobuy_manage.dart';
import '../branch/wheretobuy_step.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';
import 'branch/branch_step1.dart';
import 'branch/branch_list_tab.dart';
import 'admin_page_screen.dart';

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
      title: Text(title,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold)),
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
      title: Text(title,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold)),
      content: Text(content, style: const TextStyle(color: Colors.black)),
      actions: [
        TextButton(
          onPressed: () async {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          },
          child: Text(buttonText, style: const TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

enum _HomeTab {
  usefulInfo,
  community,
  giftcard,
  profile,
}

class _HomeTabDestination {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  const _HomeTabDestination({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });
}

const List<_HomeTabDestination> _homeTabDestinations = [
  _HomeTabDestination(
    label: '가이드',
    outlinedIcon: Icons.dashboard_customize_outlined,
    filledIcon: Icons.dashboard_customize_rounded,
  ),
  _HomeTabDestination(
    label: '커뮤니티',
    outlinedIcon: Icons.forum_outlined,
    filledIcon: Icons.forum_rounded,
  ),
  _HomeTabDestination(
    label: '상품권',
    outlinedIcon: Icons.redeem_outlined,
    filledIcon: Icons.redeem_rounded,
  ),
  _HomeTabDestination(
    label: '프로필',
    outlinedIcon: Icons.person_outline_rounded,
    filledIcon: Icons.person_rounded,
  ),
];

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loginRouteOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openLoginIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openLoginIfNeeded();
          });
          return const SizedBox.shrink();
        }

        return const MyPageScreen(
          showAppBar: false,
          bottomContentPadding: 120,
        );
      },
    );
  }

  Future<void> _openLoginIfNeeded() async {
    if (_loginRouteOpen || AuthService.currentUser != null || !mounted) return;

    _loginRouteOpen = true;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnToPreviousOnSuccess: true),
      ),
    );
    if (!mounted) return;
    _loginRouteOpen = false;

    if (AuthService.currentUser == null) {
      setState(() {});
    }
  }
}

class _HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _HomeBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF202734).withValues(alpha: 0.88),
                  const Color(0xFF151A24).withValues(alpha: 0.82),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  const Color(0xFFF5F8FE).withValues(alpha: 0.74),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.26 : 0.92),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x44000000) : const Color(0x25000000),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_homeTabDestinations.length, (index) {
          final destination = _homeTabDestinations[index];
          final selected = index == currentIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: isDark ? 0.16 : 0.98)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: isDark
                                ? const Color(0x55000000)
                                : const Color(0x12000000),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? destination.filledIcon
                          : destination.outlinedIcon,
                      size: 22,
                      color: selected
                          ? (isDark
                              ? const Color(0xFFF2F5FB)
                              : const Color(0xFF15161A))
                          : (isDark
                              ? const Color(0xFF9BA3B3)
                              : const Color(0xFF8A8A94)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? (isDark
                                ? const Color(0xFFF2F5FB)
                                : const Color(0xFF15161A))
                            : (isDark
                                ? const Color(0xFF9BA3B3)
                                : const Color(0xFF8A8A94)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // GlobalKey for old AirportScreen removed
  _HomeTab _currentTab = _HomeTab.usefulInfo;
  final DatabaseReference _versionReference =
      FirebaseDatabase.instance.ref("VERSION");
  bool _giftFabOpen = false;
  bool _isScrolling = false; // 스크롤 중인지 여부
  final GlobalKey<State<GiftcardInfoScreen>> _giftcardInfoKey =
      GlobalKey<State<GiftcardInfoScreen>>();
  late TabController _giftcardTabController; // 상품권 탭 전용 TabController

  // 공지사항 제목을 저장할 변수
  String _communityNoticeTitle = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final NoticePreferenceService _noticePref = NoticePreferenceService();

  // 뒤로가기 버튼 처리 관련 변수
  DateTime? _lastBackPressTime;
  final Duration _backPressTimeLimit = const Duration(seconds: 2);

  int get _currentIndex => _currentTab.index;

  void _selectHomeTab(_HomeTab tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  @override
  void initState() {
    super.initState();
    _giftcardTabController = TabController(length: 4, vsync: this);
    getVersion();
    _loadVersionFirebase();
    _loadCommunityNoticeTitle();
    _loadNotificationSettings();
    _checkForceUpdateAndNotice();
  }

  @override
  void dispose() {
    _giftcardTabController.dispose();
    super.dispose();
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
      print(
          '[강업] currentVersion: $currentVersion, requiredVersion: $requiredVersion');
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
  Future<bool> _shouldExitApp() async {
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

  Future<void> _handleBackPressed() async {
    final shouldExit = await _shouldExitApp();
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentTab = _HomeTab.values[index];
    });
  }

  PreferredSizeWidget _buildHomeAppBar({
    PreferredSizeWidget? bottom,
    bool includeGiftcardActions = false,
    bool showLogo = true,
    List<Widget>? actions,
  }) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: showLogo
          ? Image.asset(
              'asset/icon/milecatch_logo.png',
              height: 24,
              fit: BoxFit.contain,
            )
          : const SizedBox.shrink(),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.black),
      elevation: 1,
      actions: actions ??
          (includeGiftcardActions
              ? _buildGiftcardAppBarActions()
              : _buildDefaultAppBarActions()),
      bottom: bottom,
    );
  }

  List<Widget> _buildDefaultAppBarActions() {
    return <Widget>[
      IconButton(
        icon: const Icon(Icons.share, color: Colors.black),
        onPressed: _shareApp,
      ),
      IconButton(
        icon: const Icon(Icons.chat, color: Colors.black),
        onPressed: _launchOpenChat,
      ),
    ];
  }

  List<Widget> _buildProfileAppBarActions() {
    return <Widget>[
      IconButton(
        icon: const Icon(Icons.settings, color: Colors.black),
        onPressed: _openSettingsScreen,
      ),
    ];
  }

  List<Widget> _buildGiftcardAppBarActions() {
    return <Widget>[
      ..._buildDefaultAppBarActions(),
      Builder(builder: (context) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.send_rounded, color: Colors.black),
          onPressed: () async {
            final uri = Uri.parse('https://t.me/+6ZxoqIXFsI5kMzVl');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      }),
      Builder(builder: (context) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            onSelected: (value) async {
              if (value == 'manage_cards') {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CardManagePage()));
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
              icon: const Icon(Icons.more_vert, color: Colors.black),
              color: Colors.white,
              onSelected: (value) async {
                switch (value) {
                  case 'manage_cards':
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CardManagePage()));
                    break;
                  case 'manage_where_to_buy':
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WhereToBuyManagePage()));
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
    ];
  }

  void _shareApp() {
    String appLink = '';
    if (Platform.isAndroid) {
      appLink =
          'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
    } else {
      appLink = 'https://apps.apple.com/app/myapp/6446247689';
    }
    String description = "마일리지 항공 앱을 공유해보세요! $appLink";
    SharePlus.instance.share(ShareParams(text: description));
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => buildSettingsWidget()),
    );
  }

  void _refreshGiftcardInfoIfNeeded(Object? navigationResult) {
    if (navigationResult == true) {
      (_giftcardInfoKey.currentState as dynamic)?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTab == _HomeTab.giftcard) {
      // 상품권 탭 전용: 상단 TabBar(지도/정보) + FAB
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          unawaited(_handleBackPressed());
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
          appBar: _buildHomeAppBar(
            includeGiftcardActions: true,
            showLogo: false,
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: SegmentTabBar(
                        controller: _giftcardTabController,
                        labels: const ['정보', '지도', '시세', '지점'],
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _giftcardTabController,
                        physics: const NeverScrollableScrollPhysics(),
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
                          const GiftcardRatesTab(),
                          const BranchListTab(),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  bottom: 176,
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
                            MaterialPageRoute(
                                builder: (_) => const BranchStep1Page()),
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
                            MaterialPageRoute(
                                builder: (_) => const GiftBuyScreen()),
                          );
                          _refreshGiftcardInfoIfNeeded(result);
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
                            MaterialPageRoute(
                                builder: (_) => const GiftSellScreen()),
                          );
                          _refreshGiftcardInfoIfNeeded(result);
                        },
                      ),
                    ],
                  ),
                ),
              _buildFloatingBottomNav(),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 92),
            child: AnimatedBuilder(
              animation: _giftcardTabController,
              builder: (context, _) {
                final showFab = _giftcardTabController.index == 0;
                if (!showFab) return const SizedBox.shrink();

                // 스크롤 중이면 FAB 숨김
                if (_isScrolling) return const SizedBox.shrink();

                final user = FirebaseAuth.instance.currentUser;
                // 로그인 안된 경우: 로그인 유도 FAB 노출
                if (user == null) {
                  return FloatingActionButton(
                    elevation: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.90),
                    foregroundColor: const Color(0xFF74512D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 1.2,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Icon(Icons.login),
                  );
                }

                // 로그인 된 경우: 차단 상태를 구독하여 차단이면 FAB 숨김
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    final banned =
                        (snap.data?.data()?['isBanned'] as bool?) ?? false;
                    if (banned) return const SizedBox.shrink();
                    return FloatingActionButton(
                      elevation: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.90),
                      foregroundColor: const Color(0xFF74512D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.2,
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _giftFabOpen = !_giftFabOpen),
                      child: Icon(_giftFabOpen ? Icons.close : Icons.add),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    }

    // 기본 케이스 (상품권 외 탭)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBackPressed());
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
        appBar: _buildHomeAppBar(
          showLogo: _currentTab != _HomeTab.community,
          actions: _currentTab == _HomeTab.profile
              ? _buildProfileAppBarActions()
              : null,
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _buildCurrentTabPage()),
            _buildFloatingBottomNav(),
          ],
        ),
        floatingActionButton: null,
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: _HomeBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }

  Widget _buildCurrentTabPage() {
    switch (_currentTab) {
      case _HomeTab.community:
        return const CommunityScreen();
      case _HomeTab.usefulInfo:
        return UsefulInfoScreen(
          onOpenCommunity: () => _selectHomeTab(_HomeTab.community),
          onOpenGiftcard: () => _selectHomeTab(_HomeTab.giftcard),
          onOpenProfile: () => _selectHomeTab(_HomeTab.profile),
        );
      case _HomeTab.giftcard:
        return const SizedBox.shrink();
      case _HomeTab.profile:
        return const _ProfileTab();
    }
  }

  // 대한항공/아시아나 관련 위젯은 제거되었습니다

  bool _postLikeNotification = true;
  bool _postCommentNotification = true;
  bool _commentReplyNotification = true;
  bool _commentLikeNotification = true;
  String _version = '';
  String _latestVersion = '';

  bool _hasAdminAccess(dynamic roles) {
    if (roles is List) {
      return roles.any((role) {
        final value = role.toString().trim();
        return value == 'admin' || value == 'owner';
      });
    }
    if (roles is Map) {
      return roles['admin'] == true || roles['owner'] == true;
    }
    if (roles is String) {
      final value = roles.trim();
      return value == 'admin' || value == 'owner';
    }
    return false;
  }

  Widget buildSettingsWidget() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;

          return FutureBuilder<Map<String, dynamic>?>(
            future: user != null
                ? UserService.getUserFromFirestore(user.uid)
                : Future.value(null),
            builder: (context, userSnapshot) {
              final Map<String, dynamic>? userData = userSnapshot.data;
              final bool isAdmin = _hasAdminAccess(userData?['roles']);

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
                        description: Text(
                          user == null
                              ? '로그인하여 땅콩을 클라우드에 저장하세요'
                              : '${user.displayName ?? user.email ?? "사용자"}님, 안녕하세요!',
                        ),
                        leading: Icon(
                          user == null
                              ? Icons.login
                              : Icons.account_circle_outlined,
                        ),
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
                            final androidInfo =
                                await deviceInfoPlugin.androidInfo;
                            os = 'Android ${androidInfo.version.release}';
                            model = androidInfo.model ?? '';
                          } else if (Platform.isIOS) {
                            final iosInfo = await deviceInfoPlugin.iosInfo;
                            os = 'iOS ${iosInfo.systemVersion}';
                            model = iosInfo.utsname.machine ?? '';
                          }
                          final body = Uri.encodeComponent(
                            '문의내역:\n버전: ${info.version}\nOS: $os\n모델명: $model',
                          );
                          final uri = Uri.parse(
                            'mailto:skylife927@gmail.com?subject=FAQ 문의&body=$body',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            Fluttertoast.showToast(
                              msg: '이메일 앱을 열 수 없습니다.',
                            );
                          }
                        },
                        title: const Text('FAQ'),
                        leading: const Icon(Icons.question_answer_outlined),
                      ),
                      if (isAdmin)
                        SettingsTile(
                          onPressed: (context) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminPageScreen(),
                              ),
                            );
                          },
                          title: const Text('관리자 페이지'),
                          description: const Text(
                            '관리자 기능을 한곳에서 관리합니다.',
                          ),
                          leading:
                              const Icon(Icons.admin_panel_settings_outlined),
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
                        description: Text(
                          _version == _latestVersion
                              ? 'Version: $_version (최신버전입니다.)'
                              : 'Version: $_version (최신버전이 아닙니다.)',
                        ),
                        leading: const Icon(Icons.info_outline),
                      ),
                    ],
                  ),
                ],
              );
            },
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
      DocumentSnapshot doc =
          await _firestore.collection('notice').doc('community').get();

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
      _postCommentNotification =
          prefs.getBool('post_comment_notification') ?? true;
      _commentReplyNotification =
          prefs.getBool('comment_reply_notification') ?? true;
      _commentLikeNotification =
          prefs.getBool('comment_like_notification') ?? true;
    });
  }

  _launchMileageThief(String mileageTheifMarketUrl) async {
    String appLink;
    if (Platform.isAndroid) {
      appLink =
          'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief';
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
