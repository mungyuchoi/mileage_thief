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
