import 'attachment_file.dart';

class PostingData {
  final String title;
  final String content;
  final String? categoryId;
  final List<AttachmentFile> attachments;
  final List<String> tags;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PostingData({
    this.title = '',
    this.content = '',
    this.categoryId,
    this.attachments = const [],
    this.tags = const [],
    this.isPublic = true,
    this.createdAt,
    this.updatedAt,
  });

  PostingData copyWith({
    String? title,
    String? content,
    String? categoryId,
    List<AttachmentFile>? attachments,
    List<String>? tags,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostingData(
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'tags': tags,
      'isPublic': isPublic,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PostingData.fromJson(Map<String, dynamic> json) {
    return PostingData(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      categoryId: json['categoryId'],
      attachments: (json['attachments'] as List?)?.map((e) => AttachmentFile.fromJson(e)).toList() ?? [],
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      isPublic: json['isPublic'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  @override
  String toString() {
    return 'PostingData{title: $title, content: ${content.length} chars, categoryId: $categoryId, attachments: ${attachments.length}, tags: $tags, isPublic: $isPublic, createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostingData &&
        other.title == title &&
        other.content == content &&
        other.categoryId == categoryId &&
        _listEquals(other.attachments, attachments) &&
        _listEquals(other.tags, tags) &&
        other.isPublic == isPublic &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      content,
      categoryId,
      attachments.length,
      tags.length,
      isPublic,
      createdAt,
      updatedAt,
    );
  }
}

