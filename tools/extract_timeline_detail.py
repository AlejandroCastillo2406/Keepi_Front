import re
from pathlib import Path

src_path = Path(__file__).resolve().parents[1] / "lib/screens/doctor/doctor_patient_timeline_screen.dart"
out_path = Path(__file__).resolve().parents[1] / "lib/widgets/timeline_event_detail_sheet.dart"
text = src_path.read_text(encoding="utf-8")

start_helpers = text.index("  void _openDocumentView")
end_helpers = text.index("  @override\n  Widget build(BuildContext context) {")
start_show = text.index("  void _showEventDetail")
end_show = text.index("  Widget _buildProfessionalCalendarCard")

helpers = text[start_helpers:end_helpers]
show_and_builds = text[start_show:end_show]
end_s3 = end_show

show_and_builds = re.sub(
    r"  void _showEventDetail\(BuildContext context, TimelineEvent event\) \{\n",
    "  Widget _buildDetailContent(BuildContext context) {\n    final event = widget.event;\n",
    show_and_builds,
    count=1,
)

show_and_builds = re.sub(
    r"\n    showModalBottomSheet\([\s\S]*?child: ListView\(\n              controller: controller,",
    "\n    return Container(\n"
    "            decoration: const BoxDecoration(\n"
    "              color: KeepiColors.surfaceBg,\n"
    "              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),\n"
    "            ),\n"
    "            child: ListView(\n"
    "              controller: widget.scrollController,",
    show_and_builds,
    count=1,
)

show_and_builds = show_and_builds.replace(
    "onNoteSaved: _loadTimeline,", "onNoteSaved: widget.onNoteSaved,"
)

show_and_builds = re.sub(
    r"(DoctorEventNoteSection\([\s\S]*?\),\s*)\],\s*\),\s*\),\s*\);\s*\},\s*\);\s*\}",
    r"\1],\n            ),\n          );\n  }",
    show_and_builds,
)

build_helpers = text[end_s3 : text.rindex("\n}")]

header = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../core/app_theme.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import '../services/prescription_service.dart';
import '../services/questionnaire_service.dart';
import '../widgets/doctor_event_note_section.dart';

class TimelineEventDetailSheet extends StatefulWidget {
  const TimelineEventDetailSheet({
    super.key,
    required this.patientId,
    required this.event,
    this.scrollController,
    this.onNoteSaved,
  });

  final String patientId;
  final TimelineEvent event;
  final ScrollController? scrollController;
  final VoidCallback? onNoteSaved;

  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required TimelineEvent event,
    VoidCallback? onNoteSaved,
  }) {
    final isAppointment = event.eventType.toLowerCase() == 'appointment';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: isAppointment ? 0.85 : 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => TimelineEventDetailSheet(
          patientId: patientId,
          event: event,
          onNoteSaved: onNoteSaved,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  State<TimelineEventDetailSheet> createState() =>
      _TimelineEventDetailSheetState();
}

class _TimelineEventDetailSheetState extends State<TimelineEventDetailSheet> {
  String? _openingDocumentId;

"""

footer = """
  @override
  Widget build(BuildContext context) {
    return _buildDetailContent(context);
  }
}
"""

out_path.write_text(header + helpers + show_and_builds + build_helpers + footer, encoding="utf-8")
print("written", out_path)
