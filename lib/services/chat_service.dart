import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/chat_message_model.dart';
import '../utils/image_compressor.dart';

class ChatService {
  ChatService._();

  static const String globalRoomId = 'global';
  static const int pageSize = 50;
  static const int regularUserMaxMessages = 150;
  static const int maxTextLength = 2000;
  static const int maxImagesPerMessage = 10;
  static const int imageTargetBytes = 1024 * 1024;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  static CollectionReference<Map<String, dynamic>> _messagesRef(
    String roomId,
  ) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages');
  }

  static Future<ChatPage> fetchMessages({
    required String roomId,
    required bool isAdmin,
    required int loadedCount,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    if (!isAdmin && loadedCount >= regularUserMaxMessages) {
      return const ChatPage(
        messages: <ChatMessage>[],
        lastDocument: null,
        hasMore: false,
      );
    }

    final remaining = isAdmin ? pageSize : regularUserMaxMessages - loadedCount;
    final limit = remaining < pageSize ? remaining : pageSize;

    Query<Map<String, dynamic>> query = _messagesRef(roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final messages = snapshot.docs
        .map(ChatMessage.fromDoc)
        .where((message) => message.isVisible)
        .toList();
    final fetchedCount = snapshot.docs.length;
    final nextLoadedCount = loadedCount + fetchedCount;
    final hasMore = fetchedCount == limit &&
        (isAdmin || nextLoadedCount < regularUserMaxMessages);

    return ChatPage(
      messages: messages,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfter,
      hasMore: hasMore,
    );
  }

  static Stream<List<ChatMessage>> watchLatestMessages({
    required String roomId,
    int limit = pageSize,
  }) {
    return _messagesRef(roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(ChatMessage.fromDoc)
            .where((message) => message.isVisible)
            .toList());
  }

  static Future<void> sendMessage({
    required String roomId,
    required User currentUser,
    required Map<String, dynamic> userProfile,
    required String text,
    required List<XFile> images,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && images.isEmpty) {
      throw Exception('메시지 내용이 비어 있습니다.');
    }
    if (trimmedText.length > maxTextLength) {
      throw Exception('메시지는 최대 $maxTextLength자까지 입력할 수 있습니다.');
    }
    if (images.length > maxImagesPerMessage) {
      throw Exception('이미지는 한 번에 최대 $maxImagesPerMessage개까지 보낼 수 있습니다.');
    }
    if (userProfile['isBanned'] == true) {
      throw Exception('이용이 제한된 계정입니다.');
    }

    final messageRef = _messagesRef(roomId).doc();
    final imageUrls = <String>[];
    var uploadedBytes = 0;

    for (final image in images) {
      final upload = await _uploadChatImage(
        roomId: roomId,
        messageId: messageRef.id,
        imageFile: File(image.path),
      );
      imageUrls.add(upload.url);
      uploadedBytes += upload.bytes;
    }

    final roles = userProfile['roles'];
    final isAdmin =
        roles is List && roles.map((e) => e.toString()).contains('admin');
    final author = <String, dynamic>{
      'uid': currentUser.uid,
      'displayName': userProfile['displayName'] ?? '익명',
      'photoURL': userProfile['photoURL'] ?? '',
      'displayGrade':
          isAdmin ? '★★★' : (userProfile['displayGrade'] ?? '이코노미 Lv.1'),
      'currentSkyEffect': userProfile['currentSkyEffect'] ?? '',
    };

    final batch = _firestore.batch();
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final now = FieldValue.serverTimestamp();
    final lastMessage = trimmedText.isNotEmpty
        ? _truncate(trimmedText, 80)
        : '사진 ${imageUrls.length}장';

    batch.set(
      roomRef,
      <String, dynamic>{
        'roomId': roomId,
        'title': '마일캐치 채팅',
        'description': '마일캐치 사용자가 함께 보는 단일 채팅방',
        'isActive': true,
        'lastMessage': lastMessage,
        'lastMessageAt': now,
        'createdAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(messageRef, <String, dynamic>{
      'messageId': messageRef.id,
      'text': trimmedText,
      'imageUrls': imageUrls,
      'author': author,
      'createdAt': now,
      'updatedAt': now,
      'isDeleted': false,
      'isHidden': false,
      'reportsCount': 0,
    });

    final usageDate = DateFormat('yyyyMMdd').format(DateTime.now());
    final usageRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chat_usage')
        .doc(usageDate);
    batch.set(
      usageRef,
      <String, dynamic>{
        'messageCount': FieldValue.increment(1),
        'imageCount': FieldValue.increment(imageUrls.length),
        'bytesUploaded': FieldValue.increment(uploadedBytes),
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<ChatPostDraft> buildPostDraft({
    required String roomId,
    required String promotedBy,
    required List<ChatMessage> messages,
  }) async {
    final selected = messages.where((message) {
      return message.isVisible && (message.hasText || message.hasImages);
    }).toList()
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });

    if (selected.isEmpty) {
      throw Exception('정리할 메시지가 없습니다.');
    }

    final imageUrls = <String>[];
    final buffer = StringBuffer();

    for (final message in selected) {
      final text = message.text.trim();
      if (text.isNotEmpty) {
        final lines = text
            .split('\n')
            .map((line) => line.trimRight())
            .where((line) => line.trim().isNotEmpty);
        for (final line in lines) {
          buffer.write('<p>${_linkifyEscapedLine(line)}</p>');
        }
      }
      imageUrls.addAll(message.imageUrls);
    }

    return ChatPostDraft(
      title: _buildDraftTitle(selected),
      contentHtml: buffer.toString(),
      imageUrls: imageUrls,
      sourceChat: <String, dynamic>{
        'roomId': roomId,
        'messageIds': selected.map((message) => message.messageId).toList(),
        'promotedBy': promotedBy,
        'imageUrls': imageUrls,
      },
    );
  }

  static Future<int> reportMessages({
    required String roomId,
    required User reporter,
    required Map<String, dynamic>? reporterProfile,
    required List<ChatMessage> messages,
    required String reason,
    required String detail,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('신고 사유를 선택해주세요.');
    }

    final reportableMessages = messages.where((message) {
      final authorUid = (message.author['uid'] ?? '').toString();
      return message.isVisible &&
          authorUid.isNotEmpty &&
          authorUid != reporter.uid;
    }).toList();
    if (reportableMessages.isEmpty) {
      throw Exception('신고할 다른 사용자의 메시지를 선택해주세요.');
    }

    final reporterName =
        (reporterProfile?['displayName'] ?? reporter.displayName ?? '익명')
            .toString();
    final trimmedDetail = detail.trim();
    var submittedCount = 0;
    var batch = _firestore.batch();
    var operationCount = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (operationCount == 0) return;
      if (!force && operationCount < 450) return;
      await batch.commit();
      batch = _firestore.batch();
      operationCount = 0;
    }

    for (final message in reportableMessages) {
      final messageRef = _messagesRef(roomId).doc(message.messageId);
      final reportRef = messageRef.collection('reports').doc(reporter.uid);
      final alreadyReported = await reportRef.get();
      if (alreadyReported.exists) continue;
      final globalReportRef = _firestore
          .collection('reports')
          .doc('chat_messages')
          .collection('messages')
          .doc();
      final userReportRef = _firestore
          .collection('users')
          .doc(reporter.uid)
          .collection('reports')
          .doc(globalReportRef.id);

      final reportData = <String, dynamic>{
        'reportId': globalReportRef.id,
        'reportPath': globalReportRef.path,
        'userReportPath': userReportRef.path,
        'type': 'chat_message',
        'reason': trimmedReason,
        'detail': trimmedDetail,
        'reporterUid': reporter.uid,
        'reporterName': reporterName,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'roomId': roomId,
        'messageId': message.messageId,
        'messageAuthor': message.author,
        'messageText': _truncate(message.text, 500),
        'imageUrls': message.imageUrls,
        'detailPath': 'chat_rooms/$roomId/messages/${message.messageId}',
      };

      batch.set(reportRef, reportData);
      batch.set(globalReportRef, reportData);
      batch.set(userReportRef, reportData);
      batch.update(messageRef, <String, dynamic>{
        'reportsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      operationCount += 4;
      submittedCount += 1;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
    if (submittedCount == 0) {
      throw Exception('이미 신고한 메시지입니다.');
    }
    return submittedCount;
  }

  static Future<_ChatImageUpload> _uploadChatImage({
    required String roomId,
    required String messageId,
    required File imageFile,
  }) async {
    var uploadFile = imageFile;
    final originalBytes = await imageFile.length();
    if (originalBytes > imageTargetBytes) {
      uploadFile = await ImageCompressor.compressToUnderSize(
        imageFile,
        targetBytes: imageTargetBytes,
      );
    }

    final uploadBytes = await uploadFile.length();
    final ext = path.extension(uploadFile.path).toLowerCase();
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    final storage = _storageInstance();
    final ref = storage
        .ref()
        .child('chat_rooms')
        .child(roomId)
        .child('messages')
        .child(messageId)
        .child('images')
        .child('${_uuid.v4()}$safeExt');

    final snapshot = await ref.putFile(
      uploadFile,
      SettableMetadata(
        contentType: _contentTypeForExtension(safeExt),
        cacheControl: 'public, max-age=31536000',
      ),
    );
    final url = await snapshot.ref.getDownloadURL();
    return _ChatImageUpload(url: url, bytes: uploadBytes);
  }

  static FirebaseStorage _storageInstance() {
    if (kIsWeb) return FirebaseStorage.instance;
    if (Platform.isIOS) {
      return FirebaseStorage.instanceFor(
        bucket: 'mileagethief.firebasestorage.app',
      );
    }
    return FirebaseStorage.instance;
  }

  static String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static String _buildDraftTitle(List<ChatMessage> messages) {
    for (final message in messages) {
      final text = message.text.trim();
      if (text.isNotEmpty) {
        final firstLine = text.split('\n').first.trim();
        if (firstLine.isNotEmpty) return _truncate(firstLine, 36);
      }
    }
    return '';
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  static String _linkifyEscapedLine(String line) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s<]+|www\.[^\s<]+)');
    final buffer = StringBuffer();
    var start = 0;
    for (final match in urlRegex.allMatches(line)) {
      buffer.write(_escapeHtml(line.substring(start, match.start)));
      final rawUrl = match.group(0) ?? '';
      final href = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
      buffer.write(
        '<a href="${_escapeHtmlAttribute(href)}" target="_blank">'
        '${_escapeHtml(rawUrl)}</a>',
      );
      start = match.end;
    }
    buffer.write(_escapeHtml(line.substring(start)));
    return buffer.toString();
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _escapeHtmlAttribute(String value) => _escapeHtml(value);
}

class _ChatImageUpload {
  const _ChatImageUpload({
    required this.url,
    required this.bytes,
  });

  final String url;
  final int bytes;
}
