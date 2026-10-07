import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Plays [url] muted and looping, painted with BoxFit.cover. Shows nothing
/// until the first frame is ready (the poster underneath stays visible).
class LiveCoverVideo extends StatefulWidget {
  final String url;
  const LiveCoverVideo({super.key, required this.url});

  @override
  State<LiveCoverVideo> createState() => _LiveCoverVideoState();
}

class _LiveCoverVideoState extends State<LiveCoverVideo> {
  web.HTMLVideoElement? _v;
  ui.Image? _img;
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = web.document.createElement('video') as web.HTMLVideoElement;
    v.muted = true;
    v.defaultMuted = true;
    v.loop = true;
    v.autoplay = true;
    v.playsInline = true;
    v.setAttribute('muted', '');
    v.setAttribute('playsinline', '');
    v.crossOrigin = 'anonymous';
    v.preload = 'auto';
    // Kept in the document (iOS Safari only decodes attached videos), but
    // invisible and out of the way.
    final s = v.style;
    s.position = 'fixed';
    s.left = '0';
    s.top = '0';
    s.width = '2px';
    s.height = '2px';
    s.opacity = '0';
    s.pointerEvents = 'none';
    s.zIndex = '-1';
    v.src = widget.url;
    web.document.body?.append(v);
    v.play().toDart.catchError((_) => null);
    _v = v;
    // 20 frames a second is plenty for a cover; at most three covers play.
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) => _grab());
  }

  Future<void> _grab() async {
    final v = _v;
    if (v == null || _busy || v.readyState < 2 || v.videoWidth == 0) return;
    _busy = true;
    try {
      final img = await ui_web.createImageFromTextureSource(v, width: v.videoWidth, height: v.videoHeight);
      if (!mounted) {
        img.dispose();
        return;
      }
      final old = _img;
      setState(() => _img = img);
      old?.dispose();
    } catch (_) {
      // Frame not available (e.g. CORS); the poster stays.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    final v = _v;
    if (v != null) {
      v.pause();
      v.removeAttribute('src');
      v.load();
      v.remove();
    }
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) return const SizedBox.shrink();
    return RawImage(image: img, fit: BoxFit.cover);
  }
}
