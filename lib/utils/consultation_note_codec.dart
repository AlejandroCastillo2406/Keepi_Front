/// Separa notas clínicas y signos vitales en el TXT guardado en S3.
class ConsultationVitals {
  const ConsultationVitals({
    this.bloodPressure = '',
    this.heartRate = '',
    this.temperature = '',
    this.allergies = '',
  });

  final String bloodPressure;
  final String heartRate;
  final String temperature;
  final String allergies;

  bool get isEmpty =>
      bloodPressure.isEmpty &&
      heartRate.isEmpty &&
      temperature.isEmpty &&
      allergies.isEmpty;

  bool get isComplete =>
      bloodPressure.isNotEmpty &&
      heartRate.isNotEmpty &&
      temperature.isNotEmpty;

  ConsultationVitals copyWith({
    String? bloodPressure,
    String? heartRate,
    String? temperature,
    String? allergies,
  }) {
    return ConsultationVitals(
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      temperature: temperature ?? this.temperature,
      allergies: allergies ?? this.allergies,
    );
  }
}

class ConsultationNoteCodec {
  static const _markerStart = '--- KEEPIMETRICAS ---';
  static const _markerEnd = '--- FIN KEEPIMETRICAS ---';

  static ({String clinicalNote, ConsultationVitals vitals}) decode(
    String raw,
  ) {
    final text = raw.trim();
    if (!text.contains(_markerStart)) {
      return (clinicalNote: text, vitals: const ConsultationVitals());
    }

    final parts = text.split(_markerStart);
    final clinical = parts.first.trim();
    final block = parts.length > 1 ? parts[1] : '';
    final vitalsText = block.split(_markerEnd).first.trim();

    String read(String label) {
      for (final line in vitalsText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('$label:')) {
          return trimmed.substring(label.length + 1).trim();
        }
      }
      return '';
    }

    return (
      clinicalNote: clinical,
      vitals: ConsultationVitals(
        bloodPressure: read('Presión'),
        heartRate: read('Frecuencia cardíaca'),
        temperature: read('Temperatura'),
        allergies: read('Alergias'),
      ),
    );
  }

  static String encode({
    required String clinicalNote,
    required ConsultationVitals vitals,
  }) {
    final note = clinicalNote.trim();
    if (vitals.isEmpty) return note;

    final buffer = StringBuffer();
    if (note.isNotEmpty) {
      buffer.writeln(note);
      buffer.writeln();
    }
    buffer.writeln(_markerStart);
    if (vitals.bloodPressure.isNotEmpty) {
      buffer.writeln('Presión: ${vitals.bloodPressure}');
    }
    if (vitals.heartRate.isNotEmpty) {
      buffer.writeln('Frecuencia cardíaca: ${vitals.heartRate}');
    }
    if (vitals.temperature.isNotEmpty) {
      buffer.writeln('Temperatura: ${vitals.temperature}');
    }
    if (vitals.allergies.isNotEmpty) {
      buffer.writeln('Alergias: ${vitals.allergies}');
    }
    buffer.writeln(_markerEnd);
    return buffer.toString().trim();
  }
}
