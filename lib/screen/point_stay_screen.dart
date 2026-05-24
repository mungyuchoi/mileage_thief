import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../const/colors.dart';
import '../models/community_label_model.dart';
import '../models/marriott_stay_record.dart';
import '../models/point_hotel_model.dart';
import '../services/analytics_service.dart';
import '../services/marriott_stay_service.dart';
import '../services/point_hotel_service.dart';
import '../widgets/admob_banner.dart';
import '../widgets/marriott_stay_records_tab.dart';
import '../widgets/point_hotel_explore_tab.dart';
import '../widgets/point_hotel_favorite_button.dart';
import '../widgets/point_hotel_tab.dart';
import '../widgets/segment_tab_bar.dart';
import 'community_detail_screen.dart';
import 'community_post_create_simple_screen.dart';
import 'marriott_stay_list_screen.dart';
import 'marriott_stay_form_screen.dart';
import 'point_hotel_detail_screen.dart';
import 'user_scrap_upload_screen.dart';

enum _PointStayTabKind {
  feed,
  brand,
  records,
  hotel,
  explore,
}

enum _PointStayCreateAction {
  write,
  blog,
  cafe,
  hotelRequest,
}

class _PointStayTabConfig {
  final String label;
  final String analyticsName;
  final _PointStayTabKind kind;
  final String? featureId;

  const _PointStayTabConfig({
    required this.label,
    required this.analyticsName,
    this.kind = _PointStayTabKind.feed,
    this.featureId,
  });
}

class PointStayScreen extends StatefulWidget {
  const PointStayScreen({super.key});

  @override
  State<PointStayScreen> createState() => _PointStayScreenState();
}

