import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityNotificationModel {
  final String id;
  final String notificationId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? receivedAt;
  final DateTime? createdAt;

  CommunityNotificationModel({
    required this.id,
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    this.receivedAt,
    this.createdAt,
  });

  /// Firestore 문서에서 NotificationModel 생성
  factory CommunityNotificationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityNotificationModel.fromMap(data, doc.id);
  }

  /// Map에서 NotificationModel 생성
  factory CommunityNotificationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CommunityNotificationModel(
      id: documentId,
      notificationId: map['notificationId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      isRead: map['isRead'] ?? false,
      receivedAt: map['receivedAt'] is Timestamp 
          ? (map['receivedAt'] as Timestamp).toDate()
          : map['receivedAt'] is String
              ? DateTime.tryParse(map['receivedAt'])
              : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt'])
              : null,
    );
  }

  /// NotificationModel을 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'receivedAt': receivedAt != null ? Timestamp.fromDate(receivedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  /// 읽음 상태 변경된 새 인스턴스 반환
  CommunityNotificationModel copyWith({
    String? id,
    String? notificationId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? receivedAt,
    DateTime? createdAt,
  }) {
    return CommunityNotificationModel(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      receivedAt: receivedAt ?? this.receivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, title: $title, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityNotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 알림 타입 상수
class NotificationType {
  static const String comment = 'comment';
  static const String like = 'like';
  static const String mention = 'mention';
  static const String follow = 'follow';
  static const String system = 'system';
}

/// 딥링크 타입 상수
class DeepLinkType {
  static const String postDetail = 'post_detail';
  static const String userProfile = 'user_profile';
  static const String myPage = 'my_page';
} 