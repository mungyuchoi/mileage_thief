import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/category_service.dart';
import 'branch/branch_detail_screen.dart';
import 'community_detail_screen.dart';
import 'dan_screen.dart';
import 'deals/deals_screen.dart';
import 'deals/flight_deals_screen.dart';
import 'gift/gift_buy_screen.dart';
import 'gift/gift_sell_screen.dart';

typedef _PostDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;
typedef _BoardDocs = List<Map<String, dynamic>>;
typedef _GuideAds = List<Map<String, dynamic>>;

const Map<String, String> _boardNameById = {
  'question': '마일리지',
  'deal': '적립/카드 혜택',
  'seat_share': '좌석 공유',
  'review': '항공 리뷰',
  'free': '자유게시판',
  'seats': '오늘의 좌석',
  'news': '오늘의 뉴스',
  'error_report': '오류 신고',
  'suggestion': '건의사항',
  'notice': '운영 공지사항',
  'aeroroute_news': 'AeroRoutes',
  'secretflying_news': 'SecretFlying',
  'workingholiday_news': '워킹홀리데이',
};

String _displayBoardName(Map<String, dynamic> data) {
  final boardId = (data['boardId'] as String?)?.trim();
  final boardName = (data['boardName'] as String?)?.trim();

  if (boardId != null && _boardNameById.containsKey(boardId)) {
    return _boardNameById[boardId]!;
  }
  if (boardName != null && boardName.isNotEmpty) {
    return boardName;
  }
  if (boardId != null && boardId.isNotEmpty) {
    return boardId;
  }
  return '커뮤니티';
}

String? _extractFirstImageUrl(String htmlString) {
  if (htmlString.isEmpty) return null;

  final imgTag =
      RegExp('<img[^>]+src=["\']([^"\']+)["\']', caseSensitive: false)
          .firstMatch(htmlString);
  if (imgTag != null && imgTag.groupCount >= 1) {
    return imgTag.group(1);
  }
  return null;
}

class _CacheEntry<T> {
  T? data;
  DateTime? fetchedAt;
  Future<T>? inFlight;
}

class _UsefulInfoMemoryCache {
  static const Duration ttl = Duration(minutes: 10);
  static final Map<String, _CacheEntry<dynamic>> _entries = {};

  static T? peek<T>(String key) {
    return _entries[key]?.data as T?;
  }

  static Future<T> get<T>(
    String key,
    Future<T> Function() loader, {
    bool force = false,
  }) async {
    final entry = _entries.putIfAbsent(key, () => _CacheEntry<T>());
    final typedEntry = entry as _CacheEntry<T>;
    final cachedData = typedEntry.data;
    final fetchedAt = typedEntry.fetchedAt;
    final cacheFresh =
        fetchedAt != null && DateTime.now().difference(fetchedAt) < ttl;

    if (!force && cachedData != null) {
      if (!cacheFresh && typedEntry.inFlight == null) {
        _refreshInBackground(key, loader);
      }
      return cachedData;
    }

    if (!force && typedEntry.inFlight != null) {
      return typedEntry.inFlight!;
    }

    final future = loader();
    typedEntry.inFlight = future;
    try {
      final data = await future;
      typedEntry
        ..data = data
        ..fetchedAt = DateTime.now();
      return data;
    } finally {
      typedEntry.inFlight = null;
    }
  }

  static void _refreshInBackground<T>(
    String key,
    Future<T> Function() loader,
  ) {
    get<T>(key, loader, force: true);
  }
}

class UsefulInfoScreen extends StatefulWidget {
  final VoidCallback onOpenCommunity;
  final VoidCallback onOpenGiftcard;
  final VoidCallback onOpenProfile;

  const UsefulInfoScreen({
    super.key,
    required this.onOpenCommunity,
    required this.onOpenGiftcard,
    required this.onOpenProfile,
  });

  @override
  State<UsefulInfoScreen> createState() => _UsefulInfoScreenState();
}

class _UsefulInfoScreenState extends State<UsefulInfoScreen> {
  static const double _bottomFloatingNavClearance = 176;

  final CategoryService _categoryService = CategoryService();

  Future<_PostDocs> _bestPostsFuture = Future.value(const []);
  Future<_PostDocs> _popularPostsFuture = Future.value(const []);
  Future<_PostDocs> _newsPostsFuture = Future.value(const []);
  Future<_PostDocs> _aeroRoutesNewsFuture = Future.value(const []);
  Future<_PostDocs> _secretFlyingNewsFuture = Future.value(const []);
  Future<_PostDocs> _workingHolidayNewsFuture = Future.value(const []);
  Future<_PostDocs> _benefitPostsFuture = Future.value(const []);
  Future<_PostDocs> _noticePostsFuture = Future.value(const []);
  Future<_BoardDocs> _boardsFuture = Future.value(const []);
  Future<_GuideAds> _guideAdsFuture = Future.value(const []);

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  void _loadSections({bool force = false}) {
    _bestPostsFuture = _cached(
      'bestPosts',
      _fetchBestPosts,
      force: force,
    );
    _popularPostsFuture = _cached(
      'popularPosts',
      _fetchPopularPosts,
      force: force,
    );
    _newsPostsFuture = _cached(
      'newsPosts',
      () => _fetchPostsByBoard('news', limit: 8),
      force: force,
    );
    _aeroRoutesNewsFuture = _cached(
      'aeroRoutesNewsPosts',
      () => _fetchPostsByBoard('aeroroute_news', limit: 8),
      force: force,
    );
    _secretFlyingNewsFuture = _cached(
      'secretFlyingNewsPosts',
      () => _fetchPostsByBoard('secretflying_news', limit: 8),
      force: force,
    );
    _workingHolidayNewsFuture = _cached(
      'workingHolidayNewsPosts',
      () => _fetchPostsByBoard('workingholiday_news', limit: 8),
      force: force,
    );
    _benefitPostsFuture = _cached(
      'benefitPosts',
      () => _fetchPostsByBoard('deal', limit: 8),
      force: force,
    );
    _noticePostsFuture = _cached(
      'noticePosts',
      () => _fetchPostsByBoard('notice', limit: 6),
      force: force,
    );
    _boardsFuture = _cached(
      'boards',
      _categoryService.getBoards,
      force: force,
    );
    _guideAdsFuture = _cached(
      'guideAds',
      _fetchGuideAds,
      force: force,
    );
  }

