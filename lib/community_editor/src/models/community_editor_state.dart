/// 커뮤니티 에디터 상태를 관리하는 모델입니다.
class CommunityEditorState {
  final bool isReady;
  final bool isFocused;
  final bool isContentFocused;
  final bool isTitleFocused;
  final String currentText;
  final String currentTitle;
  final bool isDirty;
  final bool hasUnsavedChanges;
  final bool showToolbar;
  final Map<String, dynamic> formatState;

  const CommunityEditorState({
    this.isReady = false,
    this.isFocused = false,
    this.isContentFocused = false,
    this.isTitleFocused = false,
    this.currentText = '',
    this.currentTitle = '',
    this.isDirty = false,
    this.hasUnsavedChanges = false,
    this.showToolbar = false,
    this.formatState = const {},
  });

  CommunityEditorState copyWith({
    bool? isReady,
    bool? isFocused,
    bool? isContentFocused,
    bool? isTitleFocused,
    String? currentText,
    String? currentTitle,
    bool? isDirty,
    bool? hasUnsavedChanges,
    bool? showToolbar,
    Map<String, dynamic>? formatState,
  }) {
    return CommunityEditorState(
      isReady: isReady ?? this.isReady,
      isFocused: isFocused ?? this.isFocused,
      isContentFocused: isContentFocused ?? this.isContentFocused,
      isTitleFocused: isTitleFocused ?? this.isTitleFocused,
      currentText: currentText ?? this.currentText,
      currentTitle: currentTitle ?? this.currentTitle,
      isDirty: isDirty ?? this.isDirty,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      showToolbar: showToolbar ?? this.showToolbar,
      formatState: formatState ?? this.formatState,
    );
  }

  @override
  String toString() {
    return 'CommunityEditorState{isReady: $isReady, isFocused: $isFocused, isContentFocused: $isContentFocused, isTitleFocused: $isTitleFocused, currentText: ${currentText.length} chars, currentTitle: ${currentTitle.length} chars, isDirty: $isDirty, hasUnsavedChanges: $hasUnsavedChanges, showToolbar: $showToolbar}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityEditorState &&
        other.isReady == isReady &&
        other.isFocused == isFocused &&
        other.isContentFocused == isContentFocused &&
        other.isTitleFocused == isTitleFocused &&
        other.currentText == currentText &&
        other.currentTitle == currentTitle &&
        other.isDirty == isDirty &&
        other.hasUnsavedChanges == hasUnsavedChanges &&
        other.showToolbar == showToolbar;
  }

  @override
  int get hashCode {
    return Object.hash(
      isReady,
      isFocused,
      isContentFocused,
      isTitleFocused,
      currentText,
      currentTitle,
      isDirty,
      hasUnsavedChanges,
      showToolbar,
    );
  }
}

