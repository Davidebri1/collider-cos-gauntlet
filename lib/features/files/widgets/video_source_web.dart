import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

/// A controller for the stored [bytes] (an object URL; freed by [release]).
class VideoSource {
  final VideoPlayerController controller;
  final String _url;
  VideoSource._(this.controller, this._url);

  static Future<VideoSource?> open(String name, Uint8List bytes, String mime) async {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
      final url = web.URL.createObjectURL(blob);
      return VideoSource._(VideoPlayerController.networkUrl(Uri.parse(url)), url);
    } catch (_) {
      return null;
    }
  }

  Future<void> release() async {
    await controller.dispose();
    web.URL.revokeObjectURL(_url);
  }
}
