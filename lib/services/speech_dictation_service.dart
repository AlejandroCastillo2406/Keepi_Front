import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kDebugMode;
import 'package:speech_to_text/speech_to_text.dart';

import 'web_speech_engine.dart';

/// Dictado por voz: Web Speech API en navegador, speech_to_text en móvil/desktop.
class SpeechDictationService {
  SpeechDictationService();

  static const silenceCutoff = Duration(seconds: 3);

  final SpeechToText _speech = SpeechToText();
  final WebSpeechEngine _web = WebSpeechEngine();

  bool _initialized = false;
  bool _listening = false;
  bool _sessionActive = false;

  void Function(String status)? _statusHandler;
  void Function(String message)? _errorHandler;
  void Function(String text, {required bool isFinal})? _transcriptHandler;

  bool get isListening =>
      kIsWeb ? _web.isActive : (_listening || _speech.isListening);
  bool get isInitialized => kIsWeb ? WebSpeechEngine.isSupported : _initialized;

  Future<String?> initialize() async {
    if (kIsWeb) {
      if (!WebSpeechEngine.isSupported) {
        return 'Dictado no disponible. Usa Chrome o Edge, HTTPS y permite el micrófono.';
      }
      return null;
    }

    if (_initialized) return null;

    final ok = await _speech.initialize(
      onStatus: _handleNativeStatus,
      onError: (error) {
        _listening = false;
        if (kDebugMode) {
          debugPrint('Speech dictation error: ${error.errorMsg}');
        }
        _errorHandler?.call(error.errorMsg);
      },
    );

    _initialized = ok;
    if (!ok) {
      return 'No se pudo iniciar el dictado por voz en este dispositivo.';
    }
    if (!_speech.isAvailable) {
      return 'Dictado no disponible en este dispositivo.';
    }
    return null;
  }

  void _handleNativeStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _listening = true;
    } else if (status == SpeechToText.doneStatus || status == 'doneNoResult') {
      _listening = false;
      _sessionActive = false;
    }
    _statusHandler?.call(status);
  }

  Future<String?> _resolveLocaleHint() async {
    final userTag = PlatformDispatcher.instance.locale.toLanguageTag();
    if (kIsWeb) {
      final lang = userTag.toLowerCase().split('-').first;
      return lang == 'es' ? 'es-ES' : 'en-US';
    }

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

  Future<String?> _startWeb() async {
    final locale = await _resolveLocaleHint();
    _listening = true;

    return _web.start(
      localeId: locale ?? 'es-ES',
      onTranscript: (text, {required isFinal}) {
        _transcriptHandler?.call(text, isFinal: isFinal);
      },
      onStatus: (status) {
        if (status == 'listening') {
          _listening = true;
        } else if (status == 'notListening' ||
            status == 'done' ||
            status == 'doneNoResult') {
          _listening = false;
          _sessionActive = false;
        }
        _statusHandler?.call(status);
      },
      onError: (message) {
        _listening = false;
        _sessionActive = false;
        _errorHandler?.call(message);
      },
    );
  }

  Future<bool> _waitUntilListening({
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_speech.isListening || _listening) return true;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return _speech.isListening || _listening;
  }

  Future<String?> _startNative() async {
    if (!_sessionActive) return null;

    final locale = await _resolveLocaleHint();

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          _transcriptHandler?.call(
            words,
            isFinal: result.finalResult,
          );
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          localeId: locale,
          listenFor: const Duration(minutes: 5),
          pauseFor: silenceCutoff,
        ),
      );
    } catch (e) {
      _listening = false;
      _sessionActive = false;
      return 'No se pudo iniciar el dictado: $e';
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final listening = await _waitUntilListening();
    if (!listening) {
      _listening = false;
      _sessionActive = false;
      return 'No se pudo iniciar el reconocimiento de voz.';
    }

    _listening = true;
    return null;
  }

  Future<String?> start({
    required void Function(String text, {required bool isFinal}) onTranscript,
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) async {
    if (_sessionActive && isListening) return null;

    _transcriptHandler = onTranscript;
    _statusHandler = onStatus;
    _errorHandler = onError;
    _sessionActive = true;

    final initError = await initialize();
    if (initError != null) {
      _sessionActive = false;
      return initError;
    }

    if (kIsWeb) {
      final error = await _startWeb();
      if (error != null) {
        _sessionActive = false;
        _listening = false;
      }
      return error;
    }

    return _startNative();
  }

  Future<void> stop() async {
    _sessionActive = false;
    _listening = false;
    if (kIsWeb) {
      await _web.stop();
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    _sessionActive = false;
    _listening = false;
    if (kIsWeb) {
      await _web.stop();
      return;
    }
    await _speech.cancel();
  }

  void dispose() {
    _sessionActive = false;
    if (kIsWeb) {
      _web.dispose();
      return;
    }
    _speech.stop();
  }
}
