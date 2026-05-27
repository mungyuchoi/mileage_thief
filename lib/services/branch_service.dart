import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screen/branch/branch_detail_screen.dart';
import '../screen/community_chat_screen.dart';
import '../screen/community_screen.dart';
import '../screen/community_detail_screen.dart';
import '../screen/contest_detail_screen.dart';
import '../screen/giftcard_deals_screen.dart';
import '../screen/giftcard_rates_screen.dart';
import '../screen/giftcard_settlement_screen.dart';
import '../screen/point_stay_screen.dart';
import 'analytics_service.dart';

class BranchService {
  static final BranchService _instance = BranchService._internal();
  factory BranchService() => _instance;
  BranchService._internal();

  /// Branch SDK 초기화
  Future<void> initialize() async {
    try {
      await FlutterBranchSdk.init(
        enableLogging: true,
      );

      debugPrint('Branch SDK 초기화 완료');

      // 딥링크 리스너 설정
      _setupDeepLinkListener();

      // 초기 딥링크 처리 (앱이 종료된 상태에서 딥링크로 실행된 경우)
      _handleInitialDeepLink();
    } catch (e) {
      debugPrint('Branch SDK 초기화 오류: $e');
    }
  }

  /// 딥링크 리스너 설정
  void _setupDeepLinkListener() {
    FlutterBranchSdk.listSession().listen((data) {
      debugPrint('Branch 딥링크 수신: $data');
      _handleDeepLinkData(data);
    }, onError: (error) {
      debugPrint('Branch 딥링크 오류: $error');
    });
  }

  /// 초기 딥링크 처리
  Future<void> _handleInitialDeepLink() async {
    try {
      final data = await FlutterBranchSdk.getFirstReferringParams();
      if (data.isNotEmpty) {
        debugPrint('초기 딥링크 데이터: $data');

        // getFirstReferringParams는 앱 설치 후 첫 번째 링크를 계속 저장하므로
        // 실제 새로운 클릭인지 확인 (최근 클릭만 처리)
        final clickTimestamp = data['+click_timestamp'];
        if (clickTimestamp != null) {
          final clickTime =
              DateTime.fromMillisecondsSinceEpoch(clickTimestamp * 1000);
          final now = DateTime.now();
          final difference = now.difference(clickTime);

          // 30초 이내의 클릭만 처리 (앱이 딥링크로 실행된 경우)
          if (difference.inSeconds <= 30) {
            debugPrint('최근 딥링크 클릭 감지 (${difference.inSeconds}초 전) - 처리함');
            _handleDeepLinkData(data);
          } else {
            debugPrint('오래된 딥링크 데이터 무시 (${difference.inMinutes}분 전)');
          }
        } else {
          debugPrint('클릭 타임스탬프 없음 - 무시');
        }
      }
    } catch (e) {
      debugPrint('초기 딥링크 처리 오류: $e');
    }
  }

