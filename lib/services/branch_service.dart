import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screen/community_detail_screen.dart';
import '../screen/contest_detail_screen.dart';

class BranchService {
  static final BranchService _instance = BranchService._internal();
  factory BranchService() => _instance;
  BranchService._internal();

  /// Branch SDK 초기화
  Future<void> initialize() async {
    try {
      await FlutterBranchSdk.init(
        enableLogging: true,
        disableTracking: false,
      );
      
      print('Branch SDK 초기화 완료');
      
      // 딥링크 리스너 설정
      _setupDeepLinkListener();
      
      // 초기 딥링크 처리 (앱이 종료된 상태에서 딥링크로 실행된 경우)
      _handleInitialDeepLink();
      
    } catch (e) {
      print('Branch SDK 초기화 오류: $e');
    }
  }

  /// 딥링크 리스너 설정
  void _setupDeepLinkListener() {
    FlutterBranchSdk.listSession().listen((data) {
      print('Branch 딥링크 수신: $data');
      _handleDeepLinkData(data);
    }, onError: (error) {
      print('Branch 딥링크 오류: $error');
    });
  }

  /// 초기 딥링크 처리
  Future<void> _handleInitialDeepLink() async {
    try {
      final data = await FlutterBranchSdk.getFirstReferringParams();
      if (data.isNotEmpty) {
        print('초기 딥링크 데이터: $data');
        
        // getFirstReferringParams는 앱 설치 후 첫 번째 링크를 계속 저장하므로
        // 실제 새로운 클릭인지 확인 (최근 클릭만 처리)
        final clickTimestamp = data['+click_timestamp'];
        if (clickTimestamp != null) {
          final clickTime = DateTime.fromMillisecondsSinceEpoch(clickTimestamp * 1000);
          final now = DateTime.now();
          final difference = now.difference(clickTime);
          
          // 30초 이내의 클릭만 처리 (앱이 딥링크로 실행된 경우)
          if (difference.inSeconds <= 30) {
            print('최근 딥링크 클릭 감지 (${difference.inSeconds}초 전) - 처리함');
            _handleDeepLinkData(data);
          } else {
            print('오래된 딥링크 데이터 무시 (${difference.inMinutes}분 전)');
          }
        } else {
          print('클릭 타임스탬프 없음 - 무시');
        }
      }
    } catch (e) {
      print('초기 딥링크 처리 오류: $e');
    }
  }

  /// 딥링크 데이터 처리
  void _handleDeepLinkData(Map<dynamic, dynamic> data) {
    // Branch 링크를 실제로 클릭했는지 확인
    final clickedBranchLink = data['+clicked_branch_link'];
    
    // 실제 딥링크 클릭이 아니면 처리하지 않음
    if (clickedBranchLink != true) {
      print('Branch 초기화 콜백 (딥링크 클릭 아님): $data');
      return;
    }
    
    // 콘테스트 딥링크 처리
    final contestId = data['contestId']?.toString();
    if (contestId != null) {
      print('실제 딥링크 클릭 감지 - 콘테스트로 이동: $contestId');
      _navigateToContest(contestId);
      return;
    }
    
    // 게시글 딥링크 처리
    final postId = data['postId']?.toString();
    final dateString = data['dateString']?.toString();
    final boardId = data['boardId']?.toString() ?? 'free';
    final boardName = data['boardName']?.toString() ?? '자유게시판';
    final scrollToCommentId = data['scrollToCommentId']?.toString();

    if (postId != null && dateString != null) {
      print('실제 딥링크 클릭 감지 - 게시글로 이동: $postId');
      _navigateToPost(postId, dateString, boardId, boardName, scrollToCommentId);
    } else {
      print('딥링크 데이터 부족: postId=$postId, dateString=$dateString');
    }
  }

  /// 게시글로 이동
  void _navigateToPost(String postId, String dateString, String boardId, String boardName, String? scrollToCommentId) {
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
        buo.contentMetadata?.addCustomMetadata('scrollToCommentId', scrollToCommentId);
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
        print('Branch 링크 생성 성공: ${response.result}');
        return response.result;
      } else {
        print('Branch 링크 생성 실패: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      print('Branch 링크 생성 오류: $e');
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
        buo.contentMetadata?.addCustomMetadata('scrollToCommentId', scrollToCommentId);
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

      print('공유 시트 결과: $response');
    } catch (e) {
      print('공유 시트 오류: $e');
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
        print('Branch 콘테스트 링크 생성 성공: ${response.result}');
        return response.result;
      } else {
        print('Branch 콘테스트 링크 생성 실패: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      print('Branch 콘테스트 링크 생성 오류: $e');
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

      print('콘테스트 공유 시트 결과: $response');
    } catch (e) {
      print('콘테스트 공유 시트 오류: $e');
    }
  }
} 