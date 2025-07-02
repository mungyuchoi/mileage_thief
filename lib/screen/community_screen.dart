import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'community_detail_screen.dart';
import 'community_post_create_screen.dart';
import 'community_search_screen.dart';
import 'my_page_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 게시판 목록 (md파일 boards 표 기반, 아이콘 포함)
  final List<Map<String, dynamic>> boards = [
    {'id': 'free', 'name': '자유게시판'},
    {'id': 'question', 'name': '마일리지'},
    {'id': 'deal', 'name': '적립/카드 혜택'},
    {'id': 'seat_share', 'name': '좌석 공유'},
    {'id': 'review', 'name': '항공 리뷰'},
    {'id': 'error_report', 'name': '오류 신고'},
    {'id': 'suggestion', 'name': '건의사항'},
    {'id': 'notice', 'name': '운영 공지사항'}
  ];

  String selectedBoardId = 'all';
  String selectedBoardName = '전체글';
  Map<String, dynamic>? userProfile;
  bool isProfileLoading = false;
  
  // 뷰 모드 토글 (false: 카드뷰, true: 간단뷰)
  bool isCompactView = false;

  // 무한 스크롤 관련 변수
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final int _postsPerPage = 20;
  
  // 초기 로딩 상태 관리
  bool _isInitialLoading = true;

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
      setState(() {
        isProfileLoading = true;
      });
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
      case 'question':
        return Icons.help_outline;
      case 'deal':
        return Icons.card_giftcard;
      case 'seat_share':
        return Icons.event_seat;
      case 'review':
        return Icons.rate_review;
      case 'error_report':
        return Icons.bug_report;
      case 'suggestion':
        return Icons.lightbulb_outline;
      case 'free':
        return Icons.chat_bubble_outline;
      case 'notice':
        return Icons.campaign;
      case 'popular':
        return Icons.star_border;
      default:
        return Icons.list;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF74512D),
                          ),
                        );
                      } else if (userProfile != null) {
                        final displayName =
                            userProfile!['displayName'] ?? '사용자';
                        final displayGrade =
                            userProfile!['displayGrade'] ?? '이코노미 Lv.1';
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // drawer 닫기
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyPageScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Builder(
                                builder: (context) {
                                  // 사용자 프로필에서 photoURL 가져오기 (fallback 포함)
                                  final photoURL = userProfile!['photoURL'] ?? '';
                                  
                                  return CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    radius: 18,
                                    backgroundImage: photoURL.isNotEmpty
                                        ? NetworkImage(photoURL)
                                        : null,
                                    child: photoURL.isEmpty
                                        ? const Icon(Icons.person,
                                            color: Colors.black, size: 20)
                                        : null,
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black)),
                                  Text('등급: $displayGrade',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        return const Text(
                          '정보를 불러올 수 없습니다',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red),
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
                            colors: [Color(0xFFFFF8DC), Color(0xFF74512D)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        )
                      : null,
                  child: ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(
                      Icons.list,
                      color: selectedBoardId == 'all'
                          ? Colors.white
                          : Colors.black54,
                    ),
                    title: Text(
                      '전체글',
                      style: TextStyle(
                        color: selectedBoardId == 'all'
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: selectedBoardId == 'all'
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                ...boards.map(
                  (board) => Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: selectedBoardId == board['id']
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF8DC), Color(0xFF74512D)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          )
                        : null,
                    child: ListTile(
                      leading: Icon(
                        getBoardIcon(board['id'] as String),
                        color: selectedBoardId == board['id']
                            ? Colors.white
                            : Colors.black54,
                      ),
                      title: Text(
                        board['name']!,
                        style: TextStyle(
                          color: selectedBoardId == board['id']
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: selectedBoardId == board['id']
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: selectedBoardId == board['id'],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                colors: [Color(0xFFFFF8DC), Color(0xFF74512D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.brown),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Text(
                        selectedBoardName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 프로필 이미지 (로그인 상태일 때만 표시)
                    if (AuthService.currentUser != null && userProfile != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyPageScreen(),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                backgroundImage: userProfile!['photoURL'] != null &&
                                    userProfile!['photoURL'].toString().isNotEmpty
                                    ? NetworkImage(userProfile!['photoURL'])
                                    : null,
                                child: userProfile!['photoURL'] == null ||
                                    userProfile!['photoURL'].toString().isEmpty
                                    ? const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.grey,
                                )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 뷰 모드 토글 버튼
                    IconButton(
                      icon: Icon(
                        isCompactView ? Icons.view_module : Icons.view_list,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          isCompactView = !isCompactView;
                        });
                      },
                      tooltip: isCompactView ? '카드뷰로 보기' : '간단뷰로 보기',
                    ),
                    // 검색 버튼
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CommunitySearchScreen(),
                          ),
                        );
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
              color: const Color(0xFF74512D),
              onRefresh: () async {
                _refreshPosts();
              },
              child: _isInitialLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF74512D),
                      ),
                    )
                  : _posts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.post_add_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '게시글이 없습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '첫 번째 게시글을 작성해보세요!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          isCompactView ? const SizedBox.shrink() : const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        // 로딩 인디케이터 표시
                        if (index == _posts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF74512D),
                              ),
                            ),
                          );
                        }

                        final post =
                            _posts[index].data() as Map<String, dynamic>;
                        final createdAt =
                            (post['createdAt'] as Timestamp?)?.toDate() ??
                                DateTime.now();

                        // HTML 태그 제거해서 미리보기 텍스트 만들기
                        String plainText =
                            _removeHtmlTags(post['contentHtml'] ?? '');

                        // 뷰 모드에 따라 다른 위젯 반환
                        if (isCompactView) {
                          return _buildCompactListItem(post, createdAt, index);
                        }

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 1.5,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              // 게시글 조회수 증가
                              _incrementViewCount(_posts[index].id,
                                  _posts[index].reference.parent.parent!.id);

                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommunityDetailScreen(
                                    postId: _posts[index].id,
                                    boardId: post['boardId'] ?? '',
                                    boardName: _getBoardName(post['boardId'] ?? ''),
                                    dateString: _posts[index].reference.parent.parent!.id,
                                  ),
                                ),
                              );
                              
                              // 게시글 수정/삭제가 있었으면 목록 새로고침
                              if (result == true) {
                                _refreshPosts();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 프로필 영역 (프로필 이미지, 닉네임, 시간)
                                  _buildCardAuthorRow(post),
                                  const SizedBox(height: 12),

                                  // 제목 (굵게) + 최신 키워드
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          post['title'] ?? '제목 없음',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: Colors.black,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // 최신 키워드 (2시간 이내)
                                      if (DateTime.now().difference(createdAt).inHours < 2)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '최신',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          const Icon(
                                              Icons.comment,
                                              size: 16,
                                              color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post['commentCount'] ?? 0}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54),
                                          ),
                                          const SizedBox(width: 16),
                                          const Icon(Icons.favorite_border,
                                              size: 16, color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post['likesCount'] ?? 0}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 현재 선택된 게시판이 'all'이 아닌 경우 초기값으로 전달
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => selectedBoardId != 'all'
                  ? CommunityPostCreateScreen(
                      initialBoardId: selectedBoardId,
                      initialBoardName: selectedBoardName,
                    )
                  : const CommunityPostCreateScreen(),
            ),
          );
          
          // 게시글 작성이 완료되면 목록 새로고침
          if (result == true || result == false) {
            _refreshPosts();
          }
        },
        backgroundColor: const Color(0xFF74512D),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  // 스크롤 리스너
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMorePosts();
      }
    }
  }

  // 초기 게시글 로드
  Future<void> _loadInitialPosts() async {
    try {
      setState(() {
        _isInitialLoading = true;
      });

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
        _isInitialLoading = false; // 로딩 완료
      });
    } catch (e) {
      print('초기 게시글 로드 오류: $e');
      setState(() {
        _isInitialLoading = false; // 오류 발생 시에도 로딩 상태 해제
      });
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
      _isInitialLoading = true; // 새로고침 시 로딩 상태 활성화
    });
    _loadInitialPosts();
  }

  // HTML 태그 제거 (<br> 태그 전까지만 추출)
  String _removeHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    // <br> 태그가 나오기 전까지의 HTML만 추출
    String beforeBr = htmlString.split(RegExp(r'<br\s*/?>', caseSensitive: false))[0];
    
    // HTML 태그 제거
    String cleaned = beforeBr
        .replaceAll(RegExp(r'<[^>]*>'), '') // 모든 HTML 태그 제거
        .replaceAll(RegExp(r'&[^;]+;'), '') // HTML 엔티티 제거
        .trim();
    
    return cleaned;
  }

  // boardId로 게시판 이름 가져오기
  String _getBoardName(String boardId) {
    try {
      return boards.firstWhere((board) => board['id'] == boardId)['name'] ??
          '알 수 없음';
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

  // 간단뷰 아이템 위젯
  Widget _buildCompactListItem(Map<String, dynamic> post, DateTime createdAt, int index) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // 게시글 조회수 증가
              _incrementViewCount(_posts[index].id, _posts[index].reference.parent.parent!.id);

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(
                    postId: _posts[index].id,
                    boardId: post['boardId'] ?? '',
                    boardName: _getBoardName(post['boardId'] ?? ''),
                    dateString: _posts[index].reference.parent.parent!.id,
                  ),
                ),
              );
              
              // 게시글 수정/삭제가 있었으면 목록 새로고침
              if (result == true) {
                _refreshPosts();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1줄: 제목 + 시간
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          post['title'] ?? '제목 없음',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 2줄: 조회수 | 댓글수 | 좋아요수
                  Row(
                    children: [
                      Text(
                        '조회 ${post['viewsCount'] ?? 0}회',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const Text(
                        ' | ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const Icon(Icons.comment, size: 12, color: Colors.black45),
                      const SizedBox(width: 2),
                      Text(
                        '${post['commentCount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const Text(
                        ' | ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                      const Icon(Icons.favorite_border, size: 12, color: Colors.black45),
                      const SizedBox(width: 2),
                      Text(
                        '${post['likesCount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // 얇은 구분선
        const Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.black12,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  // 스카이 이펙트 미리보기 위젯
  Widget _buildSkyEffectPreview(String? effectId) {
    if (effectId == null) return const SizedBox.shrink();
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('effects').doc(effectId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lottieUrl = data['lottieUrl'] as String?;
        
        if (lottieUrl != null && lottieUrl.isNotEmpty) {
          return Lottie.network(
            lottieUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            repeat: true,
            animate: true,
          );
        } else {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
      },
    );
  }

  // 카드 작성자 Row를 반드시 함수로 분리해서 사용하도록 수정합니다.
  Widget _buildCardAuthorRow(Map<String, dynamic> post) {
    final photoURL = post['author']?['photoURL'] ?? post['author']?['profileImageUrl'] ?? '';
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey[300],
          radius: 16,
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          child: photoURL.isEmpty ? const Icon(Icons.person, color: Colors.black54, size: 18) : null,
        ),
        const SizedBox(width: 4),
        if (post['author']?['currentSkyEffect'] != null)
          SizedBox(
            width: 32,
            height: 20,
            child: _buildSkyEffectPreview(post['author']['currentSkyEffect']),
          ),
        const SizedBox(width: 4),
        Text(
          post['author']['displayName'] ?? '익명',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
