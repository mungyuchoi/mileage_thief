import 'package:flutter/material.dart';
import '../services/category_service.dart';

class CommunityBoardSelectScreen extends StatefulWidget {
  const CommunityBoardSelectScreen({Key? key}) : super(key: key);

  @override
  State<CommunityBoardSelectScreen> createState() => _CommunityBoardSelectScreenState();
}

class _CommunityBoardSelectScreenState extends State<CommunityBoardSelectScreen> {
  final CategoryService _categoryService = CategoryService();
  List<Map<String, dynamic>> boards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    try {
      final loadedBoards = await _categoryService.getBoards();
      setState(() {
        boards = loadedBoards;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          board['name'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          board['description'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
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