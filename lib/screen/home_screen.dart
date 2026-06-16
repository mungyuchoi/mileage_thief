import 'dart:io';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mileage_thief/screen/login_screen.dart';
import 'package:mileage_thief/screen/my_page_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../const/colors.dart';
import '../screen/community_screen.dart';
import '../services/remote_config_service.dart';
import 'giftcard_map_screen.dart';
import 'giftcard_rates_screen.dart';
import '../services/notice_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:mileage_thief/screen/asiana_screen.dart' as asiana;
import 'giftcard_deals_screen.dart';
import 'giftcard_info_screen.dart';
import 'giftcard_settlement_screen.dart';
import 'my_card_dashboard_screen.dart';
import 'notification_settings_screen.dart';
import 'useful_info_screen.dart';
import 'world_map_screen.dart';
import 'user_scrap_upload_screen.dart';
import 'user_report_history_screen.dart';
import '../widgets/gift_action_pill.dart';
import '../widgets/segment_tab_bar.dart';
import '../widgets/community_chat_floating_button.dart';
import '../branch/card_step.dart';
import '../branch/wheretobuy_manage.dart';
import '../branch/wheretobuy_step.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';
import 'branch/branch_step1.dart';
import 'branch/branch_list_tab.dart';
import 'admin_page_screen.dart';
import 'community_chat_screen.dart';

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

const TextStyle _mileageSettingActionTitleTextStyle = TextStyle(
  color: Color(0xFF1D212C),
  fontWeight: FontWeight.w800,
);

class _MileageSettingSection extends StatelessWidget {
  const _MileageSettingSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(
                height: 8,
                indent: 52,
                color: Color(0xFFE9EBF0),
              ),
          ],
        ],
      ),
    );
  }
}

class _MileageSettingSectionLabel extends StatelessWidget {
  const _MileageSettingSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7E8492),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MileageSettingActionTile extends StatelessWidget {
  const _MileageSettingActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minLeadingWidth: 32,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(icon, color: const Color(0xFFAEB4C0)),
      title: Text(
        title,
        style: _mileageSettingActionTitleTextStyle,
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF8A91A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFC0C5CF),
      ),
      onTap: onTap,
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
  worldMap,
  giftcard,
  profile,
}

const String _communityChatIconAsset =
    'asset/icon/kakaotalk_sharing_btn_medium.png';

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
    label: '세계지도',
    outlinedIcon: Icons.public_outlined,
    filledIcon: Icons.public_rounded,
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

  /// 제공되면 좌측에 '접기' 핸들(<)을 노출(세계지도 탭 전용).
  final VoidCallback? onCollapse;

  const _HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: McColors.line, width: 0.8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onCollapse != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onCollapse,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: McColors.mutedLight,
                  ),
                ),
              ),
            ),
          ...List.generate(_homeTabDestinations.length, (index) {
          final destination = _homeTabDestinations[index];
          final selected = index == currentIndex;
          final selectedAccent = currentIndex == _HomeTab.giftcard.index
              ? GiftcardColors.accent
              : McColors.accent;
          final selectedAccentSoft = currentIndex == _HomeTab.giftcard.index
              ? GiftcardColors.accentSoft
              : McColors.accentSoft;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? selectedAccentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? destination.filledIcon
                          : destination.outlinedIcon,
                      size: 21,
                      color: selected ? selectedAccent : McColors.mutedLight,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: index == _HomeTab.usefulInfo.index
                            ? _mileageSettingActionTitleTextStyle.fontWeight
                            : FontWeight.w700,
                        color: selected ? selectedAccent : McColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        ],
      ),
    );
  }
}