  /// 딥링크 데이터 처리
  void _handleDeepLinkData(Map<dynamic, dynamic> data) {
    // Branch 링크를 실제로 클릭했는지 확인
    final clickedBranchLink = data['+clicked_branch_link'];

    // 실제 딥링크 클릭이 아니면 처리하지 않음
    if (clickedBranchLink != true) {
      debugPrint('Branch 초기화 콜백 (딥링크 클릭 아님): $data');
      return;
    }

    // 앱 내부 목적지 딥링크 처리
    final destination = _firstStringValue(data, const [
      'destination',
      'screen',
      'target',
      'route',
      'type',
    ]);
    final linkValue = _firstStringValue(data, const [
      'linkValue',
      'deeplink',
      'deepLink',
      'path',
    ]);
    _logBranchDeepLinkOpen(data, destination: destination);

    if (_isChatDestination(destination) ||
        _chatRoomIdFromLinkValue(linkValue) != null) {
      final roomId = _firstStringValue(data, const [
            'roomId',
            'chatRoomId',
          ]) ??
          _chatRoomIdFromLinkValue(linkValue) ??
          'global';
      debugPrint('실제 딥링크 클릭 감지 - 채팅으로 이동: $roomId');
      _navigateToChat(roomId);
      return;
    }

    // 콘테스트 딥링크 처리
    final contestId = data['contestId']?.toString();
    if (contestId != null) {
      debugPrint('실제 딥링크 클릭 감지 - 콘테스트로 이동: $contestId');
      _navigateToContest(contestId);
      return;
    }

    final cardId = data['cardId']?.toString();
    final linkCardId = _cardIdFromLinkValue(linkValue);
    final resolvedCardId =
        cardId?.trim().isNotEmpty == true ? cardId!.trim() : linkCardId;
    if (resolvedCardId != null && resolvedCardId.trim().isNotEmpty) {
      debugPrint('실제 딥링크 클릭 감지 - 카드 상세로 이동: $resolvedCardId');
      _navigateToCard(resolvedCardId.trim());
      return;
    }

    if (_isCardCatalogDestination(destination) ||
        _isCardCatalogDestination(linkValue)) {
      debugPrint('실제 딥링크 클릭 감지 - 카드 목록으로 이동');
      _navigateToCards();
      return;
    }

    final giftcardDealId = data['giftcardDealId']?.toString() ??
        data['dealId']?.toString() ??
        _giftcardDealIdFromLinkValue(linkValue);
    if (giftcardDealId != null && giftcardDealId.trim().isNotEmpty) {
      debugPrint('실제 딥링크 클릭 감지 - 상품권 특가로 이동: $giftcardDealId');
      _navigateToGiftcardDeal(giftcardDealId.trim());
      return;
    }

    if (_isGiftcardDealDestination(destination) ||
        _isGiftcardDealDestination(linkValue)) {
      debugPrint('실제 딥링크 클릭 감지 - 상품권 특가 목록으로 이동');
      _navigateToGiftcardDealList();
      return;
    }

    if (_isPointStayDestination(destination) ||
        _isPointStayDestination(linkValue)) {
      debugPrint('실제 딥링크 클릭 감지 - 포인트 숙박으로 이동');
      _navigateToPointStay();
      return;
    }

    // 게시글 딥링크 처리
    final postId = data['postId']?.toString();
    final dateString = data['dateString']?.toString();
    final rawBoardId = data['boardId']?.toString();
    final boardId = rawBoardId ?? 'free';
    final boardName = data['boardName']?.toString() ?? '자유게시판';
    final scrollToCommentId = data['scrollToCommentId']?.toString();

    if (postId != null && dateString != null) {
      debugPrint('실제 딥링크 클릭 감지 - 게시글로 이동: $postId');
      _navigateToPost(
          postId, dateString, boardId, boardName, scrollToCommentId);
      return;
    }

    final communityBoardId = _communityBoardIdFromLinkValue(linkValue) ??
        (_isCommunityDestination(destination)
            ? (rawBoardId?.trim().isNotEmpty == true
                ? rawBoardId!.trim()
                : 'all')
            : null);
    if (communityBoardId != null) {
      debugPrint('실제 딥링크 클릭 감지 - 커뮤니티 보드로 이동: $communityBoardId');
      _navigateToCommunityBoard(
        communityBoardId,
        boardName: data['boardName']?.toString(),
      );
    } else {
      debugPrint('딥링크 데이터 부족: postId=$postId, dateString=$dateString');
    }
  }