  Future<void> _refresh() async {
    setState(() => _loadSections(force: true));
    await Future.wait([
      _bestPostsFuture,
      _popularPostsFuture,
      _newsPostsFuture,
      _aeroRoutesNewsFuture,
      _secretFlyingNewsFuture,
      _workingHolidayNewsFuture,
      _benefitPostsFuture,
      _noticePostsFuture,
      _boardsFuture,
      _guideAdsFuture,
    ]);
  }

  Future<T> _cached<T>(
    String key,
    Future<T> Function() loader, {
    bool force = false,
  }) {
    return _UsefulInfoMemoryCache.get<T>(key, loader, force: force);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          _bottomFloatingNavClearance,
        ),
        children: [
          _GuideAdBannerSection(
            future: _guideAdsFuture,
            initialAds: _UsefulInfoMemoryCache.peek<_GuideAds>('guideAds'),
            onTapAd: _handleAdTap,
          ),
          _QuickActionsSection(
            actions: [
              _QuickAction(
                icon: Icons.flight_takeoff,
                title: '특가',
                subtitle: '항공권/호텔',
                onTap: () => _push(const DealsScreen()),
              ),
              _QuickAction(
                icon: Icons.airplane_ticket_outlined,
                title: '대한항공',
                subtitle: '마일리지 검색',
                onTap: () => _push(const SearchDanScreen()),
              ),
              _QuickAction(
                icon: Icons.card_giftcard,
                title: '상품권',
                subtitle: '시세/지도',
                onTap: widget.onOpenGiftcard,
              ),
              _QuickAction(
                icon: Icons.shopping_cart_outlined,
                title: '구매 등록',
                subtitle: '상품권',
                onTap: () => _push(const GiftBuyScreen()),
              ),
              _QuickAction(
                icon: Icons.attach_money_outlined,
                title: '판매 등록',
                subtitle: '상품권',
                onTap: () => _push(const GiftSellScreen()),
              ),
              _QuickAction(
                icon: Icons.person_outline,
                title: '프로필',
                subtitle: '내 활동',
                onTap: widget.onOpenProfile,
              ),
            ],
          ),
          const _GiftcardRateTableSection(),
          _PostSection(
            title: '베스트 게시글',
            icon: Icons.local_fire_department_outlined,
            future: _bestPostsFuture,
            initialPosts: _UsefulInfoMemoryCache.peek<_PostDocs>('bestPosts'),
            emptyText: '아직 베스트 게시글이 없습니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
            showThumbnail: true,
          ),
          _PostSection(
            title: '인기 게시글',
            icon: Icons.trending_up,
            future: _popularPostsFuture,
            initialPosts:
                _UsefulInfoMemoryCache.peek<_PostDocs>('popularPosts'),
            emptyText: '인기 게시글을 불러오지 못했습니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
            showThumbnail: true,
          ),
          _PostSection(
            title: 'AeroRoutes',
            icon: Icons.public,
            future: _aeroRoutesNewsFuture,
            initialPosts:
                _UsefulInfoMemoryCache.peek<_PostDocs>('aeroRoutesNewsPosts'),
            emptyText: 'AeroRoutes 뉴스가 준비되는 중입니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
          _PostSection(
            title: 'SecretFlying',
            icon: Icons.public,
            future: _secretFlyingNewsFuture,
            initialPosts:
                _UsefulInfoMemoryCache.peek<_PostDocs>('secretFlyingNewsPosts'),
            emptyText: 'SecretFlying 뉴스가 준비되는 중입니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
          _PostSection(
            title: '워킹홀리데이',
            icon: Icons.public,
            future: _workingHolidayNewsFuture,
            initialPosts: _UsefulInfoMemoryCache.peek<_PostDocs>(
              'workingHolidayNewsPosts',
            ),
            emptyText: '워킹홀리데이 뉴스가 준비되는 중입니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
          _PostSection(
            title: '오늘의 뉴스',
            icon: Icons.newspaper_outlined,
            future: _newsPostsFuture,
            initialPosts: _UsefulInfoMemoryCache.peek<_PostDocs>('newsPosts'),
            emptyText: '등록된 뉴스가 없습니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
          _PostSection(
            title: '적립/카드혜택',
            icon: Icons.credit_card_outlined,
            future: _benefitPostsFuture,
            initialPosts:
                _UsefulInfoMemoryCache.peek<_PostDocs>('benefitPosts'),
            emptyText: '등록된 혜택 글이 없습니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
          _FeatureLinkSection(
            title: '핫딜',
            icon: Icons.local_offer_outlined,
            items: [
              _FeatureLink(
                title: '특가 항공권',
                subtitle: '여행사 특가 모아보기',
                icon: Icons.flight,
                onTap: () => _push(const FlightDealsScreen()),
              ),
              _FeatureLink(
                title: '쇼핑몰 적립',
                subtitle: '땅콩 적립 바로가기',
                icon: Icons.shopping_bag_outlined,
                onTap: () => _push(const DealsScreen()),
              ),
            ],
          ),
          _PopularBoardSection(
            title: '인기 게시판',
            icon: Icons.dashboard_outlined,
            boardsFuture: _boardsFuture,
            postsFuture: _popularPostsFuture,
            initialBoards: _UsefulInfoMemoryCache.peek<_BoardDocs>('boards'),
            initialPosts:
                _UsefulInfoMemoryCache.peek<_PostDocs>('popularPosts'),
            onOpenCommunity: widget.onOpenCommunity,
          ),
          _PostSection(
            title: '운영 공지사항',
            icon: Icons.campaign_outlined,
            future: _noticePostsFuture,
            initialPosts: _UsefulInfoMemoryCache.peek<_PostDocs>('noticePosts'),
            emptyText: '새 공지사항이 없습니다.',
            onSeeAll: widget.onOpenCommunity,
            onTapPost: _openPost,
          ),
        ],
      ),
    );
  }

  Future<_PostDocs> _fetchBestPosts() async {
    final metaDoc = await FirebaseFirestore.instance
        .collection('meta')
        .doc('bestPosts')
        .get();
    final List<dynamic> idsDynamic = metaDoc.data()?['postIds'] ?? [];
    final postIds = idsDynamic.map((e) => e.toString()).take(10).toList();
    if (postIds.isEmpty) return [];

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('posts')
        .where('postId', whereIn: postIds)
        .where('isDeleted', isEqualTo: false)
        .get();

    final docs = snapshot.docs.where(_isVisiblePost).toList()
      ..sort((a, b) =>
          postIds.indexOf(_postId(a)).compareTo(postIds.indexOf(_postId(b))));
    return docs;
  }

  Future<_PostDocs> _fetchPopularPosts() async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('posts')
        .where('isDeleted', isEqualTo: false)
        .orderBy('likesCount', descending: true)
        .limit(10)
        .get();
    return snapshot.docs.where(_isVisiblePost).toList();
  }

  Future<_PostDocs> _fetchPostsByBoard(
    String boardId, {
    int limit = 8,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('posts')
        .where('boardId', isEqualTo: boardId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.where(_isVisiblePost).toList();
  }

  Future<_GuideAds> _fetchGuideAds() async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('bottom_sheet_ads')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: false)
        .get();

    return snap.docs
        .map<Map<String, dynamic>>(
      (doc) => <String, dynamic>{'id': doc.id, ...doc.data()},
    )
        .where((ad) {
      final Timestamp? startTs = ad['startAt'] as Timestamp?;
      final Timestamp? endTs = ad['endAt'] as Timestamp?;
      final startAt = startTs?.toDate();
      final endAt = endTs?.toDate();
      final startOk = startAt == null || !startAt.isAfter(now);
      final endOk = endAt == null || !endAt.isBefore(now);
      return startOk && endOk;
    }).toList();
  }

  bool _isVisiblePost(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data['isHidden'] != true;
  }

  String _postId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return (doc.data()['postId'] as String?) ?? doc.id;
  }

