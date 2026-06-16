import '../core/api_endpoints.dart';
import '../providers/consultation_bootstrap_provider.dart';
import 'api_client.dart';

extension ConsultationBootstrapApi on ApiClient {
  Future<ConsultationBootstrapData> fetchConsultationBootstrap({
    required String patientId,
    required String appointmentId,
  }) async {
    final res = await dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorConsultationBootstrap(patientId),
      queryParameters: {'appointment_id': appointmentId},
    );
    return ConsultationBootstrapData.fromJson(res.data ?? const {});
  }
}
