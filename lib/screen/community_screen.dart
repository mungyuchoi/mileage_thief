import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/category_service.dart';
import '../services/community_notification_history_service.dart';
import 'login_screen.dart';
import 'community_detail_screen.dart';
import 'community_post_create_screen.dart';
import 'community_search_screen.dart';
import 'community_notification_history_screen.dart';
import 'my_page_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CategoryService _categoryService = CategoryService();
  List<Map<String, dynamic>> boards = [];
  bool isLoadingBoards = true;

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
  
  // 이펙트 캐시 (성능 최적화)
  static final Map<String, Map<String, dynamic>> _effectCache = {};
  
  // 스크롤 상태 추적 (애니메이션 최적화)
  bool _isScrolling = false;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadBoards();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    try {
      final loadedBoards = await _categoryService.getBoards();
      setState(() {
        boards = loadedBoards;
        isLoadingBoards = false;
      });
    } catch (e) {
      setState(() {
        isLoadingBoards = false;
      });
    }
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

  // 로그인 확인 및 유도 함수
  Future<bool> _checkLoginAndNavigate() async {
    final user = AuthService.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: "로그인이 필요한 기능입니다. 로그인 페이지로 이동합니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
      );
      
      // 로그인 화면으로 이동
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      
      // 로그인 성공 시 프로필 다시 로드
      if (result == true) {
        await _loadUserProfile();
        return true;
      }
      return false;
    }
    return true;
  }

  // 아이콘 이름(String) → IconData 매핑
  Map<String, IconData> IconsMap = {
    'help_outline': Icons.help_outline,
    'card_giftcard': Icons.card_giftcard,
    'event_seat': Icons.event_seat,
    'rate_review': Icons.rate_review,
    'bug_report': Icons.bug_report,
    'lightbulb_outline': Icons.lightbulb_outline,
    'chat_bubble_outline': Icons.chat_bubble_outline,
    'campaign': Icons.campaign,
    'star_border': Icons.star_border,
    'newspaper_outlined': Icons.newspaper_outlined,
    'airline_seat_recline_extra': Icons.airline_seat_recline_extra,
  };

  IconData getBoardIcon(String? iconName) {
    return IconsMap[iconName] ?? Icons.list;
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
                        getBoardIcon(board['icon']),
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
                    // 알림 버튼 + 뱃지
                    _buildCommunityNotificationButton(),
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
                            onTap: () => _onPostTap(post, index),
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
                                  _buildCardAuthorRow(post, createdAt),
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
      floatingActionButton: (userProfile?['isBanned'] == true)
          ? null
          : (() {
              final board = boards.firstWhere(
                (b) => b['id'] == selectedBoardId,
                orElse: () => {'_notFound':true},
              );
              final fabEnabled = board == null ? true : (board['fabEnabled'] ?? true);
              print("FloatingAction fabEnabled:$fabEnabled, selectedBoardId:$selectedBoardId");
              final isAdmin = (userProfile?['roles'] ?? []).contains('admin');
              if (fabEnabled || isAdmin) {
                return FloatingActionButton(
                  onPressed: () async {
                    // 로그인 확인
                    final isLoggedIn = await _checkLoginAndNavigate();
                    if (!isLoggedIn) return;

                    // final result = await Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => selectedBoardId != 'all'
                    //         ? CommunityPostCreateScreen(
                    //       initialBoardId: selectedBoardId,
                    //       initialBoardName: selectedBoardName,
                    //     )
                    //         : const CommunityPostCreateScreen(),
                    //   ),
                    // );
                    final result = await Navigator.pushNamed(
                      context,
                      '/community/create_v3',
                      arguments: {
                        'initialBoardId': selectedBoardId != 'all' ? selectedBoardId : null,
                        'initialBoardName': selectedBoardId != 'all' ? selectedBoardName : null,
                      },
                    );
                    if (result == true || result == false) {
                      _refreshPosts();
                    }
                  },
                  backgroundColor: const Color(0xFF74512D),
                  child: const Icon(Icons.edit, color: Colors.white),
                );
              } else {
                return null;
              }
            })(),
    );
  }

  // 스크롤 리스너
  void _onScroll() {
    // 스크롤 상태 추적
    if (!_isScrolling) {
      setState(() {
        _isScrolling = true;
      });
    }
    
    // 기존 타이머 취소
    _scrollTimer?.cancel();
    
    // 스크롤 멈춤 감지 (300ms 후)
    _scrollTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    });
    
    // 무한 스크롤 로직
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

      // 차단 유저 제외 처리
      List<String> blockedUids = [];
      final user = AuthService.currentUser;
      if (user != null) {
        final blockedSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('blocked')
            .get();
        blockedUids = blockedSnapshot.docs.map((doc) => doc.id).toList();
      }

      Query query = _getQuery();
      if (blockedUids.isNotEmpty) {
        query = query.where('author.uid', whereNotIn: blockedUids);
      }
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
      List<String> blockedUids = [];
      final user = AuthService.currentUser;
      if (user != null) {
        final blockedSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('blocked')
            .get();
        blockedUids = blockedSnapshot.docs.map((doc) => doc.id).toList();
      }

      Query query = _getQuery();
      query = query.startAfterDocument(_lastDocument!);
      if (blockedUids.isNotEmpty) {
        query = query.where('author.uid', whereNotIn: blockedUids);
      }
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

  // 게시글 진입 조건 체크 및 상세화면 이동 함수
  Future<void> _onPostTap(Map<String, dynamic> post, int index) async {
    final boardId = post['boardId'] ?? '';
    final user = AuthService.currentUser;

    // 1. 로그인 체크
    if (user == null) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          content: const Text(
            '로그인을 먼저 해주세요.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              child: const Text('확인', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      // 로그인 화면으로 이동
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (result == true) {
        await _loadUserProfile();
      }
      return;
    }

    // 2. boardId가 'seats'일 때 등급 체크
    if (boardId == 'seats') {
      final grade = userProfile?['displayGrade'] ?? '';
      final isEconomy = grade.startsWith('이코노미 Lv.');
      final isBusiness = grade.startsWith('비즈니스 Lv.');
      final isFirst = grade.startsWith('퍼스트 Lv.');
      int economyLevel = 0;
      if (isEconomy) {
        final match = RegExp(r'이코노미 Lv\.(\d+)').firstMatch(grade);
        if (match != null) {
          economyLevel = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }
      final allowed = (isEconomy && economyLevel >= 2) || isBusiness || isFirst;
      if (!allowed) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 80,
                  child: Lottie.network(
                    'https://firebasestorage.googleapis.com/v0/b/mileagethief.firebasestorage.app/o/lottie%2Flock.json?alt=media&token=db2b5411-d1ce-4f23-8a66-23a349fcaf91',
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, color: Colors.black),
                    children: [
                      TextSpan(text: '이 게시판은\n'),
                      TextSpan(
                        text: '이코노미 레벨 2',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 20,
                        ),
                      ),
                      TextSpan(text: '부터\n진입 가능합니다.'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74512D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
            actionsAlignment: MainAxisAlignment.center,
          ),
        );
        return;
      }
    }

    // 통과 시 상세화면 이동
    _incrementViewCount(_posts[index].id, _posts[index].reference.parent.parent!.id);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityDetailScreen(
          postId: _posts[index].id,
          boardId: boardId,
          boardName: _getBoardName(boardId),
          dateString: _posts[index].reference.parent.parent!.id,
        ),
      ),
    );
    if (result == true) {
      _refreshPosts();
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

  /// 커뮤니티 알림 버튼 + 뱃지 (실시간 업데이트)
  Widget _buildCommunityNotificationButton() {
    final user = AuthService.currentUser;
    
    // 로그인하지 않은 사용자는 알림 버튼만 표시 (뱃지 없음)
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        onPressed: () async {
          // 로그인 확인 후 알림 화면으로 이동
          final isLoggedIn = await _checkLoginAndNavigate();
          if (isLoggedIn) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CommunityNotificationHistoryScreen(),
              ),
            );
          }
        },
        tooltip: '커뮤니티 알림',
      );
    }

    // 로그인한 사용자는 실시간 뱃지와 함께 표시
    return StreamBuilder<int>(
      stream: CommunityNotificationHistoryService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? Icons.notifications : Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityNotificationHistoryScreen(),
                  ),
                );
              },
              tooltip: '커뮤니티 알림',
            ),
            // 읽지 않은 알림 뱃지
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 간단뷰 아이템 위젯
  Widget _buildCompactListItem(Map<String, dynamic> post, DateTime createdAt, int index) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onPostTap(post, index),
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
                  // 2줄: displayName displayGrade | 조회수 | 댓글수 | 좋아요수
                  Row(
                    children: [
                      // displayName
                      Text(
                        post['author']?['displayName'] ?? '익명',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // displayGrade
                      Text(
                        post['author']?['displayGrade'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const Text(
                        ' | ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
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

  // 스카이 이펙트 미리보기 위젯 (캐시 최적화)
  Widget _buildSkyEffectPreview(String? effectId) {
    if (effectId == null || effectId.isEmpty) return const SizedBox.shrink();
    
    // 캐시에서 먼저 확인
    if (_effectCache.containsKey(effectId)) {
      final cachedData = _effectCache[effectId]!;
      final lottieUrl = cachedData['lottieUrl'] as String?;
      
      if (lottieUrl != null && lottieUrl.isNotEmpty) {
        return Lottie.network(
          lottieUrl,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          repeat: true,
          animate: !_isScrolling, // 스크롤 중일 때는 애니메이션 멈춤
          // 캐싱 옵션 추가
          options: LottieOptions(
            enableMergePaths: false, // 성능 최적화
          ),
          // 에러 처리
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
          },
        );
      } else {
        return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
      }
    }
    
    // 캐시에 없으면 Firestore에서 로드
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('effects').doc(effectId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF74512D),
                ),
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final lottieUrl = data['lottieUrl'] as String?;
        
        // 캐시에 저장
        _effectCache[effectId] = data;
        
        if (lottieUrl != null && lottieUrl.isNotEmpty) {
                      return Lottie.network(
              lottieUrl,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              repeat: true,
              animate: !_isScrolling, // 스크롤 중일 때는 애니메이션 멈춤
              // 캐싱 옵션 추가
              options: LottieOptions(
                enableMergePaths: false, // 성능 최적화
              ),
              // 에러 처리
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
              },
            );
        } else {
          return const Icon(Icons.auto_awesome, color: Color(0xFF74512D), size: 12);
        }
      },
    );
  }

  // 카드 작성자 Row를 반드시 함수로 분리해서 사용하도록 수정합니다.
  Widget _buildCardAuthorRow(Map<String, dynamic> post, DateTime createdAt) {
    final photoURL = post['author']?['photoURL'] ?? post['author']?['profileImageUrl'] ?? '';
    final displayName = post['author']['displayName'] ?? '익명';
    final isRecent = DateTime.now().difference(createdAt).inHours < 2;
    final hasSkyEffect = post['author']?['currentSkyEffect'] != null && 
                        (post['author']['currentSkyEffect'] as String).isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 16,
              backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
              child: photoURL.isEmpty ? const Icon(Icons.person, color: Colors.black54, size: 18) : null,
            ),
            SizedBox(width: hasSkyEffect ? 4 : 8), // 스카이 이펙트가 있으면 4, 없으면 8
            if (hasSkyEffect)
              SizedBox(
                width: 24,
                height: 24,
                child: _buildSkyEffectPreview(post['author']['currentSkyEffect']),
              ),
            if (hasSkyEffect) const SizedBox(width: 4), // 스카이 이펙트가 있을 때만 추가 간격
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (isRecent)
              Container(
                margin: const EdgeInsets.only(left: 6),
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
        // 우측 상단에 시간
        Text(
          _formatTime(createdAt),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
