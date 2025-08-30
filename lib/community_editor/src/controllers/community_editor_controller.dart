import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:io';
import '../models/community_editor_state.dart';
import '../models/community_post_data.dart';
import '../constants/community_editor_constants.dart';
import '../utils/firebase_image_uploader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mileage_thief/utils/image_compressor.dart' as app_compress;

/// 커뮤니티 에디터의 컨트롤러입니다.
/// WebView 기반 HTML 에디터로 제목, 내용, 이미지, 텍스트 포맷팅 등을 관리합니다.
class CommunityEditorController extends ChangeNotifier {
  // 기본 컨트롤러들
  final TextEditingController titleController = TextEditingController();
  final FocusNode titleFocusNode = FocusNode();

  // WebView 컨트롤러
  WebViewController? _webViewController;

  // 상태 관리
  CommunityEditorState _state = const CommunityEditorState();
  CommunityPostData _postData = const CommunityPostData();

  // 이미지 선택기
  final ImagePicker _imagePicker = ImagePicker();

  // 콜백 함수
  Function(CommunityEditorState)? onStateChanged;

  // 현재 HTML 내용
  String _currentHtml = '';

  CommunityEditorController() {
    _setupListeners();
  }

  // Getters
  CommunityEditorState get state => _state;
  CommunityPostData get postData => _postData;
  bool get showToolbar => _state.showToolbar;
  bool get hasUnsavedChanges => _postData.hasUnsavedChanges;

  void _setupListeners() {
    // 제목 필드 리스너
    titleController.addListener(() {
      _updatePostData(title: titleController.text);
    });

    titleFocusNode.addListener(() {
      _updateState(
        isTitleFocused: titleFocusNode.hasFocus,
        showToolbar: false, // 제목에서는 툴바 숨김
        isContentFocused: false, // 제목 포커스시 에디터 포커스 해제
        isFocused: titleFocusNode.hasFocus,
      );
    });
  }

  /// WebView 컨트롤러를 설정합니다.
  void setWebViewController(WebViewController controller) {
    _webViewController = controller;
  }

  /// JavaScript 메시지를 처리합니다.
  void handleJavaScriptMessage(String message) {
    try {
      final data = json.decode(message) as Map<String, dynamic>;
      _processJavaScriptMessage(data);
    } catch (e) {
      print('Error handling JavaScript message: $e');
    }
  }

  /// JavaScript 메시지를 처리합니다.
  void _processJavaScriptMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final messageData = data['data'] as Map<String, dynamic>?;

