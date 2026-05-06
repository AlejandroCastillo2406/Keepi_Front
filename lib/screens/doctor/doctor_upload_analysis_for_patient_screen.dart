import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

class DoctorUploadAnalysisForPatientScreen extends StatefulWidget {
  const DoctorUploadAnalysisForPatientScreen({
    super.key,
    required this.requestId,
    required this.description,
    required this.patientName,
  });

  final String requestId;
  final String description;
  final String patientName;

  @override
  State<DoctorUploadAnalysisForPatientScreen> createState() =>
      _DoctorUploadAnalysisForPatientScreenState();
}

class _DoctorUploadAnalysisForPatientScreenState
    extends State<DoctorUploadAnalysisForPatientScreen> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      setState(() => _selectedFile = result.files.first);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al seleccionar el archivo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final api = context.read<ApiClient>();
      final svc = DoctorService(api);
      final formData = FormData.fromMap({
        'file': kIsWeb
            ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
            : await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      await svc.doctorUploadAnalysisAndComplete(
        requestId: widget.requestId,
        formData: formData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte subido y solicitud completada.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error de red/servidor: ${DoctorService.messageFromDio(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = _selectedFile?.name;
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Subir reporte físico',
          style: TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KeepiColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patientName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.skyBlue,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _isUploading ? null : _pickDocument,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KeepiColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KeepiColors.orangeSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: KeepiColors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: KeepiColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          filename == null || filename.isEmpty
                              ? 'Seleccionar archivo (PDF, JPG, PNG)'
                              : filename,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: filename == null
                                ? KeepiColors.slateLight
                                : KeepiColors.slate,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: KeepiColors.slateLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isUploading || _selectedFile == null ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KeepiColors.orange,
                  disabledBackgroundColor:
                      KeepiColors.orange.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Subir y completar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
