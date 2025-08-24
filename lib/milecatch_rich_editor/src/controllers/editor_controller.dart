import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/editor_state.dart';
import '../models/toolbar_state.dart';
import '../utils/js_bridge.dart';

class EditorController extends ChangeNotifier {
  WebViewController? _webViewController;
  final JSBridge _jsBridge = JSBridge();
  EditorState _editorState = const EditorState();
  ToolbarState _toolbarState = const ToolbarState();

  // 콜백 함수들
  Function(String)? onTextChanged;
  Function(EditorState)? onStateChanged;
  Function()? onFocusChanged;
  Function(Map<String, dynamic>)? onDataChanged;

  // Getters
  EditorState get editorState => _editorState;
  ToolbarState get toolbarState => _toolbarState;
  bool get isReady => _editorState.isReady;
  bool get isFocused => _editorState.isFocused;
  String get currentText => _editorState.currentText;

  /// WebView 컨트롤러를 설정합니다
  void setWebViewController(WebViewController controller) {
    _webViewController = controller;
  }

  /// JavaScript 메시지를 처리합니다
  void handleJavaScriptMessage(String message) {
    try {
      final data = _jsBridge.parseMessage(message);
      _processJavaScriptMessage(data);
    } catch (e) {
      _jsBridge.debugLog('Error handling JavaScript message', e);
    }
  }

  /// 에디터에 포커스를 설정합니다
  Future<void> focusEditor() async {
    await _executeCommand('focus');
  }

  /// 에디터에서 포커스를 제거합니다
  Future<void> blurEditor() async {
    await _executeCommand('blur');
  }

  /// HTML 내용을 설정합니다
  Future<void> setHtml(String html) async {
    final escapedHtml = _jsBridge.escapeJavaScript(html);
    await _executeCommand('setHtml', {'html': escapedHtml});
  }

  /// HTML 내용을 가져옵니다
  Future<String> getHtml() async {
    await _executeCommand('getHtml');
    // 실제로는 JavaScript에서 응답을 기다려야 하지만, 
    // 간단하게 현재 텍스트를 반환
    return _editorState.currentText;
  }

  /// 플레이스홀더를 설정합니다
  Future<void> setPlaceholder(String placeholder) async {
    final escapedPlaceholder = _jsBridge.escapeJavaScript(placeholder);
    await _executeCommand('setPlaceholder', {'placeholder': escapedPlaceholder});
  }

  /// 볼드 스타일을 토글합니다
  Future<void> setBold() async {
    await _executeCommand('bold');
    _updateToolbarState(_toolbarState.copyWith(isBold: !_toolbarState.isBold));
  }

  /// 이탤릭 스타일을 토글합니다
  Future<void> setItalic() async {
    await _executeCommand('italic');
    _updateToolbarState(_toolbarState.copyWith(isItalic: !_toolbarState.isItalic));
  }

  /// 언더라인 스타일을 토글합니다
  Future<void> setUnderline() async {
    await _executeCommand('underline');
    _updateToolbarState(_toolbarState.copyWith(isUnderline: !_toolbarState.isUnderline));
  }

  /// 텍스트 색상을 설정합니다
  Future<void> setTextColor(Color color) async {
    final colorCss = _jsBridge.colorToCss(color.value);
    await _executeCommand('foreColor', {'color': colorCss});
    _updateToolbarState(_toolbarState.copyWith(textColor: color));
  }

  /// 배경 색상을 설정합니다
  Future<void> setBackgroundColor(Color color) async {
    final colorCss = _jsBridge.colorToCss(color.value);
    await _executeCommand('backColor', {'color': colorCss});
    _updateToolbarState(_toolbarState.copyWith(backgroundColor: color));
  }

  /// 폰트 크기를 설정합니다
  Future<void> setFontSize(int size) async {
    await _executeCommand('fontSize', {'size': size.toString()});
    _updateToolbarState(_toolbarState.copyWith(fontSize: size));
  }

  /// 왼쪽 정렬을 설정합니다
  Future<void> setJustifyLeft() async {
    await _executeCommand('justifyLeft');
    _updateToolbarState(_toolbarState.copyWith(textAlign: TextAlign.left));
  }

  /// 가운데 정렬을 설정합니다
  Future<void> setJustifyCenter() async {
    await _executeCommand('justifyCenter');
    _updateToolbarState(_toolbarState.copyWith(textAlign: TextAlign.center));
  }

  /// 오른쪽 정렬을 설정합니다
  Future<void> setJustifyRight() async {
    await _executeCommand('justifyRight');
    _updateToolbarState(_toolbarState.copyWith(textAlign: TextAlign.right));
  }

  /// 텍스트 정렬을 설정합니다
  Future<void> setTextAlign(TextAlign align) async {
    switch (align) {
      case TextAlign.left:
        await setJustifyLeft();
        break;
      case TextAlign.center:
        await setJustifyCenter();
        break;
      case TextAlign.right:
        await setJustifyRight();
        break;
      default:
        await setJustifyLeft();
    }
  }

  /// 이미지를 삽입합니다
  Future<void> insertImage(String url, {String? alt}) async {
    final altText = alt ?? 'Image';
    await _executeCommand('insertImage', {'url': url, 'alt': altText});
  }

  /// 텍스트를 삽입합니다
  Future<void> insertText(String text) async {
    final escapedText = _jsBridge.escapeJavaScript(text);
    await _executeCommand('insertText', {'text': escapedText});
  }

  /// HTML을 삽입합니다
  Future<void> insertHtml(String html) async {
    final escapedHtml = _jsBridge.escapeJavaScript(html);
    await _executeCommand('insertHTML', {'html': escapedHtml});
  }

