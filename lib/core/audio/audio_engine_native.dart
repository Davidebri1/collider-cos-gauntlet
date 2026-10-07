// Native audio engine (iOS / Android): just_audio, one player, the same
// play / pause / stop / ended contract as the web HTMLAudioElement engine.
import 'package:just_audio/just_audio.dart';

class AudioEngine {
  AudioPlayer? _player;
  String _src = '';
  void Function()? onEnded;

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    p.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) onEnded?.call();
    });
    _player = p;
    return p;
  }

  Future<void> play(String url) async {
    final p = _ensure();
    try {
      if (_src != url) {
        _src = url;
        if (url.startsWith('http')) {
          await p.setUrl(url);
        } else {
          // Bundled asset: the web engine gets 'assets/<path>'; Flutter's
          // asset key is the same '<path>' declared in pubspec.
          await p.setAsset(url.startsWith('assets/') ? url.substring(7) : url);
        }
      }
      await p.play();
    } catch (_) {
      _src = '';
    }
  }

  void pause() => _player?.pause();

  void stop() {
    _player?.stop();
    _player?.dispose();
    _player = null;
    _src = '';
  }
}
