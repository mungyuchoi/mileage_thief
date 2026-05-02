import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/card_product_model.dart';

class CardCatalogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static DocumentReference<Map<String, dynamic>> get _catalogRef =>
      _firestore.collection('cards').doc('catalog');

  static CollectionReference<Map<String, dynamic>> get productsRef =>
      _catalogRef.collection('cardProducts');

  static CollectionReference<Map<String, dynamic>> get changeRequestsRef =>
      _catalogRef.collection('cardChangeRequests');

  static CollectionReference<Map<String, dynamic>> get cardRequestsRef =>
      _catalogRef.collection('cardRequests');

  Stream<List<CatalogCardProduct>> watchProducts({int limit = 300}) {
    return productsRef
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CatalogCardProduct.fromFirestore)
            .toList(growable: false));
  }

  Stream<CatalogCardProduct?> watchProduct(String cardId) {
    return productsRef.doc(cardId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CatalogCardProduct.fromFirestore(doc);
    });
  }

  Stream<List<CardProductRevision>> watchRevisions(String cardId) {
    return productsRef
        .doc(cardId)
        .collection('revisions')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CardProductRevision.fromFirestore)
            .toList(growable: false));
  }

  Stream<List<CardDetailSection>> watchDetailSections(String cardId) {
    return productsRef
        .doc(cardId)
        .collection('detailSections')
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CardDetailSection.fromFirestore)
            .where((section) => section.displayBody.trim().isNotEmpty)
            .where((section) => section.title.trim() != '엑셀 계산표 기준 혜택')
            .toList(growable: false));
  }

  Stream<List<CardProductComment>> watchComments(String cardId) {
    return productsRef
        .doc(cardId)
        .collection('comments')
        .orderBy('createdAt')
        .limit(300)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CardProductComment.fromFirestore)
            .where((comment) => !comment.isDeleted)
            .toList(growable: false));
  }

  Stream<bool> watchUserLike({
    required String cardId,
    required String uid,
  }) {
    return productsRef
        .doc(cardId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<CardSourceRequest>> watchCardRequests({int limit = 100}) {
    return cardRequestsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CardSourceRequest.fromFirestore)
            .toList(growable: false));
  }

  Future<CardMutationResult> createCardProduct(
    Map<String, dynamic> card,
  ) async {
    final callable = _functions.httpsCallable('createCardProduct');
    final result = await callable.call<Map<String, dynamic>>({'card': card});
    return CardMutationResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardMutationResult> applyCardEdit({
    required String cardId,
    required int baseVersion,
    required Map<String, dynamic> patch,
  }) async {
    final callable = _functions.httpsCallable('applyCardEdit');
    final result = await callable.call<Map<String, dynamic>>({
      'cardId': cardId,
      'baseVersion': baseVersion,
      'patch': patch,
    });
    return CardMutationResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardMutationResult> rollbackCardRevision({
    required String cardId,
    required String revisionId,
  }) async {
    final callable = _functions.httpsCallable('rollbackCardRevision');
    final result = await callable.call<Map<String, dynamic>>({
      'cardId': cardId,
      'revisionId': revisionId,
    });
    return CardMutationResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardCommentResult> addCardProductComment({
    required String cardId,
    required String body,
    String? parentCommentId,
  }) async {
    final callable = _functions.httpsCallable('addCardProductComment');
    final result = await callable.call<Map<String, dynamic>>({
      'cardId': cardId,
      'body': body,
      'parentCommentId': parentCommentId,
    });
    return CardCommentResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardLikeResult> toggleCardProductLike({
    required String cardId,
  }) async {
    final callable = _functions.httpsCallable('toggleCardProductLike');
    final result = await callable.call<Map<String, dynamic>>({
      'cardId': cardId,
    });
    return CardLikeResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardViewResult> incrementCardProductView({
    required String cardId,
  }) async {
    final callable = _functions.httpsCallable('incrementCardProductView');
    final result = await callable.call<Map<String, dynamic>>({
      'cardId': cardId,
    });
    return CardViewResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardImportResult> importCardGorillaCards({
    required int startId,
    required int endId,
  }) async {
    final callable = _functions.httpsCallable('importCardGorillaCards');
    final result = await callable.call<Map<String, dynamic>>({
      'startId': startId,
      'endId': endId,
    });
    return CardImportResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<List<CardSourceCandidate>> searchCardSourceCandidates({
    required String query,
  }) async {
    final callable = _functions.httpsCallable(
      'searchCardSourceCandidates',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 140)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'query': query,
      'limit': 20,
    });
    final data = Map<String, dynamic>.from(result.data);
    return ((data['candidates'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CardSourceCandidate.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<CardSourceRequestResult> createCardSourceRequest({
    required CardSourceCandidate candidate,
    required String query,
  }) async {
    final callable = _functions.httpsCallable('createCardSourceRequest');
    final result = await callable.call<Map<String, dynamic>>({
      'sourceCardId': candidate.sourceCardId,
      'query': query,
    });
    return CardSourceRequestResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<CardRequestImportResult> importRequestedCard({
    required String requestId,
  }) async {
    final callable = _functions.httpsCallable(
      'importRequestedCard',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 190)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'requestId': requestId,
    });
    return CardRequestImportResult.fromMap(
      Map<String, dynamic>.from(result.data),
    );
  }

  Future<void> rejectCardSourceRequest({
    required String requestId,
  }) async {
    final callable = _functions.httpsCallable('rejectCardSourceRequest');
    await callable.call<Map<String, dynamic>>({
      'requestId': requestId,
    });
  }

  Future<Map<String, dynamic>> uploadMainImage({
    required String cardId,
    required PlatformFile file,
  }) async {
    final bytes = await _bytesFor(file);
    final extension = _extensionFor(file.name);
    final storagePath =
        'cards/catalog/cardProducts/$cardId/images/main.$extension';
    final ref = _storageInstance().ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: _contentTypeFor(extension),
      customMetadata: {
        'cardId': cardId,
        'originalName': file.name,
      },
    );

    await ref.putData(bytes, metadata);
    final downloadUrl = await ref.getDownloadURL();
    return {
      'main': {
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'fileName': file.name,
        'contentHash': sha256.convert(bytes).toString(),
        'uploadedAtIso': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  Future<String?> downloadUrlForStoragePath(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    try {
      return await _storageInstance().ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static FirebaseStorage _storageInstance() {
    if (kIsWeb) return FirebaseStorage.instance;
    try {
      return FirebaseStorage.instanceFor(
        bucket: 'mileagethief.firebasestorage.app',
      );
    } catch (_) {
      return FirebaseStorage.instance;
    }
  }

  static Future<Uint8List> _bytesFor(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final path = file.path;
    if (path == null) {
      throw StateError('이미지 파일을 읽을 수 없습니다.');
    }
    return File(path).readAsBytes();
  }

  static String _extensionFor(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : 'jpg';
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) return ext;
    return 'jpg';
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

class CardMutationResult {
  final String cardId;
  final int version;
  final String? revisionId;
  final String? requestId;
  final bool noChanges;

  const CardMutationResult({
    required this.cardId,
    required this.version,
    this.revisionId,
    this.requestId,
    this.noChanges = false,
  });

  factory CardMutationResult.fromMap(Map<String, dynamic> data) {
    return CardMutationResult(
      cardId: (data['cardId'] ?? '').toString(),
      version: (data['version'] as num?)?.toInt() ?? 0,
      revisionId: data['revisionId']?.toString(),
      requestId: data['requestId']?.toString(),
      noChanges: data['noChanges'] == true,
    );
  }
}

class CardImportResult {
  final String runId;
  final int startId;
  final int endId;
  final Map<String, dynamic> counts;
  final List<dynamic> importedCardIds;

  const CardImportResult({
    required this.runId,
    required this.startId,
    required this.endId,
    required this.counts,
    required this.importedCardIds,
  });

  factory CardImportResult.fromMap(Map<String, dynamic> data) {
    return CardImportResult(
      runId: (data['runId'] ?? '').toString(),
      startId: (data['startId'] as num?)?.toInt() ?? 0,
      endId: (data['endId'] as num?)?.toInt() ?? 0,
      counts: Map<String, dynamic>.from(
        (data['counts'] as Map?) ?? const <String, dynamic>{},
      ),
      importedCardIds: (data['importedCardIds'] as List?) ?? const [],
    );
  }
}

class CardCommentResult {
  final String cardId;
  final String commentId;
  final String? parentCommentId;

  const CardCommentResult({
    required this.cardId,
    required this.commentId,
    this.parentCommentId,
  });

  factory CardCommentResult.fromMap(Map<String, dynamic> data) {
    return CardCommentResult(
      cardId: _serviceString(data['cardId']),
      commentId: _serviceString(data['commentId']),
      parentCommentId: _serviceNullableString(data['parentCommentId']),
    );
  }
}

class CardLikeResult {
  final String cardId;
  final bool liked;
  final int likesCount;

  const CardLikeResult({
    required this.cardId,
    required this.liked,
    required this.likesCount,
  });

  factory CardLikeResult.fromMap(Map<String, dynamic> data) {
    return CardLikeResult(
      cardId: _serviceString(data['cardId']),
      liked: data['liked'] == true,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CardViewResult {
  final String cardId;
  final int viewsCount;

  const CardViewResult({
    required this.cardId,
    required this.viewsCount,
  });

  factory CardViewResult.fromMap(Map<String, dynamic> data) {
    return CardViewResult(
      cardId: _serviceString(data['cardId']),
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CardSourceCandidate {
  final String sourceCardId;
  final String name;
  final String issuerName;
  final String cardType;
  final String cardTypeLabel;
  final String status;
  final String? annualFeeSummary;
  final String? previousMonthSpendSummary;
  final String? imageUrl;
  final List<dynamic> primaryBenefits;

  const CardSourceCandidate({
    required this.sourceCardId,
    required this.name,
    required this.issuerName,
    required this.cardType,
    required this.cardTypeLabel,
    required this.status,
    required this.primaryBenefits,
    this.annualFeeSummary,
    this.previousMonthSpendSummary,
    this.imageUrl,
  });

  factory CardSourceCandidate.fromMap(Map<String, dynamic> data) {
    return CardSourceCandidate(
      sourceCardId: _serviceString(data['sourceCardId']),
      name: _serviceString(data['name'], fallback: '카드명 미입력'),
      issuerName: _serviceString(data['issuerName'], fallback: '카드사 미입력'),
      cardType: _serviceString(data['cardType'], fallback: 'unknown'),
      cardTypeLabel: _serviceString(data['cardTypeLabel'], fallback: '기타'),
      status: _serviceString(data['status'], fallback: 'active'),
      annualFeeSummary: _serviceNullableString(data['annualFeeSummary']),
      previousMonthSpendSummary:
          _serviceNullableString(data['previousMonthSpendSummary']),
      imageUrl: _serviceNullableString(data['imageUrl']),
      primaryBenefits: _serviceList(data['primaryBenefits']),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '사용 가능';
      case 'discontinued':
        return '단종';
      case 'hidden':
        return '숨김';
      case 'pending':
        return '정보 확인중';
      default:
        return status;
    }
  }

  String get benefitsSummary => primaryBenefits
      .map(displayValue)
      .where((value) => value.isNotEmpty)
      .take(3)
      .join(' · ');
}

class CardSourceRequest {
  final String id;
  final String status;
  final String? requesterUid;
  final String? reviewedByUid;
  final String query;
  final CardSourceCandidate candidate;
  final String? existingCardId;
  final String? importedCardId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final Map<String, dynamic> raw;

  const CardSourceRequest({
    required this.id,
    required this.status,
    required this.query,
    required this.candidate,
    required this.raw,
    this.requesterUid,
    this.reviewedByUid,
    this.existingCardId,
    this.importedCardId,
    this.createdAt,
    this.reviewedAt,
  });

  factory CardSourceRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final candidateMap = data['candidate'] is Map
        ? Map<String, dynamic>.from(data['candidate'] as Map)
        : <String, dynamic>{};
    return CardSourceRequest(
      id: doc.id,
      status: _serviceString(data['status'], fallback: 'pending'),
      requesterUid: _serviceNullableString(data['requesterUid']),
      reviewedByUid: _serviceNullableString(data['reviewedByUid']),
      query: _serviceString(data['query']),
      candidate: CardSourceCandidate.fromMap(candidateMap),
      existingCardId: _serviceNullableString(data['existingCardId']),
      importedCardId: _serviceNullableString(data['importedCardId']),
      createdAt: _serviceDate(data['createdAt']),
      reviewedAt: _serviceDate(data['reviewedAt']),
      raw: data,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '대기';
      case 'imported':
        return '가져옴';
      case 'rejected':
        return '반려';
      default:
        return status;
    }
  }

  bool get canImport => status == 'pending';
}

class CardSourceRequestResult {
  final String requestId;
  final String status;
  final String? existingCardId;

  const CardSourceRequestResult({
    required this.requestId,
    required this.status,
    this.existingCardId,
  });

  factory CardSourceRequestResult.fromMap(Map<String, dynamic> data) {
    return CardSourceRequestResult(
      requestId: _serviceString(data['requestId']),
      status: _serviceString(data['status'], fallback: 'pending'),
      existingCardId: _serviceNullableString(data['existingCardId']),
    );
  }
}

class CardRequestImportResult {
  final String requestId;
  final String cardId;
  final String? runId;
  final bool alreadyImported;

  const CardRequestImportResult({
    required this.requestId,
    required this.cardId,
    this.runId,
    this.alreadyImported = false,
  });

  factory CardRequestImportResult.fromMap(Map<String, dynamic> data) {
    return CardRequestImportResult(
      requestId: _serviceString(data['requestId']),
      cardId: _serviceString(data['cardId']),
      runId: _serviceNullableString(data['runId']),
      alreadyImported: data['alreadyImported'] == true,
    );
  }
}

String _serviceString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _serviceNullableString(dynamic value) {
  final text = _serviceString(value);
  return text.isEmpty ? null : text;
}

List<dynamic> _serviceList(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

DateTime? _serviceDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
