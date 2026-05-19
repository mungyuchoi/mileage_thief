import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../const/colors.dart';

class RoomPointsWebTab extends StatefulWidget {
  final String initialUrl;

  const RoomPointsWebTab({
    super.key,
    required this.initialUrl,
  });

  @override
  State<RoomPointsWebTab> createState() => _RoomPointsWebTabState();
}

class _RoomPointsWebTabState extends State<RoomPointsWebTab> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageFinished: (_) => _syncNavigationState(),
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _syncNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
    await _syncNavigationState();
  }

  Future<void> _goForward() async {
    if (!await _controller.canGoForward()) return;
    await _controller.goForward();
    await _syncNavigationState();
  }

  Future<void> _reload() async {
    await _controller.reload();
    await _syncNavigationState();
  }

  Future<void> _openExternal() async {
    final currentUrl = await _controller.currentUrl();
    final uri = Uri.tryParse(currentUrl ?? widget.initialUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            _RoomPointsToolbar(
              canGoBack: _canGoBack,
              canGoForward: _canGoForward,
              onBack: _goBack,
              onForward: _goForward,
              onReload: _reload,
              onOpenExternal: _openExternal,
            ),
            if (_progress < 100)
              LinearProgressIndicator(
                value: _progress <= 0 ? null : _progress / 100,
                minHeight: 2,
              ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPointsToolbar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onOpenExternal;

  const _RoomPointsToolbar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: canGoBack ? onBack : null,
          ),
          IconButton(
            tooltip: '앞으로',
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onPressed: canGoForward ? onForward : null,
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: onReload,
          ),
          const Expanded(
            child: Text(
              'RoomPoints',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McTextStyles.bodyStrong,
            ),
          ),
          IconButton(
            tooltip: '브라우저에서 열기',
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: onOpenExternal,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
