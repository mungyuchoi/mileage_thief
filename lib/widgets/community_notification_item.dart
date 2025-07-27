import 'package:flutter/material.dart';
import '../services/community_notification_history_service.dart';

class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String uid;
  final VoidCallback? onTap;

  const NotificationItem({
    Key? key,
    required this.notification,
    required this.uid,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 알림 아이콘 + 읽지 않음 표시
                _buildIconWithBadge(type, isRead),
                const SizedBox(width: 12),
                // 알림 내용
                Expanded(
                  child: _buildContent(title, body, isRead),
                ),
                const SizedBox(width: 8),
                // 시간 표시
                _buildTimeText(timeText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 아이콘 + 읽지 않음 뱃지
  Widget _buildIconWithBadge(String type, bool isRead) {
    return Stack(
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
    );
  }

  /// 알림 내용 (제목 + 본문)
  Widget _buildContent(String title, String body, bool isRead) {
    return Column(
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
    );
  }

  /// 시간 텍스트
  Widget _buildTimeText(String timeText) {
    return Text(
      timeText,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[500],
      ),
    );
  }

  /// 기본 탭 처리 (onTap이 제공되지 않은 경우)
  void _handleTap(BuildContext context) {
    CommunityNotificationHistoryService.handleNotificationTap(
      context,
      uid,
      notification,
    );
  }
}

/// 읽지 않은 알림 개수를 표시하는 뱃지 위젯
class UnreadCountBadge extends StatelessWidget {
  final int count;
  final double? size;
  final Color? backgroundColor;
  final Color? textColor;

  const UnreadCountBadge({
    Key? key,
    required this.count,
    this.size,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final badgeSize = size ?? 16.0;
    final bgColor = backgroundColor ?? Colors.red;
    final txtColor = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(badgeSize / 2),
      ),
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: txtColor,
          fontSize: badgeSize * 0.6,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 알림 타입별 스타일 정의 (확장성을 위해)
class NotificationItemStyle {
  static const double itemHeight = 80.0;
  static const double iconSize = 40.0;
  static const double badgeSize = 8.0;
  static const EdgeInsets itemMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
  static const EdgeInsets itemPadding = EdgeInsets.all(16);
  
  // 읽음/읽지않음 색상
  static const Color readBackgroundColor = Colors.white;
  static Color unreadBackgroundColor = Colors.blue[50]!;
  static Color readBorderColor = Colors.grey[200]!;
  static Color unreadBorderColor = Colors.blue[200]!;
  
  // 텍스트 색상
  static const Color titleColor = Colors.black87;
  static Color bodyColor = Colors.grey[600]!;
  static Color timeColor = Colors.grey[500]!;
  
  // 뱃지 색상
  static const Color badgeColor = Colors.red;
} 