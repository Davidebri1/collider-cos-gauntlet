import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Plays [url] muted and looping, filling the cover (BoxFit.cover). Shows
/// nothing until the first frame is ready (the poster underneath stays).
class LiveCoverVideo extends StatefulWidget {
  final String url;
  const LiveCoverVideo({super.key, required this.url});

  @override
  State<LiveCoverVideo> createState() => _LiveCoverVideoState();
}

class _LiveCoverVideoState extends State<LiveCoverVideo> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c.setLooping(true);
    _c.setVolume(0);
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.play();
      setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const SizedBox.shrink();
    final s = _c.value.size;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: s.width, height: s.height, child: VideoPlayer(_c)),
      ),
    );
  }
}
