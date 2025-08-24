class UiComposingData {
  final String content;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const UiComposingData({
    required this.content,
    this.tags = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'tags': tags,
      'metadata': metadata,
    };
  }

  factory UiComposingData.fromJson(Map<String, dynamic> json) {
    return UiComposingData(
      content: json['content'] ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      metadata: json['metadata'] ?? {},
    );
  }

  @override
  String toString() {
    return 'UiComposingData{content: ${content.length} chars, tags: $tags, metadata: $metadata}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UiComposingData &&
        other.content == content &&
        _listEquals(other.tags, tags) &&
        _mapEquals(other.metadata, metadata);
  }

  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
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
    return Object.hash(content, tags.length, metadata.toString());
  }
}

class ComposingDataUtil {
  static UiComposingData fromJson(Map<String, dynamic> json) {
    return UiComposingData.fromJson(json);
  }

  static Map<String, dynamic> toJson(UiComposingData data) {
    return data.toJson();
  }
}

