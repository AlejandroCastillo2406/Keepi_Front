import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado por voz para campos de texto (Web Speech API en navegador).
/// No fija un idioma: en web deja que el motor del navegador infiera español/inglés.
class SpeechDictationService {
  SpeechDictationService();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  bool get isListening => _listening;
  bool get isInitialized => _initialized;

  Future<String?> initialize({
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) async {
    if (_initialized) return null;

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          _listening = false;
        }
        onStatus?.call(status);
      },
      onError: (error) {
        _listening = false;
        onError?.call(error.errorMsg);
      },
    );

    _initialized = ok;
    if (!ok) {
      return 'No se pudo iniciar el dictado por voz en este dispositivo.';
    }
    if (!_speech.isAvailable) {
      return 'Dictado no disponible. Usa Chrome o Edge y permite el micrófono.';
    }
    return null;
  }

  /// En web: null → sin `lang` fijo (detección automática del motor de Google).
  /// En móvil: coincide con el idioma del sistema sin forzar español.
  Future<String?> _resolveLocaleHint() async {
    if (kIsWeb) return null;

    final userTag = PlatformDispatcher.instance.locale.toLanguageTag();
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return userTag;

      final normalized = userTag.toLowerCase().replaceAll('_', '-');
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (id == normalized) return locale.localeId;
      }

      final lang = normalized.split('-').first;
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id.startsWith(lang)) return locale.localeId;
      }

      return locales.first.localeId;
    } catch (_) {
      return userTag;
    }
  }

  Future<String?> start({
    required void Function(String text, {required bool isFinal}) onTranscript,
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) async {
    if (_listening) return null;

    final initError = await initialize(onStatus: onStatus, onError: onError);
    if (initError != null) return initError;

    final locale = await _resolveLocaleHint();

    _listening = true;
    await _speech.listen(
      onResult: (result) {
        onTranscript(
          result.recognizedWords,
          isFinal: result.finalResult,
        );
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        localeId: locale,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    return null;
  }

  Future<void> stop() async {
    if (!_listening) return;
    await _speech.stop();
    _listening = false;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _listening = false;
  }

  void dispose() {
    _speech.stop();
  }
}
