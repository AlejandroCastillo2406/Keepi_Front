import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_endpoints.dart';

class GoogleDriveAuthScreen extends StatefulWidget {
  const GoogleDriveAuthScreen({super.key, required this.authorizationUrl});

  final String authorizationUrl;

  @override
  State<GoogleDriveAuthScreen> createState() => _GoogleDriveAuthScreenState();
}

class _GoogleDriveAuthScreenState extends State<GoogleDriveAuthScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
            // Si el backend redirige al callback, cerramos la pantalla.
            if (url.contains(ApiEndpoints.authGoogleCallback)) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Google Drive'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

