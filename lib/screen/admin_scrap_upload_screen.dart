import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import '../services/admin_scrap_service.dart';
import '../services/category_service.dart';

class AdminScrapUploadScreen extends StatefulWidget {
  const AdminScrapUploadScreen({super.key});

  @override
  State<AdminScrapUploadScreen> createState() => _AdminScrapUploadScreenState();
}

class _AdminScrapUploadScreenState extends State<AdminScrapUploadScreen> {
  static const Color _background = Color(0xFFF7F7FA);
  static const Color _accent = Color(0xFF74512D);
  static const Color _text = Color(0xFF1F2533);
  static const Color _muted = Color(0xFF737B8C);
  static const String _defaultBoardId = 'milecatch_guide';
  static const String _defaultAuthorUid = 'aP3C0N511beyK7QZG9GyChs5oqO2';
  static const String _defaultAuthorSearchText = '마일캐치';

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();

  AdminScrapSource _source = AdminScrapSource.naverBlog;
  AdminScrapValidationResult? _validation;
  AdminScrapUserCandidate? _selectedUser;
  List<Map<String, dynamic>> _categories = const <Map<String, dynamic>>[];
  List<AdminScrapUserCandidate> _userResults =
      const <AdminScrapUserCandidate>[];
  String? _selectedBoardId;
  bool _loadingCategories = true;
  bool _validating = false;
  bool _searchingUsers = false;
  bool _publishing = false;
  Object? _categoryError;

