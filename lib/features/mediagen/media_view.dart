// Shows one generated asset: an image (data: URI or URL), a looping video,
// or an audio clip with its own play/pause.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../core/vision/vision_kit.dart';

class GenMediaView extends StatelessWidget {
  final String url;
  final String kind; // image | video | audio
  final BoxFit fit;
  const GenMediaView({super.key, required this.url, required this.kind, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (kind == 'video') return _GenVideo(url: url);
    if (kind == 'audio') return _GenAudio(url: url);
    if (url.startsWith('data:')) {
      final i = url.indexOf(',');
      return Image.memory(base64Decode(url.substring(i + 1)), fit: fit, gaplessPlayback: true, width: double.infinity, height: double.infinity);
    }
    return Image.network(url, fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }
}

class _GenVideo extends StatefulWidget {
  final String url;
  const _GenVideo({required this.url});
  @override
  State<_GenVideo> createState() => _GenVideoState();
}

class _GenVideoState extends State<_GenVideo> {
  VideoPlayerController? _c;
  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setVolume(0)
        ..setLooping(true)
        ..play();
      setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)));
  }
}

class _GenAudio extends StatefulWidget {
  final String url;
  const _GenAudio({required this.url});
  @override
  State<_GenAudio> createState() => _GenAudioState();
}

class _GenAudioState extends State<_GenAudio> {
  final AudioPlayer _p = AudioPlayer();
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _p.setUrl(widget.url).then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((_) => null);
    _p.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _p.playing;
    return ColoredBox(
      color: const Color(0xFF101014),
      child: Center(
        child: VCircleButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 64,
          tooltip: playing ? 'Pause' : 'Play',
          onTap: !_ready ? null : () => playing ? _p.pause() : _p.play(),
        ),
      ),
    );
  }
}
