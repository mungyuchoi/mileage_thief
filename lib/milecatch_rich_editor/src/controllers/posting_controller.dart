import 'package:flutter/material.dart';
import '../models/editor_state.dart';
import '../models/toolbar_state.dart';
import '../models/posting_data.dart';
import '../models/attachment_file.dart';
import 'editor_controller.dart';
import 'attachment_controller.dart';

// Category 모델 (간단한 버전)
class Category {
  final String id;
  final String name;
  final IconData? icon;
  final Color? color;

  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class PostingController extends ChangeNotifier {
  EditorState _editorState = const EditorState();
  ToolbarState _toolbarState = const ToolbarState();
  PostingData _postingData = const PostingData();
  final List<AttachmentFile> _attachments = [];
  Category? _selectedCategory;
  
  final TextEditingController _titleController = TextEditingController();
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isUploading = false;

  // Controllers
  final EditorController _editorController = EditorController();
  final AttachmentController _attachmentController = AttachmentController();

  PostingController() {
    _titleController.addListener(_onTitleChanged);
    
    // 에디터 컨트롤러 이벤트 리스너 설정
    _editorController.onTextChanged = _onTextChanged;
    _editorController.onStateChanged = _onEditorStateChanged;
    
    // 첨부파일 컨트롤러 이벤트 리스너 설정
    _attachmentController.addListener(_onAttachmentsChanged);
  }

  // Getters
  EditorState get editorState => _editorState;
  ToolbarState get toolbarState => _toolbarState;
  PostingData get postingData => _postingData;
  List<AttachmentFile> get attachments => List.unmodifiable(_attachments);
  Category? get selectedCategory => _selectedCategory;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isUploading => _isUploading;
  String get title => _titleController.text;
  String get content => _editorState.currentText;

  // Controllers 접근
  EditorController get editorController => _editorController;
  AttachmentController get attachmentController => _attachmentController;
  TextEditingController get titleController => _titleController;

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _editorController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  /// 에디터 상태를 업데이트합니다
  void updateEditorState(EditorState newState) {
    _editorState = newState;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 툴바 상태를 업데이트합니다
  void updateToolbarState(ToolbarState newState) {
    _toolbarState = newState;
    notifyListeners();
  }

  /// 제목을 업데이트합니다
  void updateTitle(String title) {
    _titleController.text = title;
  }

  /// 내용을 업데이트합니다
  void updateContent(String content) {
    _editorController.setHtml(content);
  }

  /// 카테고리를 선택합니다
  void selectCategory(Category? category) {
    _selectedCategory = category;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 공개 여부를 설정합니다
  void setPublic(bool isPublic) {
    _postingData = _postingData.copyWith(isPublic: isPublic);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 태그를 추가합니다
  void addTag(String tag) {
    if (tag.trim().isEmpty || _postingData.tags.contains(tag)) {
      return;
    }
    
    final newTags = List<String>.from(_postingData.tags)..add(tag.trim());
    _postingData = _postingData.copyWith(tags: newTags);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 태그를 제거합니다
  void removeTag(String tag) {
    final newTags = List<String>.from(_postingData.tags)..remove(tag);
    _postingData = _postingData.copyWith(tags: newTags);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 이미지를 첨부합니다
  Future<bool> attachImage(String imagePath) async {
    try {
      _isUploading = true;
      notifyListeners();

      final attachment = await _attachmentController.pickImageFromGallery();
      if (attachment != null) {
        _attachments.add(attachment);
        _hasUnsavedChanges = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to attach image: $e');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 파일을 첨부합니다
  Future<bool> attachFile(String filePath) async {
    try {
      _isUploading = true;
      notifyListeners();

      final attachment = await _attachmentController.pickFile();
      if (attachment != null) {
        _attachments.add(attachment);
        _hasUnsavedChanges = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to attach file: $e');
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 첨부파일을 제거합니다
  void removeAttachment(String attachmentId) {
    _attachments.removeWhere((attachment) => attachment.id == attachmentId);
    _attachmentController.removeAttachment(attachmentId);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// 게시글을 저장합니다
  Future<bool> savePost() async {
    try {
      _isSaving = true;
      notifyListeners();

      // 유효성 검사
      final validation = validatePost();
      if (validation.isNotEmpty) {
        print('Validation errors: $validation');
        return false;
      }

      // PostingData 업데이트
      _postingData = _postingData.copyWith(
        title: _titleController.text.trim(),
        content: _editorState.currentText,
        categoryId: _selectedCategory?.id,
        attachments: List.from(_attachments),
        updatedAt: DateTime.now(),
      );

      // 실제 저장 로직 (Firebase, API 호출 등)
      await Future.delayed(const Duration(seconds: 2)); // 시뮬레이션

      _hasUnsavedChanges = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to save post: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 임시 저장합니다
  Future<bool> saveDraft() async {
    try {
      _isSaving = true;
      notifyListeners();

      // PostingData 업데이트
      _postingData = _postingData.copyWith(
        title: _titleController.text.trim(),
        content: _editorState.currentText,
        categoryId: _selectedCategory?.id,
        attachments: List.from(_attachments),
        updatedAt: DateTime.now(),
      );

      // 임시 저장 로직 (SharedPreferences 등)
      await Future.delayed(const Duration(seconds: 1)); // 시뮬레이션

      return true;
    } catch (e) {
      print('Failed to save draft: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 초기화합니다
  void reset() {
    _editorState = const EditorState();
    _toolbarState = const ToolbarState();
    _postingData = const PostingData();
    _attachments.clear();
    _selectedCategory = null;
    _titleController.clear();
    _isSaving = false;
    _hasUnsavedChanges = false;
    _isUploading = false;
    
    _editorController.reset();
    _attachmentController.clearAttachments();
    
    notifyListeners();
  }

  /// 게시글을 불러옵니다
  void loadPost(PostingData post) {
    _postingData = post;
    _titleController.text = post.title;
    _editorController.setHtml(post.content);
    _attachments.clear();
    _attachments.addAll(post.attachments);
    _hasUnsavedChanges = false;
    
    notifyListeners();
  }

  /// 게시글을 검증합니다
  Map<String, String?> validatePost() {
    final errors = <String, String?>{};

    // 제목 검증
    if (_titleController.text.trim().isEmpty) {
      errors['title'] = '제목을 입력해주세요.';
    } else if (_titleController.text.trim().length > 100) {
      errors['title'] = '제목은 100자 이내로 입력해주세요.';
    }

    // 내용 검증
    if (_editorState.currentText.trim().isEmpty) {
      errors['content'] = '내용을 입력해주세요.';
    } else if (_editorState.currentText.length > 50000) {
      errors['content'] = '내용이 너무 깁니다. 50,000자 이내로 입력해주세요.';
    }

    // 카테고리 검증 (필요한 경우)
    if (_selectedCategory == null) {
      errors['category'] = '카테고리를 선택해주세요.';
    }

    // 첨부파일 검증
    if (_attachments.length > 20) {
      errors['attachments'] = '첨부파일은 최대 20개까지만 첨부할 수 있습니다.';
    }

    return errors;
  }

  // 이벤트 핸들러들
  void _onTitleChanged() {
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void _onTextChanged(String text) {
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void _onEditorStateChanged(EditorState state) {
    updateEditorState(state);
  }

  void _onAttachmentsChanged() {
    _attachments.clear();
    _attachments.addAll(_attachmentController.attachments);
    _hasUnsavedChanges = true;
    notifyListeners();
  }
}

