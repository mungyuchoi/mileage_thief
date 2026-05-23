import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/community_label_model.dart';
import '../services/admin_scrap_service.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';
import '../services/community_label_service.dart';
import '../services/user_service.dart';
import '../widgets/community_label_picker_sheet.dart';

class UserScrapUploadResult {
  const UserScrapUploadResult({
    required this.boardId,
    required this.boardName,
    required this.postId,
    required this.postNumber,
    required this.dateString,
    required this.postPath,
  });

  final String boardId;
  final String boardName;
  final String postId;
  final String postNumber;
  final String dateString;
  final String postPath;
}

enum UserScrapUploadSource {
  naverBlog,
  naverCafe,
}

extension UserScrapUploadSourceMeta on UserScrapUploadSource {
  String get label {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return '블로그';
      case UserScrapUploadSource.naverCafe:
        return '카페';
    }
  }

  String get appBarTitle {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return '블로그 스크랩';
      case UserScrapUploadSource.naverCafe:
        return '카페 스크랩';
    }
  }

  String get sectionTitle {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return '네이버 블로그 URL';
      case UserScrapUploadSource.naverCafe:
        return '네이버 카페 URL';
    }
  }

  String get sourceChipText {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return '네이버 블로그';
      case UserScrapUploadSource.naverCafe:
        return '네이버 카페';
    }
  }

  String get urlHint {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return 'https://m.blog.naver.com/...';
      case UserScrapUploadSource.naverCafe:
        return 'https://cafe.naver.com/...';
    }
  }

  IconData get icon {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return Icons.article_outlined;
      case UserScrapUploadSource.naverCafe:
        return Icons.forum_outlined;
    }
  }

  AdminScrapSource get scrapSource {
    switch (this) {
      case UserScrapUploadSource.naverBlog:
        return AdminScrapSource.naverBlog;
      case UserScrapUploadSource.naverCafe:
        return AdminScrapSource.naverCafe;
    }
  }
}

class UserScrapUploadScreen extends StatefulWidget {
  const UserScrapUploadScreen({
    super.key,
    this.initialSource = UserScrapUploadSource.naverBlog,
    this.initialLabels = const <CommunityLabel>[],
    this.preferredBoardId,
    this.preferredBoardNameKeywords = const <String>[],
  });

  final UserScrapUploadSource initialSource;
  final List<CommunityLabel> initialLabels;
  final String? preferredBoardId;
  final List<String> preferredBoardNameKeywords;

  @override
  State<UserScrapUploadScreen> createState() => _UserScrapUploadScreenState();
}

class _UserScrapUploadScreenState extends State<UserScrapUploadScreen> {
  static const Color _background = Color(0xFFF7F7FA);
  static const Color _accent = Color(0xFF74512D);
  static const Color _text = Color(0xFF1F2533);
  static const Color _muted = Color(0xFF737B8C);
  static const int _maxCommunityLabels = 5;
  static const Set<String> _blockedBoardIds = {
    'notice',
    'milecatch_guide',
    'seats',
  };

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final CommunityLabelService _labelService = CommunityLabelService();
  late final PageController _sourcePageController;
  late UserScrapUploadSource _source;

  AdminScrapValidationResult? _validation;
  List<CommunityLabel> _selectedLabels = <CommunityLabel>[];
  List<Map<String, dynamic>> _categories = const <Map<String, dynamic>>[];
  User? _firebaseUser;
  Map<String, dynamic>? _authorProfile;
  String? _selectedBoardId;
  bool _loadingAuthor = true;
  bool _loadingCategories = true;
  bool _validating = false;
  bool _publishing = false;
  Object? _categoryError;
  Object? _authorError;

