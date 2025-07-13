import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  // 캐시된 카테고리 데이터
  List<Map<String, dynamic>>? _cachedBoards;
  bool _isLoading = false;

  /// 카테고리 데이터를 로드합니다. 캐시된 데이터가 있으면 반환하고, 없으면 서버에서 로드합니다.
  Future<List<Map<String, dynamic>>> getBoards() async {
    if (kDebugMode) {
      print('_cachedBoards: $_cachedBoards개');
    }
    if (_cachedBoards != null) {
      return _cachedBoards!;
    }

    if (_isLoading) {
      // 이미 로딩 중이면 완료될 때까지 대기
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedBoards ?? [];
    }

    _isLoading = true;
    
    try {
      final snapshot = await _database.child('CATEGORIES/boards').get();
      
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        _cachedBoards = data.values.map((board) => Map<String, dynamic>.from(board)).toList();
        
        // order 필드로 정렬
        _cachedBoards!.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        
        if (kDebugMode) {
          print('카테고리 데이터 로드 완료: ${_cachedBoards!.length}개');
        }
      } else {
        // 서버 데이터가 없으면 기본값 사용
        _cachedBoards = _getDefaultBoards();
        if (kDebugMode) {
          print('서버 데이터 없음, 기본 카테고리 사용');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('카테고리 데이터 로드 실패: $e');
      }
      // 에러 발생 시 기본값 사용
      _cachedBoards = _getDefaultBoards();
    } finally {
      _isLoading = false;
    }

    return _cachedBoards!;
  }

  /// 캐시를 초기화합니다. 앱 재시작이나 강제 새로고침 시 사용
  void clearCache() {
    _cachedBoards = null;
    _isLoading = false;
  }

  /// boardId로 카테고리 이름을 가져옵니다
  Future<String> getBoardName(String boardId) async {
    final boards = await getBoards();
    final board = boards.firstWhere(
      (board) => board['id'] == boardId,
      orElse: () => {'name': '알 수 없음'},
    );
    return board['name'] ?? '알 수 없음';
  }

  /// 기본 카테고리 데이터 (서버 연결 실패 시 사용)
  List<Map<String, dynamic>> _getDefaultBoards() {
    return const [
      {'id': 'question', 'name': '마일리지', 'group': '마일리지/혜택', 'description': '마일리지, 항공사 정책, 발권 문의 등', 'order': 1},
      {'id': 'deal', 'name': '적립/카드 혜택', 'group': '마일리지/혜택', 'description': '상테크, 카드 추천, 이벤트 정보', 'order': 2},
      {'id': 'seat_share', 'name': '좌석 공유', 'group': '마일리지/혜택', 'description': '좌석 오픈 알림, 취소표 공유', 'order': 3},
      {'id': 'review', 'name': '항공 리뷰', 'group': '여행/리뷰', 'description': '라운지, 기내식, 좌석 후기 등', 'order': 4},
      {'id': 'free', 'name': '자유게시판', 'group': '여행/리뷰', 'description': '일상, 후기, 질문 섞인 잡담', 'order': 5},
      {'id': 'error_report', 'name': '오류 신고', 'group': '운영/소통', 'description': '앱/서비스 오류 제보', 'order': 6},
      {'id': 'suggestion', 'name': '건의사항', 'group': '운영/소통', 'description': '사용자 의견, 개선 요청', 'order': 7},
      {'id': 'notice', 'name': '운영 공지사항', 'group': '운영/소통', 'description': '관리자 공지, 업데이트 안내', 'order': 8},
    ];
  }
} 