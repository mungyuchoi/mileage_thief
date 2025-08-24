class EditorState {
  final bool isReady;
  final bool isLoading;
  final bool isFocused;
  final String currentText;
  final bool isDirty;
  final Map<String, dynamic> formatState;

  const EditorState({
    this.isReady = false,
    this.isLoading = false,
    this.isFocused = false,
    this.currentText = '',
    this.isDirty = false,
    this.formatState = const {},
  });

  EditorState copyWith({
    bool? isReady,
    bool? isLoading,
    bool? isFocused,
    String? currentText,
    bool? isDirty,
    Map<String, dynamic>? formatState,
  }) {
    return EditorState(
      isReady: isReady ?? this.isReady,
      isLoading: isLoading ?? this.isLoading,
      isFocused: isFocused ?? this.isFocused,
      currentText: currentText ?? this.currentText,
      isDirty: isDirty ?? this.isDirty,
      formatState: formatState ?? this.formatState,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isReady': isReady,
      'isLoading': isLoading,
      'isFocused': isFocused,
      'currentText': currentText,
      'isDirty': isDirty,
      'formatState': formatState,
    };
  }

  factory EditorState.fromJson(Map<String, dynamic> json) {
    return EditorState(
      isReady: json['isReady'] ?? false,
      isLoading: json['isLoading'] ?? false,
      isFocused: json['isFocused'] ?? false,
      currentText: json['currentText'] ?? '',
      isDirty: json['isDirty'] ?? false,
      formatState: json['formatState'] ?? {},
    );
  }

  @override
  String toString() {
    return 'EditorState{isReady: $isReady, isLoading: $isLoading, isFocused: $isFocused, currentText: ${currentText.length} chars, isDirty: $isDirty, formatState: $formatState}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EditorState &&
        other.isReady == isReady &&
        other.isLoading == isLoading &&
        other.isFocused == isFocused &&
        other.currentText == currentText &&
        other.isDirty == isDirty &&
        _mapEquals(other.formatState, formatState);
  }

  bool _mapEquals(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (String key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      isReady,
      isLoading,
      isFocused,
      currentText,
      isDirty,
      formatState.toString(),
    );
  }
}

