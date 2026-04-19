import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

class DoctorRequestAnalysisScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorRequestAnalysisScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorRequestAnalysisScreen> createState() => _DoctorRequestAnalysisScreenState();
}

class _DoctorRequestAnalysisScreenState extends State<DoctorRequestAnalysisScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  /// Lógica para enviar la solicitud al backend
  Future<void> _sendRequest() async {
    final message = _controller.text.trim();
    
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escribe una descripción')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    try {
      final svc = DoctorService(context.read<ApiClient>());

      await svc.createAnalysisRequest(
        patientId: widget.patientId,
        description: message,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada con éxito'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DoctorService.messageFromDio(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Solicitar Análisis',
          style: TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con el nombre del paciente, matching mockup
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_rounded, color: KeepiColors.orange, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOLICITANDO PARA:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: KeepiColors.orange),
                          ),
                          Text(
                            widget.patientName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KeepiColors.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '¿Qué documentos requieres?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KeepiColors.slate),
              ),
              const SizedBox(height: 8),
              const Text(
                'El paciente recibirá una notificación y podrá subir los archivos directamente desde su panel.',
                style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              
              // Campo de texto para la descripción, multiline as in mockup
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null, // Makes it multiline
                  expands: true, // Takes up all remaining space
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Ej: Favor de subir resultados de química sanguínea...',
                    hintStyle: TextStyle(color: KeepiColors.slateLight.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: KeepiColors.cardBorder.withOpacity(0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: KeepiColors.cardBorder.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: KeepiColors.orange, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Botón de acción enviar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          'Enviar solicitud al paciente',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}