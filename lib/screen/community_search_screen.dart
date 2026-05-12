import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../const/colors.dart';
import '../services/category_service.dart';
import 'community_detail_screen.dart';

class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({Key? key}) : super(key: key);

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final CategoryService _categoryService = CategoryService();

  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  String _selectedBoardFilter = 'all';
  List<Map<String, dynamic>> boards = [];
  bool isLoadingBoards = true;

  @override
  void initState() {
    super.initState();
    _loadBoards();
    // 화면 진입 시 자동으로 검색창에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadBoards() async {
    try {
      final loadedBoards = await _categoryService.getBoards();
      // 'all' 옵션 추가
      final allBoards = [
        {'id': 'all', 'name': '전체'},
        ...loadedBoards,
      ];
      setState(() {
        boards = allBoards;
        isLoadingBoards = false;
      });
    } catch (e) {
      setState(() {
        isLoadingBoards = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 검색 실행
  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Firestore 쿼리 생성
      Query baseQuery = FirebaseFirestore.instance.collectionGroup('posts');

      // 게시판 필터 적용
      if (_selectedBoardFilter != 'all') {
        baseQuery = baseQuery.where('boardId', isEqualTo: _selectedBoardFilter);
      }

      baseQuery = baseQuery
          .where('isDeleted', isEqualTo: false)
          .where('isHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50); // 검색 결과 제한

      final querySnapshot = await baseQuery.get();

      // 클라이언트 사이드에서 제목과 내용 필터링
      final filteredResults = querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toLowerCase();
        final content =
            _removeHtmlTags(data['contentHtml'] ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) || content.contains(searchQuery);
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      print('검색 오류: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  // HTML 태그 제거
  String _removeHtmlTags(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[^;]+;'), '')
        .trim();
  }

  // 시간 포맷팅
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM/dd').format(dateTime);
  }

  // 검색어 하이라이팅
  Widget _highlightSearchText(String text, String searchQuery,
      {TextStyle? baseStyle}) {
    if (searchQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = searchQuery.toLowerCase();

    if (!lowercaseText.contains(lowercaseQuery)) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        // 남은 텍스트 추가 (부모 스타일 적용)
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: baseStyle,
          ));
        }
        break;
      }

      // 하이라이트 이전 텍스트 (부모 스타일 적용)
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      // 하이라이트된 텍스트
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: TextStyle(
          backgroundColor: const Color(0xFFE8F5E8), // 연한 초록 배경
          color: McColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: baseStyle?.fontSize ?? 12,
        ),
      ));

      start = index + searchQuery.length;
    }

    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: McColors.line,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: McColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '게시글 검색',
          style: McTextStyles.appBarTitle,
        ),
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: McColors.line, width: 0.7),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: McTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: '검색어를 입력하세요 (최소 2글자)',
                      prefixIcon: Icon(Icons.search, color: McColors.accent),
                    ),
                    onChanged: (value) {
                      // 500ms 지연 후 검색 (Debounce)
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == value) {
                          _performSearch(value);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // 게시판 필터
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: boards.length,
              itemBuilder: (context, index) {
                final board = boards[index];
                final isSelected = _selectedBoardFilter == board['id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(board['name']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedBoardFilter = board['id']!;
                      });
                      if (_searchController.text.trim().length >= 2) {
                        _performSearch(_searchController.text);
                      }
                    },
                    selectedColor: McColors.accentSoft,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? McColors.accent : McColors.line,
                      width: isSelected ? 1.2 : 0.8,
                    ),
                    checkmarkColor: McColors.accent,
                    labelStyle: TextStyle(
                      color: isSelected ? McColors.accent : McColors.muted,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),

          // 검색 결과
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchController.text.trim().length < 2
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search,
                                size: 48, color: McColors.mutedLight),
                            SizedBox(height: 14),
                            Text(
                              '검색어를 입력해주세요',
                              style: McTextStyles.bodyStrong,
                            ),
                            SizedBox(height: 6),
                            Text(
                              '최소 2글자 이상 입력하세요',
                              style: McTextStyles.meta,
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48, color: McColors.mutedLight),
                                SizedBox(height: 14),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: McTextStyles.bodyStrong,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '다른 검색어를 시도해보세요',
                                  style: McTextStyles.meta,
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 결과 개수 표시
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                color: McColors.field,
                                child: Text(
                                  '검색 결과 ${_searchResults.length}개',
                                  style: McTextStyles.meta.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // 검색 결과 리스트
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final post = _searchResults[index].data()
                                        as Map<String, dynamic>;
                                    final createdAt =
                                        (post['createdAt'] as Timestamp?)
                                                ?.toDate() ??
                                            DateTime.now();

                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0.5,
                                      color: Colors.white,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CommunityDetailScreen(
                                                postId:
                                                    _searchResults[index].id,
                                                boardId: post['boardId'] ?? '',
                                                boardName: _getBoardName(
                                                    post['boardId'] ?? ''),
                                                dateString:
                                                    _searchResults[index]
                                                        .reference
                                                        .parent
                                                        .parent!
                                                        .id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 제목 (하이라이팅)
                                              _highlightSearchText(
                                                post['title'] ?? '제목 없음',
                                                _searchController.text,
                                                baseStyle:
                                                    McTextStyles.bodyStrong,
                                              ),
                                              const SizedBox(height: 8),

                                              // 내용 미리보기 (하이라이팅)
                                              _highlightSearchText(
                                                _removeHtmlTags(
                                                    post['contentHtml'] ?? ''),
                                                _searchController.text,
                                                baseStyle: McTextStyles.meta,
                                              ),
                                              const SizedBox(height: 10),

                                              // 메타 정보
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _getBoardName(
                                                            post['boardId'] ??
                                                                ''),
                                                        style: McTextStyles
                                                            .micro
                                                            .copyWith(
                                                          color: McColors.ink,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        post['author'][
                                                                'displayName'] ??
                                                            '익명',
                                                        style:
                                                            McTextStyles.micro,
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    _formatTime(createdAt),
                                                    style: McTextStyles.micro,
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
                            ],
                          ),
          ),
        ],
      ),
    );
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
}
