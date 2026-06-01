import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../widgets/doctor_note_field.dart';

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
  final _noteCtrl = TextEditingController();
  bool _isSending = false;
  DateTime? _deadline;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  /// Lógica para enviar la solicitud al backend
  Future<void> _sendRequest() async {
    final message = _controller.text.trim();
    
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escribe una descripción')),
      );
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una fecha límite')),
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
        expiresAt: _deadline!,
        doctorNote: _noteCtrl.text.trim(),
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
              const SizedBox(height: 16),
              
              // Selector de fecha límite
              const Text(
                'Fecha límite de entrega',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: KeepiColors.slate),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KeepiColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: KeepiColors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deadline == null
                              ? 'Seleccionar fecha límite'
                              : '${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _deadline == null ? FontWeight.w500 : FontWeight.w700,
                            color: _deadline == null ? KeepiColors.slateLight : KeepiColors.slate,
                          ),
                        ),
                      ),
                      if (_deadline != null)
                        const Icon(Icons.check_circle_rounded, color: KeepiColors.green, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DoctorNoteField(controller: _noteCtrl, enabled: !_isSending),
              const SizedBox(height: 20),
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
    _noteCtrl.dispose();
    super.dispose();
  }
}