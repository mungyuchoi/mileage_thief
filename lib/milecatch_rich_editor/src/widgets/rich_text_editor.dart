import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/composing_data.dart';
import '../controllers/editor_controller.dart';
import '../constants/editor_constants.dart';

class RichTextEditor extends StatefulWidget {
  final String? initialContent;
  final String? initialAttachments;
  final String placeholder;
  final bool isEditMode;
  final Function(UiComposingData)? onDataChanged;
  final Function(String)? onTextChanged;
  final Function()? onFocusChanged;
  final bool isDarkMode;

  const RichTextEditor({
    Key? key,
    this.initialContent,
    this.initialAttachments,
    this.placeholder = '내용을 입력하세요...',
    this.isEditMode = false,
    this.onDataChanged,
    this.onTextChanged,
    this.onFocusChanged,
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late WebViewController _controller;
  late EditorController _editorController;
  bool _isReady = false;
  bool _isLoading = true;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _editorController = EditorController();
    _initializeWebView();
    
    // 콜백 설정
    _editorController.onTextChanged = (text) {
      setState(() {
        _currentText = text;
      });
      widget.onTextChanged?.call(text);
    };
    
    _editorController.onFocusChanged = () {
      widget.onFocusChanged?.call();
    };
    
    _editorController.onDataChanged = (data) {
      final composingData = UiComposingData(
        content: data['content'] ?? '',
        tags: (data['tags'] as List?)?.cast<String>() ?? [],
        metadata: data['metadata'] ?? {},
      );
      widget.onDataChanged?.call(composingData);
    };
    
    _editorController.onStateChanged = (state) {
      setState(() {
        _isReady = state.isReady;
        _isLoading = state.isLoading;
      });
    };
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        EditorConstants.jsChannelName,
        onMessageReceived: (JavaScriptMessage message) {
          _editorController.handleJavaScriptMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onWebViewReady();
          },
        ),
      );

    _editorController.setWebViewController(_controller);
    _loadHtmlContent();
  }

  void _loadHtmlContent() {
    final htmlContent = widget.isDarkMode 
        ? EditorConstants.darkHtmlTemplate 
        : EditorConstants.htmlTemplate;
    
    _controller.loadHtmlString(htmlContent);
  }

  void _onWebViewReady() async {
    setState(() {
      _isReady = true;
      _isLoading = false;
    });

    // 초기 설정
    if (widget.placeholder != EditorConstants.defaultPlaceholder) {
      await _editorController.setPlaceholder(widget.placeholder);
    }

    // 초기 내용 설정
    if (widget.initialContent?.isNotEmpty == true) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _editorController.setHtml(widget.initialContent!);
    }

    // 편집 모드가 아닌 경우 포커스
    if (!widget.isEditMode) {
      await _editorController.focusEditor();
    }
  }

  /// 에디터에 포커스를 설정합니다
  Future<void> focus() async {
    await _editorController.focusEditor();
  }

  /// 에디터 내용을 설정합니다
  Future<void> setContent(String content) async {
    await _editorController.setHtml(content);
  }

  /// 에디터 내용을 가져옵니다
  Future<String> getContent() async {
    return await _editorController.getHtml();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: WebViewWidget(controller: _controller),
          ),
          
          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

