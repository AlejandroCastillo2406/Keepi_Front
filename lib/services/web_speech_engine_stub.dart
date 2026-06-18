typedef WebSpeechTranscriptHandler = void Function(
  String text, {
  required bool isFinal,
});
typedef WebSpeechStatusHandler = void Function(String status);
typedef WebSpeechErrorHandler = void Function(String message);

/// Sin soporte fuera de web.
class WebSpeechEngine {
  static bool get isSupported => false;

  bool get isActive => false;

  Future<String?> start({
    required String localeId,
    required WebSpeechTranscriptHandler onTranscript,
    WebSpeechStatusHandler? onStatus,
    WebSpeechErrorHandler? onError,
  }) async {
    return 'Dictado por voz no disponible en esta plataforma.';
  }

  Future<void> stop() async {}

  void dispose() {}
}
