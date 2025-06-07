import 'package:flutter/material.dart';
import 'cancellation_notification_register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class CancellationNotificationScreen extends StatefulWidget {
  const CancellationNotificationScreen({super.key});

  @override
  State<CancellationNotificationScreen> createState() => _CancellationNotificationScreenState();
}

class _CancellationNotificationScreenState extends State<CancellationNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('취소표 알림'),
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '내 알림'),
            Tab(text: '인기구간'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyNotificationsTab(),
          _buildPopularRoutesTab(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CancellationNotificationRegisterScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildMyNotificationsTab() {
    final currentUser = AuthService.currentUser;
    
    if (currentUser == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '로그인이 필요합니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '취소표 알림을 이용하려면\n로그인을 해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cancel_subscriptions')
          .doc(currentUser.uid)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00256B),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '설정된 알림이 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '취소표 알림을 설정하여\n원하는 항공편의 취소표 소식을 받아보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSubscriptionCard(data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> data, String docId) {
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final seatClasses = List<String>.from(data['seatClasses'] ?? []);
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    final peanutUsed = data['peanutUsed'] ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final dateFormatter = DateFormat('MM.dd');

    String getSeatClassText() {
      return seatClasses.map((cls) {
        switch (cls) {
          case 'E': return '이코노미';
          case 'B': return '비즈니스';
          case 'F': return '퍼스트';
          default: return cls;
        }
      }).join(', ');
    }

    String getDateRangeText() {
      if (startDate == null) return '';
      if (endDate == null || startDate == endDate) {
        return dateFormatter.format(startDate);
      }
      return '${dateFormatter.format(startDate)} ~ ${dateFormatter.format(endDate)}';
    }

    void _showDeleteConfirmDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '알림 삭제',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 만료된 알림을 삭제하시겠습니까?',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$from → $to',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        getSeatClassText(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteSubscription(docId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  '삭제',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isExpired ? 0.5 : 1.0,
        child: Stack(
          children: [
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isExpired ? Colors.grey.shade300 : const Color(0xFF00256B).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단: 구간 정보
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$from → $to',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isExpired ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpired ? Colors.grey.shade200 : const Color(0xFF00256B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isExpired ? '만료' : '활성',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.grey : const Color(0xFF00256B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 중간: 상세 정보
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow('좌석등급', getSeatClassText(), isExpired),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow('알림기간', getDateRangeText(), isExpired),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow('사용된 땅콩', '$peanutUsed개', isExpired),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow(
                            '만료일', 
                            expiresAt != null ? DateFormat('MM.dd HH:mm').format(expiresAt) : '', 
                            isExpired
                          ),
                        ),
                      ],
                    ),
                    
                    if (isExpired) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '이 알림은 만료되었습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // 만료된 카드에만 X 버튼 표시
            if (isExpired)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _showDeleteConfirmDialog,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSubscription(String docId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00256B),
          ),
        ),
      );

      // Firestore에서 문서 삭제
      await _firestore
          .collection('cancel_subscriptions')
          .doc(currentUser.uid)
          .collection('items')
          .doc(docId)
          .delete();

      // 로딩 닫기
      Navigator.of(context).pop();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('만료된 알림이 삭제되었습니다'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // 로딩 닫기
      Navigator.of(context).pop();

      // 에러 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, bool isExpired) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isExpired ? Colors.grey : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isExpired ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRoutesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('popular_subscriptions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  '오류가 발생했습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00256B),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '인기구간 정보가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '많은 사람들이 관심있어 하는\n항공편 취소표 정보를 확인해보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // count 순으로 정렬
        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCount = aData['count'] ?? 0;
            final bCount = bData['count'] ?? 0;
            return bCount.compareTo(aCount); // 내림차순
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildPopularRouteCard(data, doc.id, index + 1);
          },
        );
      },
    );
  }

  Widget _buildPopularRouteCard(Map<String, dynamic> data, String routeKey, int rank) {
    final count = data['count'] ?? 0;
    final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
    
    // routeKey 파싱: "ICN-LAS_EBF" → from: "ICN", to: "LAS", seatClasses: ["E", "B", "F"]
    final routeInfo = _parseRouteKey(routeKey);
    final from = routeInfo['from'] ?? '';
    final to = routeInfo['to'] ?? '';
    final seatClasses = routeInfo['seatClasses'] ?? <String>[];

    // 순위별 색상 및 아이콘
    Color getRankColor() {
      switch (rank) {
        case 1: return Colors.amber;
        case 2: return Colors.grey.shade400;
        case 3: return Colors.orange.shade400;
        default: return const Color(0xFF00256B);
      }
    }

    IconData getRankIcon() {
      switch (rank) {
        case 1: return Icons.emoji_events;
        case 2: return Icons.military_tech;
        case 3: return Icons.workspace_premium;
        default: return Icons.trending_up;
      }
    }

    String getSeatClassText() {
      return seatClasses.map((cls) {
        switch (cls) {
          case 'E': return '이코노미';
          case 'B': return '비즈니스';
          case 'F': return '퍼스트';
          default: return cls;
        }
      }).join(', ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: rank <= 3 ? 4 : 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: rank <= 3 ? getRankColor().withOpacity(0.3) : Colors.grey.shade200,
            width: rank <= 3 ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 순위 표시
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: getRankColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: getRankColor(),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      getRankIcon(),
                      color: getRankColor(),
                      size: 20,
                    ),
                    Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: getRankColor(),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 구간 및 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$from → $to',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getSeatClassText(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    if (lastUpdated != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '업데이트: ${DateFormat('MM.dd HH:mm').format(lastUpdated)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 구독자 수
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00256B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00256B),
                      ),
                    ),
                    const Text(
                      '명',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00256B),
                      ),
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

  Map<String, dynamic> _parseRouteKey(String routeKey) {
    try {
      // "ICN-LAS_EBF" 형태 파싱
      final parts = routeKey.split('_');
      if (parts.length != 2) return {};
      
      final routePart = parts[0]; // "ICN-LAS"
      final classesPart = parts[1]; // "EBF"
      
      final routeSegments = routePart.split('-');
      if (routeSegments.length != 2) return {};
      
      final from = routeSegments[0];
      final to = routeSegments[1];
      
      // "EBF" → ["E", "B", "F"]
      final seatClasses = classesPart.split('').toList();
      
      return {
        'from': from,
        'to': to,
        'seatClasses': seatClasses,
      };
    } catch (e) {
      print('routeKey 파싱 오류: $e');
      return {};
    }
  }
} 