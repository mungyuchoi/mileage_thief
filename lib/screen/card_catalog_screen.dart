import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../models/card_product_model.dart';
import '../models/community_label_model.dart';
import '../services/analytics_service.dart';
import '../services/branch_service.dart';
import '../services/card_catalog_service.dart';
import '../widgets/segment_tab_bar.dart';
import 'community_detail_screen.dart';
import 'community_post_create_simple_screen.dart';
import 'user_profile_screen.dart';

const Color _cardInk = McColors.ink;
const Color _cardLine = McColors.line;
const Color _cardMuted = McColors.muted;
const Color _cardPage = McColors.background;
const Color _cardAccent = McColors.accent;

class CardCatalogScreen extends StatefulWidget {
  final VoidCallback? onRequireLogin;
  final bool showAppBar;
  final List<CatalogCardProduct>? products;

  const CardCatalogScreen({
    super.key,
    this.onRequireLogin,
    this.showAppBar = true,
    this.products,
  });

  @override
  State<CardCatalogScreen> createState() => _CardCatalogScreenState();
}

class _CardCatalogScreenState extends State<CardCatalogScreen> {
  final CardCatalogService _service = CardCatalogService();
  final TextEditingController _queryController = TextEditingController();
  late final Future<bool> _adminFuture = _canAccessAdmin();
  String _statusFilter = 'active';
  String _sortOrder = 'popular';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(
      'card_catalog',
      screenClass: 'CardCatalogScreen',
      source: 'screen_init',
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                '카드',
                style: McTextStyles.appBarTitle,
              ),
              backgroundColor: Colors.white,
              foregroundColor: _cardAccent,
              elevation: 0.4,
              actions: [
                FutureBuilder<bool>(
                  future: _adminFuture,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '카드 요청',
                          icon: const Icon(Icons.inbox_outlined),
                          onPressed: _openAdminRequests,
                        ),
                        IconButton(
                          tooltip: '카드 정보 수집',
                          icon: _importing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          onPressed: _importing ? null : _openImportDialog,
                        ),
                      ],
                    );
                  },
                ),
              ],
            )
          : null,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'card_request',
            backgroundColor: Colors.white,
            foregroundColor: _cardAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _cardLine),
            ),
            icon: const Icon(Icons.search_outlined),
            label: const Text(
              '카드 요청',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            onPressed: _openRequest,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'card_create',
            backgroundColor: _cardAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_card_outlined),
            label: const Text(
              '카드 추가',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: widget.products != null
          ? _buildCatalogBody(products: widget.products!)
          : StreamBuilder<List<CatalogCardProduct>>(
              stream: _service.watchProducts(),
              initialData: _service.peekProducts(),
              builder: (context, snapshot) {
                return _buildCatalogBody(
                  products: snapshot.data ?? const [],
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  error: snapshot.error,
                );
              },
            ),
    );
  }

  Widget _buildCatalogBody({
    required List<CatalogCardProduct> products,
    bool isLoading = false,
    Object? error,
  }) {
    final header = _CatalogSearchHeader(
      controller: _queryController,
      statusFilter: _statusFilter,
      sortOrder: _sortOrder,
      onStatusChanged: (value) {
        setState(() => _statusFilter = value);
        AnalyticsService.instance
            .logAction('card_catalog_filter_changed', params: {
          'screen': 'card_catalog',
          'filter': 'status',
          'value': value,
        });
      },
      onSortChanged: (value) {
        setState(() => _sortOrder = value);
        AnalyticsService.instance
            .logAction('card_catalog_filter_changed', params: {
          'screen': 'card_catalog',
          'filter': 'sort',
          'value': value,
        });
      },
      onQueryChanged: (value) {
        setState(() {});
        final trimmed = value.trim();
        if (trimmed.length >= 2) {
          AnalyticsService.instance.logAction('card_search_performed', params: {
            'screen': 'card_catalog',
            'query_length': trimmed.length,
          });
        }
      },
    );

    if (isLoading && products.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (error != null && products.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.error_outline,
              title: '카드 정보를 불러오지 못했습니다.',
              message: '$error',
            ),
          ),
        ],
      );
    }

    final filteredProducts = _filterAndSort(products);
    if (filteredProducts.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.credit_card_off_outlined,
              title: '표시할 카드가 없습니다.',
              message: '필수 정보만으로도 새 카드를 추가할 수 있습니다.',
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) return const SizedBox(height: 10);
                final product = filteredProducts[index ~/ 2];
                return _CardProductTile(
                  product: product,
                  service: _service,
                  onTap: () => _openDetail(product.id),
                );
              },
              childCount: filteredProducts.length * 2 - 1,
            ),
          ),
        ),
      ],
    );
  }

  List<CatalogCardProduct> _filterAndSort(List<CatalogCardProduct> products) {
    final query = _queryController.text.trim().toLowerCase();
    final filtered = products.where((product) {
      if (_statusFilter != 'all' && product.status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.searchableText.contains(query);
    }).toList();

    filtered.sort((a, b) {
      if (_sortOrder == 'popular') {
        final likes = b.likesCount.compareTo(a.likesCount);
        if (likes != 0) return likes;
        final views = b.viewsCount.compareTo(a.viewsCount);
        if (views != 0) return views;
      }

      final updated =
          _dateMillis(b.updatedAt).compareTo(_dateMillis(a.updatedAt));
      if (updated != 0) return updated;
      return b.likesCount.compareTo(a.likesCount);
    });

    return filtered;
  }

  Future<void> _openCreate() async {
    if (!_ensureLoggedInForCardWrite()) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardProductEditScreen(
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  Future<void> _openRequest() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardSourceRequestScreen(
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  Future<void> _openAdminRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CardRequestManageScreen(),
      ),
    );
  }

  Future<void> _openDetail(String cardId) async {
    AnalyticsService.instance.logAction('card_detail_open', params: {
      'screen': 'card_catalog',
      'card_id': cardId,
      'source': 'catalog_list',
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'card_detail'),
        builder: (_) => CardProductDetailScreen(
          cardId: cardId,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  bool _ensureLoggedInForCardWrite() {
    if (FirebaseAuth.instance.currentUser != null) return true;
    Fluttertoast.showToast(msg: '로그인 후 카드 정보를 수정할 수 있습니다.');
    widget.onRequireLogin?.call();
    return false;
  }

  Future<bool> _canAccessAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return _hasAdminAccess(doc.data()?['roles']);
  }

  Future<void> _openImportDialog() async {
    final startController = TextEditingController(text: '1');
    final endController = TextEditingController(text: '25');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카드 정보 수집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '시작 ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: endController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '끝 ID'),
            ),
            const SizedBox(height: 8),
            const Text(
              '한 번에 최대 50개까지 수집합니다.',
              style: TextStyle(color: Color(0xFF7E8492)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('수집'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final startId = int.tryParse(startController.text.trim()) ?? 1;
    final endId = int.tryParse(endController.text.trim()) ?? startId;
    setState(() => _importing = true);
    try {
      final result = await _service.importCardGorillaCards(
        startId: startId,
        endId: endId,
      );
      final success = result.counts['success'] ?? 0;
      final failed = result.counts['failed'] ?? 0;
      final notFound = result.counts['notFound'] ?? 0;
      Fluttertoast.showToast(
        msg: '수집 완료: 성공 $success, 실패 $failed, 없음 $notFound',
      );
    } catch (error) {
      Fluttertoast.showToast(msg: '카드 정보 수집에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

class CardSourceRequestScreen extends StatefulWidget {
  final VoidCallback? onRequireLogin;

  const CardSourceRequestScreen({
    super.key,
    this.onRequireLogin,
  });

  @override
  State<CardSourceRequestScreen> createState() =>
      _CardSourceRequestScreenState();
}

class _CardSourceRequestScreenState extends State<CardSourceRequestScreen> {
  final CardCatalogService _service = CardCatalogService();
  final TextEditingController _searchController = TextEditingController();
  List<CardSourceCandidate> _candidates = const [];
  String? _searchedQuery;
  String? _requestingSourceId;
  Timer? _searchDebounce;
  int _searchToken = 0;
  bool _searching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queueSearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      _searchToken++;
      setState(() {
        _searchedQuery = null;
        _candidates = const [];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(showValidationToast: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '카드 요청',
          style: McTextStyles.appBarTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: _cardInk,
        elevation: 0.4,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _SectionPanel(
            title: '카드 검색',
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _queueSearch,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: _cardMuted),
                  hintText: '카드명 또는 카드사명',
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    tooltip: '검색',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _searching ? null : () => _search(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '찾는 카드를 선택하면 관리자에게 가져오기 요청이 전달됩니다.',
                style: TextStyle(
                  color: _cardMuted,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: _cardAccent),
              ),
            )
          else if (_searchedQuery != null && _candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: _EmptyState(
                icon: Icons.search_off_outlined,
                title: '검색 결과가 없습니다.',
                message: '카드명을 조금 다르게 입력해보세요.',
              ),
            )
          else
            for (final candidate in _candidates) ...[
              _SourceCandidateTile(
                candidate: candidate,
                isRequesting: _requestingSourceId == candidate.sourceCardId,
                onRequest: () => _request(candidate),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _search({bool showValidationToast = true}) async {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      if (showValidationToast) {
        Fluttertoast.showToast(msg: '두 글자 이상 입력해주세요.');
      }
      return;
    }
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _searchedQuery = query;
      _candidates = const [];
    });
    try {
      final candidates = await _service.searchCardSourceCandidates(
        query: query,
      );
      if (!mounted) return;
      if (token != _searchToken || query != _searchController.text.trim()) {
        return;
      }
      setState(() => _candidates = candidates);
    } catch (error) {
      if (token == _searchToken && query == _searchController.text.trim()) {
        Fluttertoast.showToast(msg: '카드 검색에 실패했습니다: $error');
      }
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _request(CardSourceCandidate candidate) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 카드 요청을 보낼 수 있습니다.');
      widget.onRequireLogin?.call();
      return;
    }
    setState(() => _requestingSourceId = candidate.sourceCardId);
    try {
      final result = await _service.createCardSourceRequest(
        candidate: candidate,
        query: _searchedQuery ?? _searchController.text.trim(),
      );
      final suffix =
          result.existingCardId == null ? '' : ' 기존 카드도 최신 정보로 확인됩니다.';
      Fluttertoast.showToast(msg: '카드 요청을 보냈습니다.$suffix');
    } catch (error) {
      Fluttertoast.showToast(msg: '카드 요청에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _requestingSourceId = null);
    }
  }
}

class CardRequestManageScreen extends StatefulWidget {
  const CardRequestManageScreen({super.key});

  @override
  State<CardRequestManageScreen> createState() =>
      _CardRequestManageScreenState();
}

class _CardRequestManageScreenState extends State<CardRequestManageScreen> {
  final CardCatalogService _service = CardCatalogService();
  final Set<String> _workingRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '카드 요청',
          style: McTextStyles.appBarTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: _cardInk,
        elevation: 0.4,
      ),
      body: StreamBuilder<List<CardSourceRequest>>(
        stream: _service.watchCardRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline,
              title: '요청을 불러오지 못했습니다.',
              message: '${snapshot.error}',
            );
          }
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return const _EmptyState(
              icon: Icons.inbox_outlined,
              title: '카드 요청이 없습니다.',
              message: '사용자가 카드 가져오기를 요청하면 여기에 표시됩니다.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _CardRequestTile(
                request: request,
                isWorking: _workingRequestIds.contains(request.id),
                onImport: request.canImport ? () => _import(request) : null,
                onReject: request.canImport ? () => _reject(request) : null,
                onOpenImported: request.importedCardId == null
                    ? null
                    : () => _openImported(request.importedCardId!),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _import(CardSourceRequest request) async {
    setState(() => _workingRequestIds.add(request.id));
    try {
      final result = await _service.importRequestedCard(
        requestId: request.id,
      );
      Fluttertoast.showToast(
        msg: result.alreadyImported ? '이미 가져온 카드입니다.' : '카드를 가져왔습니다.',
      );
    } catch (error) {
      Fluttertoast.showToast(msg: '카드 가져오기에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _workingRequestIds.remove(request.id));
    }
  }

  Future<void> _reject(CardSourceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('요청을 반려할까요?'),
        content: Text('${request.candidate.name} 요청을 반려합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('반려'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _workingRequestIds.add(request.id));
    try {
      await _service.rejectCardSourceRequest(requestId: request.id);
      Fluttertoast.showToast(msg: '요청을 반려했습니다.');
    } catch (error) {
      Fluttertoast.showToast(msg: '요청 반려에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _workingRequestIds.remove(request.id));
    }
  }

  Future<void> _openImported(String cardId) async {
    AnalyticsService.instance.logAction('card_detail_open', params: {
      'screen': 'card_catalog',
      'card_id': cardId,
      'source': 'import_result',
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'card_detail'),
        builder: (_) => CardProductDetailScreen(cardId: cardId),
      ),
    );
  }
}

class CardProductDetailScreen extends StatefulWidget {
  final String cardId;
  final VoidCallback? onRequireLogin;

  const CardProductDetailScreen({
    super.key,
    required this.cardId,
    this.onRequireLogin,
  });

  @override
  State<CardProductDetailScreen> createState() =>
      _CardProductDetailScreenState();
}

enum _CardDetailAction { like, share, edit, history }

class _CardProductDetailScreenState extends State<CardProductDetailScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = ['피드', '정보', '혜택', '댓글'];
  static const List<String> _tabAnalyticsNames = [
    'feed',
    'info',
    'benefits',
    'comments',
  ];

  final CardCatalogService _service = CardCatalogService();
  late final Future<bool> _adminFuture = _canAccessAdmin();
  late final Stream<CatalogCardProduct?> _productStream;
  late final TabController _tabController;
  List<_CardFeedPost> _feedPosts = <_CardFeedPost>[];
  bool _sharing = false;
  bool _likeToggling = false;
  bool _viewIncremented = false;
  bool _isLoadingFeed = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _productStream = _service.watchProduct(widget.cardId);
    AnalyticsService.instance.logScreenView(
      'card_detail',
      screenClass: 'CardProductDetailScreen',
      source: 'screen_init',
      parameters: {'card_id': widget.cardId},
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadFeedPosts();
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
    AnalyticsService.instance.logAction('sub_tab_selected', params: {
      'tab_group': 'card_detail',
      'tab': _tabAnalyticsNames[nextIndex],
      'card_id': widget.cardId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogCardProduct?>(
      stream: _productStream,
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product != null && !_viewIncremented) {
          _viewIncremented = true;
          Future.microtask(() => _incrementView(product.id));
        }
        return Scaffold(
          backgroundColor: _cardPage,
          resizeToAvoidBottomInset: false,
          floatingActionButton: product != null && _selectedTabIndex == 0
              ? FloatingActionButton.extended(
                  heroTag: 'card_feed_post_create_${product.id}',
                  backgroundColor: _cardAccent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('글쓰기'),
                  onPressed: () => _openCardFeedPostCreate(product),
                )
              : null,
          appBar: AppBar(
            title: Text(
              product?.name ?? '카드 상세',
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.appBarTitle,
            ),
            backgroundColor: Colors.white,
            foregroundColor: _cardInk,
            elevation: 0.4,
            actions: [
              if (product != null) _buildActionMenu(product),
            ],
          ),
          body: _buildBody(snapshot, product),
        );
      },
    );
  }

  Widget _buildActionMenu(CatalogCardProduct product) {
    return FutureBuilder<bool>(
      future: _adminFuture,
      builder: (context, adminSnapshot) {
        final isAdmin = adminSnapshot.data == true;
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return _actionMenuButton(
            product: product,
            liked: false,
            isAdmin: isAdmin,
          );
        }
        return StreamBuilder<bool>(
          stream: _service.watchUserLike(
            cardId: product.id,
            uid: user.uid,
          ),
          builder: (context, likeSnapshot) {
            return _actionMenuButton(
              product: product,
              liked: likeSnapshot.data == true,
              isAdmin: isAdmin,
            );
          },
        );
      },
    );
  }

  Widget _actionMenuButton({
    required CatalogCardProduct product,
    required bool liked,
    required bool isAdmin,
  }) {
    final busy = _sharing || _likeToggling;
    return PopupMenuButton<_CardDetailAction>(
      tooltip: '카드 메뉴',
      enabled: !busy,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _cardLine),
      ),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_horiz, color: _cardAccent),
      onSelected: (action) => _handleActionMenuSelection(action, product),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CardDetailAction.like,
          child: _ActionMenuRow(
            icon: liked ? Icons.favorite : Icons.favorite_border_outlined,
            label: liked
                ? '좋아요 취소 ${product.likesCount}'
                : '좋아요 ${product.likesCount}',
          ),
        ),
        const PopupMenuItem(
          value: _CardDetailAction.share,
          child: _ActionMenuRow(
            icon: Icons.share_outlined,
            label: '공유',
          ),
        ),
        const PopupMenuItem(
          value: _CardDetailAction.edit,
          child: _ActionMenuRow(
            icon: Icons.edit_outlined,
            label: '수정',
          ),
        ),
        if (isAdmin)
          const PopupMenuItem(
            value: _CardDetailAction.history,
            child: _ActionMenuRow(
              icon: Icons.history_outlined,
              label: '히스토리/롤백',
            ),
          ),
      ],
    );
  }

  void _handleActionMenuSelection(
    _CardDetailAction action,
    CatalogCardProduct product,
  ) {
    switch (action) {
      case _CardDetailAction.like:
        _toggleLike(product);
        break;
      case _CardDetailAction.share:
        _shareCard(product);
        break;
      case _CardDetailAction.edit:
        _openEdit(product);
        break;
      case _CardDetailAction.history:
        _openHistory(product);
        break;
    }
  }

  Widget _buildBody(
    AsyncSnapshot<CatalogCardProduct?> snapshot,
    CatalogCardProduct? product,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        product == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: '카드 정보를 불러오지 못했습니다.',
        message: '${snapshot.error}',
      );
    }
    if (product == null) {
      return const _EmptyState(
        icon: Icons.credit_card_off_outlined,
        title: '카드가 없습니다.',
        message: '삭제되었거나 아직 동기화되지 않은 카드입니다.',
      );
    }

    final issuerUrl = _cardIssuerUrl(product);
    final showSangtechPanel = _estimatedPerMileKRW(product) > 0;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final keyboardInset =
        _selectedTabIndex == 3 ? mediaQuery.viewInsets.bottom : 0.0;
    final contentBottomPadding =
        (_selectedTabIndex == 0 ? 96.0 : 28.0) + bottomInset + keyboardInset;

    return RefreshIndicator(
      color: _cardAccent,
      backgroundColor: Colors.white,
      onRefresh: _loadFeedPosts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: EdgeInsets.fromLTRB(16, 16, 16, contentBottomPadding),
        children: [
          _CardHeroImage(product: product, service: _service),
          const SizedBox(height: 12),
          ScrollableUnderlineTabBar(
            controller: _tabController,
            labels: _tabs,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            separatorWidth: 18,
          ),
          const SizedBox(height: 12),
          _buildSelectedTab(
            product: product,
            issuerUrl: issuerUrl,
            showSangtechPanel: showSangtechPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab({
    required CatalogCardProduct product,
    required String? issuerUrl,
    required bool showSangtechPanel,
  }) {
    switch (_selectedTabIndex) {
      case 1:
        return _buildInfoTab(product: product, issuerUrl: issuerUrl);
      case 2:
        return _buildBenefitsTab(
          product: product,
          showSangtechPanel: showSangtechPanel,
        );
      case 3:
        return _CardCommentsSection(
          service: _service,
          cardId: product.id,
          onRequireLogin: widget.onRequireLogin,
        );
      case 0:
      default:
        return _buildFeedTab(product);
    }
  }

  Widget _buildInfoTab({
    required CatalogCardProduct product,
    required String? issuerUrl,
  }) {
    return Column(
      children: [
        _CardFactsPanel(product: product),
        const SizedBox(height: 12),
        _CardEventSummarySection(
          service: _service,
          product: product,
        ),
        const SizedBox(height: 12),
        _DetailSummaryPanel(product: product),
        _DetailSectionsList(
          service: _service,
          cardId: product.id,
        ),
        if (issuerUrl != null) ...[
          const SizedBox(height: 12),
          _IssuerLinkPanel(onTap: () => _openIssuerUrl(issuerUrl)),
        ],
      ],
    );
  }

  Widget _buildBenefitsTab({
    required CatalogCardProduct product,
    required bool showSangtechPanel,
  }) {
    return Column(
      children: [
        _BenefitsPanel(
          title: '주요 혜택',
          values: product.primaryBenefits,
          emptyMessage: '아직 입력된 혜택 정보가 없습니다.',
        ),
        const SizedBox(height: 12),
        _CardTravelPanel(product: product),
        if (showSangtechPanel) ...[
          const SizedBox(height: 12),
          _CardSangtechPanel(product: product),
        ],
        const SizedBox(height: 12),
        _NoticePanel(values: product.exclusions),
      ],
    );
  }

  Widget _buildFeedTab(CatalogCardProduct product) {
    if (_isLoadingFeed) {
      return const _SectionPanel(
        title: '피드',
        children: [
          Row(
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
                  style: TextStyle(color: _cardMuted),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_feedPosts.isEmpty) {
      return _SectionPanel(
        title: '피드',
        children: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.grid_on_outlined,
                    color: _cardMuted,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '아직 ${product.name} 라벨 글이 없습니다.',
                    style: const TextStyle(
                      color: _cardMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _openCardFeedPostCreate(product),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('첫 글 남기기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _feedPosts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) => _buildFeedTile(_feedPosts[index]),
    );
  }

  Widget _buildFeedTile(_CardFeedPost post) {
    final imageUrl = post.imageUrl;
    return Material(
      color: const Color(0xFFF4F5F7),
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

  Widget _buildTextFeedTile(_CardFeedPost post) {
    final preview = post.previewText.trim();
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _cardInk,
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
                  color: _cardMuted,
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

  Future<void> _loadFeedPosts() async {
    try {
      final indexedPosts = await _loadIndexedFeedPosts();
      final baseQuery = FirebaseFirestore.instance
          .collectionGroup('posts')
          .where('isDeleted', isEqualTo: false)
          .where('isHidden', isEqualTo: false);
      final legacyDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...await _loadLegacyPostDocs(
          baseQuery.where('entityRefs.cardId', isEqualTo: widget.cardId),
          debugLabel: 'cardId',
        ),
        ...await _loadLegacyPostDocs(
          baseQuery.where('entityRefs.cardIds', arrayContains: widget.cardId),
          debugLabel: 'cardIds',
        ),
      ];

      final postsByPath = <String, _CardFeedPost>{};
      for (final post in indexedPosts) {
        if (post.isDeleted || post.isHidden) continue;
        postsByPath[post.postPath] = post;
      }
      for (final doc in legacyDocs) {
        final post = _CardFeedPost.fromPostDoc(doc);
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
        _feedPosts = posts.take(60).toList(growable: false);
        _isLoadingFeed = false;
      });
    } catch (e) {
      debugPrint('카드 피드 로드 오류: $e');
      if (!mounted) return;
      setState(() => _isLoadingFeed = false);
    }
  }

  Future<List<_CardFeedPost>> _loadIndexedFeedPosts() async {
    final ref = FirebaseFirestore.instance
        .collection('cards')
        .doc('catalog')
        .collection('cardProducts')
        .doc(widget.cardId)
        .collection('labeledPosts');

    try {
      final snap =
          await ref.orderBy('createdAt', descending: true).limit(60).get();
      return snap.docs
          .map(_CardFeedPost.fromIndexedDoc)
          .whereType<_CardFeedPost>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('카드 라벨 인덱스 최신순 조회 오류: $e');
      try {
        final snap = await ref.limit(60).get();
        return snap.docs
            .map(_CardFeedPost.fromIndexedDoc)
            .whereType<_CardFeedPost>()
            .toList(growable: false);
      } catch (fallbackError) {
        debugPrint('카드 라벨 인덱스 기본 조회 오류: $fallbackError');
        return const <_CardFeedPost>[];
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
      debugPrint('카드 관련 게시글 $debugLabel 최신순 조회 오류: $e');
      try {
        final snap = await query.limit(60).get();
        return snap.docs;
      } catch (fallbackError) {
        debugPrint('카드 관련 게시글 $debugLabel 기본 조회 오류: $fallbackError');
        return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
    }
  }

  void _openFeedPost(_CardFeedPost post) {
    AnalyticsService.instance.logAction('card_feed_post_open', params: {
      'screen': 'card_detail',
      'card_id': widget.cardId,
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

  Future<void> _openCardFeedPostCreate(CatalogCardProduct product) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      widget.onRequireLogin?.call();
      return;
    }

    final cardLabel = CommunityLabel.card(
      cardId: product.id,
      name: product.name,
      issuerName: product.issuerName,
    );
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityPostCreateSimpleScreen(
          initialBoardId: 'deal',
          initialBoardName: '적립/카드 혜택',
          initialLabels: [cardLabel.toMap()],
          entityRefs: {
            'cardIds': [product.id],
            'cardId': product.id,
          },
          lockBoardSelection: true,
        ),
      ),
    );
    if (mounted) {
      await _loadFeedPosts();
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

  Future<void> _openIssuerUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      Fluttertoast.showToast(msg: '카드사 링크를 열 수 없습니다.');
      return;
    }
    AnalyticsService.instance.logAction('issuer_link_open', params: {
      'screen': 'card_detail',
      'card_id': widget.cardId,
    });
    AnalyticsService.instance.logAction('external_link_open', params: {
      'screen': 'card_detail',
      'source': 'issuer_link',
      'card_id': widget.cardId,
    });
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        Fluttertoast.showToast(msg: '카드사 링크를 열 수 없습니다.');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: '카드사 링크를 열 수 없습니다.');
    }
  }

  Future<void> _openEdit(CatalogCardProduct product) async {
    if (!_ensureLoggedInForCardWrite()) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardProductEditScreen(
          product: product,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  Future<void> _openHistory(CatalogCardProduct product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardRevisionHistoryScreen(product: product),
      ),
    );
  }

  Future<void> _shareCard(CatalogCardProduct product) async {
    setState(() => _sharing = true);
    try {
      AnalyticsService.instance.logAction('card_shared', params: {
        'screen': 'card_detail',
        'card_id': product.id,
      });
      final imageUrl = product.mainDownloadUrl ??
          await _service.downloadUrlForStoragePath(product.mainStoragePath);
      final description = [
        product.issuerName,
        product.cardTypeLabel,
        if (product.annualFeeSummary != '-') '연회비 ${product.annualFeeSummary}',
      ].join(' · ');
      final link = await BranchService().createCardShareLink(
        cardId: product.id,
        title: product.name,
        description: description,
        imageUrl: imageUrl,
      );
      final shareText = link == null || link.isEmpty
          ? '${product.name}\n$description\n\n마일캐치 카드 정보'
          : '${product.name}\n$description\n\n$link';
      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (error) {
      Fluttertoast.showToast(msg: '공유 링크를 만들지 못했습니다: $error');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _toggleLike(CatalogCardProduct product) async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 좋아요를 누를 수 있습니다.');
      widget.onRequireLogin?.call();
      return;
    }
    if (_likeToggling) return;

    setState(() => _likeToggling = true);
    try {
      final result = await _service.toggleCardProductLike(cardId: product.id);
      AnalyticsService.instance.logAction('card_liked', params: {
        'screen': 'card_detail',
        'card_id': product.id,
        'state': result.liked ? 'on' : 'off',
      });
      Fluttertoast.showToast(
        msg: result.liked ? '좋아요를 눌렀습니다.' : '좋아요를 취소했습니다.',
      );
    } catch (error) {
      Fluttertoast.showToast(msg: '좋아요 처리에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _likeToggling = false);
    }
  }

  Future<void> _incrementView(String cardId) async {
    try {
      await _service.incrementCardProductView(cardId: cardId);
    } catch (_) {
      // 조회수 증가는 사용자 흐름을 막지 않는다.
    }
  }

  Future<bool> _canAccessAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return _hasAdminAccess(doc.data()?['roles']);
  }

  bool _ensureLoggedInForCardWrite() {
    if (FirebaseAuth.instance.currentUser != null) return true;
    Fluttertoast.showToast(msg: '로그인 후 카드 정보를 수정할 수 있습니다.');
    widget.onRequireLogin?.call();
    return false;
  }
}

class _CardFeedPost {
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

  const _CardFeedPost({
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

  static _CardFeedPost? fromIndexedDoc(
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

    return _CardFeedPost(
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

  static _CardFeedPost? fromPostDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dateDoc = doc.reference.parent.parent;
    final dateString = dateDoc?.id;
    if (dateString == null || dateString.isEmpty) return null;
    final data = doc.data();
    final contentHtml = _feedString(data['contentHtml']);
    return _CardFeedPost(
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

String? _cleanFeedUrl(String? value) {
  final url = value?.trim();
  if (url == null || url.isEmpty) return null;
  return url.replaceAll('&amp;', '&');
}

class CardProductEditScreen extends StatefulWidget {
  final CatalogCardProduct? product;
  final VoidCallback? onRequireLogin;

  const CardProductEditScreen({
    super.key,
    this.product,
    this.onRequireLogin,
  });

  @override
  State<CardProductEditScreen> createState() => _CardProductEditScreenState();
}

class _CardProductEditScreenState extends State<CardProductEditScreen> {
  final CardCatalogService _service = CardCatalogService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _issuerController;
  late final TextEditingController _rewardController;
  late final TextEditingController _annualFeeController;
  late final TextEditingController _previousMonthController;
  late final TextEditingController _benefitsController;
  late final TextEditingController _exclusionsController;
  late final TextEditingController _detailController;
  String _cardType = 'credit';
  String _status = 'active';
  PlatformFile? _selectedImage;
  bool _saving = false;

  bool get _isCreate => widget.product == null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _issuerController = TextEditingController(text: product?.issuerName ?? '');
    _rewardController =
        TextEditingController(text: product?.rewardProgram ?? '');
    _annualFeeController = TextEditingController(
        text: product?.annualFeeSummary == '-'
            ? ''
            : product?.annualFeeSummary ?? '');
    _previousMonthController = TextEditingController(
      text: product?.previousMonthSpendSummary == '-'
          ? ''
          : product?.previousMonthSpendSummary ?? '',
    );
    _benefitsController = TextEditingController(
      text: (product?.primaryBenefits ?? const [])
          .map(displayValue)
          .where((value) => value.isNotEmpty)
          .join('\n'),
    );
    _exclusionsController = TextEditingController(
      text: (product?.exclusions ?? const [])
          .map(displayValue)
          .where((value) => value.isNotEmpty)
          .join('\n'),
    );
    _detailController =
        TextEditingController(text: product?.detailSummary ?? '');
    _cardType = product?.cardType ?? 'credit';
    _status = product?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _issuerController.dispose();
    _rewardController.dispose();
    _annualFeeController.dispose();
    _previousMonthController.dispose();
    _benefitsController.dispose();
    _exclusionsController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: _cardAccent,
          secondary: _cardAccent,
          onPrimary: Colors.white,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _cardAccent,
          selectionColor: _cardAccent.withValues(alpha: 0.18),
          selectionHandleColor: _cardAccent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          floatingLabelStyle: TextStyle(color: _cardAccent),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _cardAccent, width: 1.4),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _cardMuted),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _cardAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _cardLine,
            disabledForegroundColor: _cardMuted,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _cardAccent),
        ),
      ),
      child: Scaffold(
        backgroundColor: _cardPage,
        appBar: AppBar(
          title: Text(
            _isCreate ? '카드 추가' : '카드 수정',
            style: McTextStyles.appBarTitle,
          ),
          backgroundColor: Colors.white,
          foregroundColor: _cardInk,
          elevation: 0.4,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _cardAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _cardLine,
                disabledForegroundColor: _cardMuted,
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '저장 중' : '저장'),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _EditPanel(
                title: '필수 정보',
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '카드명'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '카드명을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _issuerController,
                    decoration: const InputDecoration(labelText: '카드사명'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '카드사명을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cardType,
                    decoration: const InputDecoration(labelText: '카드 유형'),
                    dropdownColor: Colors.white,
                    iconEnabledColor: _cardInk,
                    items: const [
                      DropdownMenuItem(value: 'credit', child: Text('신용')),
                      DropdownMenuItem(value: 'check', child: Text('체크')),
                      DropdownMenuItem(value: 'hybrid', child: Text('하이브리드')),
                      DropdownMenuItem(value: 'unknown', child: Text('기타')),
                    ],
                    onChanged: (value) =>
                        setState(() => _cardType = value ?? 'unknown'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EditPanel(
                title: '선택 정보',
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: '상태'),
                    dropdownColor: Colors.white,
                    iconEnabledColor: _cardInk,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('사용 가능')),
                      DropdownMenuItem(value: 'pending', child: Text('정보 확인중')),
                      DropdownMenuItem(
                          value: 'discontinued', child: Text('단종')),
                      DropdownMenuItem(value: 'hidden', child: Text('숨김')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'active'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rewardController,
                    decoration:
                        const InputDecoration(labelText: '마일리지/리워드 프로그램'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _annualFeeController,
                    decoration: const InputDecoration(labelText: '연회비'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _previousMonthController,
                    decoration: const InputDecoration(labelText: '전월실적'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EditPanel(
                title: '혜택/상세',
                children: [
                  TextFormField(
                    controller: _benefitsController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '주요 혜택',
                      helperText: '한 줄에 하나씩 입력',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _exclusionsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '제외/유의 항목',
                      helperText: '한 줄에 하나씩 입력',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '상세 정보',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EditPanel(
                title: '카드 이미지',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedImage?.name ??
                              (widget.product?.mainStoragePath == null
                                  ? '이미지 없음'
                                  : '기존 이미지 사용'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ),
                      TextButton.icon(
                        style:
                            TextButton.styleFrom(foregroundColor: _cardAccent),
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('선택'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _selectedImage = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 카드 정보를 수정할 수 있습니다.');
      widget.onRequireLogin?.call();
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      if (_isCreate) {
        final created = await _service.createCardProduct(payload);
        if (_selectedImage != null) {
          final images = await _service.uploadMainImage(
            cardId: created.cardId,
            file: _selectedImage!,
          );
          await _service.applyCardEdit(
            cardId: created.cardId,
            baseVersion: created.version,
            patch: {'images': images},
          );
        }
        Fluttertoast.showToast(msg: '카드를 추가했습니다.');
      } else {
        final product = widget.product!;
        final patch = Map<String, dynamic>.from(payload);
        if (_selectedImage != null) {
          patch['images'] = await _service.uploadMainImage(
            cardId: product.id,
            file: _selectedImage!,
          );
        }
        final result = await _service.applyCardEdit(
          cardId: product.id,
          baseVersion: product.version,
          patch: patch,
        );
        Fluttertoast.showToast(
          msg: result.noChanges ? '변경된 내용이 없습니다.' : '카드를 수정했습니다.',
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      Fluttertoast.showToast(msg: '저장에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'name': _nameController.text.trim(),
      'issuerName': _issuerController.text.trim(),
      'cardType': _cardType,
      'status': _status,
      'rewardProgram': _emptyToNull(_rewardController.text),
      'annualFee': {'summary': _annualFeeController.text.trim()},
      'previousMonthSpend': {'summary': _previousMonthController.text.trim()},
      'primaryBenefits': _lines(_benefitsController.text),
      'exclusions': _lines(_exclusionsController.text),
      'detailSummary': _detailController.text.trim(),
    };
  }
}

class CardRevisionHistoryScreen extends StatefulWidget {
  final CatalogCardProduct product;

  const CardRevisionHistoryScreen({
    super.key,
    required this.product,
  });

  @override
  State<CardRevisionHistoryScreen> createState() =>
      _CardRevisionHistoryScreenState();
}

class _CardRevisionHistoryScreenState extends State<CardRevisionHistoryScreen> {
  final CardCatalogService _service = CardCatalogService();
  final Map<String, Future<_RevisionActorProfile?>> _actorProfileFutures = {};
  bool _rollingBack = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '수정 히스토리',
          style: McTextStyles.appBarTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: _cardInk,
        elevation: 0.4,
      ),
      body: StreamBuilder<List<CardProductRevision>>(
        stream: _service.watchRevisions(widget.product.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline,
              title: '히스토리를 불러오지 못했습니다.',
              message: '${snapshot.error}',
            );
          }
          final revisions = snapshot.data ?? const [];
          if (revisions.isEmpty) {
            return const _EmptyState(
              icon: Icons.history_toggle_off_outlined,
              title: '히스토리가 없습니다.',
              message: '수정이 발생하면 여기에 기록됩니다.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: revisions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final revision = revisions[index];
              return _RevisionTile(
                revision: revision,
                actorProfileFuture: _actorProfileFuture(revision.actorUid),
                onTap: () => _showRevision(revision),
                onActorTap: _openActorProfile,
                onRollback: revision.action == 'create' || _rollingBack
                    ? null
                    : () => _rollback(revision),
              );
            },
          );
        },
      ),
    );
  }

  Future<_RevisionActorProfile?> _actorProfileFuture(String? uid) {
    final actorUid = uid?.trim() ?? '';
    if (actorUid.isEmpty) return Future.value(null);

    return _actorProfileFutures.putIfAbsent(actorUid, () async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actorUid)
          .get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return const _RevisionActorProfile(
          displayName: '사용자 정보 없음',
          exists: false,
        );
      }

      final displayName = _firstNonEmpty([
        data['displayName'],
        data['nickname'],
        data['name'],
      ]);
      final photoUrl = _emptyToNull(_firstNonEmpty([
        data['photoURL'],
        data['photoUrl'],
        data['profileImageUrl'],
        data['profileImageURL'],
      ]));

      return _RevisionActorProfile(
        displayName: displayName.isEmpty ? '이름 없는 사용자' : displayName,
        photoUrl: photoUrl,
      );
    });
  }

  void _openActorProfile(String uid) {
    final actorUid = uid.trim();
    if (actorUid.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userUid: actorUid),
      ),
    );
  }

  Future<void> _showRevision(CardProductRevision revision) async {
    final actorUid = revision.actorUid?.trim() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              '${revision.actionLabel} v${revision.versionFrom} → v${revision.versionTo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 6),
            _RevisionActorSummary(
              actorUid: actorUid,
              profileFuture: _actorProfileFuture(actorUid),
              leadingLabel: '수정자',
              onTap: actorUid.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _openActorProfile(actorUid);
                      });
                    },
            ),
            const SizedBox(height: 14),
            for (final change in revision.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChangeDiff(change: change),
              ),
          ],
        );
      },
    );
  }

  Future<void> _rollback(CardProductRevision revision) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 시점으로 롤백할까요?'),
        content: Text(
          'v${revision.versionFrom} 이전 상태로 복원하고, 롤백 이력을 새로 남깁니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('롤백'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _rollingBack = true);
    try {
      await _service.rollbackCardRevision(
        cardId: widget.product.id,
        revisionId: revision.id,
      );
      Fluttertoast.showToast(msg: '롤백했습니다.');
    } catch (error) {
      Fluttertoast.showToast(msg: '롤백에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _rollingBack = false);
    }
  }
}

class _CatalogSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final String statusFilter;
  final String sortOrder;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onQueryChanged;

  const _CatalogSearchHeader({
    required this.controller,
    required this.statusFilter,
    required this.sortOrder,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: _cardMuted),
              hintText: '카드명, 카드사, 혜택 검색',
              hintStyle: const TextStyle(
                color: _cardMuted,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: const Color(0xFFF4F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardAccent, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(
                        label: '사용 가능',
                        selected: statusFilter == 'active',
                        onTap: () => onStatusChanged('active'),
                        width: 96,
                      ),
                      _StatusChip(
                        label: '단종',
                        selected: statusFilter == 'discontinued',
                        onTap: () => onStatusChanged('discontinued'),
                        width: 96,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SortDropdown(
                value: sortOrder,
                onChanged: onSortChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SortDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF4B5563),
          ),
          borderRadius: BorderRadius.circular(8),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          items: const [
            DropdownMenuItem(
              value: 'popular',
              child: Text('인기순', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'latest',
              child: Text('최신순', overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: (nextValue) {
            if (nextValue == null) return;
            onChanged(nextValue);
          },
        ),
      ),
    );
  }
}

class _CardProductTile extends StatelessWidget {
  final CatalogCardProduct product;
  final CardCatalogService service;
  final VoidCallback onTap;

  const _CardProductTile({
    required this.product,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CardImageBox(product: product, service: service, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.issuerName} · ${product.cardTypeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallPill(product.statusLabel),
                        if (product.rewardProgram != null)
                          _SmallPill(product.rewardProgram!),
                        _MetricPill(
                          icon: Icons.favorite_border_outlined,
                          value: product.likesCount,
                        ),
                        _MetricPill(
                          icon: Icons.visibility_outlined,
                          value: product.viewsCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC0C5CF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final int value;

  const _MetricPill({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _cardMuted),
          const SizedBox(width: 3),
          Text(
            _compactCount(value),
            style: const TextStyle(
              color: _cardInk,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCandidateTile extends StatelessWidget {
  final CardSourceCandidate candidate;
  final bool isRequesting;
  final VoidCallback onRequest;

  const _SourceCandidateTile({
    required this.candidate,
    required this.isRequesting,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final benefitText = candidate.benefitsSummary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SourceImageBox(url: candidate.imageUrl, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${candidate.issuerName} · ${candidate.cardTypeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cardMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (benefitText.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      benefitText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF303544),
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SmallPill(candidate.statusLabel),
                      if (candidate.annualFeeSummary != null)
                        _SmallPill(candidate.annualFeeSummary!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isRequesting ? null : onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: _cardAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('요청'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRequestTile extends StatelessWidget {
  final CardSourceRequest request;
  final bool isWorking;
  final VoidCallback? onImport;
  final VoidCallback? onReject;
  final VoidCallback? onOpenImported;

  const _CardRequestTile({
    required this.request,
    required this.isWorking,
    required this.onImport,
    required this.onReject,
    required this.onOpenImported,
  });

  @override
  Widget build(BuildContext context) {
    final candidate = request.candidate;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceImageBox(url: candidate.imageUrl, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SmallPill(request.statusLabel),
                          if (request.existingCardId != null) ...[
                            const SizedBox(width: 6),
                            const _SmallPill('기존 카드 있음'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        candidate.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate.issuerName} · ${candidate.cardTypeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _cardMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '요청: ${_dateText(request.createdAt)} · ${request.requesterUid ?? '-'}',
              style: const TextStyle(
                color: Color(0xFF8A91A1),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (onImport != null)
                  FilledButton.icon(
                    onPressed: isWorking ? null : onImport,
                    icon: isWorking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('가져오기'),
                  ),
                if (onImport != null && onReject != null)
                  const SizedBox(width: 8),
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: isWorking ? null : onReject,
                    icon: const Icon(Icons.close_outlined, size: 18),
                    label: const Text('반려'),
                  ),
                const Spacer(),
                if (onOpenImported != null)
                  TextButton.icon(
                    onPressed: onOpenImported,
                    icon: const Icon(Icons.open_in_new_outlined, size: 18),
                    label: const Text('열기'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceImageBox extends StatelessWidget {
  final String? url;
  final double size;

  const _SourceImageBox({
    required this.url,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _CardPlaceholder(size: size);
    }
    return _NetworkImageBox(url: imageUrl, size: size);
  }
}

class _CardHeroImage extends StatelessWidget {
  final CatalogCardProduct product;
  final CardCatalogService service;

  const _CardHeroImage({
    required this.product,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F1F4)),
      ),
      child: Column(
        children: [
          Container(
            width: 184,
            height: 184,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF6F7FA),
            ),
            alignment: Alignment.center,
            child: _CardImageBox(product: product, service: service, size: 150),
          ),
          const SizedBox(height: 14),
          Text(
            product.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _cardInk,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${product.issuerName} · ${product.cardTypeLabel}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _cardMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallPill(product.statusLabel),
              if (product.rewardProgram != null)
                _SmallPill(product.rewardProgram!),
              _MetricPill(
                icon: Icons.favorite_border_outlined,
                value: product.likesCount,
              ),
              _MetricPill(
                icon: Icons.visibility_outlined,
                value: product.viewsCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardFactsPanel extends StatelessWidget {
  final CatalogCardProduct product;

  const _CardFactsPanel({required this.product});

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: '기본 정보',
      children: [
        _IconInfoRow(
          iconAsset: _benefitIconAsset('카드사 ${product.issuerName}'),
          label: '카드사',
          value: product.issuerName,
        ),
        _IconInfoRow(
          iconAsset: _benefitIconAsset(product.cardTypeLabel),
          label: '카드 유형',
          value: product.cardTypeLabel,
        ),
        _IconInfoRow(
          iconAsset: 'asset/icon/card_benefits/default.svg',
          label: '상태',
          value: product.statusLabel,
        ),
        _IconInfoRow(
          iconAsset: _benefitIconAsset(product.rewardProgram ?? '마일리지'),
          label: '마일리지',
          value: product.rewardProgram ?? '-',
        ),
        _IconInfoRow(
          iconAsset: 'asset/icon/card_benefits/pay.svg',
          label: '연회비',
          value: product.annualFeeSummary,
        ),
        _IconInfoRow(
          iconAsset: 'asset/icon/card_benefits/life.svg',
          label: '전월실적',
          value: product.previousMonthSpendSummary,
        ),
        _IconInfoRow(
          iconAsset: 'asset/icon/card_benefits/default.svg',
          label: '수정 시간',
          value: _dateText(product.updatedAt),
          compact: true,
        ),
      ],
    );
  }
}

class _IconInfoRow extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;
  final bool compact;

  const _IconInfoRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BenefitIcon(asset: iconAsset, size: 28),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A91A1),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF252A36),
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsPanel extends StatelessWidget {
  final String title;
  final List<dynamic> values;
  final String emptyMessage;

  const _BenefitsPanel({
    required this.title,
    required this.values,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final items = _benefitItems(values);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
        ),
        if (items.isEmpty)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF0F1F4)),
              ),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: _cardMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
        else
          for (final item in items) ...[
            _BenefitRow(item: item),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final _BenefitDisplayItem item;

  const _BenefitRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF0F1F4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BenefitIcon(asset: item.iconAsset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: _cardInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF555C6B),
                        height: 1.35,
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
    );
  }
}

class _NoticePanel extends StatelessWidget {
  final List<dynamic> values;

  const _NoticePanel({required this.values});

  @override
  Widget build(BuildContext context) {
    final items = _benefitItems(values);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
          child: Text(
            '제외/유의 항목',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BenefitRow(
              item: _BenefitDisplayItem(
                title: item.title,
                description: item.description,
                iconAsset: 'asset/icon/card_benefits/default.svg',
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailSummaryPanel extends StatelessWidget {
  final CatalogCardProduct product;

  const _DetailSummaryPanel({required this.product});

  @override
  Widget build(BuildContext context) {
    final summary = product.detailSummary.trim();
    if (summary.isEmpty) return const SizedBox.shrink();
    return _SectionPanel(
      title: '상세 정보',
      children: [
        Text(
          summary,
          style: const TextStyle(
            color: Color(0xFF303544),
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CardTravelPanel extends StatelessWidget {
  final CatalogCardProduct product;

  const _CardTravelPanel({required this.product});

  @override
  Widget build(BuildContext context) {
    final items = <_BenefitDisplayItem>[
      if (product.isMileageCard)
        _BenefitDisplayItem(
          title: '항공 마일리지',
          description: product.mileagePrograms.isEmpty
              ? product.rewardProgram ?? '마일리지 적립 카드로 분류됩니다.'
              : product.mileagePrograms.join(' · '),
          iconAsset: _benefitIconAsset('마일리지 항공'),
        ),
      if (product.isTravelCard)
        _BenefitDisplayItem(
          title: '트래블/해외',
          description: _firstNonEmpty([
            product.travelFlags['summary'],
            product.detailSummary,
            '해외, 여행, 라운지 혜택을 함께 검토할 카드입니다.',
          ]),
          iconAsset: _benefitIconAsset('여행 해외 라운지'),
        ),
      if (product.loungeSummaryText.isNotEmpty)
        _BenefitDisplayItem(
          title: '공항 라운지',
          description: product.loungeSummaryText,
          iconAsset: _benefitIconAsset('라운지'),
        ),
    ];

    if (items.isEmpty) {
      return const _SectionPanel(
        title: '마일리지/라운지/여행',
        children: [
          Text(
            '아직 여행 특화 정보가 정리되지 않았습니다. 댓글과 피드로 실제 혜택을 검증해보세요.',
            style: TextStyle(
              color: _cardMuted,
              fontWeight: FontWeight.w400,
              height: 1.38,
            ),
          ),
        ],
      );
    }

    return _SectionPanel(
      title: '마일리지/라운지/여행',
      children: [
        for (final item in items) ...[
          _BenefitRow(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CardEventSummarySection extends StatelessWidget {
  final CardCatalogService service;
  final CatalogCardProduct product;

  const _CardEventSummarySection({
    required this.service,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardEvent>>(
      stream: service.watchEvents(cardId: product.id, limit: 12),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <CardEvent>[];
        final fallbackText = product.eventSummaryText;
        if (events.isEmpty && fallbackText.isEmpty) {
          return const _SectionPanel(
            title: '이벤트',
            children: [
              Text(
                '진행중인 캐시백/연회비 이벤트가 확인되면 이곳에 표시됩니다.',
                style: TextStyle(
                  color: _cardMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );
        }
        return _SectionPanel(
          title: '이벤트',
          children: [
            if (fallbackText.isNotEmpty)
              _IconInfoRow(
                iconAsset: _benefitIconAsset('캐시백 이벤트'),
                label: '요약',
                value: fallbackText,
              ),
            for (final event in events) ...[
              _CardEventInlineTile(event: event),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _CardEventInlineTile extends StatelessWidget {
  final CardEvent event;

  const _CardEventInlineTile({required this.event});

  Future<void> _openUrl() async {
    final raw = event.applyUrl ?? event.sourceUrl;
    if (raw == null || raw.trim().isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FB),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BenefitIcon(asset: _benefitIconAsset('이벤트 캐시백'), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      event.displayBenefit,
                      if (event.endsAt != null)
                        '${DateFormat('M.d').format(event.endsAt!)}까지',
                    ].join(' · '),
                    style: const TextStyle(
                      color: _cardMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if ((event.applyUrl ?? event.sourceUrl)?.isNotEmpty == true)
              IconButton(
                tooltip: '출처 보기',
                onPressed: _openUrl,
                icon: const Icon(Icons.open_in_new_outlined, size: 19),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardSangtechPanel extends StatefulWidget {
  final CatalogCardProduct product;

  const _CardSangtechPanel({required this.product});

  @override
  State<_CardSangtechPanel> createState() => _CardSangtechPanelState();
}

class _CardSangtechPanelState extends State<_CardSangtechPanel> {
  double _monthlyAmount = 1000000;

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    final perMile = _estimatedPerMileKRW(widget.product);
    final miles = perMile <= 0 ? 0 : (_monthlyAmount / perMile).round();
    final yearlyMiles = miles * 12;
    final valueKRW = yearlyMiles * 15;

    return _SectionPanel(
      title: '상테크 계산',
      children: [
        Text(
          '월 상품권/실적 반영 금액 ${won.format(_monthlyAmount.round())}원',
          style: const TextStyle(
            color: _cardInk,
            fontWeight: FontWeight.w400,
          ),
        ),
        Slider(
          value: _monthlyAmount,
          min: 100000,
          max: 5000000,
          divisions: 49,
          activeColor: _cardAccent,
          onChanged: (value) => setState(() => _monthlyAmount = value),
        ),
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: '월 예상',
                value: miles <= 0 ? '-' : '${won.format(miles)}마일',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: '연 가치',
                value: valueKRW <= 0 ? '-' : '${won.format(valueKRW)}원',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          perMile <= 0
              ? '마일 적립률이 명확하지 않아 실제 댓글/토론 검증이 필요합니다.'
              : '임시 기준: ${won.format(perMile)}원당 1마일, 1마일 15원 가치로 계산합니다.',
          style: const TextStyle(
            color: _cardMuted,
            height: 1.35,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _cardMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: _cardInk,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitIcon extends StatelessWidget {
  final String asset;
  final double size;

  const _BenefitIcon({
    required this.asset,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardLine),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        asset,
        width: size * 0.58,
        height: size * 0.58,
        colorFilter: const ColorFilter.mode(_cardMuted, BlendMode.srcIn),
      ),
    );
  }
}

class _IssuerLinkPanel extends StatelessWidget {
  final VoidCallback onTap;

  const _IssuerLinkPanel({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardAccent,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(Icons.language_outlined, color: Colors.white, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '카드사 바로가기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImageBox extends StatelessWidget {
  final CatalogCardProduct product;
  final CardCatalogService service;
  final double size;

  const _CardImageBox({
    required this.product,
    required this.service,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final downloadUrl = product.mainDownloadUrl;
    if (downloadUrl != null) {
      return _NetworkImageBox(url: downloadUrl, size: size);
    }

    final storagePath = product.mainStoragePath;
    if (storagePath != null) {
      return FutureBuilder<String?>(
        future: service.downloadUrlForStoragePath(storagePath),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) return _CardPlaceholder(size: size);
          return _NetworkImageBox(url: url, size: size);
        },
      );
    }

    return _CardPlaceholder(size: size);
  }
}

class _NetworkImageBox extends StatelessWidget {
  final String url;
  final double size;

  const _NetworkImageBox({
    required this.url,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _CardPlaceholder(size: size),
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  final double size;

  const _CardPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.credit_card,
        color: const Color(0xFF8A91A1),
        size: size * 0.42,
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionPanel({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _EditPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditPanel({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(title: title, children: children);
  }
}

class _RevisionTile extends StatelessWidget {
  final CardProductRevision revision;
  final Future<_RevisionActorProfile?> actorProfileFuture;
  final VoidCallback onTap;
  final ValueChanged<String> onActorTap;
  final VoidCallback? onRollback;

  const _RevisionTile({
    required this.revision,
    required this.actorProfileFuture,
    required this.onTap,
    required this.onActorTap,
    required this.onRollback,
  });

  @override
  Widget build(BuildContext context) {
    final firstChanges = revision.changes.take(3).map((c) => c.path).join(', ');
    final actorUid = revision.actorUid?.trim() ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SmallPill(revision.actionLabel),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'v${revision.versionFrom} → v${revision.versionTo}',
                      style: const TextStyle(fontWeight: FontWeight.w400),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRollback,
                    icon: const Icon(Icons.restore_outlined, size: 18),
                    label: const Text('롤백'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                firstChanges.isEmpty ? '변경 필드 없음' : firstChanges,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5E6676),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dateText(revision.createdAt),
                style: const TextStyle(color: Color(0xFF8A91A1), fontSize: 12),
              ),
              const SizedBox(height: 8),
              _RevisionActorSummary(
                actorUid: actorUid,
                profileFuture: actorProfileFuture,
                dense: true,
                onTap: actorUid.isEmpty ? null : () => onActorTap(actorUid),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevisionActorProfile {
  final String displayName;
  final String? photoUrl;
  final bool exists;

  const _RevisionActorProfile({
    required this.displayName,
    this.photoUrl,
    this.exists = true,
  });
}

class _RevisionActorSummary extends StatelessWidget {
  final String? actorUid;
  final Future<_RevisionActorProfile?> profileFuture;
  final VoidCallback? onTap;
  final bool dense;
  final String? leadingLabel;

  const _RevisionActorSummary({
    required this.actorUid,
    required this.profileFuture,
    this.onTap,
    this.dense = false,
    this.leadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final uid = actorUid?.trim() ?? '';
    return FutureBuilder<_RevisionActorProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final loading = uid.isNotEmpty &&
            snapshot.connectionState == ConnectionState.waiting;
        final profile = snapshot.data;
        final displayName =
            loading ? '사용자 확인 중' : (profile?.displayName ?? '수정자 정보 없음');
        final subtitle = loading
            ? '프로필을 불러오는 중'
            : uid.isEmpty
                ? '수정자 정보 없음'
                : profile?.exists == false
                    ? '사용자 정보 없음'
                    : '프로필 보기';
        final photoUrl = loading ? null : profile?.photoUrl;
        final canOpenProfile =
            uid.isNotEmpty && onTap != null && profile?.exists != false;

        final content = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 0 : 10,
            vertical: dense ? 0 : 8,
          ),
          child: Row(
            children: [
              _RevisionActorAvatar(
                photoUrl: photoUrl,
                loading: loading,
                size: dense ? 30 : 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leadingLabel != null) ...[
                      Text(
                        leadingLabel!,
                        style: const TextStyle(
                          color: Color(0xFF8A91A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cardInk,
                        fontSize: dense ? 13 : 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canOpenProfile
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF8A91A1),
                        fontSize: dense ? 11 : 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpenProfile)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        );

        if (!canOpenProfile) return content;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: content,
          ),
        );
      },
    );
  }
}

class _RevisionActorAvatar extends StatelessWidget {
  final String? photoUrl;
  final bool loading;
  final double size;

  const _RevisionActorAvatar({
    required this.photoUrl,
    required this.loading,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl?.trim() ?? '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEFF3F8),
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isNotEmpty
          ? null
          : loading
              ? SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.person_outline,
                  size: size * 0.56,
                  color: const Color(0xFF6B7280),
                ),
    );
  }
}

class _DetailSectionsList extends StatelessWidget {
  final CardCatalogService service;
  final String cardId;

  const _DetailSectionsList({
    required this.service,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardDetailSection>>(
      stream: service.watchDetailSections(cardId),
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const <CardDetailSection>[];
        if (sections.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            const SizedBox(height: 12),
            for (final section in sections) ...[
              _DetailSectionCard(section: section),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  final CardDetailSection section;

  const _DetailSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF0F1F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BenefitIcon(asset: _benefitIconAsset(section.title)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      color: _cardInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (section.body.isNotEmpty)
              Text(
                section.body,
                style: const TextStyle(
                  color: Color(0xFF303544),
                  height: 1.48,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Html(data: section.html),
          ],
        ),
      ),
    );
  }
}

class _ActionMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionMenuRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _cardInk),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: _cardInk,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CardCommentsSection extends StatefulWidget {
  final CardCatalogService service;
  final String cardId;
  final VoidCallback? onRequireLogin;

  const _CardCommentsSection({
    required this.service,
    required this.cardId,
    required this.onRequireLogin,
  });

  @override
  State<_CardCommentsSection> createState() => _CardCommentsSectionState();
}

class _CardCommentsSectionState extends State<_CardCommentsSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();
  late Stream<List<CardProductComment>> _commentsStream;
  CardProductComment? _replyTarget;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _commentsStream = widget.service.watchComments(widget.cardId);
    _inputFocusNode.addListener(_handleInputFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _CardCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId ||
        oldWidget.service != widget.service) {
      _commentsStream = widget.service.watchComments(widget.cardId);
      _replyTarget = null;
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_handleInputFocusChanged);
    _inputFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleInputFocusChanged() {
    if (_inputFocusNode.hasFocus) {
      _scheduleEnsureInputVisible();
    }
  }

  void _scheduleEnsureInputVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInputVisible();
    });
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted && _inputFocusNode.hasFocus) {
        _ensureInputVisible();
      }
    });
  }

  void _ensureInputVisible() {
    final inputContext = _inputKey.currentContext;
    if (!mounted || inputContext == null) return;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final visibleFraction = screenHeight <= 0
        ? 0.6
        : ((screenHeight - keyboardInset) / screenHeight).clamp(0.35, 1.0);
    final alignment = (visibleFraction - 0.16).clamp(0.16, 0.72);

    Scrollable.ensureVisible(
      inputContext,
      alignment: alignment,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _startReply(CardProductComment comment) {
    setState(() => _replyTarget = comment);
    _inputFocusNode.requestFocus();
    _scheduleEnsureInputVisible();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: '댓글',
      children: [
        StreamBuilder<List<CardProductComment>>(
          stream: _commentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text(
                '댓글을 불러오지 못했습니다: ${snapshot.error}',
                style: const TextStyle(
                  color: _cardMuted,
                  fontWeight: FontWeight.w400,
                ),
              );
            }

            final comments = snapshot.data ?? const <CardProductComment>[];
            final parents = comments
                .where((comment) => !comment.isReply)
                .toList(growable: false);
            final repliesByParent = <String, List<CardProductComment>>{};
            for (final comment
                in comments.where((comment) => comment.isReply)) {
              final parentId = comment.parentCommentId;
              if (parentId == null) continue;
              repliesByParent.putIfAbsent(parentId, () => []).add(comment);
            }

            if (parents.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '아직 댓글이 없습니다.',
                  style: TextStyle(
                    color: _cardMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final comment in parents) ...[
                  _CardCommentTile(
                    comment: comment,
                    onReply: () => _startReply(comment),
                  ),
                  for (final reply in repliesByParent[comment.id] ??
                      const <CardProductComment>[])
                    Padding(
                      padding: const EdgeInsets.only(left: 34, top: 8),
                      child: _CardCommentTile(comment: reply),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        if (_replyTarget != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cardLine),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_replyTarget!.displayName}님에게 답글',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cardInk,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _replyTarget = null),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: _cardMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: TextField(
            key: _inputKey,
            controller: _controller,
            focusNode: _inputFocusNode,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 96,
            ),
            onTap: _scheduleEnsureInputVisible,
            decoration: InputDecoration(
              counterText: '',
              hintText: _replyTarget == null ? '댓글을 입력하세요' : '답글을 입력하세요',
              filled: true,
              fillColor: const Color(0xFFF4F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: '등록',
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                onPressed: _sending ? null : _send,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      Fluttertoast.showToast(msg: '댓글을 입력해주세요.');
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 댓글을 남길 수 있습니다.');
      widget.onRequireLogin?.call();
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.service.addCardProductComment(
        cardId: widget.cardId,
        body: body,
        parentCommentId: _replyTarget?.id,
      );
      _controller.clear();
      if (mounted) setState(() => _replyTarget = null);
      Fluttertoast.showToast(msg: '댓글을 등록했습니다.');
    } catch (error) {
      Fluttertoast.showToast(msg: '댓글 등록에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _CardCommentTile extends StatelessWidget {
  final CardProductComment comment;
  final VoidCallback? onReply;

  const _CardCommentTile({
    required this.comment,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = comment.photoURL;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFECEFF4),
          backgroundImage: photoUrl == null || photoUrl.isEmpty
              ? null
              : NetworkImage(photoUrl),
          child: photoUrl == null || photoUrl.isEmpty
              ? const Icon(Icons.person, size: 18, color: _cardMuted)
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cardLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _cardInk,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (comment.isAdmin) ...[
                      const SizedBox(width: 6),
                      const _SmallPill('관리자'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    comment.displayGrade,
                    _dateText(comment.createdAt),
                  ].where((value) => value.trim().isNotEmpty).join(' · '),
                  style: const TextStyle(
                    color: _cardMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: Color(0xFF303544),
                    height: 1.38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (onReply != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onReply,
                      icon: const Icon(Icons.reply_outlined, size: 17),
                      label: const Text('답글'),
                      style: TextButton.styleFrom(
                        foregroundColor: _cardAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeDiff extends StatelessWidget {
  final CardRevisionChange change;

  const _ChangeDiff({required this.change});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.path,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 8),
          Text(
            '이전: ${displayValue(change.oldValue).isEmpty ? '-' : displayValue(change.oldValue)}',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            '변경: ${displayValue(change.newValue).isEmpty ? '-' : displayValue(change.newValue)}',
            style: const TextStyle(color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;

  const _SmallPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardLine),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _cardInk,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: width,
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: selected ? _cardAccent : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _cardAccent : const Color(0xFFD1D5DB),
                width: 1.1,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7E8492), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitDisplayItem {
  final String title;
  final String description;
  final String iconAsset;

  const _BenefitDisplayItem({
    required this.title,
    required this.description,
    required this.iconAsset,
  });
}

List<_BenefitDisplayItem> _benefitItems(List<dynamic> values) {
  return values
      .map(_benefitItem)
      .whereType<_BenefitDisplayItem>()
      .toList(growable: false);
}

_BenefitDisplayItem? _benefitItem(dynamic value) {
  var title = '';
  var description = '';

  if (value is Map) {
    title = _firstNonEmpty([
      value['title'],
      value['label'],
      value['name'],
      value['category'],
      value['group'],
    ]);
    description = _firstNonEmpty([
      value['value'],
      value['summary'],
      value['description'],
      value['detail'],
      value['body'],
    ]);
  }

  final text = displayValue(value);
  if (title.isEmpty && text.isNotEmpty) {
    final separator = RegExp(r'\s+[·ㆍ]\s+|[:：]');
    final match = separator.firstMatch(text);
    if (match == null) {
      title = text.length > 14 ? text.substring(0, 14) : text;
      description = text.length > 14 ? text : '';
    } else {
      title = text.substring(0, match.start).trim();
      description = text.substring(match.end).trim();
    }
  }
  if (description.isEmpty && text.isNotEmpty && title != text) {
    description = text;
  }
  if (title.isEmpty && description.isEmpty) return null;

  final searchable = '$title $description';
  return _BenefitDisplayItem(
    title: title.isEmpty ? '혜택' : title,
    description: description,
    iconAsset: _benefitIconAsset(searchable),
  );
}

String _benefitIconAsset(String text) {
  final value = text.toLowerCase();
  if (value.contains('온라인') ||
      value.contains('internet') ||
      value.contains('디지털')) {
    return 'asset/icon/card_benefits/online.svg';
  }
  if (value.contains('쇼핑') ||
      value.contains('마트') ||
      value.contains('백화점') ||
      value.contains('쿠팡') ||
      value.contains('g마켓') ||
      value.contains('옥션')) {
    return 'asset/icon/card_benefits/shopping.svg';
  }
  if (value.contains('간편') ||
      value.contains('pay') ||
      value.contains('페이') ||
      value.contains('결제') ||
      value.contains('청구')) {
    return 'asset/icon/card_benefits/pay.svg';
  }
  if (value.contains('주유') || value.contains('충전') || value.contains('oil')) {
    return 'asset/icon/card_benefits/fuel.svg';
  }
  if (value.contains('카페') || value.contains('커피') || value.contains('스타벅스')) {
    return 'asset/icon/card_benefits/cafe.svg';
  }
  if (value.contains('항공') ||
      value.contains('마일') ||
      value.contains('여행') ||
      value.contains('호텔') ||
      value.contains('asiana') ||
      value.contains('대한항공')) {
    return 'asset/icon/card_benefits/travel.svg';
  }
  if (value.contains('택시') ||
      value.contains('교통') ||
      value.contains('버스') ||
      value.contains('지하철')) {
    return 'asset/icon/card_benefits/transport.svg';
  }
  if (value.contains('푸드') ||
      value.contains('음식') ||
      value.contains('외식') ||
      value.contains('배달')) {
    return 'asset/icon/card_benefits/food.svg';
  }
  if (value.contains('통신') ||
      value.contains('휴대폰') ||
      value.contains('mobile')) {
    return 'asset/icon/card_benefits/telecom.svg';
  }
  if (value.contains('영화') || value.contains('티켓') || value.contains('문화')) {
    return 'asset/icon/card_benefits/movie.svg';
  }
  if (value.contains('병원') || value.contains('약국') || value.contains('의료')) {
    return 'asset/icon/card_benefits/medical.svg';
  }
  if (value.contains('생활') || value.contains('보험') || value.contains('세탁')) {
    return 'asset/icon/card_benefits/life.svg';
  }
  return 'asset/icon/card_benefits/default.svg';
}

int _estimatedPerMileKRW(CatalogCardProduct product) {
  for (final value in [
    product.raw['mileRuleUsedPerMileKRW'],
    product.raw['creditPerMileKRW'],
    product.raw['checkPerMileKRW'],
    product.raw['perMileKRW'],
    product.raw['milePerKRW'],
  ]) {
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed > 0) return parsed;
    }
  }
  final haystack = [
    product.rewardProgram,
    product.detailSummary,
    ...product.primaryBenefits.map(displayValue),
  ].whereType<String>().join(' ');
  final match = RegExp(r'([0-9,]+)\s*원당\s*([0-9,]+)\s*마일').firstMatch(haystack);
  if (match != null) {
    final krw = int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
    final miles = int.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0;
    if (krw > 0 && miles > 0) return (krw / miles).round();
  }
  return 0;
}

String? _cardIssuerUrl(CatalogCardProduct product) {
  final raw = product.raw;
  final direct = _firstUrl([
    raw['applyUrl'],
    raw['applicationUrl'],
    raw['issuerUrl'],
    raw['officialUrl'],
    raw['homepageUrl'],
    raw['productUrl'],
    raw['cardUrl'],
  ]);
  if (direct != null) return direct;

  for (final key in const [
    'issuer',
    'cardIssuer',
    'cardCompany',
    'official',
    'application',
  ]) {
    final url = _urlFromValue(raw[key]);
    if (url != null) return url;
  }

  final sourceRefs = raw['sourceRefs'];
  if (sourceRefs is Map) {
    for (final key in const [
      'issuer',
      'cardIssuer',
      'cardCompany',
      'official',
      'application',
    ]) {
      final url = _urlFromValue(sourceRefs[key]);
      if (url != null) return url;
    }
  }

  return null;
}

String? _firstUrl(Iterable<dynamic> values) {
  for (final value in values) {
    final url = _urlFromValue(value);
    if (url != null) return url;
  }
  return null;
}

String? _urlFromValue(dynamic value) {
  if (value is String) {
    final text = value.trim();
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
  }
  if (value is Map) {
    return _firstUrl([
      value['applyUrl'],
      value['applicationUrl'],
      value['issuerUrl'],
      value['officialUrl'],
      value['homepageUrl'],
      value['productUrl'],
      value['cardUrl'],
      value['url'],
      value['linkUrl'],
    ]);
  }
  return null;
}

String _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final text = displayValue(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

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

String _dateText(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('yyyy.MM.dd HH:mm').format(date);
}

int _dateMillis(DateTime? date) => date?.millisecondsSinceEpoch ?? 0;

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _lines(String value) {
  return value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

String _compactCount(int value) {
  if (value >= 1000000) {
    final text = (value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1);
    return '${text.replaceAll('.0', '')}M';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${text.replaceAll('.0', '')}K';
  }
  return value.toString();
}
