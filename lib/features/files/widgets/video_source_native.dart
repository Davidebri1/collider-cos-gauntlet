import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// A controller for the stored [bytes] (written to the cache; removed by
/// [release]).
class VideoSource {
  final VideoPlayerController controller;
  final File _file;
  VideoSource._(this.controller, this._file);

  static Future<VideoSource?> open(String name, Uint8List bytes, String mime) async {
    try {
      final tmp = await getTemporaryDirectory();
      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final f = File('${tmp.path}${Platform.pathSeparator}play_$safe');
      await f.writeAsBytes(bytes, flush: true);
      return VideoSource._(VideoPlayerController.file(f), f);
    } catch (_) {
      return null;
    }
  }

  Future<void> release() async {
    await controller.dispose();
    try {
      await _file.delete();
    } catch (_) {}
  }
}
