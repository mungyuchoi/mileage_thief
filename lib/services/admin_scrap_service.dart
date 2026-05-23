import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/community_label_model.dart';

enum AdminScrapSource {
  naverBlog,
  naverCafe,
  aagag,
}

extension AdminScrapSourceLabel on AdminScrapSource {
  String get label {
    switch (this) {
      case AdminScrapSource.naverBlog:
        return '네이버 블로그';
      case AdminScrapSource.naverCafe:
        return '네이버 카페';
      case AdminScrapSource.aagag:
        return 'AAGAG';
    }
  }

  String get functionValue {
    switch (this) {
      case AdminScrapSource.naverBlog:
        return 'naver_blog';
      case AdminScrapSource.naverCafe:
        return 'naver_cafe';
      case AdminScrapSource.aagag:
        return 'aagag_issue';
    }
  }
}

class AdminScrapMediaCounts {
  const AdminScrapMediaCounts({
    required this.images,
    required this.videos,
    required this.links,
  });

  final int images;
  final int videos;
  final int links;

  factory AdminScrapMediaCounts.fromJson(Map<String, dynamic> json) {
    return AdminScrapMediaCounts(
      images: _intValue(json['images']),
      videos: _intValue(json['videos']),
      links: _intValue(json['links']),
    );
  }
}

class AdminScrapDuplicatePost {
  const AdminScrapDuplicatePost({
    required this.postId,
    required this.postNumber,
    required this.dateString,
    required this.boardId,
    required this.title,
    required this.postPath,
  });

  final String postId;
  final String postNumber;
  final String dateString;
  final String boardId;
  final String title;
  final String postPath;

  factory AdminScrapDuplicatePost.fromJson(Map<String, dynamic> json) {
    return AdminScrapDuplicatePost(
      postId: _stringValue(json['postId']),
      postNumber: _stringValue(json['postNumber']),
      dateString: _stringValue(json['dateString']),
      boardId: _stringValue(json['boardId']),
      title: _stringValue(json['title']),
      postPath: _stringValue(json['postPath']),
    );
  }
}

class AdminScrapValidationResult {
  const AdminScrapValidationResult({
    required this.ok,
    required this.canPublish,
    required this.sourceType,
    required this.normalizedUrl,
    required this.title,
    required this.scrapedAuthor,
    required this.scrapedDateText,
    required this.contentHtml,
    required this.previewHtml,
    required this.mediaCounts,
    required this.warnings,
    this.duplicatePost,
  });

  final bool ok;
  final bool canPublish;
  final String sourceType;
  final String normalizedUrl;
  final String title;
  final String scrapedAuthor;
  final String scrapedDateText;
  final String contentHtml;
  final String previewHtml;
  final AdminScrapMediaCounts mediaCounts;
  final List<String> warnings;
  final AdminScrapDuplicatePost? duplicatePost;

  factory AdminScrapValidationResult.fromJson(Map<String, dynamic> json) {
    final duplicate = _mapValue(json['duplicatePost']);
    return AdminScrapValidationResult(
      ok: json['ok'] == true,
      canPublish: json['canPublish'] == true,
      sourceType: _stringValue(json['sourceType']),
      normalizedUrl: _stringValue(json['normalizedUrl']),
      title: _stringValue(json['title']),
      scrapedAuthor: _stringValue(json['scrapedAuthor']),
      scrapedDateText: _stringValue(json['scrapedDateText']),
      contentHtml: _stringValue(json['contentHtml']),
      previewHtml: _stringValue(json['previewHtml']),
      mediaCounts: AdminScrapMediaCounts.fromJson(
        _mapValue(json['mediaCounts']),
      ),
      warnings: _stringList(json['warnings']),
      duplicatePost: duplicate.isEmpty
          ? null
          : AdminScrapDuplicatePost.fromJson(duplicate),
    );
  }
}

class AdminScrapPublishResult {
  const AdminScrapPublishResult({
    required this.postId,
    required this.postNumber,
    required this.dateString,
    required this.postPath,
  });

  final String postId;
  final String postNumber;
  final String dateString;
  final String postPath;

  factory AdminScrapPublishResult.fromJson(Map<String, dynamic> json) {
    return AdminScrapPublishResult(
      postId: _stringValue(json['postId']),
      postNumber: _stringValue(json['postNumber']),
      dateString: _stringValue(json['dateString']),
      postPath: _stringValue(json['postPath']),
    );
  }
}