  /// 실행 취소합니다
  Future<void> undo() async {
    await _executeCommand('undo');
  }

  /// 다시 실행합니다
  Future<void> redo() async {
    await _executeCommand('redo');
  }

  /// 내용을 지웁니다
  Future<void> clear() async {
    await _executeCommand('clear');
    _updateEditorState(_editorState.copyWith(
      currentText: '',
      isDirty: false,
    ));
  }

  /// 선택된 텍스트를 가져옵니다
  Future<String> getSelectedText() async {
    await _executeCommand('getSelectedText');
    // 실제로는 JavaScript에서 응답을 기다려야 함
    return '';
  }

  /// 선택된 텍스트를 교체합니다
  Future<void> replaceSelection(String text) async {
    final escapedText = _jsBridge.escapeJavaScript(text);
    await _executeCommand('replaceSelection', {'text': escapedText});
  }

  /// 에디터 상태를 요청합니다
  Future<void> requestEditorState() async {
    await _executeCommand('getEditorState');
  }

  /// 데이터를 요청합니다
  Future<void> requestData({bool isForUpload = false, bool isAutoSave = false}) async {
    await _executeCommand('getData', {
      'isForUpload': isForUpload,
      'isAutoSave': isAutoSave,
    });
  }

  /// 첨부파일이 추가되었을 때 호출합니다
  Future<void> onAttachAdded(String attachmentId) async {
    await _executeCommand('onAttachAdded', {'attachmentId': attachmentId});
  }

  /// 파일을 제거합니다
  Future<void> removeFile(String fileId, {bool isForUpload = false}) async {
    await _executeCommand('removeFile', {
      'fileId': fileId,
      'isForUpload': isForUpload,
    });
  }

  /// 첨부파일 목록을 설정합니다
  Future<void> setAttachments(String attachments) async {
    await _executeCommand('setAttachments', {'attachments': attachments});
  }

  /// 헤더 스타일을 적용합니다
  Future<void> applyHeaderStyle() async {
    await _executeCommand('formatBlock', {'tag': 'h2'});
  }

  /// 본문 스타일을 적용합니다
  Future<void> applyBodyStyle() async {
    await _executeCommand('formatBlock', {'tag': 'p'});
  }

  /// 강조 스타일을 적용합니다
  Future<void> applyEmphasisStyle() async {
    await _executeCommand('formatBlock', {'tag': 'strong'});
  }

  /// 인용 스타일을 적용합니다
  Future<void> applyQuoteStyle() async {
    await _executeCommand('formatBlock', {'tag': 'blockquote'});
  }

  /// 다크 모드를 토글합니다
  Future<void> toggleDarkMode() async {
    await _executeCommand('toggleDarkMode');
  }

  /// 읽기 전용 모드를 설정합니다
  Future<void> setReadOnly(bool readOnly) async {
    await _executeCommand('setReadOnly', {'readOnly': readOnly});
  }

  /// 에디터 높이를 조정합니다
  Future<void> resizeEditor(double height) async {
    await _executeCommand('resizeEditor', {'height': height});
  }

  /// 특정 위치로 스크롤합니다
  Future<void> scrollTo(int position) async {
    await _executeCommand('scrollTo', {'position': position});
  }

  /// 커서 위치를 설정합니다
  Future<void> setCursorPosition(int position) async {
    await _executeCommand('setCursorPosition', {'position': position});
  }

  /// 에디터를 초기화합니다
  void reset() {
    _editorState = const EditorState();
    _toolbarState = const ToolbarState();
    notifyListeners();
  }

  /// JavaScript 명령을 실행합니다
  Future<void> _executeCommand(String command, [Map<String, dynamic>? params]) async {
    if (_webViewController == null) {
      _jsBridge.debugLog('WebView controller is null');
      return;
    }

    try {
      final script = _buildJavaScriptCommand(command, params);
      await _webViewController!.runJavaScript(script);
    } catch (e) {
      _jsBridge.debugLog('Error executing JavaScript command', e);
    }
  }

  /// JavaScript 명령 문자열을 구성합니다
  String _buildJavaScriptCommand(String command, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) {
      return 'window.milecatchEditor.$command();';
    }

    final paramsJson = _jsBridge.encodeData(params);
    return 'window.milecatchEditor.$command($paramsJson);';
  }

  /// JavaScript 메시지를 처리합니다
  void _processJavaScriptMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final messageData = data['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'ready':
        _updateEditorState(_editorState.copyWith(isReady: true));
        break;
      case 'textChanged':
        final content = messageData?['content'] as String? ?? '';
        final text = messageData?['text'] as String? ?? '';
        _updateEditorState(_editorState.copyWith(
          currentText: content,
          isDirty: true,
        ));
        onTextChanged?.call(text);
        break;
      case 'focus':
        _updateEditorState(_editorState.copyWith(isFocused: true));
        onFocusChanged?.call();
        break;
      case 'blur':
        _updateEditorState(_editorState.copyWith(isFocused: false));
        onFocusChanged?.call();
        break;
      case 'dataChanged':
        onDataChanged?.call(messageData ?? {});
        break;
      default:
        _jsBridge.debugLog('Unknown message type: $type');
    }
  }

  /// 에디터 상태를 업데이트합니다
  void _updateEditorState(EditorState newState) {
    _editorState = newState;
    onStateChanged?.call(_editorState);
    notifyListeners();
  }

  /// 툴바 상태를 업데이트합니다
  void _updateToolbarState(ToolbarState newState) {
    _toolbarState = newState;
    notifyListeners();
  }
}

