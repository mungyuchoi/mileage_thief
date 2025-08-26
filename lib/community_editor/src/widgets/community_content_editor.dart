import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import '../controllers/community_editor_controller.dart';
import '../constants/community_editor_constants.dart';

/// 커뮤니티 게시글의 제목과 내용을 입력하는 위젯입니다.
/// WebView 기반으로 HTML 에디터를 제공합니다.
class CommunityContentEditor extends StatefulWidget {
  final CommunityEditorController controller;
  final String titleHint;
  final String contentHint;
  final VoidCallback? onImageTap;

  const CommunityContentEditor({
    Key? key,
    required this.controller,
    this.titleHint = '제목',
    this.contentHint = '오늘 어떤 여행을 떠나셨나요?\n경험을 공유해주세요!',
    this.onImageTap,
  }) : super(key: key);

  @override
  State<CommunityContentEditor> createState() => _CommunityContentEditorState();
}

class _CommunityContentEditorState extends State<CommunityContentEditor> {
  late WebViewController _webViewController;
  bool _isWebViewReady = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _initializeWebView();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        CommunityEditorConstants.jsChannelName,
        onMessageReceived: (JavaScriptMessage message) {
          widget.controller.handleJavaScriptMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _onWebViewReady();
          },
        ),
      );

    widget.controller.setWebViewController(_webViewController);
    _loadHtmlContent();
  }

  void _loadHtmlContent() {
    // 임시로 간단한 HTML 템플릿 사용 (디버그용)
    final htmlContent = CommunityEditorConstants.simpleHtmlTemplate;
    print('Loading HTML template');
    _webViewController.loadHtmlString(htmlContent);
  }

  void _onWebViewReady() async {
    try {
      print('WebView ready callback triggered');
      
      setState(() {
        _isWebViewReady = true;
        _isLoading = false;
      });

      // 잠시 대기 후 초기화
      await Future.delayed(const Duration(milliseconds: 500));

      // 플레이스홀더 설정
      await widget.controller.setPlaceholder(widget.contentHint);

      // 초기 HTML 내용 설정 (편집 모드인 경우)
      if (widget.controller.postData.contentHtml.isNotEmpty) {
        await widget.controller.setHTML(widget.controller.postData.contentHtml);
      }

      // 에디터 포커스는 사용자가 직접 터치할 때만
      // 자동 포커스 제거로 포커스 충돌 방지
      
      print('WebView initialization completed');
    } catch (e) {
      print('WebView initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 입력
        _buildTitleField(),
        
        // 구분선
        Container(
          height: 1,
          color: Colors.grey[200],
          margin: const EdgeInsets.only(top: 8, bottom: 16),
        ),
        
        // WebView 에디터
        Expanded(
          child: _buildWebViewEditor(),
        )
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: widget.controller.titleController,
      focusNode: widget.controller.titleFocusNode,
      decoration: InputDecoration(
        hintText: widget.titleHint,
        border: InputBorder.none,
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 18,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) {
        // 제목 입력 후 WebView 에디터로 포커스 이동
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.controller.focusEditor();
        });
      },
    );
  }

  Widget _buildWebViewEditor() {
    return Stack(
      children: [
        // WebView 에디터 (테두리 없음)
        WebViewWidget(controller: _webViewController),
        
        // 로딩 인디케이터
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                strokeWidth: 3,
              ),
            ),
          ),
        
        // 에디터가 준비되지 않았을 때 오버레이
        if (!_isWebViewReady && !_isLoading)
          Container(
            color: Colors.grey[50],
            child: const Center(
              child: Text(
                '에디터 준비 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