  bool openInternalDeepLinkValue(
    String linkValue, {
    BuildContext? context,
  }) {
    final value = linkValue.trim();
    if (value.isEmpty) return false;

    final roomId = _chatRoomIdFromLinkValue(value);
    if (roomId != null) {
      _logInternalDeepLinkOpen('community_chat', entityId: roomId);
      _navigateToChat(roomId, context: context);
      return true;
    }

    if (value.startsWith('branch:')) {
      final branchId = value.substring('branch:'.length).trim();
      if (branchId.isEmpty) return false;
      _logInternalDeepLinkOpen('branch', entityId: branchId);
      _navigateToBranch(branchId, context: context);
      return true;
    }

    final giftcardRateId = _giftcardRateIdFromLinkValue(value);
    if (giftcardRateId != null) {
      _logInternalDeepLinkOpen('giftcard_rate', entityId: giftcardRateId);
      _navigateToGiftcardRate(giftcardRateId, context: context);
      return true;
    }

    if (_isGiftcardCalculatorDestination(value)) {
      _logInternalDeepLinkOpen('giftcard_calculator');
      _navigateToGiftcardCalculator(context: context);
      return true;
    }

    if (_isCardCatalogDestination(value)) {
      _logInternalDeepLinkOpen('card_catalog');
      _navigateToCards(context: context);
      return true;
    }

    final cardId = _cardIdFromLinkValue(value);
    if (cardId != null) {
      _logInternalDeepLinkOpen('card', entityId: cardId);
      _navigateToCard(cardId, context: context);
      return true;
    }

    final giftcardDealId = _giftcardDealIdFromLinkValue(value);
    if (giftcardDealId != null) {
      _logInternalDeepLinkOpen('giftcard_deal', entityId: giftcardDealId);
      _navigateToGiftcardDeal(giftcardDealId, context: context);
      return true;
    }

    if (_isGiftcardDealDestination(value)) {
      _logInternalDeepLinkOpen('giftcard_deal_list');
      _navigateToGiftcardDealList(context: context);
      return true;
    }

    if (_isPointStayDestination(value)) {
      _logInternalDeepLinkOpen('point_stay');
      _navigateToPointStay(context: context);
      return true;
    }

    final communityBoardId = _communityBoardIdFromLinkValue(value);
    if (communityBoardId != null) {
      _logInternalDeepLinkOpen('community_board', entityId: communityBoardId);
      _navigateToCommunityBoard(communityBoardId, context: context);
      return true;
    }

    return false;
  }

  String? _firstStringValue(
    Map<dynamic, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  void _logBranchDeepLinkOpen(
    Map<dynamic, dynamic> data, {
    String? destination,
  }) {
    AnalyticsService.instance.logAction('deep_link_open', params: {
      'source': 'branch',
      'destination': destination,
      'post_id': data['postId']?.toString(),
      'board_id': data['boardId']?.toString(),
      'card_id': data['cardId']?.toString(),
      'deal_id': (data['giftcardDealId'] ?? data['dealId'] ?? data['contestId'])
          ?.toString(),
    });
  }

  void _logInternalDeepLinkOpen(String destination, {String? entityId}) {
    AnalyticsService.instance.logAction('deep_link_open', params: {
      'source': 'internal_value',
      'destination': destination,
      if (entityId != null) 'entity_id': entityId,
    });
  }

  bool _isChatDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'chat' ||
        normalized == 'community-chat' ||
        normalized == 'community/chat' ||
        normalized == '/community/chat';
  }

