import 'package:flutter/material.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final String? initialBoardId;
  final String? initialBoardName;
  const CommunityPostCreateScreen({Key? key, this.initialBoardId, this.initialBoardName}) : super(key: key);

  @override
  State<CommunityPostCreateScreen> createState() => _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState extends State<CommunityPostCreateScreen> {
  String? selectedBoardId;
  String? selectedBoardName;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedBoardId = widget.initialBoardId;
    selectedBoardName = widget.initialBoardName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('커뮤니티 게시글 작성', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('등록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('게시판 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                // 게시판 선택 화면으로 이동
                final result = await Navigator.pushNamed(context, '/community_board_select');
                if (result is Map<String, String>) {
                  setState(() {
                    selectedBoardId = result['boardId'];
                    selectedBoardName = result['boardName'];
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedBoardName ?? '게시판을 선택하세요', style: TextStyle(color: selectedBoardName == null ? Colors.grey : Colors.black, fontSize: 15)),
                    const Icon(Icons.edit, color: Colors.black38, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const Divider(height: 32, color: Color(0xFFE0E0E0)),
            const Text(
              '유용한 팁이나 정보를 공유하거나 제품 리뷰를 등록해보세요. 궁금한 내용을 문의하거나 새 기능을 제안할 수도 있습니다. 다양한 삼성 사용자와 교류해 보세요!',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 32),
            const Text('태그', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 32, color: Color(0xFFE0E0E0)),
            const Text(
              '쉼표나 공백으로 태그를 구분할 수 있습니다. 태그 앞에 # 표시를 넣는 것은 선택 사항이지만, 일부 특수 문자(/, \, ?, ;, :)는 태그에 넣을 수 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
} 