/// 세계지도 탭에서 하단 내비를 접었을 때 좌하단에 남는 '<' 플로팅 버튼.
/// 탭하면 내비가 다시 펼쳐진다.
class _CollapsedNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CollapsedNavButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: McColors.line, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.chevron_left_rounded,
            size: 26,
            color: McColors.accent,
          ),
        ),
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
  // 백그라운드 복귀 시 OS가 앱 프로세스를 종료(메모리/배터리 정책)하면
  // 콜드 스타트로 첫 탭으로 초기화된다. 마지막 탭을 저장해 두고 복원한다.
  static const String _lastTabPrefKey = 'home_last_tab_index';
  _HomeTab _currentTab = _HomeTab.usefulInfo;
  final DatabaseReference _versionReference =
      FirebaseDatabase.instance.ref("VERSION");
  bool _giftFabOpen = false;
  bool _isScrolling = false; // 스크롤 중인지 여부
  final GlobalKey<State<GiftcardInfoScreen>> _giftcardInfoKey =
      GlobalKey<State<GiftcardInfoScreen>>();
  late TabController _giftcardTabController; // 상품권 탭 전용 TabController
  int _lastGiftcardTabIndex = 0;
  String _communityInitialBoardId = 'all';
  String _communityInitialBoardName = '전체글';
  int _communityRefreshNonce = 0;
  static const String _giftcardGuideBoardId = 'milecatch_guide';
  static const String _giftcardGuideBoardName = '마일캐치 사용법';

  // 공지사항 제목을 저장할 변수
  String _communityNoticeTitle = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final NoticePreferenceService _noticePref = NoticePreferenceService();

  // 뒤로가기 버튼 처리 관련 변수
  DateTime? _lastBackPressTime;
  final Duration _backPressTimeLimit = const Duration(seconds: 2);

  int get _currentIndex => _currentTab.index;

  // 세계지도 탭에서 하단 내비를 '<' 플로팅 버튼으로 축소했는지 여부.
  bool _worldNavCollapsed = false;

  // ── 세계지도(WebView) 세션 유지 ──────────────────────────
  // 다른 탭에 갔다 와도 로딩 없이 이어서. 추천 유지 시간이 지나면 폐기 후
  // 다음 진입 시 새로 로드(메모리·배터리 절약).
  static const Duration _worldMapKeepAlive = Duration(minutes: 5);
  bool _worldMapAlive = false;
  Timer? _worldMapTtlTimer;
  Key _worldMapKey = UniqueKey();

  /// 탭 전환 시 세계지도 WebView를 살릴지/폐기 예약할지 결정.
  /// [next]로 바뀌기 직전(_currentTab은 아직 이전 탭)에 호출한다.
  void _handleWorldMapKeepAlive(_HomeTab next) {
    if (next == _HomeTab.worldMap) {
      // 진입(또는 복귀): 살리고 폐기 타이머 취소.
      _worldMapAlive = true;
      _worldMapTtlTimer?.cancel();
      _worldMapTtlTimer = null;
    } else if (_currentTab == _HomeTab.worldMap && _worldMapAlive) {
      // 세계지도를 떠남: 유지 시간 뒤 폐기(다음 진입 시 새 로드).
      _worldMapTtlTimer?.cancel();
      _worldMapTtlTimer = Timer(_worldMapKeepAlive, () {
        if (!mounted) return;
        setState(() {
          _worldMapAlive = false;
          _worldMapKey = UniqueKey();
        });
      });
    }
  }

  void _selectHomeTab(_HomeTab tab) {
    setState(() {
      _handleWorldMapKeepAlive(tab);
      // 세계지도 진입 시 자동 축소, 다른 탭은 항상 펼침.
      _worldNavCollapsed = tab == _HomeTab.worldMap;
      if (tab != _HomeTab.giftcard) {
        _giftFabOpen = false;
        _isScrolling = false;
      }
      _currentTab = tab;
    });
    _persistLastTab(tab);
    unawaited(AnalyticsService.instance.logTabSelected(
      'home',
      _homeTabAnalyticsName(tab),
      source: 'guide',
    ));
  }

  // 마지막 탭을 영구 저장(프로세스 종료 후 복원용).
  void _persistLastTab(_HomeTab tab) {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastTabPrefKey, tab.index);
      } catch (e) {
        debugPrint('마지막 탭 저장 실패: $e');
      }
    }());
  }

  // 콜드 스타트 시 마지막 탭을 복원. 첫 프레임 이후 1회만 수행한다.
  Future<void> _restoreLastTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_lastTabPrefKey);
      if (index == null) return;
      if (index < 0 || index >= _HomeTab.values.length) return;
      final tab = _HomeTab.values[index];
      if (!mounted || tab == _currentTab) return;
      _selectHomeTab(tab);
    } catch (e) {
      debugPrint('마지막 탭 복원 실패: $e');
    }
  }

  void _openCommunityTab({String? boardId, String? boardName}) {
    final nextBoardId =
        boardId?.trim().isNotEmpty == true ? boardId!.trim() : 'all';
    final nextBoardName = boardName?.trim().isNotEmpty == true
        ? boardName!.trim()
        : nextBoardId == 'all'
            ? '전체글'
            : nextBoardId;

    setState(() {
      _communityInitialBoardId = nextBoardId;
      _communityInitialBoardName = nextBoardName;
      _giftFabOpen = false;
      _isScrolling = false;
      _currentTab = _HomeTab.community;
    });
    _persistLastTab(_HomeTab.community);
    unawaited(AnalyticsService.instance.logTabSelected(
      'home',
      'community',
      source: 'community_shortcut',
    ));
    unawaited(AnalyticsService.instance.logAction(
      'community_board_selected',
      params: {
        'board_id': nextBoardId,
        'source': 'home_shortcut',
      },
    ));
  }

  Future<void> _openUserScrapUpload() async {
    if (AuthService.currentUser == null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnToPreviousOnSuccess: true),
        ),
      );
      if (!mounted || AuthService.currentUser == null) return;
    }

    unawaited(AnalyticsService.instance.logAction(
      'user_scrap_upload_open',
      params: {'source': 'profile_app_bar'},
    ));
    final result = await Navigator.of(context).push<UserScrapUploadResult>(
      MaterialPageRoute<UserScrapUploadResult>(
        settings: const RouteSettings(name: 'user_scrap_upload'),
        builder: (_) => const UserScrapUploadScreen(),
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      _communityInitialBoardId =
          result.boardId.trim().isEmpty ? 'all' : result.boardId.trim();
      _communityInitialBoardName = result.boardName.trim().isEmpty
          ? _communityInitialBoardId
          : result.boardName.trim();
      _communityRefreshNonce++;
      _giftFabOpen = false;
      _isScrolling = false;
      _currentTab = _HomeTab.community;
    });
    _persistLastTab(_HomeTab.community);
    unawaited(AnalyticsService.instance.logTabSelected(
      'home',
      'community',
      source: 'user_scrap_upload_success',
    ));
    unawaited(AnalyticsService.instance.logAction(
      'community_board_selected',
      params: {
        'board_id': _communityInitialBoardId,
        'source': 'user_scrap_upload_success',
      },
    ));
  }

  @override
  void initState() {
    super.initState();
    _giftcardTabController = TabController(length: 6, vsync: this);
    _giftcardTabController.addListener(_handleGiftcardTabChanged);
    unawaited(AnalyticsService.instance.logScreenView(
      'home',
      screenClass: 'HomeScreen',
      source: 'screen_init',
    ));
    unawaited(AnalyticsService.instance.logTabSelected(
      'home',
      _homeTabAnalyticsName(_currentTab),
      source: 'initial',
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService().markNavigationReady();
      // 콜드 스타트(프로세스 종료 복귀) 시 마지막 탭 복원.
      unawaited(_restoreLastTab());
    });
    getVersion();
    _loadVersionFirebase();
    _loadCommunityNoticeTitle();
    _checkForceUpdateAndNotice();
  }

  @override
  void dispose() {
    _worldMapTtlTimer?.cancel();
    _giftcardTabController.removeListener(_handleGiftcardTabChanged);
    _giftcardTabController.dispose();
    super.dispose();
  }

  String _homeTabAnalyticsName(_HomeTab tab) {
    return switch (tab) {
      _HomeTab.usefulInfo => 'guide',
      _HomeTab.community => 'community',
      _HomeTab.worldMap => 'world_map',
      _HomeTab.giftcard => 'giftcard',
      _HomeTab.profile => 'profile',
    };
  }

  String _giftcardTabAnalyticsName(int index) {
    const names = ['info', 'deal', 'map', 'rates', 'settlement', 'branch'];
    if (index < 0 || index >= names.length) return 'unknown';
    return names[index];
  }

  void _handleGiftcardTabChanged() {
    final index = _giftcardTabController.index;
    if (index == _lastGiftcardTabIndex) return;
    _lastGiftcardTabIndex = index;
    unawaited(AnalyticsService.instance.logTabSelected(
      'giftcard',
      _giftcardTabAnalyticsName(index),
      source: 'giftcard_tab_bar',
    ));
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
    final nextTab = _HomeTab.values[index];
    setState(() {
      _handleWorldMapKeepAlive(nextTab);
      // 세계지도 진입 시 자동 축소, 다른 탭은 항상 펼침.
      _worldNavCollapsed = nextTab == _HomeTab.worldMap;
      if (nextTab == _HomeTab.community) {
        _communityInitialBoardId = 'all';
        _communityInitialBoardName = '전체글';
      }
      if (nextTab != _HomeTab.giftcard) {
        _giftFabOpen = false;
        _isScrolling = false;
      }
      _currentTab = nextTab;
    });
    _persistLastTab(nextTab);
    unawaited(AnalyticsService.instance.logTabSelected(
      'home',
      _homeTabAnalyticsName(nextTab),
      source: 'bottom_nav',
    ));
  }

  PreferredSizeWidget _buildHomeAppBar({
    PreferredSizeWidget? bottom,
    bool includeGiftcardActions = false,
    bool showLogo = true,
    String? titleText,
    List<Widget>? actions,
  }) {
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 12,
      title: titleText != null
          ? Text(titleText, style: McTextStyles.appBarTitle)
          : showLogo
              ? Image.asset(
                  'asset/icon/milecatch_logo.png',
                  height: 24,
                  fit: BoxFit.contain,
                )
              : const SizedBox.shrink(),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: McColors.ink, size: 23),
      elevation: 0.5,
      shadowColor: McColors.line,
      actions: actions ??
          (includeGiftcardActions
              ? _buildGiftcardAppBarActions()
              : _buildDefaultAppBarActions()),
      bottom: bottom,
    );
  }

  List<Widget> _buildDefaultAppBarActions() {
    return <Widget>[
      _buildShareAppBarAction(),
      _buildCommunityChatAppBarAction(),
    ];
  }

  Widget _buildShareAppBarAction() {
    return IconButton(
      icon: const Icon(Icons.share, color: Colors.black),
      onPressed: _shareApp,
    );
  }

  Widget _buildCommunityChatAppBarAction() {
    return IconButton(
      icon: ClipOval(
        child: Image.asset(
          _communityChatIconAsset,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
        ),
      ),
      onPressed: _launchOpenChat,
    );
  }

  List<Widget> _buildGuideAppBarActions() {
    return _buildDefaultAppBarActions();
  }

  List<Widget> _buildProfileAppBarActions() {
    return <Widget>[
      IconButton(
        tooltip: '블로그 스크랩',
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        onPressed: _openUserScrapUpload,
      ),
      IconButton(
        tooltip: '설정',
        icon: const Icon(Icons.settings, color: Colors.black),
        onPressed: _openSettingsScreen,
      ),
    ];
  }

  List<Widget> _buildGiftcardAppBarActions() {
    return <Widget>[
      _buildShareAppBarAction(),
      IconButton(
        tooltip: '상품권 사용법',
        icon: const Icon(Icons.info_outline, color: Colors.black),
        onPressed: _openGiftcardGuide,
      ),
      Builder(builder: (context) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            onSelected: (value) async {
              if (value == 'manage_cards') {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyCardDashboardScreen()));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'manage_cards',
                child: Text('내 카드'),
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
                            builder: (_) => const MyCardDashboardScreen()));
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
                  child: Text('내 카드'),
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
    unawaited(AnalyticsService.instance.logAction('share_started', params: {
      'screen': 'home',
      'entity_type': 'app',
      'source': Platform.isAndroid ? 'android' : 'ios',
    }));
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

  void _openCommunityChat() {
    unawaited(
        AnalyticsService.instance.logAction('community_chat_open', params: {
      'source': 'home_fab',
    }));
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'community_chat'),
        builder: (_) => const CommunityChatScreen(),
      ),
    );
  }

  void _openGiftcardGuide() {
    _openCommunityTab(
      boardId: _giftcardGuideBoardId,
      boardName: _giftcardGuideBoardName,
    );
  }

  void _setGiftcardScrolling(bool isScrolling) {
    if (_isScrolling == isScrolling) return;
    setState(() {
      _isScrolling = isScrolling;
    });
  }

  bool _handleGiftcardScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setGiftcardScrolling(true);
    } else if (notification is ScrollEndNotification) {
      _setGiftcardScrolling(false);
    }
    return false;
  }

  Widget _buildGiftcardPrimaryTabBar() {
    return ScrollableUnderlineTabBar(
      controller: _giftcardTabController,
      labels: const ['정보', '특가', '지도', '시세', '계산', '지점'],
      indicatorColor: GiftcardColors.accent,
    );
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
            titleText: '상품권',
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleGiftcardScrollNotification,
                  child: Column(
                    children: [
                      _buildGiftcardPrimaryTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _giftcardTabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            GiftcardInfoScreen(
                              key: _giftcardInfoKey,
                              onScrollChanged: _setGiftcardScrolling,
                            ),
                            const GiftcardDealsScreen(),
                            const GiftcardMapScreen(),
                            const GiftcardRatesTab(),
                            const GiftcardSettlementScreen(),
                            const BranchListTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  bottom: 232,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GiftActionPill(
                        icon: Icons.store_mall_directory_outlined,
                        label: '지점 생성',
                        onTap: () {
                          setState(() => _giftFabOpen = false);
                          unawaited(AnalyticsService.instance.logAction(
                            'branch_created',
                            params: {'source': 'giftcard_fab'},
                          ));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                settings:
                                    const RouteSettings(name: 'branch_create'),
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
                          unawaited(AnalyticsService.instance.logAction(
                            'cta_tapped',
                            params: {
                              'screen': 'giftcard',
                              'cta': 'card_create',
                              'source': 'giftcard_fab',
                            },
                          ));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: 'card_create'),
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
                          unawaited(AnalyticsService.instance.logAction(
                            'cta_tapped',
                            params: {
                              'screen': 'giftcard',
                              'cta': 'where_to_buy_create',
                              'source': 'giftcard_fab',
                            },
                          ));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                  name: 'where_to_buy_create'),
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
                          unawaited(AnalyticsService.instance.logAction(
                            'gift_buy_started',
                            params: {
                              'mode': 'create',
                              'source': 'giftcard_fab',
                            },
                          ));
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                settings: const RouteSettings(name: 'gift_buy'),
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
                          unawaited(AnalyticsService.instance.logAction(
                            'gift_sell_started',
                            params: {
                              'mode': 'create',
                              'source': 'giftcard_fab',
                            },
                          ));
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                settings:
                                    const RouteSettings(name: 'gift_sell'),
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
                    foregroundColor: GiftcardColors.accent,
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
                      foregroundColor: GiftcardColors.accent,
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
        appBar: (_currentTab == _HomeTab.community ||
                _currentTab == _HomeTab.worldMap)
            ? null
            : _buildHomeAppBar(
                actions: _currentTab == _HomeTab.profile
                    ? _buildProfileAppBarActions()
                    : _currentTab == _HomeTab.usefulInfo
                        ? _buildGuideAppBarActions()
                        : null,
              ),
        body: Stack(
          children: [
            // 세계지도 외 탭: 현재 탭 페이지.
            if (_currentTab != _HomeTab.worldMap)
              Positioned.fill(child: _buildCurrentTabPage()),
            // 세계지도: 살아있는 동안 트리에 유지(Offstage)해 세션을 보존.
            // 활성일 때만 표시되고, 유지 시간이 지나면 트리에서 제거되어 폐기된다.
            if (_worldMapAlive)
              Positioned.fill(
                child: Offstage(
                  offstage: _currentTab != _HomeTab.worldMap,
                  child: TickerMode(
                    enabled: _currentTab == _HomeTab.worldMap,
                    child: KeyedSubtree(
                      key: _worldMapKey,
                      child: const WorldMapScreen(),
                    ),
                  ),
                ),
              ),
            _buildFloatingBottomNav(),
          ],
        ),
        floatingActionButton: _currentTab == _HomeTab.usefulInfo
            ? Padding(
                padding: const EdgeInsets.only(bottom: 92),
                child: CommunityChatFloatingButton(
                  heroTag: 'guideCommunityChatFab',
                  onPressed: _openCommunityChat,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    final collapsed = _currentTab == _HomeTab.worldMap && _worldNavCollapsed;

    // 펼침 ↔ 축소 전환을 부드럽게. 축소 시 왼쪽 하단 '<' 버튼만 남는다.
    // 축소 버튼은 웹뷰(퍼즐 부스터 등) 하단 UI와 겹치지 않게 더 아래로 내린다.
    return Positioned(
      left: collapsed ? 16 : 20,
      right: collapsed ? null : 20,
      bottom: collapsed ? 0 : 24,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          ),
          child: collapsed
              ? _CollapsedNavButton(
                  key: const ValueKey('nav-collapsed'),
                  onTap: () => setState(() => _worldNavCollapsed = false),
                )
              : _HomeBottomNavigationBar(
                  key: const ValueKey('nav-expanded'),
                  currentIndex: _currentIndex,
                  // 세계지도 탭에서는 다시 접을 수 있도록 콜백 전달.
                  onCollapse: _currentTab == _HomeTab.worldMap
                      ? () => setState(() => _worldNavCollapsed = true)
                      : null,
                  onTap: _selectTab,
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabPage() {
    switch (_currentTab) {
      case _HomeTab.community:
        return CommunityScreen(
          initialBoardId: _communityInitialBoardId,
          initialBoardName: _communityInitialBoardName,
          refreshNonce: _communityRefreshNonce,
        );
      case _HomeTab.usefulInfo:
        return UsefulInfoScreen(
          onOpenCommunity: _openCommunityTab,
          onOpenGiftcard: () => _selectHomeTab(_HomeTab.giftcard),
          onOpenProfile: () => _selectHomeTab(_HomeTab.profile),
        );
      case _HomeTab.worldMap:
        // 세계지도는 body의 Offstage(KeepAlive)에서 렌더하므로 여기선 비움.
        return const SizedBox.shrink();
      case _HomeTab.giftcard:
        return const SizedBox.shrink();
      case _HomeTab.profile:
        return const _ProfileTab();
    }
  }

  // 대한항공/아시아나 관련 위젯은 제거되었습니다

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
      backgroundColor: const Color(0xFFF0F1F5),
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: AuthService.authStateChanges,
          builder: (settingsContext, snapshot) {
            final user = snapshot.data;

            return FutureBuilder<Map<String, dynamic>?>(
              future: user != null
                  ? UserService.getUserFromFirestore(user.uid)
                  : Future.value(null),
              builder: (settingsContext, userSnapshot) {
                final Map<String, dynamic>? userData = userSnapshot.data;
                final bool isAdmin = _hasAdminAccess(userData?['roles']);
                final versionDescription = _version == _latestVersion
                    ? 'Version: $_version (최신버전입니다.)'
                    : 'Version: $_version (최신버전이 아닙니다.)';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.of(settingsContext).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF1A1D27),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '설정',
                          style: TextStyle(
                            color: Color(0xFF1A1D27),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isAdmin) ...[
                      _MileageSettingSection(
                        children: [
                          _MileageSettingActionTile(
                            icon: Icons.admin_panel_settings_outlined,
                            title: '관리자 페이지',
                            subtitle: '관리자 기능을 한곳에서 관리합니다.',
                            onTap: () {
                              Navigator.push(
                                settingsContext,
                                MaterialPageRoute(
                                  builder: (_) => const AdminPageScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    _MileageSettingSection(
                      children: [
                        _MileageSettingActionTile(
                          icon: user == null
                              ? Icons.login_rounded
                              : Icons.account_circle_outlined,
                          title: user == null ? '로그인' : '내 정보',
                          subtitle: user == null
                              ? '로그인하여 땅콩을 클라우드에 저장하세요'
                              : '${user.displayName ?? user.email ?? "사용자"}님, 안녕하세요!',
                          onTap: () {
                            Navigator.push(
                              settingsContext,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                        ),
                        if (user != null)
                          _MileageSettingActionTile(
                            icon: Icons.report_gmailerrorred_outlined,
                            title: '신고 내역',
                            subtitle: '내가 접수한 신고 처리 상태를 확인합니다.',
                            onTap: () {
                              Navigator.push(
                                settingsContext,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const UserReportHistoryScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _MileageSettingSectionLabel('알림'),
                    const SizedBox(height: 6),
                    _MileageSettingSection(
                      children: [
                        _MileageSettingActionTile(
                          icon: Icons.notifications_none_outlined,
                          title: '알림 설정',
                          subtitle: '커뮤니티와 레이더 푸시 수신을 관리합니다.',
                          onTap: () {
                            Navigator.push(
                              settingsContext,
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: 'notification_settings',
                                ),
                                builder: (_) =>
                                    const NotificationSettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _MileageSettingSection(
                      children: [
                        _MileageSettingActionTile(
                          icon: Icons.storefront_outlined,
                          title: '스토어로 이동',
                          onTap: () {
                            _launchMileageThief();
                          },
                        ),
                        _MileageSettingActionTile(
                          icon: Icons.question_answer_outlined,
                          title: 'FAQ',
                          onTap: () => _showFaqContactSheet(settingsContext),
                        ),
                        _MileageSettingActionTile(
                          icon: Icons.info_outline,
                          title: '버전 정보',
                          subtitle: versionDescription,
                          onTap: () {
                            Fluttertoast.showToast(
                              msg: _version == _latestVersion
                                  ? '최신버전입니다.'
                                  : '최신버전이 아닙니다. 업데이트 부탁드립니다.',
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 5,
                              backgroundColor: Colors.grey[800],
                              fontSize: 16,
                              textColor: Colors.white,
                              toastLength: Toast.LENGTH_SHORT,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
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

  void _showFaqContactSheet(BuildContext settingsContext) {
    showModalBottomSheet<void>(
      context: settingsContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FAQ',
                    style: TextStyle(
                      color: Color(0xFF1D212C),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFFAEB4C0),
                  ),
                  title: const Text(
                    '이메일 문의',
                    style: TextStyle(
                      color: Color(0xFF1D212C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC0C5CF),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _launchFaqEmail();
                  },
                ),
                const Divider(height: 1, color: Color(0xFFE9EBF0)),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.rate_review_outlined,
                    color: Color(0xFFAEB4C0),
                  ),
                  title: const Text(
                    '리뷰 남기기',
                    style: TextStyle(
                      color: Color(0xFF1D212C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC0C5CF),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _launchMileageThief();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchFaqEmail() async {
    final body = Uri.encodeComponent(await _buildFaqEmailBody());
    final subject = Uri.encodeComponent('FAQ 문의');
    final uri = Uri.parse(
      'mailto:skylife927@gmail.com?subject=$subject&body=$body',
    );

    if (!await _tryLaunchExternal(uri)) {
      Fluttertoast.showToast(msg: '이메일 앱을 열 수 없습니다.');
    }
  }

  Future<String> _buildFaqEmailBody() async {
    final info = await PackageInfo.fromPlatform();
    final deviceInfoPlugin = DeviceInfoPlugin();
    String os = Platform.operatingSystem;
    String model = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      os = 'Android ${androidInfo.version.release}';
      model = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      os = 'iOS ${iosInfo.systemVersion}';
      model = iosInfo.utsname.machine;
    }

    return '문의내역:\n버전: ${info.version}\nOS: $os\n모델명: $model';
  }

  Future<bool> _tryLaunchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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

  Future<void> _launchMileageThief() async {
    final primaryUri = Platform.isAndroid
        ? Uri.parse('market://details?id=com.mungyu.mileage_thief')
        : Uri.parse('https://apps.apple.com/app/id6446247689');
    final fallbackUri = Platform.isAndroid
        ? Uri.parse(
            'https://play.google.com/store/apps/details?id=com.mungyu.mileage_thief',
          )
        : primaryUri;

    if (await _tryLaunchExternal(primaryUri)) {
      return;
    }
    if (fallbackUri != primaryUri && await _tryLaunchExternal(fallbackUri)) {
      return;
    }

    Fluttertoast.showToast(msg: '스토어를 열 수 없습니다.');
  }
}
