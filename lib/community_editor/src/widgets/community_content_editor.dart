import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../controllers/community_editor_controller.dart';
import '../constants/community_editor_constants.dart';

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

  /// 네이티브 툴바(자체 위젯) 높이 – 키보드가 올라올 때만 적용
  final double _toolbarHeight = 56;

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
    if (mounted) setState(() {});
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
          onPageFinished: (String url) => _onWebViewReady(),
        ),
      );

    widget.controller.setWebViewController(_webViewController);

    // 간단 템플릿 로드
    _webViewController.loadHtmlString(CommunityEditorConstants.simpleHtmlTemplate);
  }

  Future<void> _injectViewportAndScrollFix() async {
    // 1) visualViewport 기반 높이 반영
    // 2) .editor 스크롤 허용 + 툴바 높이 변수로 하단 패딩 제어
    // 3) setToolbarHeight(px) 를 전역으로 주입 (Flutter에서 호출)
    const js = r'''
      (function () {
        if (window.__mc_inited) return;
        window.__mc_inited = true;

        // 스타일 주입
        const style = document.createElement('style');
        style.textContent = `
          :root{ --vvh: 100dvh; --toolbar-h:0px; --bottom-gap:0px; }
          html, body { height:100%; margin:0; padding:0; }
          /* body 스크롤을 막지 말고, 에디터 컨테이너에 스크롤 부여 */
          .editor {
            box-sizing: border-box;
            min-height: calc(var(--vvh) - var(--toolbar-h));
            /* 수평 패딩을 변수로, 기본 0px -> 제목과 일자 */
            padding-left: var(--hpad);
            padding-right: var(--hpad);
            /* 위아래만 최소 패딩, 하단은 bottom-gap 로 제어 */
            padding-top: 12px;
            padding-bottom: var(--bottom-gap);
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
          }
        `;
        document.head.appendChild(style);

        function applyViewportHeight(){
          var h = (window.visualViewport && window.visualViewport.height)
                    ? window.visualViewport.height
                    : window.innerHeight;
          document.documentElement.style.setProperty('--vvh', h + 'px');
        }
        applyViewportHeight();

        if (window.visualViewport) {
          window.visualViewport.addEventListener('resize', applyViewportHeight);
        }
        window.addEventListener('resize', applyViewportHeight);
        window.addEventListener('orientationchange', applyViewportHeight);

        // Flutter에서 호출: 키보드 up => px=56, down => px=0
        window.setToolbarHeight = function(px){
          var extra = 12; // 여유
          document.documentElement.style.setProperty('--toolbar-h', px + 'px');
          document.documentElement.style.setProperty('--bottom-gap', (px + extra) + 'px');
          // 커서가 항상 보이도록
          setTimeout(function(){
            const el = document.activeElement;
            if (el && el.scrollIntoView) el.scrollIntoView({block:'nearest'});
          }, 0);
        };

        // 입력 중에도 커서가 가려지지 않게
        function scrollCaret(){
          const sel = document.getSelection && document.getSelection();
          if (!sel || sel.rangeCount === 0) return;
          const range = sel.getRangeAt(0);
          const rect = range.getBoundingClientRect();
          const editor = document.querySelector('.editor');
          if (!editor) return;
          const er = editor.getBoundingClientRect();
          if (rect.bottom > er.bottom - 8) editor.scrollTop += (rect.bottom - er.bottom + 8);
          if (rect.top < er.top + 8) editor.scrollTop -= (er.top - rect.top + 8);
        }
        document.addEventListener('selectionchange', scrollCaret);
        document.addEventListener('input', scrollCaret);
      })();
    ''';
    await _webViewController.runJavaScript(js);
  }

  Future<void> _onWebViewReady() async {
    try {
      setState(() {
        _isWebViewReady = true;
        _isLoading = false;
      });

      // 뷰포트/스크롤/툴바 패치 주입
      await _injectViewportAndScrollFix();

      // 플레이스홀더
      await widget.controller.setPlaceholder(widget.contentHint);

      // 수정 모드 초기 내용
      if (widget.controller.postData.contentHtml.isNotEmpty) {
        await widget.controller.setHTML(widget.controller.postData.contentHtml);
      }
    } catch (e) {
      debugPrint('WebView initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 가시성
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // 키보드/툴바 상태를 WebView에 전달
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isWebViewReady) {
        final px = keyboardVisible ? _toolbarHeight : 0.0;
        _webViewController.runJavaScript('window.setToolbarHeight(${px.toStringAsFixed(0)});');
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleField(),
        Container(height: 1, color: Colors.grey[200], margin: const EdgeInsets.only(top: 8, bottom: 16)),
        Expanded(child: _buildWebViewEditor()),
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
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      textInputAction: TextInputAction.next,
      onTap: () {
        _webViewController.runJavaScript('try{ if (window.communityEditorAPI?.blur) window.communityEditorAPI.blur(); }catch(e){}');
      },
      onSubmitted: (_) => Future.delayed(const Duration(milliseconds: 100), () => widget.controller.focusEditor()),
    );
  }

  Widget _buildWebViewEditor() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
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
        if (!_isWebViewReady && !_isLoading)
          Container(
            color: Colors.grey[50],
            child: const Center(
              child: Text('에디터 준비 중...', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}
