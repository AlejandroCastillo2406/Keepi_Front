import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/scheduling_service.dart';
import 'keepi_web_dialog.dart';

/// Genera y muestra el enlace web de agenda para un paciente.
class PatientSchedulingLinkDialog {
  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required String patientName,
    String? patientEmail,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PatientSchedulingLinkDialogBody(
        patientId: patientId,
        patientName: patientName,
        patientEmail: patientEmail,
      ),
    );
  }
}

class _PatientSchedulingLinkDialogBody extends StatefulWidget {
  const _PatientSchedulingLinkDialogBody({
    required this.patientId,
    required this.patientName,
    this.patientEmail,
  });

  final String patientId;
  final String patientName;
  final String? patientEmail;

  @override
  State<_PatientSchedulingLinkDialogBody> createState() =>
      _PatientSchedulingLinkDialogBodyState();
}

class _PatientSchedulingLinkDialogBodyState
    extends State<_PatientSchedulingLinkDialogBody> {
  bool _loading = true;
  bool _sendingEmail = false;
  String? _error;
  PatientSchedulingLinkDto? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SchedulingService(context.read<ApiClient>());
      final result = await svc.generatePatientSchedulingLink(widget.patientId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = SchedulingService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  Future<void> _openLink(String link) async {
    if (!link.startsWith('http')) return;
    final uri = Uri.tryParse(link);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail() async {
    final email = (widget.patientEmail ?? '').trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El paciente no tiene correo registrado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sendingEmail = true);
    try {
      final result = await SchedulingService(context.read<ApiClient>())
          .emailPatientSchedulingLink(widget.patientId);
      if (!mounted) return;
      setState(() => _sendingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.emailSent
                ? 'Correo enviado a $email'
                : (result.emailError ?? result.message).isNotEmpty
                    ? (result.emailError ?? result.message)
                    : 'No se pudo enviar el correo.',
          ),
          backgroundColor:
              result.emailSent ? KeepiColors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SchedulingService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final link = result?.schedulingLink.trim() ?? '';
    final hasWebLink = link.startsWith('http');

    return KeepiWebDialogShell(
      title: 'Link de agenda web',
      subtitle: 'Enlace único para que el paciente agende en línea.',
      tag: 'AGENDA WEB',
      icon: Icons.link_rounded,
      iconAccent: KeepiColors.skyBlue,
      maxWidth: 520,
      maxHeightFactor: 0.72,
      child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(color: KeepiColors.orange),
                ),
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: KeepiColors.slate),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Paciente: ${result?.patientName.isNotEmpty == true ? result!.patientName : widget.patientName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: KeepiColors.slate,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (result?.message.isNotEmpty == true)
                        Text(
                          result!.message,
                          style: const TextStyle(
                            color: KeepiColors.slateLight,
                            height: 1.45,
                            fontSize: 13.5,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KeepiColors.surfaceBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KeepiColors.cardBorder),
                        ),
                        child: SelectableText(
                          link,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KeepiColors.slate,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Este enlace es único para este paciente y siempre será el mismo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ),
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (!_loading && _error == null && hasWebLink)
            OutlinedButton.icon(
              onPressed: () => _openLink(link),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir'),
            ),
          if (!_loading && _error == null && link.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _copyLink(link),
              style: FilledButton.styleFrom(
                backgroundColor: KeepiColors.orange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar enlace'),
            ),
          if (!_loading && _error == null && hasWebLink)
            TextButton.icon(
              onPressed: _sendingEmail ? null : _sendEmail,
              icon: _sendingEmail
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.outgoing_mail, size: 18),
              label: Text(_sendingEmail ? 'Enviando…' : 'Enviar por correo'),
            ),
        ],
      ),
    );
  }
}
