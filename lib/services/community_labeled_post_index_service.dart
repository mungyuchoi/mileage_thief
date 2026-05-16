import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_label_model.dart';

class CommunityLabeledPostIndexService {
  const CommunityLabeledPostIndexService._();

  static List<CommunityLabel> labelsFromPostData(Map<String, dynamic>? data) {
    if (data == null) return const <CommunityLabel>[];
    final labels = CommunityLabel.listFromMaps(data['labels']);
    if (labels.isNotEmpty) return labels;

    final rawRefs = data['entityRefs'];
    if (rawRefs is Map) {
      return CommunityLabel.listFromEntityRefs(
        Map<String, dynamic>.from(rawRefs),
      );
    }
    return const <CommunityLabel>[];
  }

  static void syncPostIndexesInBatch({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> postRef,
    required Map<String, dynamic> postData,
    required Iterable<CommunityLabel> labels,
    Iterable<CommunityLabel> previousLabels = const <CommunityLabel>[],
    String? boardName,
  }) {
    final postId = _string(postData['postId'], fallback: postRef.id);
    if (postId.isEmpty) return;

    final currentDestinations = _destinationsFor(postId, labels);
    final previousDestinations = _destinationsFor(postId, previousLabels);

    for (final entry in previousDestinations.entries) {
      if (currentDestinations.containsKey(entry.key)) continue;
      batch.delete(entry.value.ref);
    }

    for (final destination in currentDestinations.values) {
      batch.set(
        destination.ref,
        _indexDataFor(
          postRef: postRef,
          postData: postData,
          label: destination.label,
          boardName: boardName,
        ),
        SetOptions(merge: true),
      );
    }
  }

  static void updatePostStatusInBatch({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> postRef,
    required Map<String, dynamic> postData,
    bool? isDeleted,
    bool? isHidden,
  }) {
    final labels = labelsFromPostData(postData);
    if (labels.isEmpty) return;

    final postId = _string(postData['postId'], fallback: postRef.id);
    if (postId.isEmpty) return;

    final updateData = <String, dynamic>{
      if (isDeleted != null) 'isDeleted': isDeleted,
      if (isHidden != null) 'isHidden': isHidden,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (final destination in _destinationsFor(postId, labels).values) {
      batch.set(destination.ref, updateData, SetOptions(merge: true));
    }
  }

  static Map<String, _LabeledPostDestination> _destinationsFor(
    String postId,
    Iterable<CommunityLabel> labels,
  ) {
    final db = FirebaseFirestore.instance;
    final result = <String, _LabeledPostDestination>{};
    for (final label in CommunityLabel.dedupe(labels)) {
      final ref = _destinationForLabel(db, label, postId);
      if (ref == null) continue;
      result[label.key] = _LabeledPostDestination(label: label, ref: ref);
    }
    return result;
  }

  static DocumentReference<Map<String, dynamic>>? _destinationForLabel(
    FirebaseFirestore db,
    CommunityLabel label,
    String postId,
  ) {
    switch (label.type) {
      case 'branch':
        return db
            .collection('branches')
            .doc(label.targetId)
            .collection('labeledPosts')
            .doc(postId);
      case 'giftcard':
        return db
            .collection('giftcards')
            .doc(label.targetId)
            .collection('labeledPosts')
            .doc(postId);
      case 'card':
        return db
            .collection('cards')
            .doc('catalog')
            .collection('cardProducts')
            .doc(label.targetId)
            .collection('labeledPosts')
            .doc(postId);
      default:
        return null;
    }
  }

  static Map<String, dynamic> _indexDataFor({
    required DocumentReference<Map<String, dynamic>> postRef,
    required Map<String, dynamic> postData,
    required CommunityLabel label,
    String? boardName,
  }) {
    final author = postData['author'] is Map
        ? Map<String, dynamic>.from(postData['author'] as Map)
        : const <String, dynamic>{};
    final contentHtml = _string(postData['contentHtml']);
    final imageUrl = _firstImageUrl(postData, contentHtml);
    final dateString =
        postRef.parent.parent?.id ?? _string(postData['dateString']);
    final resolvedBoardName =
        _string(boardName, fallback: _string(postData['boardName']));

    return <String, dynamic>{
      'postPath': postRef.path,
      'postId': _string(postData['postId'], fallback: postRef.id),
      'dateString': dateString,
      'boardId': _string(postData['boardId']),
      'boardName': resolvedBoardName,
      'title': _string(postData['title'], fallback: '제목 없음'),
      'previewText': _previewTextFromData(postData, contentHtml),
      'imageUrl': imageUrl ?? '',
      'authorId': _string(author['uid'] ?? postData['authorId']),
      'authorDisplayName': _string(
        author['displayName'] ?? postData['authorDisplayName'],
        fallback: '익명',
      ),
      'authorPhotoURL':
          _string(author['photoURL'] ?? postData['authorPhotoURL']),
      'commentCount':
          _int(postData['commentCount'] ?? postData['commentsCount']),
      'likesCount': _int(postData['likesCount']),
      'labelKey': label.key,
      'labelType': label.type,
      'targetId': label.targetId,
      'labelDisplayName': label.displayName,
      'labelSubtitle': label.subtitle,
      'labelLinkValue': label.linkValue,
      'labelSourcePath': label.sourcePath,
      'isDeleted': postData['isDeleted'] == true,
      'isHidden': postData['isHidden'] == true,
      if (postData['createdAt'] != null) 'createdAt': postData['createdAt'],
      'updatedAt': postData['updatedAt'] ?? FieldValue.serverTimestamp(),
    };
  }

  static String _previewTextFromData(
    Map<String, dynamic> postData,
    String contentHtml,
  ) {
    final fromHtml = _plainTextFromHtml(contentHtml);
    if (fromHtml.isNotEmpty) return fromHtml;
    for (final key in const ['plainText', 'contentText', 'content']) {
      final text = _string(postData[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String? _firstImageUrl(
    Map<String, dynamic> postData,
    String contentHtml,
  ) {
    final htmlMatch = _imgTagPattern.firstMatch(contentHtml);
    final htmlUrl = htmlMatch == null ? null : _cleanUrl(htmlMatch.group(1));
    if (htmlUrl != null) return htmlUrl;

    final imageUrl = _cleanUrl(postData['imageUrl']?.toString());
    if (imageUrl != null) return imageUrl;

    final fromImageUrls = _firstUrlFromList(postData['imageUrls']);
    if (fromImageUrls != null) return fromImageUrls;

    return _firstUrlFromList(postData['attachments']);
  }

  static String? _firstUrlFromList(Object? raw) {
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is String) {
        final url = _cleanUrl(item);
        if (url != null) return url;
      }
      if (item is Map) {
        final url = _cleanUrl(item['url']?.toString());
        if (url != null) return url;
      }
    }
    return null;
  }

  static String _plainTextFromHtml(String html) {
    if (html.trim().isEmpty) return '';
    final withBreaks = html
        .replaceAll(_imgTagPattern, ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|h[1-6])\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeHtmlEntities(withBreaks)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final RegExp _imgTagPattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>''',
    caseSensitive: false,
  );

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String? _cleanUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    return url.replaceAll('&amp;', '&');
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _LabeledPostDestination {
  final CommunityLabel label;
  final DocumentReference<Map<String, dynamic>> ref;

  const _LabeledPostDestination({
    required this.label,
    required this.ref,
  });
}
