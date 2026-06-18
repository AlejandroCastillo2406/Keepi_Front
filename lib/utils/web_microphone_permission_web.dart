import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.MediaStream? _activeMicStream;

Future<String?> ensureMicrophonePermission() async {
  if (!web.window.isSecureContext) {
    return 'El micrófono solo funciona con HTTPS o en localhost.';
  }

  try {
    releaseWebMicrophone();
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    // Liberar de inmediato: el permiso queda concedido pero el stream no
    // debe bloquear la Web Speech API durante el dictado.
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    _activeMicStream = null;
    return null;
  } on Object catch (_) {
    return 'Permite el micrófono en el navegador (icono del candado en la barra de direcciones).';
  }
}

void releaseWebMicrophone() {
  final stream = _activeMicStream;
  if (stream == null) return;
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
  _activeMicStream = null;
}
