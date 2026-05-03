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

import '../models/card_product_model.dart';
import '../services/branch_service.dart';
import '../services/card_catalog_service.dart';

const Color _cardInk = Color(0xFF111827);
const Color _cardLine = Color(0xFFE5E7EB);
const Color _cardMuted = Color(0xFF6B7280);
const Color _cardPage = Color(0xFFF8F9FB);

class CardCatalogScreen extends StatefulWidget {
  final VoidCallback? onRequireLogin;

  const CardCatalogScreen({
    super.key,
    this.onRequireLogin,
  });

  @override
  State<CardCatalogScreen> createState() => _CardCatalogScreenState();
}

class _CardCatalogScreenState extends State<CardCatalogScreen> {
  final CardCatalogService _service = CardCatalogService();
  final TextEditingController _queryController = TextEditingController();
  late final Future<bool> _adminFuture = _canAccessAdmin();
  String _statusFilter = 'all';
  String _sortOrder = 'latest';
  bool _importing = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '카드',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    onPressed: _importing ? null : _openImportDialog,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'card_request',
            backgroundColor: Colors.white,
            foregroundColor: _cardInk,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _cardLine),
            ),
            icon: const Icon(Icons.search_outlined),
            label: const Text('카드 요청'),
            onPressed: _openRequest,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'card_create',
            backgroundColor: _cardInk,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('카드 추가'),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogCardProduct>>(
        stream: _service.watchProducts(),
        builder: (context, snapshot) {
          final header = _CatalogSearchHeader(
            controller: _queryController,
            statusFilter: _statusFilter,
            sortOrder: _sortOrder,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onSortChanged: (value) => setState(() => _sortOrder = value),
            onQueryChanged: (_) => setState(() {}),
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
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
          if (snapshot.hasError) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: header),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.error_outline,
                    title: '카드 정보를 불러오지 못했습니다.',
                    message: '${snapshot.error}',
                  ),
                ),
              ],
            );
          }

          final products = _filterAndSort(snapshot.data ?? const []);
          if (products.isEmpty) {
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
                      final product = products[index ~/ 2];
                      return _CardProductTile(
                        product: product,
                        service: _service,
                        onTap: () => _openDetail(product.id),
                      );
                    },
                    childCount: products.length * 2 - 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '카드 요청',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                    onPressed: _searching ? null : _search,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '찾는 카드를 선택하면 관리자에게 가져오기 요청이 전달됩니다.',
                style: TextStyle(
                  color: _cardMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      Fluttertoast.showToast(msg: '두 글자 이상 입력해주세요.');
      return;
    }
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
      setState(() => _candidates = candidates);
    } catch (error) {
      Fluttertoast.showToast(msg: '카드 검색에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
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
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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

class _CardProductDetailScreenState extends State<CardProductDetailScreen> {
  final CardCatalogService _service = CardCatalogService();
  late final Future<bool> _adminFuture = _canAccessAdmin();
  bool _sharing = false;
  bool _viewIncremented = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogCardProduct?>(
      stream: _service.watchProduct(widget.cardId),
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product != null && !_viewIncremented) {
          _viewIncremented = true;
          Future.microtask(() => _incrementView(product.id));
        }
        return Scaffold(
          backgroundColor: _cardPage,
          appBar: AppBar(
            title: Text(
              product?.name ?? '카드 상세',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.4,
            actions: [
              if (product != null)
                _CardLikeActionButton(
                  service: _service,
                  cardId: product.id,
                  likesCount: product.likesCount,
                  onRequireLogin: widget.onRequireLogin,
                ),
              if (product != null)
                IconButton(
                  tooltip: '공유',
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                  onPressed: _sharing ? null : () => _shareCard(product),
                ),
              if (product != null)
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openEdit(product),
                ),
              FutureBuilder<bool>(
                future: _adminFuture,
                builder: (context, adminSnapshot) {
                  if (product == null || adminSnapshot.data != true) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: '히스토리',
                    icon: const Icon(Icons.history_outlined),
                    onPressed: () => _openHistory(product),
                  );
                },
              ),
            ],
          ),
          body: _buildBody(snapshot, product),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<CatalogCardProduct?> snapshot,
    CatalogCardProduct? product,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
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
    return Stack(
      children: [
        ListView(
          padding:
              EdgeInsets.fromLTRB(16, 16, 16, issuerUrl == null ? 28 : 112),
          children: [
            _CardHeroImage(product: product, service: _service),
            const SizedBox(height: 12),
            _CardFactsPanel(product: product),
            const SizedBox(height: 12),
            _BenefitsPanel(
              title: '주요 혜택',
              values: product.primaryBenefits,
              emptyMessage: '아직 입력된 혜택 정보가 없습니다.',
            ),
            const SizedBox(height: 12),
            _NoticePanel(values: product.exclusions),
            const SizedBox(height: 12),
            _DetailSummaryPanel(product: product),
            _DetailSectionsList(
              service: _service,
              cardId: product.id,
            ),
            const SizedBox(height: 12),
            _CardCommentsSection(
              service: _service,
              cardId: product.id,
              onRequireLogin: widget.onRequireLogin,
            ),
          ],
        ),
        if (issuerUrl != null)
          _IssuerFloatingButton(
            onTap: () => _openIssuerUrl(issuerUrl),
          ),
      ],
    );
  }

  Future<void> _openIssuerUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      Fluttertoast.showToast(msg: '카드사 링크를 열 수 없습니다.');
      return;
    }
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
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: Text(
          _isCreate ? '카드 추가' : '카드 수정',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('사용 가능')),
                    DropdownMenuItem(value: 'pending', child: Text('정보 확인중')),
                    DropdownMenuItem(value: 'discontinued', child: Text('단종')),
                    DropdownMenuItem(value: 'hidden', child: Text('숨김')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'active'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rewardController,
                  decoration: const InputDecoration(labelText: '마일리지/리워드 프로그램'),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
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
  bool _rollingBack = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardPage,
      appBar: AppBar(
        title: const Text(
          '수정 히스토리',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                onTap: () => _showRevision(revision),
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

  Future<void> _showRevision(CardProductRevision revision) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              '${revision.actionLabel} v${revision.versionFrom} → v${revision.versionTo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '수정자: ${revision.actorUid ?? '-'}',
              style: const TextStyle(color: Color(0xFF7E8492)),
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
                fontWeight: FontWeight.w600,
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
                borderSide: const BorderSide(color: _cardInk, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: '전체',
                  selected: statusFilter == 'all',
                  onTap: () => onStatusChanged('all'),
                ),
                _StatusChip(
                  label: '사용 가능',
                  selected: statusFilter == 'active',
                  onTap: () => onStatusChanged('active'),
                ),
                _StatusChip(
                  label: '정보 확인중',
                  selected: statusFilter == 'pending',
                  onTap: () => onStatusChanged('pending'),
                ),
                _StatusChip(
                  label: '단종',
                  selected: statusFilter == 'discontinued',
                  onTap: () => onStatusChanged('discontinued'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: '최신순',
                    selected: sortOrder == 'latest',
                    onTap: () => onSortChanged('latest'),
                    fontSize: 12,
                    horizontalPadding: 14,
                    verticalPadding: 8,
                  ),
                  _StatusChip(
                    label: '인기순',
                    selected: sortOrder == 'popular',
                    onTap: () => onSortChanged('popular'),
                    fontSize: 12,
                    horizontalPadding: 14,
                    verticalPadding: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.issuerName} · ${product.cardTypeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${candidate.issuerName} · ${candidate.cardTypeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cardMuted,
                      fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w700,
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
                backgroundColor: _cardInk,
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate.issuerName} · ${candidate.cardTypeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _cardMuted,
                          fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${product.issuerName} · ${product.cardTypeLabel}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _cardMuted,
              fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF252A36),
                fontWeight: FontWeight.w900,
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                  fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF555C6B),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

class _IssuerFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _IssuerFloatingButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: SafeArea(
        top: false,
        child: Material(
          color: const Color(0xFFFFC84A),
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Icon(Icons.language_outlined, color: Colors.black, size: 22),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '카드사 바로가기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.black, size: 24),
                ],
              ),
            ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
  final VoidCallback onTap;
  final VoidCallback? onRollback;

  const _RevisionTile({
    required this.revision,
    required this.onTap,
    required this.onRollback,
  });

  @override
  Widget build(BuildContext context) {
    final firstChanges = revision.changes.take(3).map((c) => c.path).join(', ');
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
                      style: const TextStyle(fontWeight: FontWeight.w900),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_dateText(revision.createdAt)} · ${revision.actorUid ?? '-'}',
                style: const TextStyle(color: Color(0xFF8A91A1), fontSize: 12),
              ),
            ],
          ),
        ),
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
                      fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w700,
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

class _CardLikeActionButton extends StatefulWidget {
  final CardCatalogService service;
  final String cardId;
  final int likesCount;
  final VoidCallback? onRequireLogin;

  const _CardLikeActionButton({
    required this.service,
    required this.cardId,
    required this.likesCount,
    required this.onRequireLogin,
  });

  @override
  State<_CardLikeActionButton> createState() => _CardLikeActionButtonState();
}

class _CardLikeActionButtonState extends State<_CardLikeActionButton> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        tooltip: '좋아요 ${widget.likesCount}',
        icon: const Icon(Icons.favorite_border_outlined),
        onPressed: _toggleLike,
      );
    }

    return StreamBuilder<bool>(
      stream: widget.service.watchUserLike(
        cardId: widget.cardId,
        uid: user.uid,
      ),
      builder: (context, snapshot) {
        final liked = snapshot.data == true;
        return IconButton(
          tooltip: liked ? '좋아요 취소' : '좋아요 ${widget.likesCount}',
          icon: _toggling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  liked ? Icons.favorite : Icons.favorite_border_outlined,
                  color: liked ? const Color(0xFFE11D48) : null,
                ),
          onPressed: _toggling ? null : _toggleLike,
        );
      },
    );
  }

  Future<void> _toggleLike() async {
    if (FirebaseAuth.instance.currentUser == null) {
      Fluttertoast.showToast(msg: '로그인 후 좋아요를 누를 수 있습니다.');
      widget.onRequireLogin?.call();
      return;
    }

    setState(() => _toggling = true);
    try {
      final result = await widget.service.toggleCardProductLike(
        cardId: widget.cardId,
      );
      Fluttertoast.showToast(
          msg: result.liked ? '좋아요를 눌렀습니다.' : '좋아요를 취소했습니다.');
    } catch (error) {
      Fluttertoast.showToast(msg: '좋아요 처리에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
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
  CardProductComment? _replyTarget;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: '댓글',
      children: [
        StreamBuilder<List<CardProductComment>>(
          stream: widget.service.watchComments(widget.cardId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                  fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final comment in parents) ...[
                  _CardCommentTile(
                    comment: comment,
                    onReply: () => setState(() => _replyTarget = comment),
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
                      fontWeight: FontWeight.w800,
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
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
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
                          fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: Color(0xFF303544),
                    height: 1.38,
                    fontWeight: FontWeight.w700,
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
                        foregroundColor: _cardInk,
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
            style: const TextStyle(fontWeight: FontWeight.w900),
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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 14,
    this.horizontalPadding = 18,
    this.verticalPadding = 10,
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
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: selected ? _cardInk : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _cardInk : const Color(0xFFD1D5DB),
                width: 1.1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
