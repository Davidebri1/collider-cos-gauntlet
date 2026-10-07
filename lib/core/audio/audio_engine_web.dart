// Web audio engine. Made by Claude.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class AudioEngine {
  web.HTMLAudioElement? _el;
  String _src = '';
  void Function()? onEnded;

  void play(String url) {
    if (_el == null) {
      _el = web.HTMLAudioElement();
      _el!.addEventListener('ended', ((web.Event _) { onEnded?.call(); }).toJS);
    }
    if (_src != url) {
      _src = url;
      _el!.src = url;
    }
    _el!.play();
  }

  void pause() => _el?.pause();

  void stop() {
    _el?.pause();
    _el = null;
    _src = '';
  }
}
