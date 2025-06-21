import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'community_detail_screen.dart';
import 'community_post_create_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 게시판 목록 (md파일 boards 표 기반, 아이콘 포함)
  final List<Map<String, dynamic>> boards = [
    {'id': 'question', 'name': '마일리지'},
    {'id': 'deal', 'name': '적립/카드 혜택'},
    {'id': 'seat_share', 'name': '좌석 공유'},
    {'id': 'review', 'name': '항공 리뷰'},
    {'id': 'error_report', 'name': '오류 신고'},
    {'id': 'suggestion', 'name': '건의사항'},
    {'id': 'free', 'name': '자유게시판'},
    {'id': 'notice', 'name': '운영 공지사항'},
    {'id': 'popular', 'name': '인기글 모음'},
  ];

  String selectedBoardId = 'all';
  String selectedBoardName = '전체글';
  Map<String, dynamic>? userProfile;
  bool isProfileLoading = false;
  
  // 무한 스크롤 관련 변수
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final int _postsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = AuthService.currentUser;
    if (user != null) {
      setState(() { isProfileLoading = true; });
      final data = await UserService.getUserFromFirestore(user.uid);
      setState(() {
        userProfile = data;
        isProfileLoading = false;
      });
    } else {
      setState(() {
        userProfile = null;
        isProfileLoading = false;
      });
    }
  }

  IconData getBoardIcon(String boardId) {
    switch (boardId) {
      case 'question': return Icons.help_outline;
      case 'deal': return Icons.card_giftcard;
      case 'seat_share': return Icons.event_seat;
      case 'review': return Icons.rate_review;
      case 'error_report': return Icons.bug_report;
      case 'suggestion': return Icons.lightbulb_outline;
      case 'free': return Icons.chat_bubble_outline;
      case 'notice': return Icons.campaign;
      case 'popular': return Icons.star_border;
      default: return Icons.list;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white,
                  child: StatefulBuilder(
                    builder: (context, setDrawerState) {
                      final user = AuthService.currentUser;
                      if (user == null) {
                        return GestureDetector(
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                            if (result == true) {
                              await _loadUserProfile();
                              setDrawerState(() {});
                            }
                          },
                          child: const Text(
                            '로그인 해주세요',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        );
                      } else if (isProfileLoading) {
                        return const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      } else if (userProfile != null) {
                        final displayName = userProfile!['displayName'] ?? '사용자';
                        final displayGrade = userProfile!['displayGrade'] ?? '이코노미 Lv.1';
                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              radius: 18,
                              child: const Icon(Icons.person, color: Colors.black, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                                Text('등급: $displayGrade', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                          ],
                        );
                      } else {
                        return const Text(
                          '정보를 불러올 수 없습니다',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                        );
                      }
                    },
                  ),
                ),
                Container(
                  decoration: selectedBoardId == 'all'
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB2F7EF), Color(0xFF051667)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        )
                      : null,
                  child: ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(
                      Icons.list,
                      color: selectedBoardId == 'all' ? Colors.white : Colors.black54,
                    ),
                    title: Text(
                      '전체글',
                      style: TextStyle(
                        color: selectedBoardId == 'all' ? Colors.white : Colors.black87,
                        fontWeight: selectedBoardId == 'all' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selectedBoardId == 'all',
                    onTap: () {
                      setState(() {
                        selectedBoardId = 'all';
                        selectedBoardName = '전체글';
                      });
                      Navigator.pop(context);
                      _refreshPosts();
                    },
                  ),
                ),
                ...boards.map((board) =>
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: selectedBoardId == board['id']
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB2F7EF), Color(0xFF425EB2)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          )
                        : null,
                    child: ListTile(
                      leading: Icon(
                        getBoardIcon(board['id'] as String),
                        color: selectedBoardId == board['id'] ? Colors.white : Colors.black54,
                      ),
                      title: Text(
                        board['name']!,
                        style: TextStyle(
                          color: selectedBoardId == board['id'] ? Colors.white : Colors.black87,
                          fontWeight: selectedBoardId == board['id'] ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: selectedBoardId == board['id'],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: Colors.transparent,
                      onTap: () {
                        setState(() {
                          selectedBoardId = board['id']!;
                          selectedBoardName = board['name']!;
                        });
                        Navigator.pop(context);
                        _refreshPosts();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 카테고리/검색/공지 바
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB2F7EF), Color(0xFF425EB2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Text(
                        selectedBoardName,
                        style: const TextStyle(
                          color: Colors.black54, // 민트~블루 계열 텍스트
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.black),
                      onPressed: () {
                        // TODO: 검색 기능 구현
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 본문 영역
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshPosts();
              },
              child: _posts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        // 로딩 인디케이터 표시
                        if (index == _posts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final post = _posts[index].data() as Map<String, dynamic>;
                        final createdAt = (post['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                    // HTML 태그 제거해서 미리보기 텍스트 만들기
                    String plainText = _removeHtmlTags(post['contentHtml'] ?? '');

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          // 게시글 조회수 증가
                          _incrementViewCount(_posts[index].id, _posts[index].reference.parent.parent!.id);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommunityDetailScreen(
                                boardId: post['boardId'] ?? '',
                                boardName: _getBoardName(post['boardId'] ?? ''),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF8FAFF), // 연한 파랑-하양
                                Color(0xFFFDF6FF), // 연한 보라-하양
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 프로필 영역 (프로필 이미지, 닉네임, 시간)
                              Row(
                                children: [
                                  // 프로필 이미지
                                  CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    radius: 20,
                                    backgroundImage: (post['author']['photoURL'] != null && post['author']['photoURL'].toString().isNotEmpty)
                                        ? NetworkImage(post['author']['photoURL'])
                                        : null,
                                    child: (post['author']['photoURL'] == null || post['author']['photoURL'].toString().isEmpty)
                                        ? const Icon(Icons.person, color: Colors.black54, size: 22)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  // 닉네임
                                  Expanded(
                                    child: Text(
                                      post['author']['displayName'] ?? '익명',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // 시간
                                  Text(
                                    _formatTime(createdAt),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // 제목 (굵게)
                              Text(
                                post['title'] ?? '제목 없음',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              
                              // contentHtml 텍스트로만 1줄
                              if (plainText.isNotEmpty)
                                Text(
                                  plainText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 12),
                              
                              // 조회수, 댓글, 좋아요
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '조회 ${post['viewsCount'] ?? 0}회',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.mode_comment_outlined, size: 16, color: Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post['commentCount'] ?? 0}',
                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.favorite_border, size: 16, color: Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post['likesCount'] ?? 0}',
                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                      },
                    ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 현재 선택된 게시판이 'all'이 아닌 경우 초기값으로 전달
          if (selectedBoardId != 'all') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityPostCreateScreen(
                  initialBoardId: selectedBoardId,
                  initialBoardName: selectedBoardName,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunityPostCreateScreen()),
            );
          }
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  // 스크롤 리스너
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMorePosts();
      }
    }
  }

  // 초기 게시글 로드
  Future<void> _loadInitialPosts() async {
    try {
      Query query = _getQuery();
      query = query.limit(_postsPerPage);
      
      final querySnapshot = await query.get();
      
      setState(() {
        _posts = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isHidden'] != true;
        }).toList();
        
        if (_posts.isNotEmpty) {
          _lastDocument = _posts.last;
        }
        _hasMoreData = _posts.length == _postsPerPage;
      });
    } catch (e) {
      print('초기 게시글 로드 오류: $e');
    }
  }

  // 더 많은 게시글 로드
  Future<void> _loadMorePosts() async {
    if (_lastDocument == null || _isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _getQuery();
      query = query.startAfterDocument(_lastDocument!);
      query = query.limit(_postsPerPage);
      
      final querySnapshot = await query.get();
      final newPosts = querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isHidden'] != true;
      }).toList();
      
      setState(() {
        _posts.addAll(newPosts);
        if (newPosts.isNotEmpty) {
          _lastDocument = newPosts.last;
        }
        _hasMoreData = newPosts.length == _postsPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('추가 게시글 로드 오류: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // 쿼리 생성
  Query _getQuery() {
    Query query = FirebaseFirestore.instance.collectionGroup('posts');
    
    if (selectedBoardId != 'all') {
      query = query.where('boardId', isEqualTo: selectedBoardId);
      query = query.where('isDeleted', isEqualTo: false);
    } else {
      query = query.where('isDeleted', isEqualTo: false);
    }
    
    query = query.orderBy('createdAt', descending: true);
    
    return query;
  }

  // 게시판 변경 시 데이터 새로고침
  void _refreshPosts() {
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _isLoadingMore = false;
    });
    _loadInitialPosts();
  }

  // HTML 태그 제거
  String _removeHtmlTags(String htmlString) {
    // 간단한 HTML 태그 제거 (정규식 사용)
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[^;]+;'), '')
        .trim();
  }

  // boardId로 게시판 이름 가져오기
  String _getBoardName(String boardId) {
    try {
      return boards.firstWhere((board) => board['id'] == boardId)['name'] ?? '알 수 없음';
    } catch (e) {
      return '알 수 없음';
    }
  }

  // 게시글 조회수 증가
  Future<void> _incrementViewCount(String postId, String dateString) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(dateString)
          .collection('posts')
          .doc(postId)
          .update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('조회수 증가 오류: $e');
      // 조회수 증가 실패해도 앱이 멈추지 않도록 에러를 무시
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM/dd').format(dateTime);
  }
} 