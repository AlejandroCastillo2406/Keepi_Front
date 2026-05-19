import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/doctor/analysis_document_viewer_screen.dart';
import 'api_client.dart';
import 'doctor_service.dart';
import 'drive_structure_service.dart';

/// Abre archivos según el almacenamiento (Keepi Cloud / Google Drive / documento DB).
class DocumentFileOpener {
  static final _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isS3Path(String fileId) => fileId.startsWith('users/');

  static bool isDocumentUuid(String id) => _uuidRe.hasMatch(id);

  static Future<void> open(
    BuildContext context, {
    required DriveFile file,
    bool preferInAppWebView = true,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Abriendo archivo…'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final api = context.read<ApiClient>();
      final drive = DriveStructureService(api);
      var viewUrl = '';
      Map<String, String> headers = const {};

      if (isS3Path(file.id)) {
        final info = await drive.getS3FileViewUrl(file.id);
        viewUrl = info.viewUrl;
      } else if (isDocumentUuid(file.id)) {
        final svc = DoctorService(api);
        final token = api.accessToken;
        viewUrl = svc.getMobileDocumentUrl(file.id);
        if (token != null && token.isNotEmpty) {
          headers = {
            'Authorization': 'Bearer $token',
            'Accept': '*/*',
          };
        }
      } else {
        final info = await drive.getFileViewUrl(file.id);
        viewUrl = info.viewUrl.isNotEmpty ? info.viewUrl : info.downloadUrl;
      }

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();

      if (viewUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la vista previa.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (preferInAppWebView) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnalysisDocumentViewerScreen(
              url: viewUrl,
              title: file.name,
              headers: headers,
            ),
          ),
        );
        return;
      }

      final uri = Uri.parse(viewUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('DioException [bad response]: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
