import 'package:dio/dio.dart';
import '../../services/api_client.dart';

class DocumentosService {
  final ApiClient api;

  DocumentosService(this.api);

  Future<Map<String, dynamic>> fetchDashboard({int limit = 10}) async {
    try {
      // Corregimos la ruta incluyendo /api/v1/ para evitar el error 404
      final response = await api.dio.get(
        '/api/v1/documents/mobile/dashboard',
        queryParameters: {'limit': limit},
      );
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // Manejo de errores específico de Dio
      throw Exception(e.message ?? 'Error de conexión con el servidor');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }
}