import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_theme.dart';

class AnalysisDocumentViewerScreen extends StatefulWidget {
  const AnalysisDocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.headers = const {},
  });

  final String url;
  final String title;
  final Map<String, String> headers;

  @override
  State<AnalysisDocumentViewerScreen> createState() =>
      _AnalysisDocumentViewerScreenState();
}

class _AnalysisDocumentViewerScreenState
    extends State<AnalysisDocumentViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
        headers: widget.headers,
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            ),
        ],
      ),
    );
  }
}
