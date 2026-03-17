import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

/// Respuesta de POST /api/v1/documents/mobile/analyze
class AnalyzeResult {
  AnalyzeResult({
    required this.category,
    required this.recommendedName,
    this.expiryDate,
    this.tags,
    this.confidenceScore = 0,
    this.manualClassificationRequired = false,
    this.subscriptionRequired = false,
    this.subscriptionInfo,
    this.message,
  });

  final String category;
  final String recommendedName;
  final String? expiryDate;
  final List<String>? tags;
  final double confidenceScore;
  final bool manualClassificationRequired;
  final bool subscriptionRequired;
  final Map<String, dynamic>? subscriptionInfo;
  final String? message;

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    final tagsList = json['tags'] as List<dynamic>?;
    return AnalyzeResult(
      category: json['category'] as String? ?? 'Documento',
      recommendedName: json['recommended_name'] as String? ?? '',
      expiryDate: json['expiry_date'] as String?,
      tags: tagsList?.map((e) => e.toString()).toList(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      manualClassificationRequired: json['manual_classification_required'] as bool? ?? false,
      subscriptionRequired: json['subscription_required'] as bool? ?? false,
      subscriptionInfo: json['subscription_info'] as Map<String, dynamic>?,
      message: json['message'] as String?,
    );
  }
}

class DocumentUploadService {
  DocumentUploadService(this._api);
  final ApiClient _api;

  Future<AnalyzeResult> analyze(File file) async {
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final multipart = await MultipartFile.fromFile(file.path, filename: name);
    final formData = FormData.fromMap({'file': multipart});
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.documentsMobileAnalyze,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    if (res.statusCode == 402) {
      final data = res.data ?? {};
      return AnalyzeResult.fromJson({...data, 'subscription_required': true});
    }
    return AnalyzeResult.fromJson(res.data!);
  }

  Future<Map<String, dynamic>> saveAnalyzed({
    required File file,
    required String category,
    required String fileName,
    String? expiryDate,
  }) async {
    final pathName = file.path.split(RegExp(r'[/\\]')).last;
    final multipart = await MultipartFile.fromFile(file.path, filename: pathName);
    final formData = FormData.fromMap({
      'file': multipart,
      'category': category,
      'file_name': fileName,
      if (expiryDate != null && expiryDate.isNotEmpty) 'expiry_date': expiryDate,
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.documentsMobileSaveAnalyzed,
      data: formData,
    );
    return res.data!;
  }
}
