import 'package:flutter/material.dart';
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: 10, // TODO: Firestore에서 글 목록 불러오기
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // 샘플 데이터
                final sample = {
                  'title': '샘플 게시글 제목 $index',
                  'contentHtml': '샘플 게시글 내용 미리보기... 이곳에 본문이 들어갑니다.',
                  'viewCount': 10 + index * 3,
                  'commentCount': index % 3,
                  'likesCount': index % 5,
                  'createdAt': DateTime.now().subtract(Duration(minutes: index * 2)),
                };
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 1.5,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      // 더미 데이터에 boardId, boardName 추가
                      final boardId = selectedBoardId;
                      final boardName = selectedBoardName;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommunityDetailScreen(
                            boardId: boardId,
                            boardName: boardName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF8FAFF), // 연한 파랑-하양
                          Color(0xFFFDF6FF), // 연한 보라-하양
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            Text(
                              sample['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // 본문
                            Text(
                              sample['contentHtml'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // 조회수 + comment/like
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '조회 ${sample['viewCount']}회',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black38,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black38),
                                    const SizedBox(width: 4),
                                    Text('${sample['commentCount']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                    const SizedBox(width: 16),
                                    Icon(Icons.favorite_border, size: 18, color: Colors.black38),
                                    const SizedBox(width: 4),
                                    Text('${sample['likesCount']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 우측 상단 작성 시간
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Text(
                            _formatTime(sample['createdAt'] as DateTime),
                            style: const TextStyle(fontSize: 12, color: Colors.black38),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CommunityPostCreateScreen()),
          );
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 