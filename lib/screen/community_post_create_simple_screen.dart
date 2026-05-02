import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../community_editor/src/utils/firebase_image_uploader.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';
import '../services/peanut_history_service.dart';
import '../services/user_service.dart';
import '../utils/community_access_level.dart';

class CommunityPostCreateSimpleScreen extends StatefulWidget {
  const CommunityPostCreateSimpleScreen({
    super.key,
    required this.initialBoardId,
    required this.initialBoardName,
    this.initialTitle,
    this.initialContentHtml,
    this.initialImageUrls = const <String>[],
    this.sourceChat,
  });

  final String initialBoardId;
  final String initialBoardName;
  final String? initialTitle;
  final String? initialContentHtml;
  final List<String> initialImageUrls;
  final Map<String, dynamic>? sourceChat;

  @override
  State<CommunityPostCreateSimpleScreen> createState() =>
      _CommunityPostCreateSimpleScreenState();
}

class _CommunityPostCreateSimpleScreenState
    extends State<CommunityPostCreateSimpleScreen> {
  static const int _maxImages = 30;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _metaRouteController = TextEditingController();
  final TextEditingController _metaCarrierController = TextEditingController();
  final TextEditingController _metaCabinController = TextEditingController();
  final TextEditingController _metaMilesController = TextEditingController();
  final TextEditingController _metaTaxesController = TextEditingController();
  final TextEditingController _metaCashController = TextEditingController();
  final TextEditingController _metaCostController = TextEditingController();
  final TextEditingController _metaGiftcardController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = <XFile>[];
  final List<String> _initialImageUrls = <String>[];
  final List<String> _links = <String>[];
  List<Map<String, dynamic>> _boards = <Map<String, dynamic>>[];

  bool _isPickingImages = false;
  bool _isSubmitting = false;
  bool _structuredMetaExpanded = false;
  String _structuredMetaType = '발권';
  String lateBoardId = '';
  String lateBoardName = '';
  String _authorName = '익명';
  String _authorPhotoUrl = '';
  Map<String, dynamic>? _userProfile;
  CommunityAccessLevel? _selectedReadRestriction;

  String get _selectedBoardId => lateBoardId;
  String get _selectedBoardName => lateBoardName;

  @override
  void initState() {
    super.initState();
    lateBoardId = widget.initialBoardId;
    lateBoardName = widget.initialBoardName;
    final initialTitle = widget.initialTitle?.trim();
    if (initialTitle != null && initialTitle.isNotEmpty) {
      _titleController.text = initialTitle;
    }
    final initialContentHtml = widget.initialContentHtml?.trim();
    if (initialContentHtml != null && initialContentHtml.isNotEmpty) {
      _contentController.text = _plainTextFromHtml(initialContentHtml);
    }
    _initialImageUrls.addAll(widget.initialImageUrls);
    _loadAuthorProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _metaRouteController.dispose();
    _metaCarrierController.dispose();
    _metaCabinController.dispose();
    _metaMilesController.dispose();
    _metaTaxesController.dispose();
    _metaCashController.dispose();
    _metaCostController.dispose();
    _metaGiftcardController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    var nextName = (user.displayName ?? '').trim();
    var nextPhoto = (user.photoURL ?? '').trim();
    if (nextName.isEmpty) {
      nextName = (user.email ?? '').trim().split('@').first.trim();
    }

    try {
      final profile = await UserService.getUserFromFirestore(user.uid);
      _userProfile = profile;
      final firestoreName = (profile?['displayName'] as String? ?? '').trim();
      final firestorePhoto = (profile?['photoURL'] as String? ?? '').trim();
      if (firestoreName.isNotEmpty) nextName = firestoreName;
      if (firestorePhoto.isNotEmpty) nextPhoto = firestorePhoto;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _authorName = nextName.isNotEmpty ? nextName : '익명';
      _authorPhotoUrl = nextPhoto;
    });
  }

  bool get _isAdmin {
    final roles = _userProfile?['roles'];
    return roles is List && roles.contains('admin');
  }

  bool get _canSetReadRestriction {
    return CommunityAccessLevel.canSetRestriction(_userProfile);
  }

  Future<void> _ensureBoardsLoaded() async {
    if (_boards.isNotEmpty) return;
    final loadedBoards = await _categoryService.getBoards();
    if (!mounted) return;
    setState(() => _boards = loadedBoards);
  }

  List<Map<String, dynamic>> _writableBoards() {
    return _boards.where((board) {
      final boardId = (board['id'] ?? '').toString();
      if (boardId == 'notice') return _isAdmin;
      return board['fabEnabled'] == true;
    }).toList();
  }

  IconData _boardIcon(String? iconName) {
    switch ((iconName ?? '').trim().toLowerCase()) {
      case 'help_outline':
        return Icons.help_outline;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'event_seat':
        return Icons.event_seat;
      case 'rate_review':
        return Icons.rate_review;
      case 'bug_report':
        return Icons.bug_report;
      case 'lightbulb_outline':
        return Icons.lightbulb_outline;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'campaign':
        return Icons.campaign;
      case 'local_fire_department':
        return Icons.local_fire_department;
      default:
        return Icons.dashboard_customize_outlined;
    }
  }

  Future<void> _openBoardSheet() async {
    if (_isSubmitting) return;
    try {
      await _ensureBoardsLoaded();
    } catch (e) {
      _showToast('게시판 목록을 불러오지 못했습니다.');
      return;
    }
    if (!mounted) return;

    final writableBoards = _writableBoards();
    if (writableBoards.isEmpty) {
      _showToast('작성 가능한 게시판이 없습니다.');
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.38,
          maxChildSize: 0.86,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 54,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBDBDBD),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '게시판 선택',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: writableBoards.length,
                        itemBuilder: (context, index) {
                          final board = writableBoards[index];
                          final boardId = (board['id'] ?? '').toString();
                          final boardName = (board['name'] ?? '').toString();
                          final description =
                              (board['description'] ?? '').toString();
                          final selected = boardId == _selectedBoardId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.of(context).pop(board),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.black
                                        : const Color(0xFFDADADA),
                                    width: selected ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _boardIcon(board['icon']?.toString()),
                                      color: Colors.black,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            boardName,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (description.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF707070),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons.chevron_right_rounded,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    final boardId = (selected['id'] ?? '').toString();
    final boardName = (selected['name'] ?? '').toString();
    if (boardId.isEmpty || boardName.isEmpty) return;
    setState(() {
      lateBoardId = boardId;
      lateBoardName = boardName;
    });
  }

  Future<void> _pickImages() async {
    if (_isPickingImages || _isSubmitting) return;
    if (_selectedImages.length >= _maxImages) {
      _showToast('이미지는 최대 $_maxImages개까지 첨부할 수 있습니다.');
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

      final remain = _maxImages - _selectedImages.length;
      setState(() {
        _selectedImages.addAll(picked.take(remain));
      });
      if (picked.length > remain) {
        _showToast('이미지는 최대 $_maxImages개까지만 첨부됩니다.');
      }
    } catch (e) {
      _showToast('이미지 선택 실패: $e');
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  Future<void> _openLinkDialog() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF111111), width: 1.2),
          ),
          title: const Text(
            '링크 추가',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'https://example.com',
              hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDADADA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.4),
              ),
            ),
            onSubmitted: (_) {
              Navigator.of(context).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.black54)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text(
                '저장',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    final normalized = _normalizeLink(link ?? '');
    if (normalized.isEmpty) return;
    setState(() {
      _links.add(normalized);
      final current = _contentController.text;
      final separator = current.trim().isEmpty
          ? ''
          : current.endsWith('\n')
              ? ''
              : '\n';
      _contentController.text = '$current$separator$normalized';
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
    });
  }

  Future<void> _openReadRestrictionSheet() async {
    if (!_canSetReadRestriction || _isSubmitting) return;

    final levels = CommunityAccessLevel.selectableLevels(_userProfile);
    final selectedRank = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '열람 제한',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _selectedReadRestriction == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Colors.black,
                ),
                title: const Text(
                  '전체 공개',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(0),
              ),
              const Divider(height: 1),
              ...levels.map((level) {
                final isSelected = _selectedReadRestriction?.rank == level.rank;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Colors.black,
                  ),
                  title: Text(
                    '${level.label} 이상',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(level.rank),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selectedRank == null) return;
    if (!mounted) return;
    setState(() {
      _selectedReadRestriction = CommunityAccessLevel.fromRank(selectedRank);
    });
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      _showToast('제목을 입력해주세요');
      return;
    }
    if (content.isEmpty &&
        _selectedImages.isEmpty &&
        _initialImageUrls.isEmpty) {
      _showToast('내용 또는 이미지를 추가해주세요');
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showToast('로그인이 필요합니다');
      return;
    }

    setState(() => _isSubmitting = true);
    _showLoadingDialog();

    try {
      final userProfile =
          await UserService.getUserFromFirestore(currentUser.uid);
      if (userProfile == null) {
        throw Exception('사용자 정보를 가져올 수 없습니다');
      }

      const uuid = Uuid();
      final postId = uuid.v4();
      final now = DateTime.now();
      final dateString = DateFormat('yyyyMMdd').format(now);

      final imageUrls = <String>[..._initialImageUrls];
      for (final image in _selectedImages) {
        final url = await FirebaseImageUploader.uploadImage(
          imageFile: File(image.path),
          postId: postId,
          dateString: dateString,
        );
        imageUrls.add(url);
      }

      final allocatedPostNumber = await FirebaseFirestore.instance
          .runTransaction<int>((transaction) async {
        final metaRef =
            FirebaseFirestore.instance.collection('meta').doc('postNumber');
        final snap = await transaction.get(metaRef);
        final data = snap.data();
        final current = ((data?['number'] ?? 0) as num).toInt();
        final next = current + 1;
        transaction.set(metaRef, {'number': next}, SetOptions(merge: true));
        return next;
      });

      final contentHtml = _buildContentHtml(
        contentText: content,
        imageUrls: imageUrls,
      );
      final roles = userProfile['roles'];
      final isAdmin = roles is List && roles.contains('admin');
      final structuredMeta = _buildStructuredMeta();
      final readRestriction =
          CommunityAccessLevel.canSetRestriction(userProfile)
              ? _selectedReadRestriction
              : null;

      final postData = <String, dynamic>{
        'postId': postId,
        'postNumber': allocatedPostNumber.toString(),
        'boardId': _selectedBoardId,
        'title': title,
        'contentHtml': contentHtml,
        'author': {
          'uid': currentUser.uid,
          'displayName': userProfile['displayName'] ?? '익명',
          'photoURL': userProfile['photoURL'] ?? '',
          'displayGrade':
              isAdmin ? '★★★' : (userProfile['displayGrade'] ?? '이코노미 Lv.1'),
          'currentSkyEffect': userProfile['currentSkyEffect'] ?? '',
        },
        'viewsCount': 0,
        'likesCount': 0,
        'commentCount': 0,
        'reportsCount': 0,
        'isDeleted': false,
        'isHidden': false,
        'hiddenByReport': false,
        'readRestriction': readRestriction?.toRestrictionMap() ??
            CommunityAccessLevel.unrestrictedMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.sourceChat != null) {
        postData['sourceChat'] = <String, dynamic>{
          ...widget.sourceChat!,
          'promotedBy': widget.sourceChat!['promotedBy'] ?? currentUser.uid,
          'promotedAt': FieldValue.serverTimestamp(),
        };
      }
      if (structuredMeta != null) {
        postData['structuredMeta'] = structuredMeta;
      }

      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(dateString)
          .collection('posts')
          .doc(postId);
      batch.set(postRef, postData);

      final myPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('my_posts')
          .doc(postId);
      batch.set(myPostRef, {
        'postPath': 'posts/$dateString/posts/$postId',
        'title': title,
        'boardId': _selectedBoardId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
        {'postsCount': FieldValue.increment(1)},
      );
      await batch.commit();

      try {
        final userData =
            await UserService.getUserFromFirestore(currentUser.uid);
        final currentPeanut = userData?['peanutCount'] ?? 0;
        await UserService.updatePeanutCount(
            currentUser.uid, currentPeanut + 10);
        await PeanutHistoryService.addHistory(
          userId: currentUser.uid,
          type: 'post_create',
          amount: 10,
          additionalData: {
            'postId': postId,
            'dateString': dateString,
            'boardId': _selectedBoardId,
            'postTitle': title,
          },
        );
      } catch (e) {
        debugPrint('땅콩 추가 오류: $e');
      }

      if (!mounted) return;
      _hideLoadingDialog();
      setState(() => _isSubmitting = false);
      _showToast('게시글이 성공적으로 등록되었습니다');
      Navigator.of(context).pop(false);
    } catch (e) {
      debugPrint('게시글 등록 오류: $e');
      if (!mounted) return;
      _hideLoadingDialog();
      setState(() => _isSubmitting = false);
      _showToast('게시글 등록 중 오류가 발생했습니다');
    }
  }

  String _buildContentHtml({
    required String contentText,
    required List<String> imageUrls,
  }) {
    final buffer = StringBuffer();
    final lines = contentText
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty);
    for (final line in lines) {
      buffer.write('<p>${_linkifyEscapedLine(line)}</p>');
    }
    for (final imageUrl in imageUrls) {
      buffer.write(
        '<p><img src="${_escapeHtmlAttribute(imageUrl)}" '
        'style="max-width: 100%; border-radius: 8px;" /></p>',
      );
    }
    return buffer.isEmpty ? '<p>이미지</p>' : buffer.toString();
  }

  String _linkifyEscapedLine(String line) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s<]+|www\.[^\s<]+)');
    final buffer = StringBuffer();
    var start = 0;
    for (final match in urlRegex.allMatches(line)) {
      buffer.write(_escapeHtml(line.substring(start, match.start)));
      final rawUrl = match.group(0) ?? '';
      final href = _normalizeLink(rawUrl);
      buffer.write(
        '<a href="${_escapeHtmlAttribute(href)}" target="_blank">'
        '${_escapeHtml(rawUrl)}</a>',
      );
      start = match.end;
    }
    buffer.write(_escapeHtml(line.substring(start)));
    return buffer.toString();
  }

  String _normalizeLink(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _escapeHtmlAttribute(String value) => _escapeHtml(value);

  Map<String, dynamic>? _buildStructuredMeta() {
    final hasTextValue = [
      _metaRouteController,
      _metaCarrierController,
      _metaCabinController,
      _metaMilesController,
      _metaTaxesController,
      _metaCashController,
      _metaCostController,
      _metaGiftcardController,
    ].any((controller) => controller.text.trim().isNotEmpty);
    if (!hasTextValue) return null;

    final meta = <String, dynamic>{
      'schemaVersion': 1,
      'type': _structuredTypeKey,
      'typeLabel': _structuredMetaType,
      'createdFrom': 'community_simple_editor',
    };

    void putString(String key, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) meta[key] = value;
    }

    void putInt(String key, TextEditingController controller) {
      final value = _parseMetaInt(controller.text);
      if (value != null) meta[key] = value;
    }

    void putDouble(String key, TextEditingController controller) {
      final value = _parseMetaDouble(controller.text);
      if (value != null) meta[key] = value;
    }

    putString('route', _metaRouteController);
    putString('carrierOrHotel', _metaCarrierController);
    putString('cabin', _metaCabinController);
    putString('giftcardBrand', _metaGiftcardController);
    putInt('miles', _metaMilesController);
    putInt('taxes', _metaTaxesController);
    putInt('cashPrice', _metaCashController);
    putDouble('costPerMile', _metaCostController);
    return meta;
  }

  String get _structuredTypeKey {
    switch (_structuredMetaType) {
      case '호텔':
        return 'hotel';
      case '상품권':
        return 'giftcard';
      case '발권':
      default:
        return 'ticketing';
    }
  }

  int? _parseMetaInt(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  double? _parseMetaDouble(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _plainTextFromHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
  }

  void _removeInitialImageAt(int index) {
    if (index < 0 || index >= _initialImageUrls.length) return;
    setState(() => _initialImageUrls.removeAt(index));
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeLink(String link) {
    setState(() {
      _links.remove(link);
      final lines = _contentController.text
          .split('\n')
          .where((line) => line.trim() != link)
          .toList();
      _contentController.text = lines.join('\n');
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
    });
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

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 3,
                ),
                SizedBox(height: 18),
                Text(
                  '게시글을 등록하고 있습니다...',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F1F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black,
        ),
        title: const Text(
          '새 게시물',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPost,
            child: Text(
              _isSubmitting ? '게시 중' : '게시',
              style: TextStyle(
                color: _isSubmitting ? Colors.black38 : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE2E2E2),
                      backgroundImage: _authorPhotoUrl.isNotEmpty
                          ? NetworkImage(_authorPhotoUrl)
                          : null,
                      child: _authorPhotoUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.black54,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _authorName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildBoardPill(),
                if (_canSetReadRestriction) ...[
                  const SizedBox(height: 10),
                  _buildReadRestrictionButton(),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    hintText: '제목',
                    hintStyle: TextStyle(
                      color: Color(0xFF9D9D9D),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(height: 12, color: Color(0xFFE3E3E3)),
                TextField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 16,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    hintText: '내용을 입력해주세요',
                    hintStyle: TextStyle(
                      color: Color(0xFFA0A0A0),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStructuredMetaSection(),
                if (_links.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _links.map((link) {
                      return InputChip(
                        label: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        deleteIconColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFD3D3D3)),
                        onDeleted: () => _removeLink(link),
                      );
                    }).toList(),
                  ),
                ],
                if (_initialImageUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _initialImageUrls.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final imageUrl = _initialImageUrls[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imageUrl, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removeInitialImageAt(index),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final image = _selectedImages[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                Image.file(File(image.path), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removeImageAt(index),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ToolButton(
                      icon: Icons.image_outlined,
                      label: _isPickingImages ? '불러오는 중' : '이미지',
                      onTap: _isPickingImages ? null : _pickImages,
                    ),
                    const SizedBox(width: 8),
                    _ToolButton(
                      icon: Icons.link_rounded,
                      label: '링크',
                      onTap: _openLinkDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardPill() {
    return InkWell(
      onTap: _openBoardSheet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize_outlined, color: Colors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedBoardName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildReadRestrictionButton() {
    final label = _selectedReadRestriction == null
        ? '전체 공개'
        : '${_selectedReadRestriction!.label} 이상';

    return InkWell(
      onTap: _openReadRestrictionSheet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD0D0D0), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              _selectedReadRestriction == null
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            const Text(
              '열람 제한',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredMetaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 18, color: Color(0xFFE3E3E3)),
        InkWell(
          onTap: () => setState(
            () => _structuredMetaExpanded = !_structuredMetaExpanded,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: Colors.black87),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '후기 메타',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  _structuredMetaExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['발권', '호텔', '상품권'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _structuredMetaType == type,
                    selectedColor: Colors.black,
                    labelStyle: TextStyle(
                      color: _structuredMetaType == type
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                    onSelected: (_) {
                      setState(() => _structuredMetaType = type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _buildMetaTextField(
                controller: _metaRouteController,
                label: _structuredMetaType == '호텔' ? '호텔/지역' : '노선',
                hint: _structuredMetaType == '호텔' ? '파크하얏트 부산' : 'ICN-JFK',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaCarrierController,
                      label: _structuredMetaType == '호텔'
                          ? '호텔 체인'
                          : _structuredMetaType == '상품권'
                              ? '거래처'
                              : '항공사',
                      hint: _structuredMetaType == '발권' ? '대한항공' : '',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaCabinController,
                      label: _structuredMetaType == '호텔' ? '객실' : '좌석',
                      hint: _structuredMetaType == '발권' ? '비즈니스' : '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaMilesController,
                      label: _structuredMetaType == '호텔' ? '포인트' : '마일',
                      hint: '62500',
                      suffix: _structuredMetaType == '호텔' ? 'pt' : 'mile',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaTaxesController,
                      label: '세금/수수료',
                      hint: '180000',
                      suffix: '원',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaCashController,
                      label: '현금가',
                      hint: '1500000',
                      suffix: '원',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetaTextField(
                      controller: _metaCostController,
                      label: '원가',
                      hint: '9.8',
                      suffix: '원/마일',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMetaTextField(
                controller: _metaGiftcardController,
                label: '상품권/카드',
                hint: '해피머니, 신한카드',
              ),
            ],
          ),
          crossFadeState: _structuredMetaExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }

  Widget _buildMetaTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADADA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADADA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1.3),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD5D5D5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: enabled ? Colors.black : Colors.black38, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.black : Colors.black38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