  bool _isCardCatalogDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'cards' ||
        normalized == 'card-list' ||
        normalized == 'card-catalog' ||
        normalized == 'card/catalog' ||
        normalized == '/card' ||
        normalized == '/cards' ||
        normalized == '/card/catalog';
  }

  bool _isGiftcardDealDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'giftcard-deal' ||
        normalized == 'giftcard-deals' ||
        normalized == 'giftcard-deal-list' ||
        normalized == 'giftcard/special' ||
        normalized == 'giftcard/deals' ||
        normalized == '/giftcard/deals' ||
        normalized == '/giftcard/special';
  }

  bool _isGiftcardCalculatorDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'calculator:giftcard' ||
        normalized == 'giftcard-calculator' ||
        normalized == 'giftcard/calculator' ||
        normalized == '/giftcard/calculator' ||
        normalized == '/giftcard/settlement' ||
        normalized == 'giftcard-settlement';
  }

  bool _isPointStayDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'feature:point-stay' ||
        normalized == 'point-stay' ||
        normalized == 'pointstay' ||
        normalized == 'hotel-point-stay' ||
        normalized == 'hotel/point-stay' ||
        normalized == '/point-stay' ||
        normalized == '/hotel/point-stay';
  }

  bool _isCommunityDestination(String? value) {
    if (value == null) return false;
    final normalized =
        value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    return normalized == 'community' ||
        normalized == 'community-board' ||
        normalized == 'community/board' ||
        normalized == '/community' ||
        normalized == '/community/board';
  }

  String? _communityBoardIdFromLinkValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_isCommunityDestination(trimmed)) return 'all';
    final normalized = trimmed.toLowerCase().replaceAll('_', '-');

    const prefixes = [
      'community:',
      'community-board:',
      'community/board:',
      '/community/board/',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final boardId = trimmed.substring(prefix.length).trim();
        return boardId.isEmpty ? 'all' : boardId;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    String? boardIdFromQuery() {
      final boardId = uri.queryParameters['boardId'] ??
          uri.queryParameters['board'] ??
          uri.queryParameters['tab'] ??
          uri.queryParameters['id'];
      return boardId?.trim().isNotEmpty == true ? boardId!.trim() : null;
    }

    if (host == 'community' || host == 'community-board') {
      final queryBoardId = boardIdFromQuery();
      if (queryBoardId != null) return queryBoardId;
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first.toLowerCase() == 'board') {
        return segments[1].trim().isEmpty ? 'all' : segments[1].trim();
      }
      return 'all';
    }
    if (path == '/community' || path == '/community/board') {
      return boardIdFromQuery() ?? 'all';
    }
    if (uri.pathSegments.length >= 3 &&
        uri.pathSegments[0].toLowerCase() == 'community' &&
        uri.pathSegments[1].toLowerCase() == 'board') {
      final queryBoardId = boardIdFromQuery();
      if (queryBoardId != null) return queryBoardId;
      final board = uri.pathSegments[2].trim();
      return board.isEmpty ? 'all' : board;
    }
    return null;
  }

  String? _giftcardDealIdFromLinkValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.toLowerCase().replaceAll('_', '-');

    const prefixes = [
      'giftcard-deal:',
      'giftcard-deals:',
      'giftcard/deal:',
      '/giftcard/deal/',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final dealId = trimmed.substring(prefix.length).trim();
        return dealId.isEmpty ? null : dealId;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'giftcard-deal' || host == 'giftcard-deals') {
      final dealId = uri.queryParameters['dealId'] ??
          uri.queryParameters['giftcardDealId'] ??
          uri.queryParameters['id'];
      return dealId?.trim().isNotEmpty == true ? dealId!.trim() : null;
    }
    if (path == '/giftcard/deal' || path == '/giftcard/deals/detail') {
      final dealId = uri.queryParameters['dealId'] ??
          uri.queryParameters['giftcardDealId'] ??
          uri.queryParameters['id'];
      return dealId?.trim().isNotEmpty == true ? dealId!.trim() : null;
    }
    return null;
  }

  String? _giftcardRateIdFromLinkValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.toLowerCase().replaceAll('_', '-');

    const prefixes = [
      'giftcard-rate:',
      'giftcard:',
      'rate:',
      'giftcard/rate:',
      '/giftcard/rate/',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final giftcardId = trimmed.substring(prefix.length).trim();
        return giftcardId.isEmpty ? null : giftcardId;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'giftcard' || host == 'giftcard-rate' || host == 'rate') {
      final giftcardId = uri.queryParameters['giftcardId'] ??
          uri.queryParameters['id'] ??
          (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null);
      return giftcardId?.trim().isNotEmpty == true ? giftcardId!.trim() : null;
    }
    if (path == '/giftcard/rate' || path == '/giftcard/rates/detail') {
      final giftcardId =
          uri.queryParameters['giftcardId'] ?? uri.queryParameters['id'];
      return giftcardId?.trim().isNotEmpty == true ? giftcardId!.trim() : null;
    }
    return null;
  }

  String? _cardIdFromLinkValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.toLowerCase().replaceAll('_', '-');

    const prefixes = [
      'card:',
      'card-detail:',
      'cards:',
      'card/detail:',
      '/card/detail/',
      '/cards/',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final cardId = trimmed.substring(prefix.length).trim();
        return cardId.isEmpty ? null : cardId;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final path = uri.path;
    if (host == 'card' || host == 'cards') {
      final cardId = uri.queryParameters['cardId'] ??
          uri.queryParameters['id'] ??
          (path.length > 1 ? path.substring(1) : null);
      return cardId?.trim().isNotEmpty == true ? cardId!.trim() : null;
    }
    if (path.toLowerCase() == '/card/detail' ||
        path.toLowerCase() == '/cards/detail') {
      final cardId = uri.queryParameters['cardId'] ?? uri.queryParameters['id'];
      return cardId?.trim().isNotEmpty == true ? cardId!.trim() : null;
    }
    return null;
  }

  String? _chatRoomIdFromLinkValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.toLowerCase().replaceAll('_', '-');

    if (normalized == 'chat' ||
        normalized == 'community-chat' ||
        normalized == 'community/chat' ||
        normalized == '/community/chat') {
      return 'global';
    }

    const prefixes = [
      'chat:',
      'community-chat:',
      'community/chat:',
      '/community/chat/',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final roomId = trimmed.substring(prefix.length).trim();
        return roomId.isEmpty ? 'global' : roomId;
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.host.toLowerCase() == 'chat') {
      return uri.queryParameters['roomId']?.trim().isNotEmpty == true
          ? uri.queryParameters['roomId']!.trim()
          : 'global';
    }
    if (uri.host.toLowerCase() == 'community' &&
        uri.path.toLowerCase() == '/chat') {
      return uri.queryParameters['roomId']?.trim().isNotEmpty == true
          ? uri.queryParameters['roomId']!.trim()
          : 'global';
    }
    if (uri.path.toLowerCase() == '/community/chat') {
      return uri.queryParameters['roomId']?.trim().isNotEmpty == true
          ? uri.queryParameters['roomId']!.trim()
          : 'global';
    }
    return null;
  }

  /// 게시글로 이동
  void _navigateToPost(String postId, String dateString, String boardId,
      String boardName, String? scrollToCommentId) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => CommunityDetailScreen(
            postId: postId,
            dateString: dateString,
            boardId: boardId,
            boardName: boardName,
            scrollToCommentId: scrollToCommentId,
          ),
        ),
      );
    }
  }

  void _navigateToChat(
    String roomId, {
    BuildContext? context,
  }) {
    final screen = CommunityChatScreen(roomId: roomId);
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToBranch(
    String branchId, {
    BuildContext? context,
  }) {
    final screen = BranchDetailScreen(branchId: branchId);
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToCards({
    BuildContext? context,
  }) {
    if (context != null) {
      Navigator.of(context).pushNamed('/cards');
      return;
    }
    navigatorKey.currentState?.pushNamed('/cards');
  }

  void _navigateToCard(
    String cardId, {
    BuildContext? context,
  }) {
    final arguments = {'cardId': cardId};
    if (context != null) {
      Navigator.of(context).pushNamed('/card/detail', arguments: arguments);
      return;
    }
    navigatorKey.currentState?.pushNamed('/card/detail', arguments: arguments);
  }

  void _navigateToGiftcardRate(
    String giftcardId, {
    BuildContext? context,
  }) {
    final screen = GiftcardBrandRatesPage(
      giftcardId: giftcardId,
      giftcardName: giftcardId,
    );
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToGiftcardCalculator({
    BuildContext? context,
  }) {
    final screen = Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('상품권 계산'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: const SafeArea(child: GiftcardSettlementScreen()),
    );
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToGiftcardDeal(
    String dealId, {
    BuildContext? context,
  }) {
    final screen = GiftcardDealDetailScreen(dealId: dealId);
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToGiftcardDealList({
    BuildContext? context,
  }) {
    final screen = Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('상품권 특가'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: const SafeArea(child: GiftcardDealsScreen()),
    );
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToPointStay({
    BuildContext? context,
  }) {
    const screen = PointStayScreen();
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  String _communityBoardNameFor(String boardId, String? providedName) {
    final trimmedName = providedName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;

    const names = {
      'all': '전체글',
      'free': '자유게시판',
      'deal': '적립/카드 혜택',
      'milecatch_guide': '마일캐치 사용법',
      'hotdeal': '핫딜',
      'hot_deal': '핫딜',
      'question': '마일리지',
      'seats': '오늘의 좌석',
      'news': '오늘의 뉴스',
      'aeroroute_news': 'AeroRoutes',
      'secretflying_news': 'SecretFlying',
      'workingholiday_news': '워킹홀리데이',
      'suggestion': '건의사항',
      'notice': '운영 공지사항',
    };
    return names[boardId] ?? boardId;
  }

  void _navigateToCommunityBoard(
    String boardId, {
    String? boardName,
    BuildContext? context,
  }) {
    final trimmedBoardId = boardId.trim();
    final normalizedBoardId = trimmedBoardId.isEmpty
        ? 'all'
        : trimmedBoardId == 'hot_deal'
            ? 'hotdeal'
            : trimmedBoardId;
    final screen = CommunityScreen(
      initialBoardId: normalizedBoardId,
      initialBoardName: _communityBoardNameFor(normalizedBoardId, boardName),
    );

    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// 콘테스트로 이동
  void _navigateToContest(String contestId) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ContestDetailScreen(
            contestId: contestId,
          ),
        ),
      );
    }
  }

  /// 게시글 공유 링크 생성
  Future<String?> createPostShareLink({
    required String postId,
    required String dateString,
    required String boardId,
    required String boardName,
    String? scrollToCommentId,
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'post_$postId',
        title: title ?? '마일캐치 게시글',
        contentDescription: description ?? '마일리지 커뮤니티의 게시글을 확인해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('postId', postId)
          ..addCustomMetadata('dateString', dateString)
          ..addCustomMetadata('boardId', boardId)
          ..addCustomMetadata('boardName', boardName),
      );

      if (scrollToCommentId != null) {
        buo.contentMetadata
            ?.addCustomMetadata('scrollToCommentId', scrollToCommentId);
      }

      final lp = BranchLinkProperties(
        channel: 'community',
        feature: 'sharing',
        campaign: 'post_share',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 링크 생성 성공: ${response.result}');
        return response.result;
      } else {
        debugPrint('Branch 링크 생성 실패: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('Branch 링크 생성 오류: $e');
      return null;
    }
  }

  /// 카드 상세 공유 링크 생성
  Future<String?> createCardShareLink({
    required String cardId,
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'card_$cardId',
        title: title ?? '마일캐치 카드',
        contentDescription: description ?? '마일캐치 카드 정보를 확인해보세요!',
        imageUrl: imageUrl ?? '',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('cardId', cardId)
          ..addCustomMetadata('destination', 'card')
          ..addCustomMetadata('screen', 'card_detail')
          ..addCustomMetadata('path', '/card/detail')
          ..addCustomMetadata('linkValue', 'card:$cardId'),
      );

      final lp = BranchLinkProperties(
        channel: 'card',
        feature: 'sharing',
        campaign: 'card_share',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 카드 링크 생성 성공: ${response.result}');
        return response.result;
      }
      debugPrint('Branch 카드 링크 생성 실패: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Branch 카드 링크 생성 오류: $e');
      return null;
    }
  }

  /// 카드 목록 딥링크 생성
  Future<String?> createCardCatalogLink({
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'cards',
        title: title ?? '마일캐치 카드',
        contentDescription: description ?? '마일캐치 카드 혜택 DB를 확인해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('destination', 'cards')
          ..addCustomMetadata('screen', 'card_catalog')
          ..addCustomMetadata('path', '/cards')
          ..addCustomMetadata('linkValue', 'cards'),
      );

      final lp = BranchLinkProperties(
        channel: 'card',
        feature: 'deeplink',
        campaign: 'card_catalog',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 카드 목록 링크 생성 성공: ${response.result}');
        return response.result;
      }
      debugPrint('Branch 카드 목록 링크 생성 실패: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Branch 카드 목록 링크 생성 오류: $e');
      return null;
    }
  }

  /// 상품권 특가 공유 링크 생성
  Future<String?> createGiftcardDealShareLink({
    required String dealId,
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'giftcard_deal_$dealId',
        title: title ?? '마일캐치 상품권 특가',
        contentDescription: description ?? '상품권 특가와 할인율을 확인해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('giftcardDealId', dealId)
          ..addCustomMetadata('dealId', dealId)
          ..addCustomMetadata('destination', 'giftcard-deal')
          ..addCustomMetadata('screen', 'giftcard_deal')
          ..addCustomMetadata('path', '/giftcard/deal')
          ..addCustomMetadata('linkValue', 'giftcard-deal:$dealId'),
      );

      final lp = BranchLinkProperties(
        channel: 'giftcard',
        feature: 'sharing',
        campaign: 'giftcard_deal_share',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 상품권 특가 링크 생성 성공: ${response.result}');
        return response.result;
      }
      debugPrint('Branch 상품권 특가 링크 생성 실패: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Branch 상품권 특가 링크 생성 오류: $e');
      return null;
    }
  }

  /// 채팅방 딥링크 생성
  Future<String?> createChatLink({
    String roomId = 'global',
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'chat_$roomId',
        title: title ?? '마일캐치 채팅',
        contentDescription: description ?? '마일캐치 실시간 채팅에서 정보를 확인해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('destination', 'chat')
          ..addCustomMetadata('screen', 'chat')
          ..addCustomMetadata('linkValue', 'chat:$roomId')
          ..addCustomMetadata('roomId', roomId),
      );

      final lp = BranchLinkProperties(
        channel: 'guide',
        feature: 'deeplink',
        campaign: 'community_chat',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 채팅 링크 생성 성공: ${response.result}');
        return response.result;
      } else {
        debugPrint('Branch 채팅 링크 생성 실패: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('Branch 채팅 링크 생성 오류: $e');
      return null;
    }
  }

  /// 공유 시트 표시
  Future<void> showShareSheet({
    required String postId,
    required String dateString,
    required String boardId,
    required String boardName,
    String? scrollToCommentId,
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'post_$postId',
        title: title ?? '마일캐치 게시글',
        contentDescription: description ?? '마일리지 커뮤니티의 게시글을 확인해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('postId', postId)
          ..addCustomMetadata('dateString', dateString)
          ..addCustomMetadata('boardId', boardId)
          ..addCustomMetadata('boardName', boardName),
      );

      if (scrollToCommentId != null) {
        buo.contentMetadata
            ?.addCustomMetadata('scrollToCommentId', scrollToCommentId);
      }

      final lp = BranchLinkProperties(
        channel: 'community',
        feature: 'sharing',
        campaign: 'post_share',
      );

      final response = await FlutterBranchSdk.showShareSheet(
        buo: buo,
        linkProperties: lp,
        messageText: '마일캐치에서 흥미로운 게시글을 발견했어요!',
        androidMessageTitle: '게시글 공유',
        androidSharingTitle: '공유하기',
      );

      debugPrint('공유 시트 결과: $response');
    } catch (e) {
      debugPrint('공유 시트 오류: $e');
    }
  }

  /// 콘테스트 공유 링크 생성
  Future<String?> createContestShareLink({
    required String contestId,
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'contest_$contestId',
        title: title ?? '마일캐치 콘테스트',
        contentDescription: description ?? '마일리지 커뮤니티의 콘테스트에 참여해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('contestId', contestId),
      );

      final lp = BranchLinkProperties(
        channel: 'contest',
        feature: 'sharing',
        campaign: 'contest_share',
      );

      final response = await FlutterBranchSdk.getShortUrl(
        buo: buo,
        linkProperties: lp,
      );

      if (response.success) {
        debugPrint('Branch 콘테스트 링크 생성 성공: ${response.result}');
        return response.result;
      } else {
        debugPrint('Branch 콘테스트 링크 생성 실패: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('Branch 콘테스트 링크 생성 오류: $e');
      return null;
    }
  }

  /// 콘테스트 공유 시트 표시
  Future<void> showContestShareSheet({
    required String contestId,
    String? title,
    String? description,
  }) async {
    try {
      final buo = BranchUniversalObject(
        canonicalIdentifier: 'contest_$contestId',
        title: title ?? '마일캐치 콘테스트',
        contentDescription: description ?? '마일리지 커뮤니티의 콘테스트에 참여해보세요!',
        contentMetadata: BranchContentMetaData()
          ..addCustomMetadata('contestId', contestId),
      );

      final lp = BranchLinkProperties(
        channel: 'contest',
        feature: 'sharing',
        campaign: 'contest_share',
      );

      final response = await FlutterBranchSdk.showShareSheet(
        buo: buo,
        linkProperties: lp,
        messageText: '마일캐치에서 흥미로운 콘테스트를 발견했어요!',
        androidMessageTitle: '콘테스트 공유',
        androidSharingTitle: '공유하기',
      );

      debugPrint('콘테스트 공유 시트 결과: $response');
    } catch (e) {
      debugPrint('콘테스트 공유 시트 오류: $e');
    }
  }
}