class _PointStayScreenState extends State<PointStayScreen>
    with SingleTickerProviderStateMixin {
  static const List<_PointStayTabConfig> _tabConfigs = <_PointStayTabConfig>[
    _PointStayTabConfig(
      label: '피드',
      analyticsName: 'feed',
      featureId: CommunityLabel.pointStayFeatureId,
    ),
    _PointStayTabConfig(
      label: '호텔',
      analyticsName: 'hotel',
      kind: _PointStayTabKind.hotel,
    ),
    _PointStayTabConfig(
      label: '탐색',
      analyticsName: 'hotel_explore',
      kind: _PointStayTabKind.explore,
    ),
    _PointStayTabConfig(
      label: '메리어트',
      analyticsName: 'marriott',
      kind: _PointStayTabKind.brand,
      featureId: CommunityLabel.marriottFeatureId,
    ),
    _PointStayTabConfig(
      label: '아코르',
      analyticsName: 'accor',
      kind: _PointStayTabKind.brand,
      featureId: CommunityLabel.accorFeatureId,
    ),
    _PointStayTabConfig(
      label: '힐튼',
      analyticsName: 'hilton',
      kind: _PointStayTabKind.brand,
      featureId: CommunityLabel.hiltonFeatureId,
    ),
    _PointStayTabConfig(
      label: 'IHG',
      analyticsName: 'ihg',
      kind: _PointStayTabKind.brand,
      featureId: CommunityLabel.ihgFeatureId,
    ),
    _PointStayTabConfig(
      label: '하얏트',
      analyticsName: 'hyatt',
      kind: _PointStayTabKind.brand,
      featureId: CommunityLabel.hyattFeatureId,
    ),
    _PointStayTabConfig(
      label: '숙박기록',
      analyticsName: 'marriott_stays',
      kind: _PointStayTabKind.records,
    ),
  ];

  late final TabController _tabController;
  final Map<String, List<_PointStayFeedPost>> _feedPostsByFeature =
      <String, List<_PointStayFeedPost>>{};
  final Set<String> _loadingFeatureIds = <String>{};
  int _selectedTabIndex = 0;
  bool _pointStayActionMenuOpen = false;

  _PointStayTabConfig get _selectedTabConfig => _tabConfigs[_selectedTabIndex];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabConfigs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    AnalyticsService.instance.logScreenView(
      'point_stay',
      screenClass: 'PointStayScreen',
      source: 'screen_init',
    );
    _loadFeedPosts(CommunityLabel.pointStayFeatureId);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_selectedTabIndex == nextIndex) return;
    setState(() {
      _selectedTabIndex = nextIndex;
      _pointStayActionMenuOpen = false;
    });
    final config = _selectedTabConfig;
    AnalyticsService.instance.logAction('sub_tab_selected', params: {
      'tab_group': 'point_stay',
      'tab': config.analyticsName,
    });
    final featureId = config.featureId;
    if (featureId != null && !_feedPostsByFeature.containsKey(featureId)) {
      _loadFeedPosts(featureId);
    }
  }

  Future<void> _loadFeedPosts(String featureId, {bool force = false}) async {
    if (!force && _feedPostsByFeature.containsKey(featureId)) return;
    if (mounted) {
      setState(() => _loadingFeatureIds.add(featureId));
    }
    try {
      final indexedPosts = await _loadIndexedFeedPosts(featureId);
      final baseQuery = FirebaseFirestore.instance
          .collectionGroup('posts')
          .where('isDeleted', isEqualTo: false)
          .where('isHidden', isEqualTo: false);
      final legacyDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...await _loadLegacyPostDocs(
          baseQuery.where('entityRefs.featureKind', isEqualTo: featureId),
          debugLabel: 'featureKind',
        ),
        ...await _loadLegacyPostDocs(
          baseQuery.where(
            'entityRefs.featureKinds',
            arrayContains: featureId,
          ),
          debugLabel: 'featureKinds',
        ),
      ];

      final postsByPath = <String, _PointStayFeedPost>{};
      for (final post in indexedPosts) {
        if (post.isDeleted || post.isHidden) continue;
        postsByPath[post.postPath] = post;
      }
      for (final doc in legacyDocs) {
        final post = _PointStayFeedPost.fromPostDoc(doc);
        if (post == null || post.isDeleted || post.isHidden) continue;
        postsByPath[post.postPath] = post;
      }

      final posts = postsByPath.values.toList()
        ..sort((a, b) {
          final created = b.createdAt.compareTo(a.createdAt);
          if (created != 0) return created;
          return b.commentCount.compareTo(a.commentCount);
        });

      if (!mounted) return;
      setState(() {
        _feedPostsByFeature[featureId] = posts.take(60).toList(growable: false);
        _loadingFeatureIds.remove(featureId);
      });
    } catch (e) {
      debugPrint('포숙 피드 로드 오류($featureId): $e');
      if (!mounted) return;
      setState(() => _loadingFeatureIds.remove(featureId));
    }
  }

  Future<List<_PointStayFeedPost>> _loadIndexedFeedPosts(
    String featureId,
  ) async {
    final ref = FirebaseFirestore.instance
        .collection('communityFeatures')
        .doc(featureId)
        .collection('labeledPosts');

    try {
      final snap =
          await ref.orderBy('createdAt', descending: true).limit(60).get();
      return snap.docs
          .map(_PointStayFeedPost.fromIndexedDoc)
          .whereType<_PointStayFeedPost>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('포숙 라벨 인덱스 최신순 조회 오류: $e');
      try {
        final snap = await ref.limit(60).get();
        return snap.docs
            .map(_PointStayFeedPost.fromIndexedDoc)
            .whereType<_PointStayFeedPost>()
            .toList(growable: false);
      } catch (fallbackError) {
        debugPrint('포숙 라벨 인덱스 기본 조회 오류: $fallbackError');
        return const <_PointStayFeedPost>[];
      }
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadLegacyPostDocs(
    Query<Map<String, dynamic>> query, {
    required String debugLabel,
  }) async {
    try {
      final snap =
          await query.orderBy('createdAt', descending: true).limit(60).get();
      return snap.docs;
    } catch (e) {
      debugPrint('포숙 관련 게시글 $debugLabel 최신순 조회 오류: $e');
      try {
        final snap = await query.limit(60).get();
        return snap.docs;
      } catch (fallbackError) {
        debugPrint('포숙 관련 게시글 $debugLabel 기본 조회 오류: $fallbackError');
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
    }
  }

  void _openFeedPost(_PointStayFeedPost post) {
    AnalyticsService.instance.logAction('point_stay_feed_post_open', params: {
      'screen': 'point_stay',
      'post_id': post.postId,
      'board_id': post.boardId,
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'community_detail'),
        builder: (_) => CommunityDetailScreen(
          postId: post.postId,
          dateString: post.dateString,
          boardId: post.boardId,
          boardName: _boardNameFor(post.boardId, post.boardName),
        ),
      ),
    );
  }

  void _openHotelFromBrand(PointHotel hotel) {
    AnalyticsService.instance.logAction('point_stay_brand_hotel_open', params: {
      'screen': 'point_stay',
      'hotel_id': hotel.id,
      'brand': hotel.brand,
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'point_hotel_detail'),
        builder: (_) => PointHotelDetailScreen(
          hotel: hotel,
          nights: 1,
          checkIn: null,
        ),
      ),
    );
  }

  Future<void> _openPointStayPostCreate([
    _PointStayTabConfig? sourceConfig,
  ]) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final config = sourceConfig ?? _selectedTabConfig;
    final labels = <CommunityLabel>[
      CommunityLabel.pointStay(),
      if (config.featureId != null &&
          config.featureId != CommunityLabel.pointStayFeatureId)
        CommunityLabel.pointStayFeature(featureId: config.featureId!),
    ];
    final labelPayload = CommunityLabelPayload.fromLabels(labels);

    AnalyticsService.instance.logAction('community_create_start', params: {
      'screen': 'point_stay',
      'source': 'point_stay_feed',
      'feature_id': config.featureId ?? CommunityLabel.pointStayFeatureId,
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'community_post_create'),
        builder: (_) => CommunityPostCreateSimpleScreen(
          initialBoardId: 'deal',
          initialBoardName: '적립/카드 혜택',
          initialLabels:
              labels.map((label) => label.toMap()).toList(growable: false),
          entityRefs: labelPayload.entityRefs,
          lockBoardSelection: true,
          accentColor: PointStayColors.accent,
          accentSoftColor: PointStayColors.accentSoft,
        ),
      ),
    );
    if (mounted) {
      await _loadFeedPosts(
        config.featureId ?? CommunityLabel.pointStayFeatureId,
        force: true,
      );
    }
  }

  Future<void> _openPointStayCreateOptions([
    _PointStayTabConfig? sourceConfig,
  ]) async {
    final config = sourceConfig ?? _selectedTabConfig;
    final action = await showModalBottomSheet<_PointStayCreateAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PointStayCreateActionSheet(
        accentColor: PointStayColors.accent,
        onSelected: (action) => Navigator.of(context).pop(action),
      ),
    );
    if (action == null || !mounted) return;
    await _runPointStayCreateAction(action, config);
  }

  Future<void> _runPointStayCreateAction(
    _PointStayCreateAction action,
    _PointStayTabConfig config,
  ) async {
    switch (action) {
      case _PointStayCreateAction.write:
        await _openPointStayPostCreate(config);
        break;
      case _PointStayCreateAction.blog:
        await _openPointStayScrapUpload(
          UserScrapUploadSource.naverBlog,
          config,
        );
        break;
      case _PointStayCreateAction.cafe:
        await _openPointStayScrapUpload(
          UserScrapUploadSource.naverCafe,
          config,
        );
        break;
      case _PointStayCreateAction.hotelRequest:
        await _openHotelRequestDialog();
        break;
    }
  }

  Future<void> _openPointStayScrapUpload(
    UserScrapUploadSource source,
    _PointStayTabConfig config,
  ) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    AnalyticsService.instance
        .logAction('point_stay_scrap_upload_open', params: {
      'screen': 'point_stay',
      'source': source.name,
      'feature_id': config.featureId ?? CommunityLabel.pointStayFeatureId,
    });

    final result = await Navigator.of(context).push<UserScrapUploadResult>(
      MaterialPageRoute<UserScrapUploadResult>(
        settings: const RouteSettings(name: 'user_scrap_upload'),
        builder: (_) => UserScrapUploadScreen(
          initialSource: source,
          initialLabels: [CommunityLabel.pointStay()],
          preferredBoardId: 'review',
          preferredBoardNameKeywords: const [
            '호텔항공리뷰',
            '호텔 항공 리뷰',
            '호텔/항공 리뷰',
            '호텔항공',
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _loadFeedPosts(CommunityLabel.pointStayFeatureId, force: true);
  }

  Future<void> _openHotelRequestDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final input = await showDialog<_HotelRequestInput>(
      context: context,
      builder: (dialogContext) => const _HotelRequestDialog(),
    );
    if (input == null || !mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final reportRef = firestore
          .collection('reports')
          .doc('hotels')
          .collection('hotels')
          .doc();
      final userReportRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .doc(reportRef.id);
      final now = FieldValue.serverTimestamp();
      final displayName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email?.trim().isNotEmpty == true
              ? user.email!.trim()
              : '사용자';
      final data = <String, Object?>{
        'reportId': reportRef.id,
        'reportPath': reportRef.path,
        'userReportPath': userReportRef.path,
        'type': 'hotel_request',
        'reason': 'hotel_request',
        'status': 'pending',
        'hotelName': input.hotelName,
        'url': input.url,
        'targetSummary': input.hotelName,
        'detail': input.url.isEmpty ? '' : input.url,
        'reporterUid': user.uid,
        'reporterName': displayName,
        'reportedAt': now,
        'createdAt': now,
        'updatedAt': now,
        'source': 'point_stay',
      };
      final batch = firestore.batch();
      batch.set(reportRef, data);
      batch.set(userReportRef, data);
      await batch.commit();

      AnalyticsService.instance
          .logAction('point_stay_hotel_request_created', params: {
        'screen': 'point_stay',
        'has_url': input.url.isNotEmpty,
      });
      Fluttertoast.showToast(msg: '호텔 요청이 접수되었습니다.');
    } catch (error) {
      debugPrint('호텔 요청 저장 오류: $error');
      Fluttertoast.showToast(msg: '호텔 요청 저장 중 오류가 발생했습니다.');
    }
  }

  Future<void> _openMarriottStayForm([MarriottStayRecord? record]) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    AnalyticsService.instance.logAction('marriott_stay_form_open', params: {
      'mode': record == null ? 'create' : 'edit',
      'screen': 'point_stay',
    });

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'marriott_stay_form'),
        builder: (_) => MarriottStayFormScreen(
          initialRecord: record,
          accentColor: PointStayColors.accent,
        ),
      ),
    );
  }

  void _openMarriottStayList() {
    AnalyticsService.instance.logAction('marriott_stay_list_open', params: {
      'screen': 'point_stay',
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'marriott_stay_list'),
        builder: (_) => const MarriottStayListScreen(
          accentColor: PointStayColors.accent,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMarriottStay(MarriottStayRecord record) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '숙박기록 삭제',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${record.hotelName} 기록을 삭제할까요?',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await MarriottStayService.deleteStay(uid: uid, stayId: record.id);
      AnalyticsService.instance.logAction('marriott_stay_deleted', params: {
        'stay_type': record.stayType.value,
        'nights': record.nights,
      });
      Fluttertoast.showToast(msg: '숙박기록이 삭제되었습니다.');
    } catch (e) {
      debugPrint('메리어트 숙박기록 삭제 오류: $e');
      Fluttertoast.showToast(msg: '삭제 중 오류가 발생했습니다.');
    }
  }

  Future<void> _refreshCurrentTab() async {
    final featureId = _selectedTabConfig.featureId;
    if (featureId != null) {
      await _loadFeedPosts(featureId, force: true);
    }
  }

  String _boardNameFor(String boardId, String? providedName) {
    final trimmed = providedName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    const names = {
      'all': '전체글',
      'free': '자유게시판',
      'deal': '적립/카드 혜택',
      'milecatch_guide': '마일캐치 사용법',
      'hot_deal': '핫딜',
      'question': '마일리지',
      'seats': '오늘의 좌석',
      'news': '오늘의 뉴스',
      'suggestion': '건의사항',
      'notice': '운영 공지사항',
    };
    return names[boardId] ?? boardId;
  }

  Widget? _buildFloatingActionButton() {
    final config = _selectedTabConfig;
    if (config.featureId != null) {
      return _PointStayFloatingActionMenu(
        isOpen: _pointStayActionMenuOpen,
        heroTag: 'point_stay_${config.featureId}_post_create',
        accentColor: PointStayColors.accent,
        onToggle: () {
          setState(() {
            _pointStayActionMenuOpen = !_pointStayActionMenuOpen;
          });
        },
        onAction: (action) async {
          setState(() => _pointStayActionMenuOpen = false);
          await _runPointStayCreateAction(action, config);
        },
      );
    }
    if (config.kind == _PointStayTabKind.records) {
      return FloatingActionButton.extended(
        heroTag: 'marriott_stay_record_create',
        icon: const Icon(Icons.add),
        label: const Text('기록 추가'),
        onPressed: () => _openMarriottStayForm(),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Theme(
      data: _pointStayTheme(context),
      child: Scaffold(
        backgroundColor: McColors.background,
        floatingActionButton: _buildFloatingActionButton(),
        appBar: AppBar(
          title: const Text('포인트 숙박'),
          backgroundColor: Colors.white,
          foregroundColor: McColors.ink,
          elevation: 0.4,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              ScrollableUnderlineTabBar(
                controller: _tabController,
                labels: _tabConfigs
                    .map((config) => config.label)
                    .toList(growable: false),
                indicatorColor: PointStayColors.accent,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshCurrentTab,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + bottomInset),
                    children: [
                      _buildSelectedTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _pointStayTheme(BuildContext context) {
    final base = Theme.of(context);
    final colorScheme = base.colorScheme.copyWith(
      primary: PointStayColors.accent,
      secondary: PointStayColors.accent,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: PointStayColors.accent,
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: PointStayColors.accent,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: PointStayColors.accent,
        foregroundColor: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PointStayColors.accent,
          textStyle: McTextStyles.bodyStrong,
          visualDensity: VisualDensity.compact,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PointStayColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: PointStayColors.accent,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    final config = _selectedTabConfig;
    switch (config.kind) {
      case _PointStayTabKind.feed:
        return _buildFeedTab(config);
      case _PointStayTabKind.brand:
        return _buildBrandTab(config);
      case _PointStayTabKind.records:
        return MarriottStayRecordsTab(
          onAdd: () => _openMarriottStayForm(),
          onShowAll: _openMarriottStayList,
          onEdit: _openMarriottStayForm,
          onDelete: _confirmDeleteMarriottStay,
        );
      case _PointStayTabKind.hotel:
        return const PointHotelTab();
      case _PointStayTabKind.explore:
        return const PointHotelExploreTab();
    }
  }

  Widget _buildFeedTab(_PointStayTabConfig config) {
    final featureId = config.featureId ?? CommunityLabel.pointStayFeatureId;
    final posts =
        _feedPostsByFeature[featureId] ?? const <_PointStayFeedPost>[];
    final isInitialLoading = _loadingFeatureIds.contains(featureId) &&
        !_feedPostsByFeature.containsKey(featureId);

    if (isInitialLoading) {
      return const _PointStayPanel(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '피드를 불러오는 중입니다.',
                style: McTextStyles.meta,
              ),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      final emptyText = featureId == CommunityLabel.pointStayFeatureId
          ? '아직 포인트 숙박 라벨 글이 없습니다.'
          : '아직 ${config.label} 라벨 글이 없습니다.';
      return _PointStayPanel(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Column(
              children: [
                const Icon(
                  Icons.grid_on_outlined,
                  color: McColors.mutedLight,
                  size: 38,
                ),
                const SizedBox(height: 10),
                Text(
                  emptyText,
                  style: McTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _openPointStayCreateOptions(config),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('첫 글 남기기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) => _buildFeedTile(posts[index]),
    );
  }

  Widget _buildBrandTab(_PointStayTabConfig config) {
    final featureId = config.featureId;
    final profile = _brandProfileFor(featureId);
    if (featureId == null || profile == null) {
      return _buildFeedTab(config);
    }

    final posts =
        _feedPostsByFeature[featureId] ?? const <_PointStayFeedPost>[];
    final isInitialLoading = _loadingFeatureIds.contains(featureId) &&
        !_feedPostsByFeature.containsKey(featureId);
    return StreamBuilder<List<PointHotel>>(
      stream: PointHotelService.instance.watchHotels(),
      builder: (context, snapshot) {
        final hotels = snapshot.hasData
            ? _brandHotels(profile, snapshot.data ?? const <PointHotel>[])
            : const <PointHotel>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BrandStayHero(
              profile: profile,
              hotelCount: hotels.length,
              postCount: posts.length,
              onWrite: () => _openPointStayCreateOptions(config),
            ),
            const SizedBox(height: 8),
            _BrandHotelSection(
              profile: profile,
              hotels: hotels,
              postCount: posts.length,
              isLoading: !snapshot.hasData && !snapshot.hasError,
              hasError: snapshot.hasError,
              onHotelTap: _openHotelFromBrand,
            ),
            const SizedBox(height: 8),
            const AppBannerAd(padding: EdgeInsets.symmetric(horizontal: 16)),
            const SizedBox(height: 8),
            _PointStayPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandFeedSectionHeader(
                    profile: profile,
                    postCount: posts.length,
                    onWrite: () => _openPointStayCreateOptions(config),
                  ),
                  const SizedBox(height: 10),
                  if (isInitialLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '브랜드 피드를 불러오는 중입니다.',
                            style: McTextStyles.meta,
                          ),
                        ),
                      ],
                    )
                  else if (posts.isEmpty)
                    _BrandEmptyFeedContent(
                      profile: profile,
                      onWrite: () => _openPointStayCreateOptions(config),
                    )
                  else ...[
                    _BrandFeaturedPostCard(
                      post: posts.first,
                      profile: profile,
                      onTap: () => _openFeedPost(posts.first),
                    ),
                    if (posts.length > 1) ...[
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length - 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemBuilder: (context, index) => _buildFeedTile(
                          posts[index + 1],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedTile(_PointStayFeedPost post) {
    final imageUrl = post.imageUrl;
    return Material(
      color: McColors.field,
      child: InkWell(
        onTap: () => _openFeedPost(post),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              ColoredBox(
                color: Colors.white,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => _buildTextFeedTile(post),
                ),
              )
            else
              _buildTextFeedTile(post),
            if (post.commentCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFeedTile(_PointStayFeedPost post) {
    final preview = post.previewText.trim();
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.16,
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                preview,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: McColors.muted,
                  fontSize: 11,
                  height: 1.22,
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 4),
          Text(
            _boardNameFor(post.boardId, post.boardName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McTextStyles.micro,
          ),
        ],
      ),
    );
  }
}

class _PointStayBrandProfile {
  final String featureId;
  final String label;
  final String programName;
  final String headline;
  final String description;
  final String metricLabel;
  final String metricValue;
  final List<String> keywords;
  final List<String> chips;
  final String iconAsset;
  final Color softColor;

  const _PointStayBrandProfile({
    required this.featureId,
    required this.label,
    required this.programName,
    required this.headline,
    required this.description,
    required this.metricLabel,
    required this.metricValue,
    required this.keywords,
    required this.chips,
    required this.iconAsset,
    required this.softColor,
  });
}

const List<_PointStayBrandProfile> _pointStayBrandProfiles =
    <_PointStayBrandProfile>[
  _PointStayBrandProfile(
    featureId: CommunityLabel.marriottFeatureId,
    label: '메리어트',
    programName: 'Marriott Bonvoy',
    headline: '무료숙박권과 5박 리듬을 같이 보기',
    description: '메리어트 포인트 숙박 후보와 사용자 후기를 한 번에 보고, 성수기 현금가가 올라가는 호텔을 먼저 잡아보세요.',
    metricLabel: '추천 흐름',
    metricValue: '5박째 무료',
    keywords: ['marriott', 'westin', 'sheraton', 'ritz', 'st. regis'],
    chips: ['무료숙박권', '5박째 무료', '라운지', '성수기'],
    iconAsset: 'asset/icon/icon_marriott.svg',
    softColor: Color(0xFFEFF6FF),
  ),
  _PointStayBrandProfile(
    featureId: CommunityLabel.accorFeatureId,
    label: '아코르',
    programName: 'Accor Live Limitless',
    headline: '현금가와 ALL 포인트 차이를 바로 비교',
    description: '아코르 계열 호텔의 현금가, 포인트 사용 가치, 위치 장점을 커뮤니티 피드와 함께 훑어보세요.',
    metricLabel: '핵심 체크',
    metricValue: '현금가 대비',
    keywords: ['accor', 'fairmont', 'sofitel', 'pullman', 'novotel'],
    chips: ['ALL 포인트', '도심 호텔', '현금가 비교', '가족 여행'],
    iconAsset: 'asset/icon/icon_accor.webp',
    softColor: Color(0xFFF0FDF4),
  ),
  _PointStayBrandProfile(
    featureId: CommunityLabel.hiltonFeatureId,
    label: '힐튼',
    programName: 'Hilton Honors',
    headline: '5박째 무료와 리조트 후보를 먼저 보기',
    description: '힐튼 포인트 후보 호텔에 실제 공유 글을 붙여서, 무료숙박 리듬과 조식/티어 체감 포인트를 같이 봅니다.',
    metricLabel: '추천 흐름',
    metricValue: '5박째 무료',
    keywords: ['hilton', 'doubletree', 'conrad', 'waldorf'],
    chips: ['5박째 무료', '조식', '리조트', '티어 혜택'],
    iconAsset: 'asset/icon/icon_hilton.svg',
    softColor: Color(0xFFFFF7ED),
  ),
  _PointStayBrandProfile(
    featureId: CommunityLabel.ihgFeatureId,
    label: 'IHG',
    programName: 'IHG One Rewards',
    headline: '다이내믹 포인트 변동을 빠르게 포착',
    description: 'IHG 계열 후보 호텔과 최근 포숙 공유를 붙여서, 공항/도심 실속 호텔의 변동 타이밍을 확인합니다.',
    metricLabel: '핵심 체크',
    metricValue: '변동 포인트',
    keywords: ['ihg', 'holiday', 'intercontinental', 'kimpton', 'crowne'],
    chips: ['공항 호텔', '변동 포인트', '실속 숙박', '환승'],
    iconAsset: 'asset/icon/icon_ihg.svg',
    softColor: Color(0xFFF5F3FF),
  ),
  _PointStayBrandProfile(
    featureId: CommunityLabel.hyattFeatureId,
    label: '하얏트',
    programName: 'World of Hyatt',
    headline: '낮은 카테고리 고효율 호텔 먼저 잡기',
    description: '하얏트 후보 호텔의 카테고리, 포인트 가치, 실제 후기 흐름을 함께 보여줘 다음 포숙 결정을 돕습니다.',
    metricLabel: '추천 흐름',
    metricValue: '저카테고리',
    keywords: ['hyatt', 'jdv', 'andaz', 'park hyatt', 'hyatt place'],
    chips: ['카테고리', '게스트 선호', '스윗스팟', '후기'],
    iconAsset: 'asset/icon/icon_hyatt.svg',
    softColor: Color(0xFFFDF2F8),
  ),
];

_PointStayBrandProfile? _brandProfileFor(String? featureId) {
  if (featureId == null) return null;
  for (final profile in _pointStayBrandProfiles) {
    if (profile.featureId == featureId) return profile;
  }
  return null;
}

List<PointHotel> _brandHotels(
  _PointStayBrandProfile profile,
  List<PointHotel> source,
) {
  final hotels = source.where((hotel) {
    if (profile.featureId == CommunityLabel.marriottFeatureId &&
        hotel.isMarriottBonvoy) {
      return true;
    }
    final brand = hotel.brand.toLowerCase();
    final name = hotel.name.toLowerCase();
    return profile.keywords.any(
      (keyword) => brand.contains(keyword) || name.contains(keyword),
    );
  }).toList(growable: false);

  return hotels.toList()
    ..sort((a, b) {
      final hasRate =
          (b.hasAwardRate ? 1 : 0).compareTo(a.hasAwardRate ? 1 : 0);
      if (hasRate != 0) return hasRate;
      final value = b.krwPerPoint.compareTo(a.krwPerPoint);
      if (value != 0) return value;
      return b.rating.compareTo(a.rating);
    });
}

class _PointStayBrandIcon extends StatelessWidget {
  final _PointStayBrandProfile profile;
  final double size;

  const _PointStayBrandIcon({
    required this.profile,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final icon = profile.iconAsset.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(
            profile.iconAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          )
        : Image.asset(
            profile.iconAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );

    return SizedBox(
      width: size,
      height: size,
      child: icon,
    );
  }
}

class _BrandStayHero extends StatelessWidget {
  final _PointStayBrandProfile profile;
  final int hotelCount;
  final int postCount;
  final VoidCallback onWrite;

  const _BrandStayHero({
    required this.profile,
    required this.hotelCount,
    required this.postCount,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: 44,
                child: Center(
                  child: _PointStayBrandIcon(profile: profile, size: 36),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.label} 포숙 라운지',
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w400,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.programName,
                      style: const TextStyle(
                        color: PointStayColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile.headline,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(profile.description, style: McTextStyles.body),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final chip in profile.chips) _BrandChip(label: chip),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BrandMetric(
                label: '호텔',
                value: '$hotelCount개',
              ),
              const SizedBox(width: 8),
              _BrandMetric(
                label: '공유글',
                value: '$postCount개',
              ),
              const SizedBox(width: 8),
              _BrandMetric(
                label: profile.metricLabel,
                value: profile.metricValue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onWrite,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text('${profile.label} 포숙 공유'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PointStayColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w400),
                side: const BorderSide(color: McColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  final String label;

  const _BrandChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PointStayColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: PointStayColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _BrandMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BrandMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: McColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McTextStyles.micro,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHotelSection extends StatelessWidget {
  final _PointStayBrandProfile profile;
  final List<PointHotel> hotels;
  final int postCount;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<PointHotel> onHotelTap;

  const _BrandHotelSection({
    required this.profile,
    required this.hotels,
    required this.postCount,
    this.isLoading = false,
    this.hasError = false,
    required this.onHotelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '지금 볼 만한 호텔',
                  style: McTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                profile.programName,
                style: McTextStyles.micro,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Firestore 호텔 정보를 불러오는 중입니다.',
                    style: McTextStyles.meta,
                  ),
                ),
              ],
            )
          else if (hasError)
            const _BrandHotelStatusPanel(
              text: '호텔 정보를 불러오지 못했습니다. Firestore 연결 또는 권한을 확인해 주세요.',
            )
          else if (hotels.isEmpty)
            _BrandNoHotelPanel(profile: profile)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < hotels.length; i++) ...[
                    SizedBox(
                      width: 254,
                      child: _BrandHotelCard(
                        hotel: hotels[i],
                        relatedPostCount: postCount == 0
                            ? 0
                            : (postCount - i).clamp(1, postCount),
                        onTap: () => onHotelTap(hotels[i]),
                      ),
                    ),
                    if (i != hotels.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandHotelCard extends StatelessWidget {
  final PointHotel hotel;
  final int relatedPostCount;
  final VoidCallback onTap;

  const _BrandHotelCard({
    required this.hotel,
    required this.relatedPostCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: McColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: AspectRatio(
                  aspectRatio: 1.75,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        hotel.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Icon(Icons.hotel_outlined, size: 34),
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: 5,
                        child: PointHotelFavoriteButton(
                          hotel: hotel,
                          color: Colors.white,
                          selectedColor: Colors.white,
                          size: 24,
                          minTouchSize: 36,
                          splashRadius: 20,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hotel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: McColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, size: 15),
                        Text(
                          hotel.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hotel.locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _HotelValueChip(
                          label: hotel.hasAwardRate
                              ? '${NumberFormat('#,###').format(hotel.pointsPerNight)} pts'
                              : '포인트 확인 전',
                          accent: true,
                        ),
                        if (hotel.hasAwardRate && hotel.hasCashRate)
                          _HotelValueChip(
                            label:
                                '${hotel.krwPerPoint.toStringAsFixed(1)}원/pt',
                          ),
                        _HotelValueChip(
                          label: relatedPostCount == 0
                              ? '관련 글 대기'
                              : '관련 글 $relatedPostCount개',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelValueChip extends StatelessWidget {
  final String label;
  final bool accent;

  const _HotelValueChip({
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? PointStayColors.accentSoft : McColors.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: accent ? PointStayColors.accent : McColors.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _BrandHotelStatusPanel extends StatelessWidget {
  final String text;

  const _BrandHotelStatusPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return _PointStayPanel(
      child: Text(
        text,
        style: McTextStyles.meta,
      ),
    );
  }
}

class _BrandNoHotelPanel extends StatelessWidget {
  final _PointStayBrandProfile profile;

  const _BrandNoHotelPanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _PointStayPanel(
      child: Text(
        '${profile.label} 호텔 후보를 준비 중입니다.',
        style: McTextStyles.body,
      ),
    );
  }
}

class _BrandFeedSectionHeader extends StatelessWidget {
  final _PointStayBrandProfile profile;
  final int postCount;
  final VoidCallback onWrite;

  const _BrandFeedSectionHeader({
    required this.profile,
    required this.postCount,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '피드',
                style: McTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${profile.label} 라벨 글 $postCount개',
                style: McTextStyles.meta,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onWrite,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('글쓰기'),
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class _BrandFeaturedPostCard extends StatelessWidget {
  final _PointStayFeedPost post;
  final _PointStayBrandProfile profile;
  final VoidCallback onTap;

  const _BrandFeaturedPostCard({
    required this.post,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrl;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: McColors.line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: imageUrl == null
                      ? ColoredBox(
                          color: profile.softColor,
                          child: Center(
                            child: _PointStayBrandIcon(
                              profile: profile,
                              size: 32,
                            ),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: profile.softColor,
                            child: Center(
                              child: _PointStayBrandIcon(
                                profile: profile,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HotelValueChip(label: profile.label, accent: true),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _feedDateLabel(post),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McTextStyles.micro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      post.previewText.isEmpty
                          ? '내용 미리보기 없음'
                          : post.previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McTextStyles.meta,
                    ),
                    if (post.commentCount > 0) ...[
                      const SizedBox(height: 7),
                      Text(
                        '댓글 ${post.commentCount}개',
                        style: const TextStyle(
                          color: PointStayColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandEmptyFeedContent extends StatelessWidget {
  final _PointStayBrandProfile profile;
  final VoidCallback onWrite;

  const _BrandEmptyFeedContent({
    required this.profile,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PointStayBrandIcon(profile: profile, size: 36),
        const SizedBox(height: 10),
        Text(
          '아직 ${profile.label} 라벨 글이 없습니다.',
          textAlign: TextAlign.center,
          style: McTextStyles.bodyStrong.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '호텔 후보는 먼저 보여주고, 사용자가 공유하면 이곳에 실제 후기가 쌓입니다.',
          textAlign: TextAlign.center,
          style: McTextStyles.meta,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onWrite,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('첫 글 남기기'),
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

String _feedDateLabel(_PointStayFeedPost post) {
  if (post.createdAt.millisecondsSinceEpoch > 0) {
    return DateFormat('M월 d일').format(post.createdAt);
  }
  return post.dateString;
}

class _PointStayPanel extends StatelessWidget {
  final Widget child;

  const _PointStayPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: child,
    );
  }
}

class _PointStayFloatingActionMenu extends StatelessWidget {
  final bool isOpen;
  final String heroTag;
  final Color accentColor;
  final VoidCallback onToggle;
  final ValueChanged<_PointStayCreateAction> onAction;

  const _PointStayFloatingActionMenu({
    required this.isOpen,
    required this.heroTag,
    required this.accentColor,
    required this.onToggle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isOpen
              ? Column(
                  key: const ValueKey('point_stay_actions_open'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _PointStayFabAction(
                      label: '글쓰기',
                      icon: Icons.edit_outlined,
                      accentColor: accentColor,
                      onTap: () => onAction(_PointStayCreateAction.write),
                    ),
                    _PointStayFabAction(
                      label: '블로그 가져오기',
                      icon: Icons.article_outlined,
                      accentColor: accentColor,
                      onTap: () => onAction(_PointStayCreateAction.blog),
                    ),
                    _PointStayFabAction(
                      label: '카페 가져오기',
                      icon: Icons.forum_outlined,
                      accentColor: accentColor,
                      onTap: () => onAction(_PointStayCreateAction.cafe),
                    ),
                    _PointStayFabAction(
                      label: '호텔 요청',
                      icon: Icons.hotel_outlined,
                      accentColor: accentColor,
                      onTap: () =>
                          onAction(_PointStayCreateAction.hotelRequest),
                    ),
                    const SizedBox(height: 8),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: heroTag,
          tooltip: isOpen ? '닫기' : '작성 메뉴',
          onPressed: onToggle,
          child: Icon(isOpen ? Icons.close_rounded : Icons.edit_outlined),
        ),
      ],
    );
  }
}

class _PointStayFabAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PointStayFabAction({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                label,
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: null,
            tooltip: label,
            backgroundColor: Colors.white,
            foregroundColor: accentColor,
            onPressed: onTap,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}

class _PointStayCreateActionSheet extends StatelessWidget {
  final Color accentColor;
  final ValueChanged<_PointStayCreateAction> onSelected;

  const _PointStayCreateActionSheet({
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8DCE3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          _PointStayActionTile(
            label: '글쓰기',
            icon: Icons.edit_outlined,
            accentColor: accentColor,
            onTap: () => onSelected(_PointStayCreateAction.write),
          ),
          _PointStayActionTile(
            label: '블로그 가져오기',
            icon: Icons.article_outlined,
            accentColor: accentColor,
            onTap: () => onSelected(_PointStayCreateAction.blog),
          ),
          _PointStayActionTile(
            label: '카페 가져오기',
            icon: Icons.forum_outlined,
            accentColor: accentColor,
            onTap: () => onSelected(_PointStayCreateAction.cafe),
          ),
          _PointStayActionTile(
            label: '호텔 요청',
            icon: Icons.hotel_outlined,
            accentColor: accentColor,
            onTap: () => onSelected(_PointStayCreateAction.hotelRequest),
          ),
        ],
      ),
    );
  }
}

class _PointStayActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PointStayActionTile({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: accentColor.withValues(alpha: 0.11),
        foregroundColor: accentColor,
        child: Icon(icon),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _HotelRequestInput {
  final String hotelName;
  final String url;

  const _HotelRequestInput({
    required this.hotelName,
    required this.url,
  });
}

class _HotelRequestDialog extends StatefulWidget {
  const _HotelRequestDialog();

  @override
  State<_HotelRequestDialog> createState() => _HotelRequestDialogState();
}

class _HotelRequestDialogState extends State<_HotelRequestDialog> {
  final TextEditingController _hotelController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _hotelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final hotelName = _hotelController.text.trim();
    final url = _urlController.text.trim();
    if (hotelName.isEmpty) {
      setState(() => _errorText = '호텔명을 입력해주세요.');
      return;
    }
    Navigator.of(context).pop(
      _HotelRequestInput(
        hotelName: hotelName,
        url: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        '호텔 요청',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hotelController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '호텔명',
              hintText: '예: JW 메리어트 제주',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL (선택)',
              hintText: '공식/예약/참고 URL',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('요청'),
        ),
      ],
    );
  }
}

class _PointStayFeedPost {
  static final RegExp _imgTagPattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );

  final String postPath;
  final String postId;
  final String dateString;
  final String title;
  final String boardId;
  final String? boardName;
  final String? imageUrl;
  final String previewText;
  final int commentCount;
  final DateTime createdAt;
  final bool isDeleted;
  final bool isHidden;

  const _PointStayFeedPost({
    required this.postPath,
    required this.postId,
    required this.dateString,
    required this.title,
    required this.boardId,
    required this.boardName,
    required this.imageUrl,
    required this.previewText,
    required this.commentCount,
    required this.createdAt,
    required this.isDeleted,
    required this.isHidden,
  });

  static _PointStayFeedPost? fromIndexedDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final postPath = _feedString(data['postPath']);
    final postId = _feedString(data['postId'], fallback: doc.id);
    final dateString = _feedString(
      data['dateString'],
      fallback: _dateStringFromPostPath(postPath),
    );
    if (postId.isEmpty || dateString.isEmpty) return null;

    return _PointStayFeedPost(
      postPath: postPath.isEmpty ? 'posts/$dateString/posts/$postId' : postPath,
      postId: postId,
      dateString: dateString,
      title: _feedString(data['title'], fallback: '제목 없음'),
      boardId: _feedString(data['boardId'], fallback: 'free'),
      boardName: _nullableFeedString(data['boardName']),
      imageUrl: _cleanFeedUrl(_feedString(data['imageUrl'])),
      previewText: _feedString(data['previewText']),
      commentCount: _feedInt(data['commentCount'] ?? data['commentsCount']),
      createdAt: _feedDateTime(data['createdAt']),
      isDeleted: data['isDeleted'] == true,
      isHidden: data['isHidden'] == true,
    );
  }

  static _PointStayFeedPost? fromPostDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dateDoc = doc.reference.parent.parent;
    final dateString = dateDoc?.id;
    if (dateString == null || dateString.isEmpty) return null;
    final data = doc.data();
    final contentHtml = _feedString(data['contentHtml']);
    return _PointStayFeedPost(
      postPath: doc.reference.path,
      postId: _feedString(data['postId'], fallback: doc.id),
      dateString: dateString,
      title: _feedString(data['title'], fallback: '제목 없음'),
      boardId: _feedString(data['boardId'], fallback: 'free'),
      boardName: _nullableFeedString(data['boardName']),
      imageUrl: _firstImageUrl(data, contentHtml),
      previewText: _previewTextFromData(data, contentHtml),
      commentCount: _feedInt(data['commentCount'] ?? data['commentsCount']),
      createdAt: _feedDateTime(data['createdAt']),
      isDeleted: data['isDeleted'] == true,
      isHidden: data['isHidden'] == true,
    );
  }

  static String? _firstImageUrl(
    Map<String, dynamic> data,
    String contentHtml,
  ) {
    final htmlMatch = _imgTagPattern.firstMatch(contentHtml);
    final htmlUrl =
        htmlMatch == null ? null : _cleanFeedUrl(htmlMatch.group(1));
    if (htmlUrl != null) return htmlUrl;

    final imageUrl = _cleanFeedUrl(_feedString(data['imageUrl']));
    if (imageUrl != null) return imageUrl;

    final fromImageUrls = _firstUrlFromList(data['imageUrls']);
    if (fromImageUrls != null) return fromImageUrls;

    return _firstUrlFromList(data['attachments']);
  }

  static String? _firstUrlFromList(Object? raw) {
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is String) {
        final url = _cleanFeedUrl(item);
        if (url != null) return url;
      }
      if (item is Map) {
        final url = _cleanFeedUrl(item['url']?.toString());
        if (url != null) return url;
      }
    }
    return null;
  }

  static String _previewTextFromData(
    Map<String, dynamic> data,
    String contentHtml,
  ) {
    final fromHtml = _plainTextFromHtml(contentHtml);
    if (fromHtml.isNotEmpty) return fromHtml;
    for (final key in const ['plainText', 'contentText', 'content']) {
      final text = _feedString(data[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _plainTextFromHtml(String html) {
    if (html.trim().isEmpty) return '';
    final withBreaks = html
        .replaceAll(_imgTagPattern, ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|h[1-6])\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeHtmlEntities(withBreaks)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String _dateStringFromPostPath(String path) {
    final parts = path.split('/');
    if (parts.length >= 4 && parts[0] == 'posts' && parts[2] == 'posts') {
      return parts[1];
    }
    return '';
  }
}

String _feedString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableFeedString(Object? value) {
  final text = _feedString(value);
  return text.isEmpty ? null : text;
}

int _feedInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_feedString(value)) ?? 0;
}

DateTime _feedDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String? _cleanFeedUrl(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text.replaceAll('&amp;', '&');
}