  void _openPost(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final dateString = doc.reference.parent.parent?.id;
    if (dateString == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(
          postId: _postId(doc),
          boardId: (data['boardId'] as String?) ?? 'free',
          boardName: _displayBoardName(data),
          dateString: dateString,
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handleAdTap(Map<String, dynamic> ad) {
    final linkType = (ad['linkType'] as String?) ?? 'web';
    final linkValue = (ad['linkValue'] as String?) ?? '';

    if (linkValue.isEmpty) return;

    if (linkType == 'web') {
      launchUrl(Uri.parse(linkValue), mode: LaunchMode.externalApplication);
      return;
    }

    if (linkType == 'deeplink' && linkValue.startsWith('branch:')) {
      final branchId = linkValue.substring('branch:'.length);
      if (branchId.isEmpty) return;
      _push(BranchDetailScreen(branchId: branchId));
    }
  }
}

class _GuideAdBannerSection extends StatelessWidget {
  final Future<_GuideAds> future;
  final _GuideAds? initialAds;
  final ValueChanged<Map<String, dynamic>> onTapAd;

  const _GuideAdBannerSection({
    required this.future,
    required this.initialAds,
    required this.onTapAd,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GuideAds>(
      future: future,
      initialData: initialAds,
      builder: (context, snapshot) {
        final ads = snapshot.data ?? const <Map<String, dynamic>>[];
        if (ads.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _GuideAdBannerCarousel(
            ads: ads,
            onTapAd: onTapAd,
          ),
        );
      },
    );
  }
}

class _GuideAdBannerCarousel extends StatefulWidget {
  final _GuideAds ads;
  final ValueChanged<Map<String, dynamic>> onTapAd;

  const _GuideAdBannerCarousel({
    required this.ads,
    required this.onTapAd,
  });

  @override
  State<_GuideAdBannerCarousel> createState() => _GuideAdBannerCarouselState();
}

class _GuideAdBannerCarouselState extends State<_GuideAdBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _GuideAdBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads.length != widget.ads.length) {
      _timer?.cancel();
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.ads.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_pageController.hasClients) return;
      final nextPage = ((_pageController.page?.round() ?? _currentPage) + 1) %
          widget.ads.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.ads.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final ad = widget.ads[index];
                final imageUrl = (ad['imageUrl'] as String?) ?? '';
                return Material(
                  color: const Color(0xFFEDEEF2),
                  child: InkWell(
                    onTap: () => widget.onTapAd(ad),
                    child: imageUrl.isEmpty
                        ? const Center(
                            child: Text(
                              '이미지가 없습니다',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text(
                                  '이미지를 불러오지 못했습니다',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
            Positioned(
              right: 14,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.ads.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final List<_QuickAction> actions;

  const _QuickActionsSection({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '빠른 실행',
      icon: Icons.bolt_outlined,
      child: SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 78,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F1EC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        action.icon,
                        color: const Color(0xFF74512D),
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const List<String> _giftcardRateDefaultGiftcardIds = [
  'lotte',
  'shinsegae',
  'hyundai',
  'galleria',
];

const Map<String, String> _giftcardRateDefaultNames = {
  'lotte': '롯데상품권',
  'shinsegae': '신세계상품권',
  'hyundai': '현대상품권',
  'galleria': '갤러리아상품권',
};

const double _giftcardRateNameColumnWidth = 76;
const double _giftcardRateBranchColumnWidth = 84;

String _compactGiftcardRateName(String name) {
  return name.replaceAll('상품권', '').trim();
}

class _GiftcardRateTableSection extends StatefulWidget {
  const _GiftcardRateTableSection();

  @override
  State<_GiftcardRateTableSection> createState() =>
      _GiftcardRateTableSectionState();
}

class _GiftcardRateTableSectionState extends State<_GiftcardRateTableSection> {
  static final Map<String, _GiftcardRateTableData> _cacheByUserKey = {};
  static final Map<String, Future<_GiftcardRateTableData>> _inFlightByUserKey =
      {};

  final GlobalKey _captureKey = GlobalKey();
  late Future<_GiftcardRateTableData> _future;
  bool _isExporting = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _future = _loadTableData();
  }

  Future<void> _refreshRates() async {
    if (_isRefreshing) return;
    final future = _loadTableData(force: true);
    setState(() {
      _isRefreshing = true;
      _future = future;
    });
    try {
      await future;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<_GiftcardRateTableData> _loadTableData({bool force = false}) {
    final userKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final cached = _cacheByUserKey[userKey];
    if (!force && cached != null) {
      return Future.value(cached);
    }

    if (!force && _inFlightByUserKey[userKey] != null) {
      return _inFlightByUserKey[userKey]!;
    }

    final future = _fetchTableData().then((data) {
      _cacheByUserKey[userKey] = data;
      return data;
    });
    _inFlightByUserKey[userKey] = future;
    future.whenComplete(() {
      if (identical(_inFlightByUserKey[userKey], future)) {
        _inFlightByUserKey.remove(userKey);
      }
    });
    return future;
  }

  Future<_GiftcardRateTableData> _fetchTableData() async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;
    final branchesSnap = await firestore.collection('branches').get();
    final giftsSnap = await firestore.collection('giftcards').get();
    final Map<String, Map<String, dynamic>> branchesById = {
      for (final doc in branchesSnap.docs) doc.id: doc.data(),
    };
    final Map<String, String> giftNames = {
      ..._giftcardRateDefaultNames,
      for (final doc in giftsSnap.docs)
        doc.id: (doc.data()['name'] as String?) ??
            _giftcardRateDefaultNames[doc.id] ??
            doc.id,
    };
    final Set<String> knownGiftcardIds = giftNames.keys.toSet();

    final List<String> configuredBranchIds = [];
    final List<String> configuredGiftcardIds = [];
    if (user != null) {
      try {
        final config = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('giftcard_meta')
            .doc('order')
            .get();
        final raw = config.data()?['branchIds'];
        if (raw is List) {
          configuredBranchIds.addAll(
            raw
                .map((e) => e.toString())
                .where((id) => id.isNotEmpty && branchesById.containsKey(id)),
          );
        }
        final giftRaw = config.data()?['giftcardIds'];
        if (giftRaw is List) {
          configuredGiftcardIds.addAll(
            giftRaw
                .map((e) => e.toString())
                .where((id) => id.isNotEmpty && knownGiftcardIds.contains(id)),
          );
        }
      } catch (_) {
        // 사용자 설정 로드 실패 시 기본값으로 진행합니다.
      }
    }

    final List<String> branchIds = configuredBranchIds.take(3).toList();
    if (branchIds.length < 3) {
      final defaults = await _loadDefaultBranchIds(branchesSnap.docs);
      for (final id in defaults) {
        if (branchIds.length >= 3) break;
        if (!branchIds.contains(id)) branchIds.add(id);
      }
    }

    final List<String> giftcardIds = configuredGiftcardIds.take(6).toList();
    if (giftcardIds.length < 3) {
      giftcardIds
        ..clear()
        ..addAll(
          _giftcardRateDefaultGiftcardIds
              .where((id) => knownGiftcardIds.contains(id))
              .take(6),
        );
    }

    final Map<String, Map<String, _GiftcardRateCell>> cells = {};
    for (final giftcardId in giftcardIds) {
      cells[giftcardId] = {};
    }

    for (final branchId in branchIds) {
      for (final giftcardId in giftcardIds) {
        final doc = await firestore
            .collection('branches')
            .doc(branchId)
            .collection('giftcardRates_current')
            .doc(giftcardId)
            .get();
        if (!doc.exists) continue;
        final data = doc.data();
        if (data == null) continue;
        cells[giftcardId]![branchId] = _GiftcardRateCell.fromMap(data);
      }
    }

    return _GiftcardRateTableData(
      branches: [
        for (final id in branchIds)
          _GiftcardRateBranch(
            id: id,
            name: (branchesById[id]?['name'] as String?) ?? id,
          ),
      ],
      giftcardIds: giftcardIds,
      giftcardNames: giftNames,
      cells: cells,
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<String>> _loadDefaultBranchIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> branchDocs,
  ) async {
    final List<_GiftcardRateDefaultBranchCandidate> candidates = [];
    for (final branchDoc in branchDocs) {
      final rateDoc = await branchDoc.reference
          .collection('giftcardRates_current')
          .doc('lotte')
          .get();
      final data = rateDoc.data();
      final num? sellPrice = data?['sellPrice_general'] as num?;
      if (sellPrice == null) continue;
      candidates.add(
        _GiftcardRateDefaultBranchCandidate(
          branchId: branchDoc.id,
          branchName: (branchDoc.data()['name'] as String?) ?? branchDoc.id,
          sellPrice: sellPrice.toDouble(),
          sellFeeRate:
              (data?['sellFeeRate_general'] as num?)?.toDouble() ?? 999,
        ),
      );
    }

    candidates.sort((a, b) {
      final price = b.sellPrice.compareTo(a.sellPrice);
      if (price != 0) return price;
      final fee = a.sellFeeRate.compareTo(b.sellFeeRate);
      if (fee != 0) return fee;
      return a.branchName.compareTo(b.branchName);
    });
    return candidates.take(3).map((e) => e.branchId).toList();
  }

  Future<bool> _canEdit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final roles = data?['roles'];
      if (roles is List && roles.map((e) => e.toString()).contains('admin')) {
        return true;
      }
      final grade = (data?['grade'] ?? '').toString();
      final displayGrade = (data?['displayGrade'] ?? '').toString();
      return grade == '비즈니스' ||
          grade == '퍼스트' ||
          displayGrade.startsWith('비즈니스') ||
          displayGrade.startsWith('퍼스트');
    } catch (_) {
      return false;
    }
  }

  Future<void> _openEditScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    final allowed = await _canEdit();
    if (!allowed) {
      Fluttertoast.showToast(msg: '비즈니스 레벨 이상부터 편집할 수 있습니다.');
      return;
    }

    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const GiftcardRateOrderEditScreen(),
      ),
    );
    if (changed == true) _refreshRates();
  }

  Future<Uint8List?> _captureImageBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writeTempImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'giftcard_rates_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _shareImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _captureImageBytes();
      if (bytes == null) {
        Fluttertoast.showToast(msg: '이미지를 만들지 못했습니다.');
        return;
      }
      final file = await _writeTempImage(bytes);
      await SharePlus.instance.share(
        ShareParams(
          text: '마일캐치 상품권 시세',
          files: [XFile(file.path)],
        ),
      );
    } catch (_) {
      Fluttertoast.showToast(msg: '공유 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _captureImageBytes();
      if (bytes == null) {
        Fluttertoast.showToast(msg: '이미지를 만들지 못했습니다.');
        return;
      }
      final fileName =
          'giftcard_rates_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      String? path;
      try {
        path = await FilePicker.platform.saveFile(
          dialogTitle: '상품권 시세 이미지 저장',
          fileName: fileName,
          type: FileType.image,
          bytes: bytes,
        );
      } catch (_) {
        final dir = await getApplicationDocumentsDirectory();
        final file = await File('${dir.path}/$fileName')
            .writeAsBytes(bytes, flush: true);
        path = file.path;
      }
      if (path != null) {
        Fluttertoast.showToast(msg: '상품권 시세 이미지를 저장했습니다.');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: '다운로드 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: '상품권 시세',
      icon: Icons.card_giftcard_outlined,
      child: FutureBuilder<_GiftcardRateTableData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return _GiftcardRateTableFrame(
                child: _GiftcardRateEmptyState(
                  text: '상품권 시세를 불러오지 못했습니다.',
                  onRefresh: _refreshRates,
                ),
              );
            }
            return const _GiftcardRateTableFrame(
              child: SizedBox(
                height: 168,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: _captureKey,
                child: _GiftcardRateTableFrame(
                  child: _GiftcardRateTable(data: data),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GiftcardRateActionButton(
                    icon: Icons.refresh,
                    tooltip: '새로고침',
                    loading: _isRefreshing,
                    onTap: _isRefreshing ? null : _refreshRates,
                  ),
                  const SizedBox(width: 8),
                  _GiftcardRateActionButton(
                    icon: Icons.tune,
                    tooltip: '편집',
                    onTap: _openEditScreen,
                  ),
                  const Spacer(),
                  _GiftcardRateActionButton(
                    icon: Icons.ios_share,
                    tooltip: '공유',
                    onTap: _isExporting ? null : _shareImage,
                  ),
                  const SizedBox(width: 8),
                  _GiftcardRateActionButton(
                    icon: Icons.download_outlined,
                    tooltip: '다운로드',
                    onTap: _isExporting ? null : _downloadImage,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GiftcardRateTableFrame extends StatelessWidget {
  final Widget child;

  const _GiftcardRateTableFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GiftcardRateTable extends StatelessWidget {
  final _GiftcardRateTableData data;

  const _GiftcardRateTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('yyyy.MM.dd HH:mm').format(data.fetchedAt);
    final tableWidth = _giftcardRateNameColumnWidth +
        (data.branches.length * _giftcardRateBranchColumnWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '상품권 시세',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ),
            Text(
              '$timestamp 기준',
              style: const TextStyle(fontSize: 9, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth.toDouble(),
            child: Column(
              children: [
                _GiftcardRateTableRow(
                  isHeader: true,
                  label: '상품권',
                  branchCells: [
                    for (final branch in data.branches) branch.name,
                  ],
                ),
                for (final giftcardId in data.giftcardIds)
                  _GiftcardRateTableRow(
                    label: _compactGiftcardRateName(
                      data.giftcardNames[giftcardId] ??
                          _giftcardRateDefaultNames[giftcardId] ??
                          giftcardId,
                    ),
                    branchCells: [
                      for (final branch in data.branches)
                        data.cells[giftcardId]?[branch.id]?.displayText ?? '-',
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GiftcardRateTableRow extends StatelessWidget {
  final bool isHeader;
  final String label;
  final List<String> branchCells;

  const _GiftcardRateTableRow({
    this.isHeader = false,
    required this.label,
    required this.branchCells,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFFF6F6F6) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isHeader ? Colors.black12 : const Color(0xFFEAEAEA),
          ),
        ),
      ),
      child: Row(
        children: [
          _GiftcardRateTableCell(
            text: label,
            width: _giftcardRateNameColumnWidth,
            isHeader: isHeader,
            alignLeft: true,
          ),
          for (final cell in branchCells)
            _GiftcardRateTableCell(
              text: cell,
              width: _giftcardRateBranchColumnWidth,
              isHeader: isHeader,
            ),
        ],
      ),
    );
  }
}

class _GiftcardRateTableCell extends StatelessWidget {
  final String text;
  final double width;
  final bool isHeader;
  final bool alignLeft;

  const _GiftcardRateTableCell({
    required this.text,
    required this.width,
    this.isHeader = false,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n');
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: isHeader ? 42 : 50),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE6E6E6), width: 0.7),
        ),
      ),
      child: parts.length == 2 && !isHeader
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: alignLeft
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  parts[0],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parts[1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              text,
              maxLines: isHeader ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                height: 1.2,
                fontWeight: isHeader ? FontWeight.w900 : FontWeight.w800,
                color: const Color(0xFF1D1D1F),
              ),
            ),
    );
  }
}

class _GiftcardRateActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  const _GiftcardRateActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFF3F3F3) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  size: 19,
                  color:
                      onTap == null ? Colors.black26 : const Color(0xFF1D1D1F),
                ),
        ),
      ),
    );
  }
}

class _GiftcardRateEmptyState extends StatelessWidget {
  final String text;
  final VoidCallback onRefresh;

  const _GiftcardRateEmptyState({
    required this.text,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('다시 불러오기'),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class GiftcardRateOrderEditScreen extends StatefulWidget {
  const GiftcardRateOrderEditScreen({super.key});

  @override
  State<GiftcardRateOrderEditScreen> createState() =>
      _GiftcardRateOrderEditScreenState();
}

class _GiftcardRateOrderEditScreenState
    extends State<GiftcardRateOrderEditScreen> {
  late final PageController _pageController;
  bool _loading = true;
  bool _saving = false;
  int _pageIndex = 0;
  List<_GiftcardRateBranch> _branches = [];
  List<_GiftcardRateGiftcard> _giftcards = [];
  List<String> _selectedBranchIds = [];
  List<String> _selectedGiftcardIds = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final branchesSnap =
        await FirebaseFirestore.instance.collection('branches').get();
    final branches = branchesSnap.docs
        .map(
          (doc) => _GiftcardRateBranch(
            id: doc.id,
            name: (doc.data()['name'] as String?) ?? doc.id,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final giftsSnap =
        await FirebaseFirestore.instance.collection('giftcards').get();
    final Map<String, _GiftcardRateGiftcard> giftById = {
      for (final entry in _giftcardRateDefaultNames.entries)
        entry.key: _GiftcardRateGiftcard(
          id: entry.key,
          name: entry.value,
          sortOrder: _giftcardRateDefaultGiftcardIds.indexOf(entry.key),
        ),
    };
    for (final doc in giftsSnap.docs) {
      final data = doc.data();
      giftById[doc.id] = _GiftcardRateGiftcard(
        id: doc.id,
        name: (data['name'] as String?) ??
            _giftcardRateDefaultNames[doc.id] ??
            doc.id,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 999,
      );
    }
    final giftcards = giftById.values.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.compareTo(b.name);
      });

    final config = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('giftcard_meta')
        .doc('order')
        .get();
    final raw = config.data()?['branchIds'];
    final selected = raw is List
        ? raw
            .map((e) => e.toString())
            .where((id) => branches.any((branch) => branch.id == id))
            .take(3)
            .toList()
        : <String>[];
    final giftRaw = config.data()?['giftcardIds'];
    final selectedGifts = giftRaw is List
        ? giftRaw
            .map((e) => e.toString())
            .where((id) => giftcards.any((giftcard) => giftcard.id == id))
            .take(6)
            .toList()
        : _giftcardRateDefaultGiftcardIds
            .where((id) => giftcards.any((giftcard) => giftcard.id == id))
            .take(6)
            .toList();

    if (!mounted) return;
    setState(() {
      _branches = branches;
      _giftcards = giftcards;
      _selectedBranchIds = selected;
      _selectedGiftcardIds = selectedGifts;
      _loading = false;
    });
  }

  void _toggleBranch(String branchId) {
    setState(() {
      if (_selectedBranchIds.contains(branchId)) {
        _selectedBranchIds.remove(branchId);
      } else {
        if (_selectedBranchIds.length >= 3) {
          Fluttertoast.showToast(msg: '최대 3개 지점까지 선택할 수 있습니다.');
          return;
        }
        _selectedBranchIds.add(branchId);
      }
    });
  }

  void _moveBranch(String branchId, int delta) {
    final index = _selectedBranchIds.indexOf(branchId);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= _selectedBranchIds.length) return;
    setState(() {
      final item = _selectedBranchIds.removeAt(index);
      _selectedBranchIds.insert(next, item);
    });
  }

  void _toggleGiftcard(String giftcardId) {
    setState(() {
      if (_selectedGiftcardIds.contains(giftcardId)) {
        if (_selectedGiftcardIds.length <= 3) {
          Fluttertoast.showToast(msg: '상품권은 최소 3개 이상 선택해야 합니다.');
          return;
        }
        _selectedGiftcardIds.remove(giftcardId);
      } else {
        if (_selectedGiftcardIds.length >= 6) {
          Fluttertoast.showToast(msg: '상품권은 최대 6개까지 선택할 수 있습니다.');
          return;
        }
        _selectedGiftcardIds.add(giftcardId);
      }
    });
  }

  void _moveGiftcard(String giftcardId, int delta) {
    final index = _selectedGiftcardIds.indexOf(giftcardId);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= _selectedGiftcardIds.length) return;
    setState(() {
      final item = _selectedGiftcardIds.removeAt(index);
      _selectedGiftcardIds.insert(next, item);
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_selectedGiftcardIds.length < 3) {
      Fluttertoast.showToast(msg: '상품권은 최소 3개 이상 선택해야 합니다.');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('giftcard_meta')
          .doc('order')
          .set({
        'branchIds': _selectedBranchIds,
        'giftcardIds': _selectedGiftcardIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': user.uid,
      }, SetOptions(merge: true));
      Fluttertoast.showToast(msg: '상품권 시세 설정을 저장했습니다.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      Fluttertoast.showToast(msg: '저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('giftcard_meta')
          .doc('order')
          .delete();
      Fluttertoast.showToast(msg: '기본 지점 순서로 초기화했습니다.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      Fluttertoast.showToast(msg: '초기화 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('상품권 시세 편집'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text(
              '초기화',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        _GiftcardRateEditPagerButton(
                          label: '지점',
                          selected: _pageIndex == 0,
                          onTap: () => _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                        ),
                        _GiftcardRateEditPagerButton(
                          label: '상품권',
                          selected: _pageIndex == 1,
                          onTap: () => _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _pageIndex = index);
                    },
                    children: [
                      ListView(
                        padding:
                            EdgeInsets.fromLTRB(16, 12, 16, 40 + bottomInset),
                        children: [
                          _GiftcardRateEditPanel(
                            title: '선택한 지점',
                            child: _selectedBranchIds.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      '선택한 지점이 없으면 롯데상품권 기준 상위 3개 지점이 표시됩니다.',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final branchId in _selectedBranchIds)
                                        _SelectedBranchTile(
                                          rank: _selectedBranchIds
                                                  .indexOf(branchId) +
                                              1,
                                          branch: _branches.firstWhere(
                                            (branch) => branch.id == branchId,
                                            orElse: () => _GiftcardRateBranch(
                                              id: branchId,
                                              name: branchId,
                                            ),
                                          ),
                                          onMoveUp: () =>
                                              _moveBranch(branchId, -1),
                                          onMoveDown: () =>
                                              _moveBranch(branchId, 1),
                                          onRemove: () =>
                                              _toggleBranch(branchId),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 14),
                          _GiftcardRateEditPanel(
                            title: '지점 선택',
                            child: Column(
                              children: [
                                for (final branch in _branches)
                                  _BranchSelectTile(
                                    branch: branch,
                                    selected:
                                        _selectedBranchIds.contains(branch.id),
                                    onTap: () => _toggleBranch(branch.id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListView(
                        padding:
                            EdgeInsets.fromLTRB(16, 12, 16, 40 + bottomInset),
                        children: [
                          _GiftcardRateEditPanel(
                            title: '선택한 상품권',
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '최소 3개, 최대 6개까지 순서대로 표시됩니다.',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                for (final giftcardId in _selectedGiftcardIds)
                                  _SelectedGiftcardTile(
                                    rank: _selectedGiftcardIds
                                            .indexOf(giftcardId) +
                                        1,
                                    giftcard: _giftcards.firstWhere(
                                      (giftcard) => giftcard.id == giftcardId,
                                      orElse: () => _GiftcardRateGiftcard(
                                        id: giftcardId,
                                        name: giftcardId,
                                        sortOrder: 999,
                                      ),
                                    ),
                                    onMoveUp: () =>
                                        _moveGiftcard(giftcardId, -1),
                                    onMoveDown: () =>
                                        _moveGiftcard(giftcardId, 1),
                                    onRemove: () => _toggleGiftcard(giftcardId),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _GiftcardRateEditPanel(
                            title: '상품권 선택',
                            child: Column(
                              children: [
                                for (final giftcard in _giftcards)
                                  _GiftcardSelectTile(
                                    giftcard: giftcard,
                                    selected: _selectedGiftcardIds
                                        .contains(giftcard.id),
                                    onTap: () => _toggleGiftcard(giftcard.id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _GiftcardRateEditPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _GiftcardRateEditPanel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GiftcardRateEditPagerButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GiftcardRateEditPagerButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBranchTile extends StatelessWidget {
  final int rank;
  final _GiftcardRateBranch branch;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _SelectedBranchTile({
    required this.rank,
    required this.branch,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              branch.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '위로',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: onMoveUp,
          ),
          IconButton(
            tooltip: '아래로',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onMoveDown,
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SelectedGiftcardTile extends StatelessWidget {
  final int rank;
  final _GiftcardRateGiftcard giftcard;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _SelectedGiftcardTile({
    required this.rank,
    required this.giftcard,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              giftcard.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '위로',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: onMoveUp,
          ),
          IconButton(
            tooltip: '아래로',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onMoveDown,
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _BranchSelectTile extends StatelessWidget {
  final _GiftcardRateBranch branch;
  final bool selected;
  final VoidCallback onTap;

  const _BranchSelectTile({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                branch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? Colors.black : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftcardSelectTile extends StatelessWidget {
  final _GiftcardRateGiftcard giftcard;
  final bool selected;
  final VoidCallback onTap;

  const _GiftcardSelectTile({
    required this.giftcard,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                giftcard.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? Colors.black : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftcardRateTableData {
  final List<_GiftcardRateBranch> branches;
  final List<String> giftcardIds;
  final Map<String, String> giftcardNames;
  final Map<String, Map<String, _GiftcardRateCell>> cells;
  final DateTime fetchedAt;

  const _GiftcardRateTableData({
    required this.branches,
    required this.giftcardIds,
    required this.giftcardNames,
    required this.cells,
    required this.fetchedAt,
  });
}

class _GiftcardRateBranch {
  final String id;
  final String name;

  const _GiftcardRateBranch({
    required this.id,
    required this.name,
  });
}

class _GiftcardRateGiftcard {
  final String id;
  final String name;
  final int sortOrder;

  const _GiftcardRateGiftcard({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
}

class _GiftcardRateCell {
  final int? sellPrice;
  final double? sellFeeRate;

  const _GiftcardRateCell({
    required this.sellPrice,
    required this.sellFeeRate,
  });

  factory _GiftcardRateCell.fromMap(Map<String, dynamic> data) {
    final num? price = data['sellPrice_general'] as num?;
    return _GiftcardRateCell(
      sellPrice: price?.toInt(),
      sellFeeRate: (data['sellFeeRate_general'] as num?)?.toDouble() ??
          _rateFromPrice(price),
    );
  }

  String get displayText {
    if (sellPrice == null) return '-';
    final formatter = NumberFormat('#,###');
    final rateText =
        sellFeeRate == null ? '' : '\n(${sellFeeRate!.toStringAsFixed(2)}%)';
    return '${formatter.format(sellPrice)}$rateText';
  }

  static double? _rateFromPrice(num? price) {
    if (price == null) return null;
    return ((100000 - price.toDouble()) / 100000) * 100;
  }
}

class _GiftcardRateDefaultBranchCandidate {
  final String branchId;
  final String branchName;
  final double sellPrice;
  final double sellFeeRate;

  const _GiftcardRateDefaultBranchCandidate({
    required this.branchId,
    required this.branchName,
    required this.sellPrice,
    required this.sellFeeRate,
  });
}

class _PostSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<_PostDocs> future;
  final _PostDocs? initialPosts;
  final String emptyText;
  final VoidCallback onSeeAll;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTapPost;
  final bool showThumbnail;

  const _PostSection({
    required this.title,
    required this.icon,
    required this.future,
    this.initialPosts,
    required this.emptyText,
    required this.onSeeAll,
    required this.onTapPost,
    this.showThumbnail = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      icon: icon,
      onTapHeader: onSeeAll,
      child: FutureBuilder<_PostDocs>(
        future: future,
        initialData: initialPosts,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? [];
          if (posts.isEmpty &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 122,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          if (posts.isEmpty) {
            return _EmptySectionText(text: emptyText);
          }

          return SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final doc = posts[index];
                final data = doc.data();
                return _PostCard(
                  title: (data['title'] as String?) ?? '제목 없음',
                  boardName: _displayBoardName(data),
                  thumbnailUrl: showThumbnail
                      ? _extractFirstImageUrl(
                          (data['contentHtml'] as String?) ?? '',
                        )
                      : null,
                  likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
                  viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
                  onTap: () => onTapPost(doc),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeatureLinkSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_FeatureLink> items;

  const _FeatureLinkSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      icon: icon,
      onTapHeader: items.isEmpty ? null : items.first.onTap,
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 184,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.chevron_right,
                          size: 18, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PopularBoardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<_BoardDocs> boardsFuture;
  final Future<_PostDocs> postsFuture;
  final _BoardDocs? initialBoards;
  final _PostDocs? initialPosts;
  final VoidCallback onOpenCommunity;

  const _PopularBoardSection({
    required this.title,
    required this.icon,
    required this.boardsFuture,
    required this.postsFuture,
    this.initialBoards,
    this.initialPosts,
    required this.onOpenCommunity,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      icon: icon,
      onTapHeader: onOpenCommunity,
      child: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([boardsFuture, postsFuture]),
        initialData: initialBoards != null && initialPosts != null
            ? <Object>[initialBoards!, initialPosts!]
            : null,
        builder: (context, snapshot) {
          final boards =
              (snapshot.data?[0] as List<Map<String, dynamic>>?) ?? [];
          final posts = (snapshot.data?[1] as _PostDocs?) ?? [];
          final popularBoards = _rankBoards(boards, posts);

          if (popularBoards.isEmpty &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          if (popularBoards.isEmpty) {
            return const _EmptySectionText(text: '인기 게시판을 불러오지 못했습니다.');
          }

          return SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: popularBoards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final board = popularBoards[index];
                return InkWell(
                  onTap: onOpenCommunity,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 136,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          board.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '좋아요 ${board.likesCount} · 조회 ${board.viewCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(Icons.chevron_right,
                              size: 18, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<_PopularBoard> _rankBoards(
    List<Map<String, dynamic>> boards,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
  ) {
    final namesById = {
      for (final board in boards)
        (board['id'] ?? '').toString(): (board['name'] ?? '').toString(),
    };
    final Map<String, _PopularBoard> ranked = {};

    for (final post in posts) {
      final data = post.data();
      final boardId = (data['boardId'] ?? '').toString();
      if (boardId.isEmpty ||
          boardId == 'error_report' ||
          boardId == 'suggestion') {
        continue;
      }

      final current = ranked[boardId] ??
          _PopularBoard(
            boardId: boardId,
            name: namesById[boardId]?.isNotEmpty == true
                ? namesById[boardId]!
                : (data['boardName'] ?? boardId).toString(),
            likesCount: 0,
            viewCount: 0,
          );

      ranked[boardId] = current.copyWith(
        likesCount:
            current.likesCount + ((data['likesCount'] as num?)?.toInt() ?? 0),
        viewCount:
            current.viewCount + ((data['viewCount'] as num?)?.toInt() ?? 0),
      );
    }

    final list = ranked.values.toList()
      ..sort((a, b) {
        final scoreA = a.likesCount * 3 + a.viewCount;
        final scoreB = b.likesCount * 3 + b.viewCount;
        return scoreB.compareTo(scoreA);
      });
    return list.take(8).toList();
  }
}

class _PopularBoard {
  final String boardId;
  final String name;
  final int likesCount;
  final int viewCount;

  const _PopularBoard({
    required this.boardId,
    required this.name,
    required this.likesCount,
    required this.viewCount,
  });

  _PopularBoard copyWith({
    int? likesCount,
    int? viewCount,
  }) {
    return _PopularBoard(
      boardId: boardId,
      name: name,
      likesCount: likesCount ?? this.likesCount,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTapHeader;

  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.onTapHeader,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  if (onTapHeader != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: Colors.black45,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String title;
  final String boardName;
  final String? thumbnailUrl;
  final int likesCount;
  final int viewCount;
  final VoidCallback onTap;

  const _PostCard({
    required this.title,
    required this.boardName,
    this.thumbnailUrl,
    required this.likesCount,
    required this.viewCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 214,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              boardName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF74512D),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: thumbnailUrl == null ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  if (thumbnailUrl != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnailUrl!,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 54,
                          height: 54,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 18,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite_border, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 3),
                Text('$likesCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const SizedBox(width: 10),
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 3),
                Text('$viewCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  final String text;

  const _EmptySectionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[600])),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _FeatureLink {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
