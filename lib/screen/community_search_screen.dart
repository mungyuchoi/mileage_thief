import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'community_detail_screen.dart';

class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({Key? key}) : super(key: key);

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  String _selectedBoardFilter = 'all';
  
  // 게시판 목록 (커뮤니티 스크린과 동일)
  final List<Map<String, dynamic>> boards = [
    {'id': 'all', 'name': '전체'},
    {'id': 'question', 'name': '마일리지'},
    {'id': 'deal', 'name': '적립/카드 혜택'},
    {'id': 'seat_share', 'name': '좌석 공유'},
    {'id': 'review', 'name': '항공 리뷰'},
    {'id': 'error_report', 'name': '오류 신고'},
    {'id': 'suggestion', 'name': '건의사항'},
    {'id': 'free', 'name': '자유게시판'},
    {'id': 'notice', 'name': '운영 공지사항'},
    {'id': 'popular', 'name': '인기글 모음'},
  ];

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 자동으로 검색창에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
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
        final content = _removeHtmlTags(data['contentHtml'] ?? '').toLowerCase();
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
  Widget _highlightSearchText(String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(text);
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = searchQuery.toLowerCase();
    
    if (!lowercaseText.contains(lowercaseQuery)) {
      return Text(text);
    }

    final spans = <TextSpan>[];
    int start = 0;
    
    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        // 남은 텍스트 추가
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      // 하이라이트 이전 텍스트
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      // 하이라이트된 텍스트
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFE8F5E8), // 연한 초록 배경
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ));
      
      start = index + searchQuery.length;
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(
          fontSize: 12, // 일반 텍스트 크기 작게
        ),
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '게시글 검색',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: const InputDecoration(
                      hintText: '검색어를 입력하세요 (최소 2글자)',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF74512D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF74512D), width: 2),
                      ),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF74512D)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF74512D) : Colors.grey,
                      width: isSelected ? 2 : 1,
                    ),
                    checkmarkColor: const Color(0xFF74512D),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF74512D) : Colors.black54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              '검색어를 입력해주세요',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '최소 2글자 이상 입력하세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '다른 검색어를 시도해보세요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 결과 개수 표시
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                color: Colors.grey[100],
                                child: Text(
                                  '검색 결과 ${_searchResults.length}개',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              // 검색 결과 리스트
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final post = _searchResults[index].data() as Map<String, dynamic>;
                                    final createdAt = (post['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                                    
                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      color: Colors.white,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CommunityDetailScreen(
                                                boardId: post['boardId'] ?? '',
                                                boardName: _getBoardName(post['boardId'] ?? ''),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // 제목 (하이라이팅)
                                              DefaultTextStyle(
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                child: _highlightSearchText(
                                                  post['title'] ?? '제목 없음',
                                                  _searchController.text,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              
                                              // 내용 미리보기 (하이라이팅)
                                              DefaultTextStyle(
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                                child: _highlightSearchText(
                                                  _removeHtmlTags(post['contentHtml'] ?? ''),
                                                  _searchController.text,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // 메타 정보
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _getBoardName(post['boardId'] ?? ''),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black87,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        post['author']['displayName'] ?? '익명',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    _formatTime(createdAt),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black54,
                                                    ),
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
      return boards.firstWhere((board) => board['id'] == boardId)['name'] ?? '알 수 없음';
    } catch (e) {
      return '알 수 없음';
    }
  }
} 