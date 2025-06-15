import 'package:flutter/material.dart';

class CommunityBoardSelectScreen extends StatelessWidget {
  final List<Map<String, dynamic>> boards = const [
    {'id': 'question', 'name': '마일리지 질문', 'group': '마일리지/혜택'},
    {'id': 'deal', 'name': '적립/카드 혜택', 'group': '마일리지/혜택'},
    {'id': 'seat_share', 'name': '좌석 공유', 'group': '마일리지/혜택'},
    {'id': 'review', 'name': '항공 리뷰', 'group': '여행/리뷰'},
    {'id': 'free', 'name': '자유게시판', 'group': '여행/리뷰'},
    {'id': 'error_report', 'name': '오류 신고', 'group': '운영/소통'},
    {'id': 'suggestion', 'name': '건의사항', 'group': '운영/소통'},
    {'id': 'notice', 'name': '운영 공지사항', 'group': '운영/소통'},
    {'id': 'popular', 'name': '인기글 모음', 'group': '운영/소통'},
  ];

  const CommunityBoardSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 그룹별로 묶기
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var board in boards) {
      groups.putIfAbsent(board['group'], () => []).add(board);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('게시판 선택', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('최근 사용', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 8),
                Text('항공 리뷰', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
          ...groups.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              ...entry.value.map((board) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context, {'boardId': board['id'], 'boardName': board['name']});
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      board['name'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              )),
              const Divider(height: 24),
            ],
          )),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
} 