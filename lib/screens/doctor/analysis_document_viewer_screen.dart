import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/document_bytes_loader.dart';

/// Visor de documentos (análisis, S3 Keepi Cloud, Drive, descarga móvil).
class AnalysisDocumentViewerScreen extends StatefulWidget {
  const AnalysisDocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.headers = const {},
    this.mimeType,
  });

  final String url;
  final String title;
  final Map<String, String> headers;
  final String? mimeType;

  @override
  State<AnalysisDocumentViewerScreen> createState() =>
      _AnalysisDocumentViewerScreenState();
}

enum _ViewerMode { loading, pdf, image, web, error }

class _AnalysisDocumentViewerScreenState
    extends State<AnalysisDocumentViewerScreen> {
  _ViewerMode _mode = _ViewerMode.loading;
  Uint8List? _bytes;
  String? _error;
  WebViewController? _webController;
  Timer? _webTimeout;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _prepareViewer();
  }

  @override
  void dispose() {
    _webTimeout?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  String get _effectiveMime {
    final m = widget.mimeType?.trim();
    if (m != null && m.isNotEmpty) return m.toLowerCase();
    final lower = widget.title.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return '';
  }

  bool get _isPdf =>
      _effectiveMime.contains('pdf') ||
      widget.title.toLowerCase().endsWith('.pdf');

  bool get _isImage {
    final m = _effectiveMime;
    return m.startsWith('image/') ||
        RegExp(r'\.(png|jpe?g|webp|gif|bmp)$', caseSensitive: false)
            .hasMatch(widget.title);
  }

  Future<void> _prepareViewer() async {
    await _loadBytes();
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await DocumentBytesLoader.fetch(
        url: widget.url,
        headers: widget.headers,
      );
      if (!mounted) return;

      final kind = DocumentBytesLoader.detectKind(bytes);
      if (kind == DetectedFileKind.pdf) {
        setState(() {
          _bytes = bytes;
          _mode = _ViewerMode.pdf;
        });
        return;
      }
      if (kind == DetectedFileKind.image) {
        setState(() {
          _bytes = bytes;
          _mode = _ViewerMode.image;
        });
        return;
      }

      if (_isPdf || _isImage) {
        setState(() {
          _mode = _ViewerMode.error;
          _error = widget.title.toLowerCase().endsWith('.pdf')
              ? 'Este archivo no es un PDF válido. Si subiste una foto, vuelve a guardarla desde el análisis (con extensión .jpg o .png).'
              : 'No se pudo reconocer el formato del archivo.';
        });
        return;
      }

      _bytes = bytes;
      _initWebView();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mode = _ViewerMode.error;
        _error = _messageFromError(e);
      });
    }
  }

  String _messageFromError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 403) return 'No tienes permiso para ver este archivo.';
      if (code == 404) return 'Archivo no encontrado en el almacenamiento.';
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
      return e.message ?? 'Error al descargar el archivo';
    }
    return e.toString();
  }

  void _onPdfLoadFailed(PdfDocumentLoadFailedDetails details) {
    if (!mounted) return;
    setState(() {
      _mode = _ViewerMode.error;
      _error = details.error.isNotEmpty
          ? details.error
          : 'No se pudo mostrar el PDF.';
    });
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _mode = _ViewerMode.loading);
          },
          onPageFinished: (_) {
            _webTimeout?.cancel();
            if (mounted) setState(() => _mode = _ViewerMode.web);
          },
          onWebResourceError: (err) {
            _webTimeout?.cancel();
            if (!mounted) return;
            setState(() {
              _mode = _ViewerMode.error;
              _error = err.description.isNotEmpty
                  ? err.description
                  : 'No se pudo cargar la vista previa';
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
        headers: widget.headers,
      );

    _webTimeout = Timer(const Duration(seconds: 25), () {
      if (!mounted) return;
      if (_mode == _ViewerMode.loading) {
        setState(() {
          _mode = _ViewerMode.error;
          _error =
              'La vista previa tardó demasiado. Prueba abrirlo en el navegador.';
        });
      }
    });

    if (mounted) setState(() => _mode = _ViewerMode.loading);
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        actions: [
          if ((_mode == _ViewerMode.error || _mode == _ViewerMode.web) &&
              !DocumentBytesLoader.requiresAuthInApp(widget.url))
            IconButton(
              tooltip: 'Abrir fuera de la app',
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _ViewerMode.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: KeepiColors.orange),
              SizedBox(height: 16),
              Text(
                'Cargando documento…',
                style: TextStyle(color: KeepiColors.slateLight),
              ),
            ],
          ),
        );
      case _ViewerMode.pdf:
        final bytes = _bytes;
        if (bytes == null) {
          return const Center(child: Text('Sin datos del PDF'));
        }
        return ColoredBox(
          color: Colors.white,
          child: SfPdfViewer.memory(
            bytes,
            controller: _pdfController,
            onDocumentLoadFailed: _onPdfLoadFailed,
          ),
        );
      case _ViewerMode.image:
        final bytes = _bytes;
        if (bytes == null) {
          return const Center(child: Text('Sin datos de la imagen'));
        }
        return ColoredBox(
          color: Colors.white,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
      case _ViewerMode.web:
        final ctrl = _webController;
        if (ctrl == null) {
          return const SizedBox.shrink();
        }
        return WebViewWidget(controller: ctrl);
      case _ViewerMode.error:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: KeepiColors.orange),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Error al abrir el archivo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: KeepiColors.slate,
                  height: 1.4,
                ),
              ),
              if (!DocumentBytesLoader.requiresAuthInApp(widget.url)) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Abrir en navegador'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}
