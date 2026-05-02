import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/image_viewer.dart';
import 'community_board_select_screen.dart';
import 'community_post_create_simple_screen.dart';
import 'login_screen.dart';

const Color _chatBackgroundColor = Color(0xFFD2867D);
const Color _chatBubbleColor = Colors.white;
const Color _chatTextColor = Color(0xFF111111);
const Color _chatSubTextColor = Color(0xFF4B3A38);
const Color _chatComposerFillColor = Color(0xFFF2F2F2);

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({
    super.key,
    this.roomId = ChatService.globalRoomId,
  });

  final String roomId;

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<XFile> _pendingImages = <XFile>[];
  final Set<String> _selectedMessageIds = <String>{};

  StreamSubscription<List<ChatMessage>>? _latestSubscription;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  Map<String, dynamic>? _userProfile;

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _isPickingImages = false;
  bool _isPromoting = false;
  bool _isReporting = false;
  bool _hasMore = true;
  bool _isAdmin = false;
  bool _isBanned = false;

  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    unawaited(_latestSubscription?.cancel());
    _textController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).maybePop();
        return;
      }
    }

    await _loadUserProfile(user.uid);
    await _loadInitialMessages();
    _watchLatestMessages();
  }

  Future<void> _loadUserProfile(String uid) async {
    final profile = await UserService.getUserFromFirestore(uid);
    if (!mounted) return;

    final roles = profile?['roles'];
    final isAdmin =
        roles is List && roles.map((role) => role.toString()).contains('admin');
    setState(() {
      _userProfile = profile;
      _isAdmin = isAdmin;
      _isBanned = profile?['isBanned'] == true;
    });
  }

  Future<void> _loadInitialMessages() async {
    setState(() => _isLoadingInitial = true);
    try {
      final page = await ChatService.fetchMessages(
        roomId: widget.roomId,
        isAdmin: _isAdmin,
        loadedCount: 0,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingInitial = false);
      _showToast('채팅을 불러오지 못했습니다.');
    }
  }

  void _watchLatestMessages() {
    unawaited(_latestSubscription?.cancel());
    _latestSubscription = ChatService.watchLatestMessages(
      roomId: widget.roomId,
    ).listen((latestMessages) {
      if (!mounted) return;
      final latestIds =
          latestMessages.map((message) => message.messageId).toSet();
      final olderMessages = _messages
          .where((message) => !latestIds.contains(message.messageId))
          .toList();
      setState(() {
        _messages
          ..clear()
          ..addAll(latestMessages)
          ..addAll(olderMessages);
        _sortMessagesDescending();
      });
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ChatService.fetchMessages(
        roomId: widget.roomId,
        isAdmin: _isAdmin,
        loadedCount: _messages.length,
        startAfter: _lastDocument,
      );
      if (!mounted) return;
      final existingIds = _messages.map((message) => message.messageId).toSet();
      setState(() {
        _messages.addAll(
          page.messages.where(
            (message) => !existingIds.contains(message.messageId),
          ),
        );
        _sortMessagesDescending();
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      _showToast('이전 메시지를 불러오지 못했습니다.');
    }
  }

  void _sortMessagesDescending() {
    _messages.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  }

  Future<void> _pickImages() async {
    if (_isPickingImages || _isSending || _isBanned) return;
    if (_pendingImages.length >= ChatService.maxImagesPerMessage) {
      _showToast('이미지는 최대 ${ChatService.maxImagesPerMessage}개까지 보낼 수 있습니다.');
      return;
    }

    setState(() => _isPickingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked.isEmpty || !mounted) return;
      final remain = ChatService.maxImagesPerMessage - _pendingImages.length;
      setState(() => _pendingImages.addAll(picked.take(remain)));
      if (picked.length > remain) {
        _showToast('이미지는 최대 ${ChatService.maxImagesPerMessage}개까지만 첨부됩니다.');
      }
    } catch (e) {
      _showToast('이미지 선택 실패: $e');
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isBanned) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('로그인이 필요합니다.');
      return;
    }

    final text = _textController.text;
    if (text.trim().isEmpty && _pendingImages.isEmpty) return;

    final profile =
        _userProfile ?? await UserService.getUserFromFirestore(user.uid);
    if (profile == null) {
      _showToast('사용자 정보를 불러오지 못했습니다.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await ChatService.sendMessage(
        roomId: widget.roomId,
        currentUser: user,
        userProfile: profile,
        text: text,
        images: List<XFile>.from(_pendingImages),
      );
      if (!mounted) return;
      setState(() {
        _textController.clear();
        _pendingImages.clear();
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _promoteSelectedMessages() async {
    if (_isPromoting || _isReporting || _selectedMessageIds.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('로그인이 필요합니다.');
      return;
    }

    setState(() => _isPromoting = true);
    try {
      final selectedMessages = _messages
          .where((message) => _selectedMessageIds.contains(message.messageId))
          .toList();
      final draft = await ChatService.buildPostDraft(
        roomId: widget.roomId,
        promotedBy: user.uid,
        messages: selectedMessages,
      );
      if (!mounted) return;

      final selectedBoard =
          await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CommunityBoardSelectScreen()),
      );
      if (selectedBoard == null || !mounted) {
        setState(() => _isPromoting = false);
        return;
      }

      final boardId = (selectedBoard['boardId'] ?? '').toString();
      final boardName = (selectedBoard['boardName'] ?? '').toString();
      if (boardId.isEmpty || boardName.isEmpty) {
        setState(() => _isPromoting = false);
        return;
      }

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CommunityPostCreateSimpleScreen(
            initialBoardId: boardId,
            initialBoardName: boardName,
            initialTitle: draft.title,
            initialContentHtml: draft.contentHtml,
            initialImageUrls: draft.imageUrls,
            sourceChat: draft.sourceChat,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedMessageIds.clear();
        _isPromoting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPromoting = false);
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showReportDialog() async {
    if (_isReporting || _selectedMessageIds.isEmpty) return;
    final reportableMessages = _selectedReportableMessages();
    if (reportableMessages.isEmpty) {
      _showToast('신고할 다른 사용자의 메시지를 선택해주세요.');
      return;
    }

    final detailController = TextEditingController();
    String? selectedReason;
    final reportInput = await showDialog<_ChatReportInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text('${reportableMessages.length}개 메시지 신고'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고 사유를 선택해주세요.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _ReportReasonTile(
                      title: '욕설/비방',
                      value: 'abuse',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                    _ReportReasonTile(
                      title: '도배/광고',
                      value: 'spam',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                    _ReportReasonTile(
                      title: '음란/선정성',
                      value: 'sexual',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                    _ReportReasonTile(
                      title: '혐오/차별',
                      value: 'hate',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                    _ReportReasonTile(
                      title: '기타',
                      value: 'etc',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detailController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '상세 내용을 입력해주세요',
                        filled: true,
                        fillColor: const Color(0xFFF6F6F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            _ChatReportInput(
                              reason: selectedReason!,
                              detail: detailController.text,
                            ),
                          );
                        },
                  child: const Text(
                    '신고',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    detailController.dispose();
    if (reportInput == null || !mounted) return;
    await _reportSelectedMessages(reportInput);
  }

  List<ChatMessage> _selectedReportableMessages() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return _messages.where((message) {
      if (!_selectedMessageIds.contains(message.messageId)) return false;
      final authorUid = (message.author['uid'] ?? '').toString();
      return currentUid != null &&
          authorUid.isNotEmpty &&
          authorUid != currentUid;
    }).toList();
  }

  Future<void> _reportSelectedMessages(_ChatReportInput reportInput) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('로그인이 필요합니다.');
      return;
    }

    setState(() => _isReporting = true);
    try {
      final submittedCount = await ChatService.reportMessages(
        roomId: widget.roomId,
        reporter: user,
        reporterProfile: _userProfile,
        messages: _selectedReportableMessages(),
        reason: reportInput.reason,
        detail: reportInput.detail,
      );
      if (!mounted) return;
      setState(() {
        _selectedMessageIds.clear();
        _isReporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$submittedCount개 메시지 신고가 접수되었습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReporting = false);
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toggleSelection(ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.messageId)) {
        _selectedMessageIds.remove(message.messageId);
      } else {
        _selectedMessageIds.add(message.messageId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds.clear());
  }

  void _removePendingImage(int index) {
    if (index < 0 || index >= _pendingImages.length) return;
    setState(() => _pendingImages.removeAt(index));
  }

  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openPendingImageViewer(int initialIndex) {
    final imagePaths = _pendingImages.map((image) => image.path).toList();
    if (imagePaths.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalImageViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[850],
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBackgroundColor,
      appBar: AppBar(
        backgroundColor: _chatBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        iconTheme: const IconThemeData(color: _chatTextColor, size: 27),
        leading: _isSelectionMode
            ? IconButton(
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedMessageIds.length}개 선택' : '채팅',
          style: const TextStyle(
            color: _chatTextColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: '신고',
              onPressed:
                  (_isPromoting || _isReporting) ? null : _showReportDialog,
              icon: _isReporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_outlined),
            ),
            TextButton.icon(
              onPressed: (_isPromoting || _isReporting)
                  ? null
                  : _promoteSelectedMessages,
              icon: _isPromoting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_note_rounded),
              label: const Text('게시글로 정리'),
              style: TextButton.styleFrom(foregroundColor: _chatTextColor),
            ),
          ] else
            IconButton(
              onPressed: _loadInitialMessages,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '아직 메시지가 없습니다.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final showLoadMore = _hasMore || (!_isAdmin && _messages.length >= 150);
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _messages.length + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildLoadMoreTile();
        }
        final message = _messages[index];
        final selected = _selectedMessageIds.contains(message.messageId);
        return _MessageBubble(
          message: message,
          isMine:
              message.author['uid'] == FirebaseAuth.instance.currentUser?.uid,
          selected: selected,
          selectionMode: _isSelectionMode,
          onTap: _isSelectionMode ? () => _toggleSelection(message) : null,
          onLongPress: () => _toggleSelection(message),
          onOpenImages: _openImageViewer,
        );
      },
    );
  }

  Widget _buildLoadMoreTile() {
    if (!_isAdmin && _messages.length >= 150) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '일반 사용자는 최근 150개까지 볼 수 있습니다.',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: OutlinedButton(
          onPressed: _isLoadingMore ? null : _loadMoreMessages,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Color(0xFFD0D0D0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(_isLoadingMore ? '불러오는 중...' : '이전 메시지 더 보기'),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImages.isNotEmpty) _buildPendingImages(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  onPressed: (_isBanned || _isSending) ? null : _pickImages,
                  icon: const Icon(Icons.image_outlined),
                  color: _chatTextColor,
                  disabledColor: Colors.black26,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !_isBanned && !_isSending,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: ChatService.maxTextLength,
                  style: const TextStyle(
                    color: _chatTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: _isBanned ? '이용이 제한된 계정입니다.' : '메시지를 입력하세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9C9C9C),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: _chatComposerFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox.square(
                dimension: 40,
                child: IconButton.filled(
                  onPressed: (_isBanned || _isSending) ? null : _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD9D9D9),
                    disabledBackgroundColor: const Color(0xFFE9E9E9),
                    foregroundColor: _chatTextColor,
                    disabledForegroundColor: Colors.black26,
                    padding: EdgeInsets.zero,
                  ),
                  iconSize: 22,
                  icon: _isSending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _chatTextColor,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingImages() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _pendingImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = _pendingImages[index];
          return Stack(
            children: [
              InkWell(
                onTap: () => _openPendingImageViewer(index),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(image.path),
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _removePendingImage(index),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenImages,
  });

  final ChatMessage message;
  final bool isMine;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final void Function(List<String> imageUrls, int initialIndex) onOpenImages;

  @override
  Widget build(BuildContext context) {
    final rawName = (message.author['displayName'] ?? '익명').toString().trim();
    final name = rawName.isEmpty ? '익명' : rawName;
    final photoUrl = (message.author['photoURL'] ?? '').toString();
    final displayGrade = (message.author['displayGrade'] ?? '').toString();
    final time = message.createdAt == null
        ? ''
        : DateFormat('HH:mm').format(message.createdAt!);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (selectionMode && !isMine) _buildSelectionMark(),
            if (!isMine) ...[
              _MessageAvatar(name: name, photoUrl: photoUrl),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 3, right: 3, bottom: 3),
                    child: _MessageAuthorLabel(
                      name: name,
                      displayGrade: displayGrade,
                      alignRight: isMine,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFF4D8)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: selected
                          ? Border.all(color: const Color(0xFFB6842B))
                          : null,
                    ),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: _chatBubbleColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.hasText)
                            Text(
                              message.text,
                              style: const TextStyle(
                                color: _chatTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.28,
                              ),
                            ),
                          if (message.hasImages) ...[
                            if (message.hasText) const SizedBox(height: 7),
                            _MessageImageGrid(
                              urls: message.imageUrls,
                              onOpenImages: onOpenImages,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                      child: Text(
                        time,
                        style: const TextStyle(
                          color: _chatSubTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 6),
              _MessageAvatar(name: name, photoUrl: photoUrl),
            ],
            if (selectionMode && isMine) _buildSelectionMark(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionMark() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? const Color(0xFFB6842B) : Colors.black26,
        size: 22,
      ),
    );
  }
}

class _MessageAuthorLabel extends StatelessWidget {
  const _MessageAuthorLabel({
    required this.name,
    required this.displayGrade,
    required this.alignRight,
  });

  final String name;
  final String displayGrade;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final grade = displayGrade.trim();
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
        spacing: 5,
        runSpacing: 2,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (grade.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFF3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                grade,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 34,
        height: 34,
        color: const Color(0xFFE1E3E8),
        child: photoUrl.trim().isEmpty
            ? _AvatarFallback(name: name)
            : Image.network(
                photoUrl,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarFallback(name: name),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '익' : trimmed.substring(0, 1);
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  const _ReportReasonTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? Colors.black : Colors.black38,
              size: 21,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatReportInput {
  const _ChatReportInput({
    required this.reason,
    required this.detail,
  });

  final String reason;
  final String detail;
}

class _MessageImageGrid extends StatelessWidget {
  const _MessageImageGrid({
    required this.urls,
    required this.onOpenImages,
  });

  final List<String> urls;
  final void Function(List<String> imageUrls, int initialIndex) onOpenImages;

  @override
  Widget build(BuildContext context) {
    final displayUrls = urls.take(4).toList();
    final crossAxisCount = displayUrls.length == 1 ? 1 : 2;
    final size = displayUrls.length == 1 ? 210.0 : 104.0;

    return SizedBox(
      width: displayUrls.length == 1 ? size : (size * 2) + 6,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayUrls.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final url = displayUrls[index];
          final extraCount = urls.length - displayUrls.length;
          return InkWell(
            onTap: () => onOpenImages(urls, index),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(url, fit: BoxFit.cover),
                  if (index == displayUrls.length - 1 && extraCount > 0)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Text(
                        '+$extraCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
