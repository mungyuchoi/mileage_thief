import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 게시판 목록 (md파일 boards 표 기반, 아이콘 포함)
  final List<Map<String, dynamic>> boards = [
    {'id': 'question', 'name': '마일리지 질문'},
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
                ListTile(
                  tileColor: Colors.transparent,
                  leading: const Icon(Icons.list),
                  title: const Text('전체글'),
                  selected: selectedBoardId == 'all',
                  onTap: () {
                    setState(() {
                      selectedBoardId = 'all';
                      selectedBoardName = '전체글';
                    });
                    Navigator.pop(context);
                  },
                ),
                ...boards.map((board) => ListTile(
                      leading: Icon(getBoardIcon(board['id'] as String)),
                      title: Text(board['name']!),
                      selected: selectedBoardId == board['id'],
                      onTap: () {
                        setState(() {
                          selectedBoardId = board['id']!;
                          selectedBoardName = board['name']!;
                        });
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 카테고리/검색/공지 바
          Container(
            color: Colors.white,
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
                    Text(selectedBoardName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          const Divider(height: 1, color: Colors.grey),
          // 본문 영역
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              itemCount: 10, // TODO: Firestore에서 글 목록 불러오기
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.black54),
                  ),
                  title: Text('샘플 게시글 제목 $index', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('샘플 게시글 내용 미리보기...'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite_border, size: 18, color: Colors.black38),
                      SizedBox(height: 4),
                      Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black38),
                    ],
                  ),
                  onTap: () {
                    // TODO: 게시글 상세로 이동
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 글쓰기 화면 이동
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
} 