class AdminScrapUserCandidate {
  const AdminScrapUserCandidate({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.displayGrade,
  });

  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String displayGrade;

  factory AdminScrapUserCandidate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminScrapUserCandidate(
      uid: doc.id,
      displayName: _stringValue(data['displayName']).isEmpty
          ? '이름 없음'
          : _stringValue(data['displayName']),
      email: _stringValue(data['email']),
      photoUrl: _stringValue(data['photoURL']),
      displayGrade: _stringValue(data['displayGrade']),
    );
  }
}

class AdminScrapService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<AdminScrapValidationResult> validateScrapPost({
    required String url,
    required AdminScrapSource source,
  }) async {
    final callable = _functions.httpsCallable(
      'validateScrapPost',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
    );
    final result = await callable.call(<String, dynamic>{
      'url': url,
      'sourceType': source.functionValue,
    });
    return AdminScrapValidationResult.fromJson(_mapValue(result.data));
  }

  static Future<AdminScrapValidationResult> validateUserScrapPost({
    required String url,
    AdminScrapSource source = AdminScrapSource.naverBlog,
  }) async {
    final callable = _functions.httpsCallable(
      'validateUserScrapPost',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
    );
    final result = await callable.call(<String, dynamic>{
      'url': url,
      'sourceType': source.functionValue,
    });
    return AdminScrapValidationResult.fromJson(_mapValue(result.data));
  }

  static Future<AdminScrapPublishResult> publishScrapPost({
    required String url,
    required AdminScrapSource source,
    required String boardId,
    required String authorUid,
    required String titleOverride,
    List<CommunityLabel> labels = const <CommunityLabel>[],
  }) async {
    final callable = _functions.httpsCallable(
      'publishScrapPost',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 100)),
    );
    final labelPayload = CommunityLabelPayload.fromLabels(labels);
    final result = await callable.call(<String, dynamic>{
      'url': url,
      'sourceType': source.functionValue,
      'boardId': boardId,
      'authorUid': authorUid,
      'titleOverride': titleOverride,
      'labels': labelPayload.labels,
    });
    return AdminScrapPublishResult.fromJson(_mapValue(result.data));
  }

  static Future<AdminScrapPublishResult> publishUserScrapPost({
    required String url,
    required String boardId,
    required String titleOverride,
    AdminScrapSource source = AdminScrapSource.naverBlog,
    List<CommunityLabel> labels = const <CommunityLabel>[],
  }) async {
    final callable = _functions.httpsCallable(
      'publishUserScrapPost',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 100)),
    );
    final labelPayload = CommunityLabelPayload.fromLabels(labels);
    final result = await callable.call(<String, dynamic>{
      'url': url,
      'boardId': boardId,
      'titleOverride': titleOverride,
      'sourceType': source.functionValue,
      'labels': labelPayload.labels,
    });
    return AdminScrapPublishResult.fromJson(_mapValue(result.data));
  }

  static Future<AdminScrapUserCandidate?> getUserByUid(String uid) async {
    final userId = uid.trim();
    if (userId.isEmpty) {
      return null;
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return AdminScrapUserCandidate.fromDoc(doc);
  }

  static Future<List<AdminScrapUserCandidate>> searchUsers(
    String query,
  ) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const <AdminScrapUserCandidate>[];
    }

    final results = <String, AdminScrapUserCandidate>{};

    Future<void> addDoc(DocumentSnapshot<Map<String, dynamic>> doc) async {
      if (doc.exists) {
        results[doc.id] = AdminScrapUserCandidate.fromDoc(doc);
      }
    }

    await addDoc(await _firestore.collection('users').doc(keyword).get());

    Future<void> addQuery(Query<Map<String, dynamic>> query) async {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        results[doc.id] = AdminScrapUserCandidate.fromDoc(doc);
      }
    }

    await Future.wait<void>([
      addQuery(
        _firestore
            .collection('users')
            .orderBy('displayName')
            .startAt([keyword]).endAt(['$keyword\uf8ff']).limit(12),
      ),
      addQuery(
        _firestore
            .collection('users')
            .orderBy('email')
            .startAt([keyword]).endAt(['$keyword\uf8ff']).limit(12),
      ),
    ]);

    final users = results.values.toList(growable: false);
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return <String, dynamic>{};
}

String _stringValue(dynamic value) {
  return value?.toString().trim() ?? '';
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}
