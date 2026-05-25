import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class GlobalSearchItem {
  GlobalSearchItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.patientId,
    required this.date,
    this.status,
  });

  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final String? patientId;
  final DateTime date;
  final String? status;

  factory GlobalSearchItem.fromJson(Map<String, dynamic> json) {
    return GlobalSearchItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      patientId: json['patient_id']?.toString(),
      date: json['date'] != null
          ? DateTime.parse(json['date'].toString())
          : DateTime.now(),
      status: json['status']?.toString(),
    );
  }
}

class SearchService {
  SearchService(this._api);
  final ApiClient _api;

  static String messageFromDio(dynamic e) {
    if (e is DioException) {
      final msg = e.response?.data?['detail'];
      if (msg != null && msg is String) return msg;
      return e.message ?? 'Error de conexión';
    }
    return e.toString();
  }

  Future<List<GlobalSearchItem>> search({
    String? query,
    String? itemType,
    int limit = 30,
  }) async {
    final q = query?.trim();
    final params = <String, dynamic>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
      'limit': limit,
    };
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.globalSearch,
      queryParameters: params.isEmpty ? null : params,
    );
    final data = res.data ?? {};
    final raw = data['results'] as List<dynamic>? ?? [];
    return raw
        .map((e) => GlobalSearchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
