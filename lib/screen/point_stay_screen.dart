import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../const/colors.dart';
import '../models/community_label_model.dart';
import '../models/marriott_stay_record.dart';
import '../services/analytics_service.dart';
import '../services/marriott_stay_service.dart';
import '../widgets/hotel_award_explore_tab.dart';
import '../widgets/marriott_stay_records_tab.dart';
import '../widgets/segment_tab_bar.dart';
import 'community_detail_screen.dart';
import 'community_post_create_simple_screen.dart';
import 'marriott_stay_list_screen.dart';
import 'marriott_stay_form_screen.dart';

enum _PointStayTabKind {
  feed,
  records,
  explore,
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
      label: '메리어트',
      analyticsName: 'marriott',
      featureId: CommunityLabel.marriottFeatureId,
    ),
    _PointStayTabConfig(
      label: '아코르',
      analyticsName: 'accor',
      featureId: CommunityLabel.accorFeatureId,
    ),
    _PointStayTabConfig(
      label: '힐튼',
      analyticsName: 'hilton',
      featureId: CommunityLabel.hiltonFeatureId,
    ),
    _PointStayTabConfig(
      label: 'IHG',
      analyticsName: 'ihg',
      featureId: CommunityLabel.ihgFeatureId,
    ),
    _PointStayTabConfig(
      label: '하얏트',
      analyticsName: 'hyatt',
      featureId: CommunityLabel.hyattFeatureId,
    ),
    _PointStayTabConfig(
      label: '숙박기록',
      analyticsName: 'marriott_stays',
      kind: _PointStayTabKind.records,
    ),
    _PointStayTabConfig(
      label: '탐색',
      analyticsName: 'explore',
      kind: _PointStayTabKind.explore,
    ),
  ];

  late final TabController _tabController;
  final Map<String, List<_PointStayFeedPost>> _feedPostsByFeature =
      <String, List<_PointStayFeedPost>>{};
  final Set<String> _loadingFeatureIds = <String>{};
  int _selectedTabIndex = 0;

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
    setState(() => _selectedTabIndex = nextIndex);
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
        builder: (_) => MarriottStayFormScreen(initialRecord: record),
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
        builder: (_) => const MarriottStayListScreen(),
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
      return FloatingActionButton.extended(
        heroTag: 'point_stay_${config.featureId}_post_create',
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
        onPressed: () => _openPointStayPostCreate(config),
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
    return Scaffold(
      backgroundColor: McColors.background,
      floatingActionButton: _buildFloatingActionButton(),
      appBar: AppBar(
        title: const Text('포인트 숙박'),
        backgroundColor: Colors.white,
        foregroundColor: McColors.ink,
        elevation: 0.4,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshCurrentTab,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
            children: [
              _PointStayIntro(onWrite: _openPointStayPostCreate),
              const SizedBox(height: 12),
              ScrollableUnderlineTabBar(
                controller: _tabController,
                labels: _tabConfigs
                    .map((config) => config.label)
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              _buildSelectedTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    final config = _selectedTabConfig;
    if (config.featureId != null) {
      return _buildFeedTab(config);
    }
    switch (config.kind) {
      case _PointStayTabKind.records:
        return MarriottStayRecordsTab(
          onAdd: () => _openMarriottStayForm(),
          onShowAll: _openMarriottStayList,
          onEdit: _openMarriottStayForm,
          onDelete: _confirmDeleteMarriottStay,
        );
      case _PointStayTabKind.explore:
        return const HotelAwardExploreTab();
      case _PointStayTabKind.feed:
        return _buildFeedTab(config);
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
                  onPressed: () => _openPointStayPostCreate(config),
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

class _PointStayIntro extends StatelessWidget {
  final VoidCallback onWrite;

  const _PointStayIntro({required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return _PointStayPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: McColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hotel_outlined,
              color: McColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '놓치던 숙박의 기회를\n먼저 캐치하다',
                  style: McTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                const Text(
                  '마일 좌석을 잡았다면, 이제 숙박에서 진짜 가치가 갈립니다. 현금가, 포인트가, 무료숙박권, 티어 혜택과 실전 후기를 함께 보고 오늘의 포숙 기회를 먼저 잡아보세요.',
                  style: McTextStyles.meta,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onWrite,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('포숙 기회 공유'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointStayPanel extends StatelessWidget {
  final Widget child;

  const _PointStayPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: child,
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
