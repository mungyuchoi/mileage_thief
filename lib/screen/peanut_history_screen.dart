import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/peanut_history_service.dart';
import '../services/user_service.dart';

class PeanutHistoryScreen extends StatefulWidget {
  const PeanutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PeanutHistoryScreen> createState() => _PeanutHistoryScreenState();
}

class _PeanutHistoryScreenState extends State<PeanutHistoryScreen> {
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;
  int _totalPeanuts = 0;

  final List<Map<String, String>> _filterOptions = [
    {'value': 'all', 'label': '전체'},
    {'value': 'post_create', 'label': '게시글'},
    {'value': 'comment_create', 'label': '댓글'},
    {'value': 'post_like', 'label': '좋아요'},
    {'value': 'admin_gift', 'label': '선물'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 정보에서 총 땅콩 수 가져오기
      final userData = await UserService.getUserFromFirestore(user.uid);
      _totalPeanuts = userData?['peanutCount'] ?? 0;

      // 히스토리 로드
      final history = await PeanutHistoryService.getHistory(
        user.uid,
        filterType: _selectedFilter,
        limit: 50,
      );

      setState(() {
        _historyList = history;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onFilterChanged(String newFilter) async {
    setState(() {
      _selectedFilter = newFilter;
    });
    await _loadData();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '땅콩 히스토리',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF74512D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 총 땅콩 수 카드
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8DC), Color(0xFF74512D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Image.asset(
                  'asset/img/peanuts.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '현재 보유 땅콩',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalPeanuts개',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 필터 옵션
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option['value'];
                
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option['label']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onFilterChanged(option['value']!);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF74512D),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    elevation: isSelected ? 2 : 0,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 히스토리 리스트
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF74512D),
                    ),
                  )
                : _historyList.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '땅콩 히스토리가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF74512D),
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _historyList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _historyList[index];
                            final type = item['type'] as String;
                            final amount = item['amount'] as int;
                            final createdAt = item['createdAt'] as Timestamp?;
                            final isClickable = type != 'admin_gift';

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: PeanutHistoryService.getIconColor(type).withOpacity(0.2),
                                  child: Icon(
                                    PeanutHistoryService.getIcon(type),
                                    color: PeanutHistoryService.getIconColor(type),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  PeanutHistoryService.getDisplayTitle(type),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      PeanutHistoryService.getDisplaySubtitle(item),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+$amount땅콩',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: isClickable
                                    ? () => PeanutHistoryService.navigateToContent(context, item)
                                    : null,
                                enabled: isClickable,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
} 