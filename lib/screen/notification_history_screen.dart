import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final String subscriptionId;
  final String from;
  final String to;
  final List<String> seatClasses;

  const NotificationHistoryScreen({
    super.key,
    required this.subscriptionId,
    required this.from,
    required this.to,
    required this.seatClasses,
  });

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getSeatClassText() {
    return widget.seatClasses.map((cls) {
      switch (cls) {
        case 'E': return '이코노미';
        case 'B': return '비즈니스';
        case 'F': return '퍼스트';
        default: return cls;
      }
    }).join(', ');
  }

  Stream<QuerySnapshot>? _getCurrentUserStream() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      return null;
    }

    return _firestore
        .collection('notification_history')
        .doc(currentUser.uid)
        .collection('items')
        .where('subscriptionId', isEqualTo: widget.subscriptionId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.from} → ${widget.to}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _getSeatClassText(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00256B),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getCurrentUserStream(),
        builder: (context, snapshot) {
          // 로그인되지 않은 사용자 처리
          if (_getCurrentUserStream() == null) {
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
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

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
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          
          // 클라이언트에서 정렬
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['notifiedAt'] as Timestamp?;
            final bTimestamp = bData['notifiedAt'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.compareTo(aTimestamp); // 내림차순
          });

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
                    '받은 알림이 없습니다',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '취소표가 발견되면 알림을 받게 됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
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
              return _buildNotificationCard(data, doc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, String docId) {
    final notifiedAt = (data['notifiedAt'] as Timestamp?)?.toDate();
    final content = data['content'] ?? '취소표가 발견되었습니다!';
    final isRead = data['isRead'] ?? false;
    final flightInfo = data['flightInfo'] as Map<String, dynamic>?;

    final dateFormatter = DateFormat('MM.dd HH:mm');
    final timeAgo = _getTimeAgo(notifiedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isRead ? 1 : 3,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead ? Colors.grey.shade200 : const Color(0xFF00256B).withOpacity(0.3),
            width: isRead ? 1 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 알림 제목과 시간
              Row(
                children: [
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 알림 시간
              Text(
                notifiedAt != null ? dateFormatter.format(notifiedAt) : '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              
              // 항공편 정보 (있는 경우)
              if (flightInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00256B).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00256B).withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (flightInfo['airline'] != null)
                        Text(
                          '항공사: ${flightInfo['airline']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (flightInfo['flightNumber'] != null)
                        Text(
                          '편명: ${flightInfo['flightNumber']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (flightInfo['departureTime'] != null)
                        Text(
                          '출발시간: ${flightInfo['departureTime']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM.dd').format(date);
    }
  }
} 