// Per-category generation settings, with the source composer's defaults
// (PromptComposer.tsx: image 9:16 / standard / neutral, video 9:16 / 720p /
// 4s / medium motion, audio 30s / vocal / 128 kbps / mp3).
import '../../models/media_specs.dart';
import '../../models/model_def.dart';

class GenSettings {
  String? task;
  String ar;
  String quality;
  String? resolution;
  String style;
  String negative;
  int duration;
  String motion;
  String? voice;
  String vocals;
  String bitrate;
  String format;

  GenSettings._(this.task, this.ar, this.quality, this.duration)
      : style = 'neutral',
        negative = '',
        motion = 'medium',
        vocals = 'vocal',
        bitrate = 'standard',
        format = 'mp3';

  factory GenSettings.defaultsFor(ModelCategory c) => switch (c) {
        ModelCategory.image => GenSettings._(defaultTaskFor(c), '9:16', 'standard', 4),
        ModelCategory.video => GenSettings._(defaultTaskFor(c), '9:16', '720p', 4),
        ModelCategory.audio => GenSettings._(defaultTaskFor(c), '9:16', 'standard', 30),
        _ => GenSettings._(null, '9:16', 'standard', 4),
      };

  GenFlags flags(ModelCategory c) => switch (c) {
        ModelCategory.image => GenFlags(task: task, ar: ar, quality: quality, resolution: resolution, style: style, negative: negative.isEmpty ? null : negative, count: 1),
        ModelCategory.video => GenFlags(task: task, ar: ar, quality: quality, duration: duration, motion: motion),
        ModelCategory.audio => GenFlags(task: task, duration: duration, voice: voice, vocals: vocals, bitrate: bitrate, format: format),
        _ => const GenFlags(),
      };

  /// Snap every value to what the selected models actually accept
  /// (never offer a value one of them will reject).
  void fitTo(ModelCategory c, List<ModelDef> models) {
    final ids = models.map((m) => m.id).toList();
    if (c == ModelCategory.image) {
      final o = intersectImageOptions(ids);
      if (o != null && o.aspectRatios.isNotEmpty && !o.aspectRatios.contains(ar)) ar = o.aspectRatios.contains('9:16') ? '9:16' : o.aspectRatios.first;
      if (o == null || o.resolutions.isEmpty) {
        resolution = null;
      } else if (resolution != null && !o.resolutions.contains(resolution)) {
        resolution = null;
      }
    } else if (c == ModelCategory.video) {
      final o = intersectVideoOptions(ids);
      final d = durationChoicesFor(models);
      if (d.isNotEmpty && !d.contains(duration)) duration = d.first;
      if (o != null && o.aspectRatios.isNotEmpty && !o.aspectRatios.contains(ar)) ar = o.aspectRatios.first;
      if (o != null && o.resolutions.isNotEmpty && !o.resolutions.contains(quality)) quality = o.resolutions.first;
    } else if (c == ModelCategory.audio) {
      final caps = unionCapabilities(models);
      if (caps.outputFormats.isNotEmpty && !caps.outputFormats.contains(format)) format = caps.outputFormats.first;
      if (voice != null && !caps.voices.contains(voice)) voice = null;
    }
  }
}
