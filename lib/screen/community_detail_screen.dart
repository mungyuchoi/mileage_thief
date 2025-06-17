import 'package:flutter/material.dart';

class CommunityDetailScreen extends StatelessWidget {
  final String boardId;
  final String boardName;
  const CommunityDetailScreen({Key? key, required this.boardId, required this.boardName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(boardName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {}),
        ],
      ),
      backgroundColor: const Color(0xFFF1F1F3),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 본문 카드
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 1.5,
                color: const Color(0xFFFCFCFE),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/1.jpg'),
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('동백섬', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Expert Level 5', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xFFEDF7FB),
                              foregroundColor: Color(0xFF3BB2D6),
                              minimumSize: Size(60, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('팔로우', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'S23U Google play 스토어앱 업데이트 있습니다',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '비슷한 앱 사용 가능 Google Go(8.6MB) 보기\n새로운 기능\n- 검색 페이지의 개선된 디자인\n- 인앱 환경에 맞게 디자인된 새 기능',
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Text('06. 11.', style: TextStyle(fontSize: 13, color: Colors.black38)),
                          Spacer(),
                          Icon(Icons.remove_red_eye, size: 16, color: Colors.black26),
                          SizedBox(width: 3),
                          Text('47', style: TextStyle(fontSize: 13, color: Colors.black38)),
                          SizedBox(width: 12),
                          Icon(Icons.mode_comment_outlined, size: 16, color: Colors.black26),
                          SizedBox(width: 3),
                          Text('4', style: TextStyle(fontSize: 13, color: Colors.black38)),
                          SizedBox(width: 12),
                          Icon(Icons.favorite_border, size: 16, color: Colors.black26),
                          SizedBox(width: 3),
                          Text('3', style: TextStyle(fontSize: 13, color: Colors.black38)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 댓글/정렬 바
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.black45),
                    const SizedBox(width: 4),
                    const Text('4', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    DropdownButton<String>(
                      value: '등록순',
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: '등록순', child: Text('등록순')),
                        DropdownMenuItem(value: '최신순', child: Text('최신순')),
                      ],
                      onChanged: (v) {},
                    ),
                  ],
                ),
              ),
              // 댓글 리스트 상단 구분선 추가
              const Divider(
                height: 16,
                thickness: 0.7,
                color: Color(0xFFE0E0E0),
                indent: 0,
                endIndent: 0,
              ),
              // 댓글 리스트 (Column)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    _buildComment(
                      profileUrl: 'https://randomuser.me/api/portraits/men/2.jpg',
                      name: '갈바람1',
                      level: '퍼스트 Lv.1',
                      content: '우긴다고 해주는것도 아니고 그러려니 합니다 😂',
                      date: '6 시간전',
                      likes: 2,
                      onReport: () {},
                      onReply: () {},
                      onLike: () {},
                      levelColor: const Color(0xFFE43232),
                    ),
                    _buildComment(
                      profileUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
                      name: '수묵금',
                      level: '작성자',
                      content: '속도가 느려지거나\n벽돌 될수도 있습니다\n벽돌 이란 ?\n스마트폰 기능 멈추고\n사용 못하는 것을 말합니다\n발열도 나지요',
                      date: '10 시간전',
                      likes: 1,
                      onReport: () {},
                      onReply: () {},
                      onLike: () {},
                      levelColor: const Color(0xFF070000),
                    ),
                    _buildComment(
                      profileUrl: 'https://randomuser.me/api/portraits/men/4.jpg',
                      name: 'COOLKAWA',
                      level: '비즈니스 Lv.1',
                      content: 'ㅋㅋㅋㅋ 다들 그러려니 참 웃픕니다',
                      date: '11 시간전',
                      likes: 1,
                      onReport: () {},
                      onReply: () {},
                      onLike: () {},
                      levelColor: const Color(0xFF01114C),
                    ),
                    _buildComment(
                      profileUrl: 'https://randomuser.me/api/portraits/men/5.jpg',
                      name: '보리보리찡',
                      level: '★ 운영자 ★',
                      content: '@COOLKAWA ㅎㅎ 😂',
                      date: '2 일전',
                      likes: 0,
                      onReport: () {},
                      onReply: () {},
                      onLike: () {},
                      levelColor: const Color(0xFF070000),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 댓글 입력창
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Colors.black38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F1F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '댓글을 입력하세요',
                            hintStyle: const TextStyle(color: Colors.black38),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3BB2D6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        minimumSize: const Size(56, 36),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('등록', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComment({
    required String profileUrl,
    required String name,
    required String level,
    required String content,
    required String date,
    required int likes,
    required VoidCallback onReport,
    required VoidCallback onReply,
    required VoidCallback onLike,
    required Color levelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(profileUrl),
                    radius: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF7FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(fontSize: 11, color: levelColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.report_gmailerrorred, color: Colors.blueGrey, size: 18),
                    onPressed: onReport,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  Row(
                    children: [
                      Icon(Icons.mode_comment_outlined, color: Colors.blueGrey, size: 16),
                      SizedBox(width: 2),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined, color: Colors.blueGrey, size: 16),
                      SizedBox(width: 2),
                      Text('$likes', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(content, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
        const Divider(
          height: 16,
          thickness: 0.7,
          color: Color(0xFFE0E0E0),
          indent: 0,
          endIndent: 0,
        ),
      ],
    );
  }
} 