  bool get _canPublish {
    return !_publishing &&
        _validation?.canPublish == true &&
        _selectedBoardId != null &&
        _selectedUser != null &&
        _titleController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _userSearchController.text = _defaultAuthorSearchText;
    _loadCategories();
    _loadDefaultAuthor();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final boards = await CategoryService().getBoards();
      final usableBoards = boards
          .where((board) => (board['id'] ?? '').toString() != 'seats')
          .toList(growable: false);
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

  String? _preferredBoardId(List<Map<String, dynamic>> boards) {
    if (boards.isEmpty) {
      return null;
    }

    final directMatch = boards
        .where((board) => (board['id'] ?? '').toString() == _defaultBoardId)
        .firstOrNull;
    if (directMatch != null) {
      return (directMatch['id'] ?? '').toString();
    }

    final nameMatch = boards.where((board) {
      final name = (board['name'] ?? '').toString().replaceAll(' ', '');
      return name == '마일캐치사용법';
    }).firstOrNull;
    if (nameMatch != null) {
      return (nameMatch['id'] ?? '').toString();
    }

    final freeBoard = boards
        .where((board) => (board['id'] ?? '').toString() == 'free')
        .firstOrNull;
    return ((freeBoard ?? boards.first)['id'] ?? '').toString();
  }

  Future<void> _loadDefaultAuthor() async {
    setState(() => _searchingUsers = true);
    try {
      final defaultUser =
          await AdminScrapService.getUserByUid(_defaultAuthorUid);
      final users = defaultUser == null
          ? await AdminScrapService.searchUsers(_defaultAuthorSearchText)
          : <AdminScrapUserCandidate>[defaultUser];
      if (!mounted) return;
      setState(() {
        _userResults = users;
        _selectedUser = defaultUser ?? _pickDefaultAuthor(users);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userResults = const <AdminScrapUserCandidate>[];
        _selectedUser = null;
      });
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  AdminScrapUserCandidate? _pickDefaultAuthor(
    List<AdminScrapUserCandidate> users,
  ) {
    if (users.isEmpty) {
      return null;
    }
    for (final user in users) {
      if (user.uid == _defaultAuthorUid) {
        return user;
      }
    }
    for (final user in users) {
      if (user.displayName.trim() == _defaultAuthorSearchText) {
        return user;
      }
    }
    return users.first;
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

  void _changeSource(AdminScrapSource source) {
    if (_source == source) return;
    setState(() {
      _source = source;
      _validation = null;
      _titleController.clear();
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
      final result = await AdminScrapService.validateScrapPost(
        url: url,
        source: _source,
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

  Future<void> _searchUsers() async {
    final query = _userSearchController.text.trim();
    if (query.isEmpty) {
      _showSnack('작성자 이름, 이메일 또는 UID를 입력해주세요.', isError: true);
      return;
    }
    setState(() {
      _searchingUsers = true;
      _userResults = const <AdminScrapUserCandidate>[];
    });
    try {
      final users = await AdminScrapService.searchUsers(query);
      if (!mounted) return;
      setState(() => _userResults = users);
      if (users.isEmpty) {
        _showSnack('검색 결과가 없습니다.');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack('사용자 검색 실패: $error', isError: true);
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  Future<void> _publish() async {
    final validation = _validation;
    final user = _selectedUser;
    final boardId = _selectedBoardId;
    if (validation == null || user == null || boardId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('스크랩 게시글 업로드'),
          content: Text('${user.displayName} 명의로 게시글을 업로드할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('업로드'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _publishing = true);
    try {
      final result = await AdminScrapService.publishScrapPost(
        url: validation.normalizedUrl,
        source: _source,
        boardId: boardId,
        authorUid: user.uid,
        titleOverride: _titleController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('업로드 완료'),
            content: Text(
              'postNumber=${result.postNumber}\n'
              'dateString=${result.dateString}\n'
              'postId=${result.postId}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      setState(() {
        _validation = null;
        _titleController.clear();
        _urlController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('업로드 실패: $error', isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('스크랩 업로드'),
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
          _SectionCard(
            title: '소스와 URL',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: AdminScrapSource.values.map((source) {
                    return ChoiceChip(
                      selected: _source == source,
                      label: Text(source.label),
                      onSelected: (_) => _changeSource(source),
                      selectedColor: const Color(0xFFE9DED2),
                      labelStyle: TextStyle(
                        color: _source == source ? _accent : _text,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: switch (_source) {
                      AdminScrapSource.naverBlog =>
                        'https://m.blog.naver.com/...',
                      AdminScrapSource.naverCafe =>
                        'https://cafe.naver.com/...',
                      AdminScrapSource.aagag =>
                        'https://aagag.com/issue/?idx=...',
                    },
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
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '발행 설정',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchController,
                        decoration: const InputDecoration(
                          labelText: '작성자 검색',
                          hintText: '닉네임, 이메일, UID',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _searchUsers(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '검색',
                      onPressed: _searchingUsers ? null : _searchUsers,
                      icon: _searchingUsers
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                if (_selectedUser != null) ...[
                  const SizedBox(height: 10),
                  _SelectedUserTile(user: _selectedUser!),
                ],
                if (_userResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._userResults.map((user) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UserResultTile(
                        user: user,
                        selected: _selectedUser?.uid == user.uid,
                        onTap: () => setState(() => _selectedUser = user),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          if (_validation != null) ...[
            const SizedBox(height: 12),
            _ValidationSection(
              validation: _validation!,
              titleController: _titleController,
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationSection extends StatelessWidget {
  const _ValidationSection({
    required this.validation,
    required this.titleController,
  });

  final AdminScrapValidationResult validation;
  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
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
              _InfoChip(
                icon: validation.canPublish
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                text: validation.canPublish ? '업로드 가능' : '업로드 불가',
                color: validation.canPublish ? Colors.green : Colors.red,
              ),
              _InfoChip(
                icon: Icons.image_outlined,
                text: '이미지 ${validation.mediaCounts.images}',
              ),
              _InfoChip(
                icon: Icons.movie_outlined,
                text: '영상 ${validation.mediaCounts.videos}',
              ),
              _InfoChip(
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
                color: _AdminScrapUploadScreenState._muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (validation.normalizedUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              validation.normalizedUrl,
              style: const TextStyle(
                color: _AdminScrapUploadScreenState._muted,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
              color: _AdminScrapUploadScreenState._text,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    this.color = _AdminScrapUploadScreenState._accent,
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

class _SelectedUserTile extends StatelessWidget {
  const _SelectedUserTile({required this.user});

  final AdminScrapUserCandidate user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '선택됨: ${user.displayName} (${user.uid})',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AdminScrapUserCandidate user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9DED2) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _AdminScrapUploadScreenState._accent
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              child: user.photoUrl.isEmpty
                  ? Text(user.displayName.characters.first)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    [
                      if (user.email.isNotEmpty) user.email,
                      if (user.displayGrade.isNotEmpty) user.displayGrade,
                      user.uid,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AdminScrapUploadScreenState._muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_rounded),
          ],
        ),
      ),
    );
  }
}