    switch (type) {
      case CommunityEditorConstants.messageTypeReady:
        _updateState(isReady: true);
        break;
      case CommunityEditorConstants.messageTypeTextChanged:
        final content = messageData?['content'] as String? ?? '';
        final text = messageData?['text'] as String? ?? '';
        _currentHtml = content;
        _updatePostData(contentHtml: content);
        _updateState(currentText: text, isDirty: true);
        break;
      case CommunityEditorConstants.messageTypeFocus:
      // 웹뷰에 포커스가 갈 때 제목 포커스 해제
        titleFocusNode.unfocus();
        _updateState(
          isContentFocused: true,
          isFocused: true,
          isTitleFocused: false,
          showToolbar: true,
        );
        break;
      case CommunityEditorConstants.messageTypeBlur:
        _updateState(
          isContentFocused: false,
          isFocused: false,
          showToolbar: false,
        );
        break;
      case CommunityEditorConstants.messageTypeImageInserted:
      // 이미지 삽입 완료 알림
        break;
      case CommunityEditorConstants.messageTypeFormatChanged:
      // 포맷 상태 업데이트
        final formatState = messageData?['formatState'] as Map<String, dynamic>?;
        if (formatState != null) {
          final convertedFormatState = <String, bool>{};
          formatState.forEach((key, value) {
            convertedFormatState[key] = value == true;
          });
          print('Format state updated: $convertedFormatState'); // 디버그 로그
          _updateState(formatState: convertedFormatState);
        }
        break;
      default:
        print('Unknown message type: $type');
    }
  }

  /// 초기 데이터로 에디터를 설정합니다.
  void initializeWithData({
    String? boardId,
    String? boardName,
    bool isEditMode = false,
    String? postId,
    String? dateString,
    String? editTitle,
    String? editContentHtml,
  }) {
    _postData = CommunityPostData(
      boardId: boardId,
      boardName: boardName,
      isEditMode: isEditMode,
      postId: postId,
      dateString: dateString,
      title: editTitle ?? '',
      contentHtml: editContentHtml ?? '',
    );

    if (editTitle != null) {
      titleController.text = editTitle;
    }

    if (editContentHtml != null) {
      _currentHtml = editContentHtml;
    }

    notifyListeners();
  }

  /// 게시판 정보를 업데이트합니다.
  void updateBoard(String? boardId, String? boardName) {
    _updatePostData(boardId: boardId, boardName: boardName);
  }

  /// 에디터에 포커스를 설정합니다.
  Future<void> focusEditor() async {
    await _executeCommand('focus');
  }

  /// HTML 내용을 설정합니다.
  Future<void> setHTML(String html) async {
    _currentHtml = html;
    await _executeCommand('setHTML', [html]);
  }

  /// HTML 내용을 가져옵니다.
  Future<String> getHTML() async {
    return _currentHtml;
  }

  /// 플레이스홀더를 설정합니다.
  Future<void> setPlaceholder(String placeholder) async {
    await _executeCommand('setPlaceholder', [placeholder]);
  }

  /// 이미지를 선택하고 에디터에 삽입합니다.
  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        // 사용자 선택 완료 직후 안내 토스트 표시
        Fluttertoast.showToast(
          msg: "이미지는 최대 30개까지만 첨부됩니다.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        // 현재 선택된 이미지 수와 합산하여 최대 개수 제한
        final currentCount = _postData.selectedImages.length;
        final remaining = CommunityEditorConstants.maxImageCount - currentCount;
        final toInsert = remaining <= 0 ? <XFile>[] : images.take(remaining).toList();

        for (final image in toInsert) {
          await _insertImageToEditor(image);
        }

        if (images.length > toInsert.length) {
          HapticFeedback.lightImpact();
          Fluttertoast.showToast(
            msg: "이미지는 최대 30개까지만 첨부됩니다.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black,
            textColor: Colors.white,
          );
        }

        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }

  /// 이미지를 에디터에 삽입합니다.
  Future<void> _insertImageToEditor(XFile imageFile) async {
    final imageId = DateTime.now().millisecondsSinceEpoch.toString();

    // 로딩 이미지 먼저 표시
    await _executeCommand('insertLoadingImage', [imageId]);

    try {
      // 임시로 base64 이미지를 표시 (즉시 표시용)
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final mimeType = _getMimeType(imageFile.path);
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      // 로딩 이미지를 base64 이미지로 교체 (즉시 표시)
      await _executeCommand('replaceLoadingImage', [imageId, dataUrl, 'Image']);

      // 추가된 이미지 파일을 임시 리스트에 저장 (나중에 Firebase 업로드용)
      final List<XFile> newImages = [..._postData.selectedImages, imageFile];
      _updatePostData(selectedImages: newImages);

    } catch (e) {
      print('이미지 삽입 오류: $e');
      // 오류 발생시 로딩 이미지 제거
      await _executeCommand('replaceLoadingImage', [imageId, '', '']);
    }
  }

  // 즉시 업로드는 사용하지 않음 (사용자 요청)

  /// 파일 경로에서 MIME 타입을 가져옵니다.
  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// 텍스트 포맷을 적용합니다.
  Future<void> applyTextFormat(String format) async {
    final command = CommunityEditorConstants.editorCommands[format];
    if (command != null) {
      await _executeCommand('execCommand', [command, null]);
      HapticFeedback.selectionClick();
    }
  }

  /// 폰트 크기를 적용합니다.
  Future<void> applyFontSize(int fontSize) async {
    // fontSize 명령은 1-7 값을 사용하므로 픽셀 값으로 변환
    String fontSizeValue;
    if (fontSize <= 10) fontSizeValue = '1';
    else if (fontSize <= 12) fontSizeValue = '2';
    else if (fontSize <= 14) fontSizeValue = '3';
    else if (fontSize <= 16) fontSizeValue = '4';
    else if (fontSize <= 18) fontSizeValue = '5';
    else if (fontSize <= 24) fontSizeValue = '6';
    else fontSizeValue = '7';

    await _executeCommand('execCommand', ['fontSize', fontSizeValue]);
    HapticFeedback.selectionClick();
  }

  /// 텍스트 색상을 적용합니다.
  Future<void> applyTextColor(Color color) async {
    final colorHex = '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    await _executeCommand('execCommand', ['foreColor', colorHex]);
    HapticFeedback.selectionClick();
  }

  /// 텍스트 정렬을 적용합니다.
  Future<void> applyTextAlignment(String alignment) async {
    String command;
    switch (alignment) {
      case 'left':
        command = 'justifyLeft';
        break;
      case 'center':
        command = 'justifyCenter';
        break;
      case 'right':
        command = 'justifyRight';
        break;
      case 'justify':
        command = 'justifyFull';
        break;
      default:
        command = 'justifyLeft';
    }

    await _executeCommand('execCommand', [command, null]);
    HapticFeedback.selectionClick();
  }

  /// 리스트를 삽입합니다.
  Future<void> insertList({bool ordered = false}) async {
    await _executeCommand('insertList', [ordered]);
    HapticFeedback.selectionClick();
  }

  /// HTML 내용에서 임시 이미지를 Firebase Storage URL로 변환하여 최종 HTML을 반환합니다.
  Future<String> getProcessedHtml() async {
    // 현재 HTML 내용 가져오기
    final currentHtml = await getHTML();

    // 게시글 ID와 날짜가 있어야 처리 가능
    if (_postData.postId == null || _postData.dateString == null) {
      print('PostId 또는 DateString이 없어서 이미지 처리를 건너뜁니다.');
      return currentHtml;
    }

    // Firebase Storage 업로드 및 URL 교체
    final processedHtml = await FirebaseImageUploader.processImagesInHtml(
      htmlContent: currentHtml,
      postId: _postData.postId!,
      dateString: _postData.dateString!,
    );

    return processedHtml;
  }

  /// 제출 전에 컨트롤러에 식별자 정보를 주입
  void setIdentifiers({required String postId, required String dateString}) {
    _updatePostData(postId: postId, dateString: dateString);
  }

  /// 임시 저장된 이미지 파일들을 정리합니다.
  void clearTempImages() {
    _updatePostData(selectedImages: []);
  }

  void _updateState({
    bool? isReady,
    bool? isFocused,
    bool? isContentFocused,
    bool? isTitleFocused,
    String? currentText,
    String? currentTitle,
    bool? isDirty,
    bool? hasUnsavedChanges,
    bool? showToolbar,
    Map<String, dynamic>? formatState,
  }) {
    _state = _state.copyWith(
      isReady: isReady,
      isFocused: isFocused,
      isContentFocused: isContentFocused,
      isTitleFocused: isTitleFocused,
      currentText: currentText,
      currentTitle: currentTitle,
      isDirty: isDirty,
      hasUnsavedChanges: hasUnsavedChanges,
      showToolbar: showToolbar,
      formatState: formatState,
    );

    onStateChanged?.call(_state);
    notifyListeners();
  }

  void _updatePostData({
    String? postId,
    String? boardId,
    String? boardName,
    String? title,
    String? contentHtml,
    List<XFile>? selectedImages,
    bool? isEditMode,
    String? dateString,
    Map<String, dynamic>? metadata,
  }) {
    _postData = _postData.copyWith(
      postId: postId,
      boardId: boardId,
      boardName: boardName,
      title: title,
      contentHtml: contentHtml,
      selectedImages: selectedImages,
      isEditMode: isEditMode,
      dateString: dateString,
      metadata: metadata,
    );

    notifyListeners();
  }

  /// JavaScript 명령을 실행합니다.
  Future<void> _executeCommand(String command, [List<dynamic>? params]) async {
    if (_webViewController == null) {
      print('WebView controller is null');
      return;
    }

    try {
      String script;
      if (params == null || params.isEmpty) {
        script = '''
          try {
            if (window.communityEditorAPI && window.communityEditorAPI.$command) {
              window.communityEditorAPI.$command();
            } else {
              console.log('communityEditorAPI.$command not available yet');
            }
          } catch (e) {
            console.error('Error executing $command:', e);
          }
        ''';
      } else {
        final paramsJson = params.map((param) => json.encode(param)).join(', ');
        script = '''
          try {
            if (window.communityEditorAPI && window.communityEditorAPI.$command) {
              window.communityEditorAPI.$command($paramsJson);
            } else {
              console.log('communityEditorAPI.$command not available yet');
            }
          } catch (e) {
            console.error('Error executing $command:', e);
          }
        ''';
      }

      await _webViewController!.runJavaScript(script);
    } catch (e) {
      print('Error executing JavaScript command: $e');
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    titleFocusNode.dispose();
    super.dispose();
  }
}
