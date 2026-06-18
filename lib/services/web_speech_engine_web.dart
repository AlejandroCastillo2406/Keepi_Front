import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

typedef WebSpeechTranscriptHandler = void Function(
  String text, {
  required bool isFinal,
});
typedef WebSpeechStatusHandler = void Function(String status);
typedef WebSpeechErrorHandler = void Function(String message);

/// Dictado directo con Web Speech API (`package:web`).
class WebSpeechEngine {
  WebSpeechEngine();

  static const silenceCutoff = Duration(seconds: 3);

  static WebSpeechEngine? _current;

  web.SpeechRecognition? _recognition;
  Timer? _silenceTimer;
  bool _active = false;
  bool _heardSpeech = false;
  bool _ending = false;

  WebSpeechTranscriptHandler? _onTranscript;
  WebSpeechStatusHandler? _onStatus;
  WebSpeechErrorHandler? _onError;

  bool _started = false;
  String? _startError;

  bool get isActive => _active;

  static bool get isSupported {
    final window = web.window;
    return window.hasProperty('SpeechRecognition'.toJS).toDart ||
        window.hasProperty('webkitSpeechRecognition'.toJS).toDart;
  }

  Future<String?> start({
    required String localeId,
    required WebSpeechTranscriptHandler onTranscript,
    WebSpeechStatusHandler? onStatus,
    WebSpeechErrorHandler? onError,
  }) async {
    if (_active) await stop();

    if (!web.window.isSecureContext) {
      return 'El micrófono solo funciona con HTTPS o en localhost.';
    }
    if (!isSupported) {
      return 'Dictado no disponible. Usa Chrome o Edge.';
    }

    _onTranscript = onTranscript;
    _onStatus = onStatus;
    _onError = onError;
    _heardSpeech = false;
    _ending = false;
    _started = false;
    _startError = null;
    _active = true;
    _current = this;

    final recognition = _createRecognition();
    _recognition = recognition;
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = localeId;

    recognition.onstart = _handleStart.toJS;
    recognition.onresult = _handleResult.toJS;
    recognition.onerror = _handleError.toJS;
    recognition.onend = _handleEnd.toJS;

    try {
      recognition.start();
    } on Object catch (e) {
      _active = false;
      _recognition = null;
      _current = null;
      return 'No se pudo iniciar el dictado: $e';
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 3000));
    while (DateTime.now().isBefore(deadline)) {
      if (_started || _startError != null || !_active) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (_startError != null) {
      await _finishSession();
      return _startError;
    }
    if (!_started) {
      await _finishSession();
      return 'No se pudo iniciar el reconocimiento. Revisa el permiso del micrófono.';
    }

    return null;
  }

  Future<void> stop() async {
    await _finishSession(userInitiated: true);
  }

  void dispose() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _ending = true;
    _active = false;
    if (_current == this) _current = null;
    final recognition = _recognition;
    _recognition = null;
    if (recognition != null) {
      try {
        recognition.abort();
      } catch (_) {}
    }
  }

  web.SpeechRecognition _createRecognition() {
    final window = web.window;
    if (window.hasProperty('SpeechRecognition'.toJS).toDart) {
      return web.SpeechRecognition();
    }
    final ctor =
        window.getProperty('webkitSpeechRecognition'.toJS) as JSFunction;
    return ctor.callAsConstructor<web.SpeechRecognition>();
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    if (!_active) return;
    _silenceTimer = Timer(silenceCutoff, () {
      if (_active) {
        unawaited(_finishSession(silenceTimeout: true));
      }
    });
  }

  Future<void> _finishSession({
    bool userInitiated = false,
    bool silenceTimeout = false,
    bool notifyNoSpeech = false,
  }) async {
    if (_ending) return;
    _ending = true;
    _active = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (_current == this) _current = null;

    final recognition = _recognition;
    _recognition = null;

    if (recognition != null) {
      try {
        if (userInitiated || silenceTimeout || notifyNoSpeech) {
          recognition.stop();
        }
      } catch (_) {}
    }

    _onStatus?.call('notListening');

    if (notifyNoSpeech && !_heardSpeech) {
      _onStatus?.call('doneNoResult');
    } else if (_heardSpeech) {
      _onStatus?.call('done');
    } else {
      _onStatus?.call('doneNoResult');
    }
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Permite el micrófono en el navegador (icono del candado).';
      case 'audio-capture':
        return 'No se detectó micrófono. Conecta uno e inténtalo de nuevo.';
      case 'network':
        return 'El reconocimiento de voz necesita conexión a internet.';
      default:
        return 'Error de dictado: $code';
    }
  }

  static void _handleStart(web.Event _) {
    final engine = _current;
    if (engine == null || !engine._active) return;
    engine._started = true;
    engine._onStatus?.call('listening');
    engine._armSilenceTimer();
  }

  static void _handleResult(web.Event event) {
    final engine = _current;
    if (engine == null || !engine._active) return;
    if (event is! web.SpeechRecognitionEvent) return;

    try {
      final results = event.results;
      final length = results.length;
      final buffer = StringBuffer();
      var lastIsFinal = false;

      for (var i = 0; i < length; i++) {
        final result = results.item(i);
        if (result.length == 0) continue;
        buffer.write(result.item(0).transcript);
        if (i == length - 1) {
          lastIsFinal = result.isFinal;
        }
      }

      final text = buffer.toString().trim();
      if (text.isEmpty) return;
      engine._heardSpeech = true;
      engine._armSilenceTimer();
      engine._onTranscript?.call(text, isFinal: lastIsFinal);
    } catch (_) {}
  }

  static void _handleError(web.Event event) {
    final engine = _current;
    if (engine == null) return;
    if (event is! web.SpeechRecognitionErrorEvent) return;

    final code = event.error;
    if (code == 'aborted') return;
    if (code == 'no-speech') {
      unawaited(engine._finishSession(notifyNoSpeech: true));
      return;
    }
    engine._startError ??= engine._humanizeError(code);
    engine._onError?.call(engine._startError!);
    unawaited(engine._finishSession());
  }

  static void _handleEnd(web.Event _) {
    final engine = _current;
    if (engine == null || engine._ending) return;
    unawaited(engine._finishSession());
  }
}
