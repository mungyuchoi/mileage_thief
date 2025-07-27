import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/community_notification_history_service.dart';
import '../services/community_notification_test_helper.dart';
import '../models/community_notification_model.dart';

class CommunityNotificationHistoryScreen extends StatefulWidget {
  const CommunityNotificationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CommunityNotificationHistoryScreen> createState() => _CommunityNotificationHistoryScreenState();
}

class _CommunityNotificationHistoryScreenState extends State<CommunityNotificationHistoryScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isMarkingAllAsRead = false;
  bool _isGeneratingDummyData = false;
  bool _isClearingData = false;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('커뮤니티 알림'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('커뮤니티 알림'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 읽지 않은 알림 개수 표시 + 전체 읽음 버튼
          StreamBuilder<int>(
            stream: CommunityNotificationHistoryService.getUnreadCount(_currentUser!.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              
              return TextButton(
                onPressed: unreadCount > 0 && !_isMarkingAllAsRead 
                    ? _markAllAsRead 
                    : null,
                child: _isMarkingAllAsRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : Text(
                        unreadCount > 0 ? '모두 읽음 ($unreadCount)' : '모두 읽음',
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.blue : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: CommunityNotificationHistoryService.getNotificationHistory(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF74512D),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '알림을 불러오는 중 오류가 발생했습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyStateWithTestButtons();
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF74512D),
            child: Column(
              children: [
                // 테스트 버튼들 (개발용)
                _buildTestButtons(),
                // 알림 목록
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationItem(notification);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 테스트 버튼들 (개발용)
  Widget _buildTestButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        children: [
          Text(
            '🧪 테스트용 버튼 (개발 중에만 표시)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.amber[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingDummyData ? null : _generateDummyData,
                  icon: _isGeneratingDummyData 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('더미 데이터 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClearingData ? null : _clearTestData,
                  icon: _isClearingData 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.clear_all, size: 18),
                  label: const Text('테스트 데이터 삭제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯 + 테스트 버튼
  Widget _buildEmptyStateWithTestButtons() {
    return Column(
      children: [
        // 테스트 버튼들
        _buildTestButtons(),
        // 빈 상태
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  '커뮤니티 알림이 없습니다',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '새로운 댓글이나 좋아요 알림이 오면 여기에 표시됩니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '위의 "더미 데이터 생성" 버튼으로 테스트해보세요!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 알림 아이템 위젯
  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final body = notification['body'] ?? '';
    final receivedAt = notification['receivedAt'];
    final timeText = CommunityNotificationHistoryService.formatNotificationTime(receivedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 알림 아이콘 + 읽지 않음 표시
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: CommunityNotificationHistoryService.getNotificationIconColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        CommunityNotificationHistoryService.getNotificationIcon(type),
                        color: CommunityNotificationHistoryService.getNotificationIconColor(type),
                        size: 20,
                      ),
                    ),
                    // 읽지 않은 알림 빨간 점
                    if (!isRead)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // 알림 내용
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 시간 표시
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 알림 아이템 탭 처리
  void _onNotificationTap(Map<String, dynamic> notification) {
    CommunityNotificationHistoryService.handleNotificationTap(
      context,
      _currentUser!.uid,
      notification,
    );
  }

  /// 전체 읽음 처리
  Future<void> _markAllAsRead() async {
    setState(() {
      _isMarkingAllAsRead = true;
    });

    try {
      await CommunityNotificationHistoryService.markAllAsRead(_currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 알림을 읽음 처리했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('읽음 처리 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAllAsRead = false;
        });
      }
    }
  }

  /// 새로고침 처리
  Future<void> _onRefresh() async {
    // 스트림이므로 자동으로 새로고침됨
    // 필요하다면 여기서 추가 로직 구현
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// 더미 데이터 생성
  Future<void> _generateDummyData() async {
    setState(() {
      _isGeneratingDummyData = true;
    });
    try {
      await CommunityNotificationTestHelper.generateDummyNotifications(_currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('테스트 알림 6개가 생성되었습니다! (읽지 않음 4개, 읽음 2개)'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('더미 데이터 생성 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingDummyData = false;
        });
      }
    }
  }

  /// 테스트 데이터 삭제
  Future<void> _clearTestData() async {
    setState(() {
      _isClearingData = true;
    });
    try {
      await CommunityNotificationTestHelper.clearAllTestNotifications(_currentUser!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 테스트 데이터가 삭제되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 데이터 삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingData = false;
        });
      }
    }
  }
} 