  bool get _canPublish {
    return !_publishing &&
        _firebaseUser != null &&
        _validation?.canPublish == true &&
        _selectedBoardId != null &&
        _titleController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
    _selectedLabels = CommunityLabel.dedupe(widget.initialLabels)
        .take(_maxCommunityLabels)
        .toList(growable: false);
    _sourcePageController = PageController(initialPage: _source.index);
    _titleController.addListener(_onTitleChanged);
    _loadAuthor();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _sourcePageController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAuthor() async {
    final user = AuthService.currentUser;
    setState(() {
      _firebaseUser = user;
      _loadingAuthor = true;
      _authorError = null;
    });
    if (user == null) {
      setState(() => _loadingAuthor = false);
      return;
    }

    try {
      final profile = await UserService.getUserFromFirestore(user.uid);
      if (!mounted) return;
      setState(() {
        _authorProfile = profile;
        _loadingAuthor = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authorError = error;
        _loadingAuthor = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final boards = await CategoryService().getBoards();
      final usableBoards =
          boards.where(_isUserScrapBoard).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _categories = usableBoards;
        _selectedBoardId = _preferredBoardId(usableBoards);
        _loadingCategories = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoryError = error;
        _loadingCategories = false;
      });
    }
  }

  bool _isUserScrapBoard(Map<String, dynamic> board) {
    final boardId = (board['id'] ?? '').toString();
    return !_blockedBoardIds.contains(boardId) && board['fabEnabled'] == true;
  }

  String? _preferredBoardId(List<Map<String, dynamic>> boards) {
    if (boards.isEmpty) return null;
    final preferredKeywords = widget.preferredBoardNameKeywords
        .map(_normalizeBoardSearchText)
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
    if (preferredKeywords.isNotEmpty) {
      for (final board in boards) {
        final id = (board['id'] ?? '').toString();
        final name = (board['name'] ?? id).toString();
        final group = (board['group'] ?? '').toString();
        final searchable = _normalizeBoardSearchText('$id $name $group');
        if (preferredKeywords.any((keyword) => searchable.contains(keyword))) {
          return id;
        }
      }
    }
    final preferredBoardId = widget.preferredBoardId?.trim();
    if (preferredBoardId != null && preferredBoardId.isNotEmpty) {
      for (final board in boards) {
        if ((board['id'] ?? '').toString() == preferredBoardId) {
          return preferredBoardId;
        }
      }
    }
    for (final board in boards) {
      if ((board['id'] ?? '').toString() == 'free') {
        return 'free';
      }
    }
    return (boards.first['id'] ?? '').toString();
  }

  String _normalizeBoardSearchText(String value) {
    return value.replaceAll(RegExp(r'[\s/_·-]+'), '').toLowerCase().trim();
  }

  Map<String, dynamic>? _selectedBoard() {
    final boardId = _selectedBoardId;
    if (boardId == null) return null;
    for (final board in _categories) {
      if ((board['id'] ?? '').toString() == boardId) {
        return board;
      }
    }
    return null;
  }

  String get _selectedBoardName {
    final board = _selectedBoard();
    if (board == null) return _selectedBoardId ?? '';
    return (board['name'] ?? board['id'] ?? '').toString();
  }

  String get _authorDisplayName {
    final profileName =
        (_authorProfile?['displayName'] ?? '').toString().trim();
    if (profileName.isNotEmpty) return profileName;
    final user = _firebaseUser;
    return user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim().isNotEmpty == true
            ? user!.email!.trim()
            : '사용자';
  }

  String get _authorPhotoUrl {
    final profilePhoto = (_authorProfile?['photoURL'] ?? '').toString().trim();
    if (profilePhoto.isNotEmpty) return profilePhoto;
    return _firebaseUser?.photoURL?.trim() ?? '';
  }

  String get _authorGrade {
    final grade = (_authorProfile?['displayGrade'] ?? '').toString().trim();
    return grade.isEmpty ? '이코노미 Lv.1' : grade;
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _urlController.text = text;
      _validation = null;
    });
  }

  Future<void> _validate() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('URL을 입력해주세요.', isError: true);
      return;
    }
    setState(() {
      _validating = true;
      _validation = null;
    });
    try {
      final result = await AdminScrapService.validateUserScrapPost(
        url: url,
        source: _source.scrapSource,
      );
      if (!mounted) return;
      setState(() {
        _validation = result;
        _titleController.text = result.title;
      });
      _showSnack(result.canPublish ? '검증이 완료되었습니다.' : '검증 경고를 확인해주세요.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('검증 실패: $error', isError: true);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _publish() async {
    final validation = _validation;
    final boardId = _selectedBoardId;
    if (validation == null || boardId == null || _firebaseUser == null) return;

    var uploaded = false;
    setState(() => _publishing = true);
    try {
      final result = await AdminScrapService.publishUserScrapPost(
        url: validation.normalizedUrl,
        boardId: boardId,
        titleOverride: _titleController.text.trim(),
        source: _source.scrapSource,
        labels: _selectedLabels,
      );
      if (!mounted) return;
      uploaded = true;
      Fluttertoast.showToast(msg: '정상적으로 업로드되었습니다.');
      Navigator.of(context).pop(
        UserScrapUploadResult(
          boardId: boardId,
          boardName: _selectedBoardName,
          postId: result.postId,
          postNumber: result.postNumber,
          dateString: result.dateString,
          postPath: result.postPath,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('업로드 실패: $error', isError: true);
    } finally {
      if (mounted && !uploaded) setState(() => _publishing = false);
    }
  }

  void _changeSource(UserScrapUploadSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _validation = null;
    });
    final page = source.index;
    if (_sourcePageController.hasClients &&
        (_sourcePageController.page?.round() ?? page) != page) {
      _sourcePageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSourcePageChanged(int page) {
    final next = UserScrapUploadSource.values[page];
    if (_source == next) return;
    setState(() {
      _source = next;
      _validation = null;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ),
    );
  }

  Future<void> _openLabelPicker() async {
    if (_publishing) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return CommunityLabelPickerSheet(
          selectedLabels: _selectedLabels,
          maxLabels: _maxCommunityLabels,
          labelService: _labelService,
          accentColor: _accent,
          onChanged: (labels) {
            if (!mounted) return;
            setState(() {
              _selectedLabels = labels;
            });
          },
        );
      },
    );
  }

  Widget _buildLabelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.label_outline, color: _muted, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '라벨',
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed:
                  _selectedLabels.length >= _maxCommunityLabels || _publishing
                      ? null
                      : _openLabelPicker,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        if (_selectedLabels.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '지점, 상품권, 카드 라벨을 연결할 수 있습니다.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in _selectedLabels)
                  InputChip(
                    avatar: Icon(
                      _labelIcon(label.type),
                      size: 16,
                      color: _accent,
                    ),
                    label: Text(
                      label.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                    backgroundColor: const Color(0xFFF8F4EF),
                    side: const BorderSide(color: Color(0xFFE7D8C6)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _publishing
                        ? null
                        : () {
                            setState(() {
                              _selectedLabels = _selectedLabels
                                  .where((item) => item.key != label.key)
                                  .toList(growable: false);
                            });
                          },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _labelIcon(String type) {
    switch (type) {
      case 'branch':
        return Icons.storefront_outlined;
      case 'giftcard':
        return Icons.card_giftcard_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'calculator':
        return Icons.calculate_outlined;
      case 'feature':
        return Icons.hotel_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Widget _buildSourceTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final source in UserScrapUploadSource.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _changeSource(source),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _source == source ? Colors.white : null,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _source == source
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        source.icon,
                        size: 17,
                        color: _source == source ? _accent : _muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        source.label,
                        style: TextStyle(
                          color: _source == source ? _accent : _muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUrlPage(UserScrapUploadSource source) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserScrapInfoChip(
          icon: source.icon,
          text: source.sourceChipText,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'URL',
            hintText: source.urlHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: '붙여넣기',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: _pasteUrl,
            ),
          ),
          onChanged: (_) => setState(() => _validation = null),
          onSubmitted: (_) => _validate(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _validating ? null : _validate,
            icon: _validating
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(_validating ? '검증 중...' : '검증'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(_source.appBarTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _canPublish ? _publish : null,
            icon: _publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_publishing ? '업로드 중...' : '업로드'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _UserScrapSectionCard(
            title: _source.sectionTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSourceTabs(),
                const SizedBox(height: 14),
                SizedBox(
                  height: 160,
                  child: PageView(
                    controller: _sourcePageController,
                    onPageChanged: _onSourcePageChanged,
                    children: [
                      for (final source in UserScrapUploadSource.values)
                        _buildUrlPage(source),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _UserScrapSectionCard(
            title: '게시 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingCategories)
                  const Center(child: CircularProgressIndicator())
                else if (_categoryError != null)
                  Row(
                    children: [
                      Expanded(child: Text('카테고리 로드 실패: $_categoryError')),
                      IconButton(
                        tooltip: '다시 시도',
                        onPressed: _loadCategories,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBoardId,
                    decoration: const InputDecoration(
                      labelText: '카테고리',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((board) {
                      final id = (board['id'] ?? '').toString();
                      final name = (board['name'] ?? id).toString();
                      final group = (board['group'] ?? '').toString();
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(group.isEmpty ? name : '$group · $name'),
                      );
                    }).toList(growable: false),
                    onChanged: (value) => setState(() {
                      _selectedBoardId = value;
                    }),
                  ),
                const SizedBox(height: 14),
                _buildLabelSection(),
                const SizedBox(height: 14),
                if (_loadingAuthor)
                  const Center(child: CircularProgressIndicator())
                else if (_firebaseUser == null)
                  const Text('로그인 후 스크랩 업로드를 사용할 수 있습니다.')
                else
                  _FixedAuthorTile(
                    displayName: _authorDisplayName,
                    photoUrl: _authorPhotoUrl,
                    displayGrade: _authorGrade,
                    uid: _firebaseUser!.uid,
                    error: _authorError,
                  ),
              ],
            ),
          ),
          if (_validation != null) ...[
            const SizedBox(height: 12),
            _UserScrapValidationSection(
              validation: _validation!,
              titleController: _titleController,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserScrapValidationSection extends StatelessWidget {
  const _UserScrapValidationSection({
    required this.validation,
    required this.titleController,
  });

  final AdminScrapValidationResult validation;
  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    return _UserScrapSectionCard(
      title: '검증 결과',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _UserScrapInfoChip(
                icon: validation.canPublish
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                text: validation.canPublish ? '업로드 가능' : '업로드 불가',
                color: validation.canPublish ? Colors.green : Colors.red,
              ),
              _UserScrapInfoChip(
                icon: Icons.image_outlined,
                text: '이미지 ${validation.mediaCounts.images}',
              ),
              _UserScrapInfoChip(
                icon: Icons.movie_outlined,
                text: '영상 ${validation.mediaCounts.videos}',
              ),
              _UserScrapInfoChip(
                icon: Icons.link_rounded,
                text: '링크 ${validation.mediaCounts.links}',
              ),
            ],
          ),
          if (validation.scrapedAuthor.isNotEmpty ||
              validation.scrapedDateText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              [
                validation.scrapedAuthor,
                validation.scrapedDateText,
              ].where((item) => item.isNotEmpty).join(' · '),
              style: const TextStyle(
                color: _UserScrapUploadScreenState._muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (validation.normalizedUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              validation.normalizedUrl,
              style: const TextStyle(
                color: _UserScrapUploadScreenState._muted,
                fontSize: 12,
              ),
            ),
          ],
          if (validation.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final warning in validation.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          const Text(
            '미리보기',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SingleChildScrollView(
              child: Html(
                data: validation.previewHtml,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    fontSize: FontSize(14),
                    lineHeight: const LineHeight(1.4),
                  ),
                  'img': Style(display: Display.block),
                },
                extensions: [
                  TagExtension(
                    tagsToExtend: {'video'},
                    builder: (ctx) {
                      final src = ctx.attributes['src'] ?? '';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF2F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.movie_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                src.isEmpty ? '영상' : src,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserScrapSectionCard extends StatelessWidget {
  const _UserScrapSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _UserScrapUploadScreenState._text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _UserScrapInfoChip extends StatelessWidget {
  const _UserScrapInfoChip({
    required this.icon,
    required this.text,
    this.color = _UserScrapUploadScreenState._accent,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAuthorTile extends StatelessWidget {
  const _FixedAuthorTile({
    required this.displayName,
    required this.photoUrl,
    required this.displayGrade,
    required this.uid,
    required this.error,
  });

  final String displayName;
  final String photoUrl;
  final String displayGrade;
  final String uid;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final secondaryText = [
      displayGrade,
      uid,
      if (error != null) '프로필 일부를 불러오지 못했습니다',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty ? Text(displayName.characters.first) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _UserScrapUploadScreenState._muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline_rounded, color: Colors.green),
        ],
      ),
    );
  }
}
