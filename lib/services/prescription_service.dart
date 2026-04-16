import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class PrescriptionService {
  PrescriptionService(this._api);
  final ApiClient _api;

  Future<PrescriptionDraftDto> createDraft({
    required String patientId,
    required File file,
  }) async {
    final form = FormData.fromMap({
      'patient_id': patientId,
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.prescriptionsDraft,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return PrescriptionDraftDto.fromJson(res.data!);
  }

  Future<PrescriptionDto> confirm({
    required String prescriptionId,
    required String extractedText,
    required List<PrescriptionItemDto> items,
  }) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      ApiEndpoints.prescriptionsConfirm(prescriptionId),
      data: {
        'extracted_text': extractedText,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    return PrescriptionDto.fromJson(res.data!);
  }

  Future<List<PrescriptionDto>> fetchMine() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.prescriptionsMine);
    final data = res.data;
    if (data is! List) return [];
    return data.map((e) => PrescriptionDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<String> getScanUrl(String prescriptionId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(ApiEndpoints.prescriptionScanUrl(prescriptionId));
    return (res.data?['url'] as String?) ?? '';
  }

  Future<void> setReminderOptIn(String prescriptionId, bool enabled) async {
    final form = FormData.fromMap({'enabled': enabled.toString()});
    await _api.dio.post(
      ApiEndpoints.prescriptionReminderOptIn(prescriptionId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? e.toString();
  }
}

class PrescriptionItemDto {
  PrescriptionItemDto({
    required this.medication,
    this.everyHours,
    this.durationDays,
    this.route,
  });
  final String medication;
  final int? everyHours;
  final int? durationDays;
  final String? route;

  factory PrescriptionItemDto.fromJson(Map<String, dynamic> j) => PrescriptionItemDto(
        medication: (j['medication'] as String?) ?? '',
        everyHours: (j['every_hours'] as num?)?.toInt(),
        durationDays: (j['duration_days'] as num?)?.toInt(),
        route: j['route'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'medication': medication,
        'every_hours': everyHours,
        'duration_days': durationDays,
        'route': route,
      };
}

class PrescriptionDraftDto {
  PrescriptionDraftDto({
    required this.id,
    required this.patientId,
    required this.extractedText,
    required this.items,
  });
  final String id;
  final String patientId;
  final String extractedText;
  final List<PrescriptionItemDto> items;

  factory PrescriptionDraftDto.fromJson(Map<String, dynamic> j) => PrescriptionDraftDto(
        id: j['id'] as String,
        patientId: j['patient_id'] as String,
        extractedText: (j['extracted_text'] as String?) ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => PrescriptionItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class PrescriptionDto {
  PrescriptionDto({
    required this.id,
    this.doctorName,
    this.sourceFileName,
    required this.status,
    required this.remindersEnabled,
    required this.items,
  });
  final String id;
  final String? doctorName;
  final String? sourceFileName;
  final String status;
  final bool remindersEnabled;
  final List<PrescriptionItemDto> items;

  factory PrescriptionDto.fromJson(Map<String, dynamic> j) => PrescriptionDto(
        id: j['id'] as String,
        doctorName: j['doctor_name'] as String?,
        sourceFileName: j['source_file_name'] as String?,
        status: (j['status'] as String?) ?? 'draft_ocr',
        remindersEnabled: (j['reminders_enabled'] as bool?) ?? false,
        items: ((j['items'] as List?) ?? [])
            .map((e) => PrescriptionItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

