import 'package:image_picker/image_picker.dart';

/// 커뮤니티 게시글 데이터를 관리하는 모델입니다.
class CommunityPostData {
  final String? postId;
  final String? boardId;
  final String? boardName;
  final String title;
  final String contentHtml;
  final List<XFile> selectedImages;
  final bool isEditMode;
  final String? dateString;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommunityPostData({
    this.postId,
    this.boardId,
    this.boardName,
    this.title = '',
    this.contentHtml = '',
    this.selectedImages = const [],
    this.isEditMode = false,
    this.dateString,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  CommunityPostData copyWith({
    String? postId,
    String? boardId,
    String? boardName,
    String? title,
    String? contentHtml,
    List<XFile>? selectedImages,
    bool? isEditMode,
    String? dateString,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityPostData(
      postId: postId ?? this.postId,
      boardId: boardId ?? this.boardId,
      boardName: boardName ?? this.boardName,
      title: title ?? this.title,
      contentHtml: contentHtml ?? this.contentHtml,
      selectedImages: selectedImages ?? this.selectedImages,
      isEditMode: isEditMode ?? this.isEditMode,
      dateString: dateString ?? this.dateString,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEmpty => title.trim().isEmpty && contentHtml.trim().isEmpty;
  bool get hasUnsavedChanges => title.isNotEmpty || contentHtml.isNotEmpty || selectedImages.isNotEmpty;

  @override
  String toString() {
    return 'CommunityPostData{postId: $postId, boardId: $boardId, boardName: $boardName, title: ${title.length} chars, contentHtml: ${contentHtml.length} chars, selectedImages: ${selectedImages.length}, isEditMode: $isEditMode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityPostData &&
        other.postId == postId &&
        other.boardId == boardId &&
        other.boardName == boardName &&
        other.title == title &&
        other.contentHtml == contentHtml &&
        other.selectedImages.length == selectedImages.length &&
        other.isEditMode == isEditMode &&
        other.dateString == dateString;
  }

  @override
  int get hashCode {
    return Object.hash(
      postId,
      boardId,
      boardName,
      title,
      contentHtml,
      selectedImages.length,
      isEditMode,
      dateString,
    );
  }
}

