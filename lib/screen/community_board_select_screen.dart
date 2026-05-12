import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../const/colors.dart';

class CommunityBoardSelectScreen extends StatefulWidget {
  const CommunityBoardSelectScreen({Key? key}) : super(key: key);

  @override
  State<CommunityBoardSelectScreen> createState() =>
      _CommunityBoardSelectScreenState();
}

class _CommunityBoardSelectScreenState
    extends State<CommunityBoardSelectScreen> {
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
        backgroundColor: McColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: McColors.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('게시판 선택', style: McTextStyles.appBarTitle),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 그룹별로 묶기 (fabEnabled==false만)
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var board in boards) {
      if (board['fabEnabled'] == true) {
        groups.putIfAbsent(board['group'], () => []).add(board);
      }
    }
    return Scaffold(
      backgroundColor: McColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: McColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('게시판 선택', style: McTextStyles.appBarTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: [
          ...groups.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: McColors.inkSoft)),
                  ),
                  ...entry.value.map((board) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context, {
                              'boardId': board['id'],
                              'boardName': board['name']
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: McColors.line),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
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
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: McColors.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  board['description'] ?? '',
                                  style: TextStyle(
                                      fontSize: 12, color: McColors.muted),
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
