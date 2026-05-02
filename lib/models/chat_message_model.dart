import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.text,
    required this.imageUrls,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.isHidden,
    required this.reportsCount,
    required this.document,
  });

  final String messageId;
  final String text;
  final List<String> imageUrls;
  final Map<String, dynamic> author;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool isHidden;
  final int reportsCount;
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;
  bool get isVisible => !isDeleted && !isHidden;

  factory ChatMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawImageUrls = data['imageUrls'];
    final authorData = data['author'];

    return ChatMessage(
      messageId: (data['messageId'] as String?) ?? doc.id,
      text: (data['text'] as String?) ?? '',
      imageUrls: rawImageUrls is List
          ? rawImageUrls.map((url) => url.toString()).toList()
          : const <String>[],
      author: authorData is Map
          ? Map<String, dynamic>.from(authorData)
          : const <String, dynamic>{},
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      isDeleted: data['isDeleted'] == true,
      isHidden: data['isHidden'] == true,
      reportsCount: ((data['reportsCount'] ?? 0) as num).toInt(),
      document: doc,
    );
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class ChatPage {
  const ChatPage({
    required this.messages,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<ChatMessage> messages;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class ChatPostDraft {
  const ChatPostDraft({
    required this.title,
    required this.contentHtml,
    required this.imageUrls,
    required this.sourceChat,
  });

  final String title;
  final String contentHtml;
  final List<String> imageUrls;
  final Map<String, dynamic> sourceChat;
}
