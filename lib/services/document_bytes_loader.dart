import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Tipo detectado por contenido real del archivo (no solo por extensión en el nombre).
enum DetectedFileKind { pdf, image, other }

/// Descarga bytes de un documento evitando enviar Authorization a URLs S3 tras redirect.
class DocumentBytesLoader {
  static bool looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D; // %PDF-
  }

  static bool looksLikeJpeg(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }

  static bool looksLikePng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool looksLikeGif(Uint8List bytes) {
    if (bytes.length < 6) return false;
    final h = String.fromCharCodes(bytes.sublist(0, 6));
    return h == 'GIF87a' || h == 'GIF89a';
  }

  static DetectedFileKind detectKind(Uint8List bytes) {
    if (looksLikePdf(bytes)) return DetectedFileKind.pdf;
    if (looksLikeJpeg(bytes) || looksLikePng(bytes) || looksLikeGif(bytes)) {
      return DetectedFileKind.image;
    }
    return DetectedFileKind.other;
  }

  static bool _isPresignedOrPublicStorage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('amazonaws.com') ||
        lower.contains('s3.') ||
        lower.contains('x-amz-');
  }

  static bool requiresAuthInApp(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/documents/mobile/download/') ||
        lower.contains('/api/v1/documents/mobile/download/');
  }

  /// Descarga el archivo. Si [headers] llevan Bearer y la API redirige a S3, la 2.ª
  /// petición va sin Authorization (S3 rechaza el token extra).
  static Future<Uint8List> fetch({
    required String url,
    Map<String, String> headers = const {},
    Dio? dio,
  }) async {
    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 120),
          ),
        );

    final hasAuth =
        headers.containsKey('Authorization') && headers['Authorization']!.isNotEmpty;

    if (hasAuth && !_isPresignedOrPublicStorage(url)) {
      final first = await client.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final code = first.statusCode ?? 0;
      if (code >= 300 && code < 400) {
        final location = first.headers.value('location') ??
            first.headers.value('Location');
        if (location != null && location.isNotEmpty) {
          return _fetchDirect(client, location);
        }
      }

      if (code >= 200 && code < 300) {
        return _bytesFromResponse(first);
      }

      throw DioException(
        requestOptions: first.requestOptions,
        response: first,
        message: 'No se pudo descargar el archivo ($code)',
      );
    }

    return _fetchDirect(client, url, headers: headers);
  }

  static Future<Uint8List> _fetchDirect(
    Dio client,
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final res = await client.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers.isEmpty ? null : headers,
        followRedirects: true,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    final code = res.statusCode ?? 0;
    if (code >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'No se pudo descargar el archivo ($code)',
      );
    }

    return _bytesFromResponse(res);
  }

  static Uint8List _bytesFromResponse(Response<List<int>> res) {
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'El archivo está vacío o no está disponible.',
      );
    }
    return Uint8List.fromList(data);
  }
}
