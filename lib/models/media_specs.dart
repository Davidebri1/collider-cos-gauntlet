// v8.3 media restore: ports of the source app's services/capabilities.ts,
// services/imageSpecs.ts, services/videoSpecs.ts and services/pricing.ts
// (collidermergedx3-glm). Same tasks, same per-model specs, same published
// USD rates, same credit arithmetic. Nothing here is invented.
import 'dart:math' as math;

import 'model_def.dart';

// ───────────────────────────── capabilities.ts ─────────────────────────────

class TaskDef {
  final String id;
  final String label;
  final ModelCategory category;
  final List<String> requires;
  final String output;
  final bool routable;
  final String? requiresCapability;
  const TaskDef(this.id, this.label, this.category, this.requires, this.output, this.routable, [this.requiresCapability]);
}

/// capabilities.ts TASKS, in source order.
const List<TaskDef> kTasks = [
  TaskDef('text-to-image', 'Text → Image', ModelCategory.image, [], 'image', true),
  TaskDef('image-to-image', 'Image → Image', ModelCategory.image, ['image'], 'image', true, 'references'),
  TaskDef('inpaint', 'Edit region', ModelCategory.image, ['image'], 'image', true, 'references'),
  TaskDef('outpaint', 'Expand canvas', ModelCategory.image, ['image'], 'image', true, 'references'),
  TaskDef('upscale-image', 'Upscale', ModelCategory.image, ['image'], 'image', true, 'resolution'),
  TaskDef('remove-background', 'Remove background', ModelCategory.image, ['image'], 'image', true, 'transparent'),
  TaskDef('text-to-video', 'Text → Video', ModelCategory.video, [], 'video', true),
  TaskDef('image-to-video', 'Image → Video', ModelCategory.video, ['image'], 'video', true),
  TaskDef('keyframe-video', 'Start + End', ModelCategory.video, ['image'], 'video', true),
  TaskDef('video-to-video', 'Restyle', ModelCategory.video, ['video'], 'video', false),
  TaskDef('extend-video', 'Extend', ModelCategory.video, ['video'], 'video', false),
  TaskDef('video-inpaint', 'Edit region', ModelCategory.video, ['video'], 'video', false),
  TaskDef('upscale-video', 'Upscale', ModelCategory.video, ['video'], 'video', false),
  TaskDef('text-to-speech', 'Text → Speech', ModelCategory.audio, [], 'audio', true),
  TaskDef('speech-to-text', 'Transcribe', ModelCategory.audio, ['audio'], 'text', true),
  TaskDef('text-to-music', 'Text → Music', ModelCategory.audio, [], 'audio', true),
  TaskDef('sound-effect', 'Sound effect', ModelCategory.audio, [], 'audio', true),
  TaskDef('dubbing', 'Dub', ModelCategory.audio, ['audio'], 'audio', true),
];

/// tasksForCategory: routable ones first (stable).
List<TaskDef> tasksForCategory(ModelCategory c) {
  final l = kTasks.where((t) => t.category == c).toList();
  return [...l.where((t) => t.routable), ...l.where((t) => !t.routable)];
}

String? defaultTaskFor(ModelCategory c) {
  for (final t in tasksForCategory(c)) {
    if (t.routable) return t.id;
  }
  return null;
}

TaskDef? taskById(String? id) {
  for (final t in kTasks) {
    if (t.id == id) return t;
  }
  return null;
}

class ModelCapabilities {
  final List<String> inputs;
  final List<String> outputs;
  final int maxInputMB;
  final List<String> acceptedFormats;
  final List<String> outputFormats;
  final List<String> voices;
  const ModelCapabilities({required this.inputs, required this.outputs, required this.maxInputMB, required this.acceptedFormats, required this.outputFormats, this.voices = const []});
  ModelCapabilities copyWith({List<String>? inputs, List<String>? outputs, List<String>? acceptedFormats, List<String>? outputFormats, List<String>? voices}) => ModelCapabilities(
        inputs: inputs ?? this.inputs,
        outputs: outputs ?? this.outputs,
        maxInputMB: maxInputMB,
        acceptedFormats: acceptedFormats ?? this.acceptedFormats,
        outputFormats: outputFormats ?? this.outputFormats,
        voices: voices ?? this.voices,
      );
}

const _imageIn = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
const _audioIn = ['mp3', 'wav', 'm4a', 'ogg', 'webm', 'flac', 'mpga', 'mpeg'];

const Map<ModelCategory, ModelCapabilities> _byCategory = {
  ModelCategory.general: ModelCapabilities(inputs: ['text', 'image'], outputs: ['text'], maxInputMB: 20, acceptedFormats: _imageIn, outputFormats: ['text', 'markdown']),
  ModelCategory.coding: ModelCapabilities(inputs: ['text', 'image'], outputs: ['text'], maxInputMB: 20, acceptedFormats: [..._imageIn, 'txt', 'md', 'json', 'csv'], outputFormats: ['text', 'markdown', 'diff']),
  ModelCategory.image: ModelCapabilities(inputs: ['text', 'image'], outputs: ['image'], maxInputMB: 20, acceptedFormats: _imageIn, outputFormats: ['png', 'jpg', 'webp']),
  ModelCategory.video: ModelCapabilities(inputs: ['text', 'image'], outputs: ['video'], maxInputMB: 20, acceptedFormats: _imageIn, outputFormats: ['mp4']),
  ModelCategory.audio: ModelCapabilities(inputs: ['text'], outputs: ['audio'], maxInputMB: 25, acceptedFormats: [], outputFormats: ['mp3', 'wav', 'opus', 'flac']),
};

ModelCapabilities capabilitiesFor(ModelDef m) {
  final base = _byCategory[m.category] ?? _byCategory[ModelCategory.general]!;
  switch (m.id) {
    case 'vid/wan-2-6':
      return base.copyWith(inputs: ['text', 'image', 'audio'], acceptedFormats: [..._imageIn, ..._audioIn]);
    case 'vid/veo-3':
      return base.copyWith(inputs: ['text', 'image'], outputFormats: ['mp4']);
    case 'aud/lyria-3-clip':
      return base.copyWith(inputs: ['text'], outputFormats: ['mp3', 'wav']);
    case 'aud/lyria-3-pro':
      return base.copyWith(inputs: ['text'], outputFormats: ['mp3', 'wav', 'flac']);
    case 'aud/kokoro-82m':
      return base.copyWith(inputs: ['text'], outputFormats: ['mp3', 'wav', 'opus'], voices: ['af_bella', 'af_sarah', 'am_adam', 'am_michael', 'bf_emma', 'bm_george']);
    case 'aud/gemini-3-1-flash-tts':
      return base.copyWith(inputs: ['text'], outputFormats: ['mp3', 'wav'], voices: ['Zephyr', 'Puck', 'Charon', 'Kore', 'Fenrir', 'Aoede']);
    case 'aud/voxtral-mini-tts':
      return base.copyWith(inputs: ['text', 'audio'], acceptedFormats: _audioIn, outputFormats: ['mp3', 'wav'], voices: ['default']);
    case 'aud/gpt-audio':
      return base.copyWith(inputs: ['text', 'audio'], outputs: ['audio', 'text'], acceptedFormats: _audioIn, outputFormats: ['mp3', 'wav', 'opus', 'flac'], voices: ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']);
    case 'aud/gpt-audio-mini':
      return base.copyWith(inputs: ['text', 'audio'], outputs: ['audio', 'text'], acceptedFormats: _audioIn, outputFormats: ['mp3', 'wav', 'opus'], voices: ['alloy', 'echo', 'nova', 'shimmer']);
  }
  return base;
}

/// unionCapabilities: the "global featureset" of the selected models.
ModelCapabilities unionCapabilities(List<ModelDef> models) {
  if (models.isEmpty) return _byCategory[ModelCategory.general]!;
  final caps = models.map(capabilitiesFor).toList();
  List<String> u(List<String> Function(ModelCapabilities) pick) => {for (final c in caps) ...pick(c)}.toList();
  var outFormats = caps.first.outputFormats;
  for (final c in caps) {
    outFormats = outFormats.where((f) => c.outputFormats.contains(f)).toList();
  }
  return ModelCapabilities(
    inputs: u((c) => c.inputs),
    outputs: u((c) => c.outputs),
    maxInputMB: caps.map((c) => c.maxInputMB).reduce(math.min),
    acceptedFormats: u((c) => c.acceptedFormats),
    outputFormats: outFormats,
    voices: u((c) => c.voices),
  );
}

// ───────────────────────────── imageSpecs.ts ─────────────────────────────

class ImageSpec {
  final String remote;
  final List<String> aspectRatios;
  final List<String> resolutions;
  final int maxCount;
  final int maxReferences;
  final List<String> backgrounds;
  final List<String> outputFormats;
  final double? usdPerImage;
  final double? usdPerMegapixel;
  final double? usdPerToken;
  const ImageSpec({required this.remote, required this.aspectRatios, required this.resolutions, required this.maxCount, required this.maxReferences, required this.backgrounds, required this.outputFormats, this.usdPerImage, this.usdPerMegapixel, this.usdPerToken});
}

const Map<String, ImageSpec> kImageSpecs = {
  'img/gpt-5-4-image-2': ImageSpec(remote: 'openai/gpt-5.4-image-2', aspectRatios: [], resolutions: [], maxCount: 10, maxReferences: 16, backgrounds: ['auto', 'opaque'], outputFormats: [], usdPerToken: 0.00003),
  'img/gpt-5-image-mini': ImageSpec(remote: 'openai/gpt-5-image-mini', aspectRatios: [], resolutions: [], maxCount: 10, maxReferences: 16, backgrounds: ['auto', 'transparent', 'opaque'], outputFormats: [], usdPerToken: 0.000008),
  'img/gemini-3-pro-image': ImageSpec(remote: 'google/gemini-3-pro-image', aspectRatios: ['1:1', '2:3', '3:2', '3:4', '4:3', '4:5', '5:4', '9:16', '16:9', '21:9'], resolutions: ['1K', '2K', '4K'], maxCount: 1, maxReferences: 14, backgrounds: [], outputFormats: [], usdPerToken: 0.00012),
  'img/gemini-3-1-flash-image': ImageSpec(remote: 'google/gemini-3.1-flash-image', aspectRatios: ['1:1', '1:4', '1:8', '2:3', '3:2', '3:4', '4:1', '4:3', '4:5', '5:4', '8:1', '9:16', '16:9', '21:9'], resolutions: ['512', '1K', '2K', '4K'], maxCount: 1, maxReferences: 14, backgrounds: [], outputFormats: [], usdPerToken: 0.00006),
  'img/seedream-4-5': ImageSpec(remote: 'bytedance-seed/seedream-4.5', aspectRatios: ['1:1', '1:2', '2:1', '2:3', '3:2', '3:4', '4:3', '4:5', '5:4', '9:16', '16:9', '9:21', '21:9'], resolutions: ['1K', '2K', '4K'], maxCount: 10, maxReferences: 14, backgrounds: [], outputFormats: [], usdPerImage: 0.04),
  'img/flux-2-max': ImageSpec(remote: 'black-forest-labs/flux.2-max', aspectRatios: ['1:1', '4:3', '3:4', '3:2', '2:3', '16:9', '9:16', '21:9'], resolutions: [], maxCount: 1, maxReferences: 8, backgrounds: [], outputFormats: ['png', 'jpeg'], usdPerMegapixel: 0.07),
  'img/flux-2-klein': ImageSpec(remote: 'black-forest-labs/flux.2-klein-4b', aspectRatios: ['1:1', '4:3', '3:4', '3:2', '2:3', '16:9', '9:16', '21:9'], resolutions: [], maxCount: 1, maxReferences: 4, backgrounds: [], outputFormats: ['png', 'jpeg'], usdPerMegapixel: 0.014),
  'img/flux-free': ImageSpec(remote: 'flux', aspectRatios: ['1:1', '4:3', '3:4', '3:2', '2:3', '16:9', '9:16', '4:5'], resolutions: [], maxCount: 1, maxReferences: 0, backgrounds: [], outputFormats: ['png']),
};

class ImageOptions {
  final List<String> aspectRatios;
  final List<String> resolutions;
  final int maxCount;
  final int maxReferences;
  final bool supportsTransparent;
  const ImageOptions(this.aspectRatios, this.resolutions, this.maxCount, this.maxReferences, this.supportsTransparent);
}

List<T> _inter<T>(List<List<T>> lists, List<T> seed) => lists.fold(seed, (acc, l) => acc.where(l.contains).toList());

/// intersectImageOptions: options every selected image model accepts.
ImageOptions? intersectImageOptions(List<String> ids) {
  final specs = [for (final id in ids) if (kImageSpecs[id] != null) kImageSpecs[id]!];
  if (specs.isEmpty) return null;
  final withRatios = specs.where((s) => s.aspectRatios.isNotEmpty).toList();
  return ImageOptions(
    withRatios.isEmpty ? const [] : _inter(withRatios.map((s) => s.aspectRatios).toList(), withRatios.first.aspectRatios),
    specs.every((s) => s.resolutions.isNotEmpty) ? _inter(specs.map((s) => s.resolutions).toList(), specs.first.resolutions) : const [],
    specs.map((s) => s.maxCount).reduce(math.min),
    specs.map((s) => s.maxReferences).reduce(math.min),
    specs.every((s) => s.backgrounds.contains('transparent')),
  );
}

// ───────────────────────────── videoSpecs.ts ─────────────────────────────

class VideoSpec {
  final String remote;
  final List<int> durations;
  final List<String> aspectRatios;
  final List<String> resolutions;
  final List<String> frameImages;
  final bool generatesAudio;
  final Map<String, double> usdPerSecond;
  final Map<String, double>? usdPerSecondWithAudio;
  const VideoSpec({required this.remote, required this.durations, required this.aspectRatios, required this.resolutions, required this.frameImages, required this.generatesAudio, required this.usdPerSecond, this.usdPerSecondWithAudio});
}

const Map<String, VideoSpec> kVideoSpecs = {
  'vid/veo-3-1-lite': VideoSpec(remote: 'google/veo-3.1-lite', durations: [4, 6, 8], aspectRatios: ['16:9', '9:16'], resolutions: ['720p', '1080p'], frameImages: ['first_frame', 'last_frame'], generatesAudio: true, usdPerSecond: {'720p': 0.03, '1080p': 0.05}, usdPerSecondWithAudio: {'720p': 0.05, '1080p': 0.08}),
  'vid/wan-2-6': VideoSpec(remote: 'alibaba/wan-2.6', durations: [5, 10], aspectRatios: ['16:9', '9:16'], resolutions: ['480p', '720p', '1080p'], frameImages: ['first_frame'], generatesAudio: true, usdPerSecond: {'480p': 0.04, '720p': 0.10, '1080p': 0.15}),
  'vid/grok-imagine-video': VideoSpec(remote: 'x-ai/grok-imagine-video', durations: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], aspectRatios: ['16:9', '9:16', '1:1', '4:3', '3:4', '3:2', '2:3'], resolutions: ['480p', '720p'], frameImages: ['first_frame'], generatesAudio: false, usdPerSecond: {'480p': 0.05, '720p': 0.07}),
  'vid/kling-3-standard': VideoSpec(remote: 'kwaivgi/kling-v3.0-std', durations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], aspectRatios: ['16:9', '9:16', '1:1'], resolutions: ['720p'], frameImages: ['first_frame', 'last_frame'], generatesAudio: true, usdPerSecond: {'720p': 0.084}, usdPerSecondWithAudio: {'720p': 0.126}),
  'vid/veo-3-1-fast': VideoSpec(remote: 'google/veo-3.1-fast', durations: [4, 6, 8], aspectRatios: ['16:9', '9:16'], resolutions: ['720p', '1080p', '4K'], frameImages: ['first_frame', 'last_frame'], generatesAudio: true, usdPerSecond: {'720p': 0.08, '1080p': 0.10, '4K': 0.25}, usdPerSecondWithAudio: {'720p': 0.10, '1080p': 0.12, '4K': 0.30}),
  'vid/hailuo-2-3': VideoSpec(remote: 'minimax/hailuo-2.3', durations: [6, 10], aspectRatios: ['16:9'], resolutions: ['1080p'], frameImages: ['first_frame'], generatesAudio: false, usdPerSecond: {'1080p': 0.0817}),
  'vid/veo-3': VideoSpec(remote: 'google/veo-3.1', durations: [4, 6, 8], aspectRatios: ['16:9', '9:16'], resolutions: ['720p', '1080p', '4K'], frameImages: ['first_frame', 'last_frame'], generatesAudio: true, usdPerSecond: {'720p': 0.20, '1080p': 0.20, '4K': 0.40}, usdPerSecondWithAudio: {'720p': 0.40, '1080p': 0.40, '4K': 0.60}),
  'vid/sora-2': VideoSpec(remote: 'openai/sora-2-pro', durations: [4, 8, 12, 16, 20], aspectRatios: ['16:9', '9:16'], resolutions: ['720p', '1080p'], frameImages: [], generatesAudio: true, usdPerSecond: {'720p': 0.30, '1080p': 0.50}),
};

/// 1 credit is budgeted at $0.002 of provider cost.
const double kUsdPerCredit = 0.002;

int? videoCredits(String modelId, int seconds, String resolution, bool withAudio) {
  final spec = kVideoSpecs[modelId];
  if (spec == null) return null;
  final table = withAudio && spec.usdPerSecondWithAudio != null ? spec.usdPerSecondWithAudio! : spec.usdPerSecond;
  final rate = table[resolution] ?? (table.values.toList()..sort((a, b) => b.compareTo(a))).first;
  return math.max(1, (rate * seconds / kUsdPerCredit).ceil());
}

class VideoOptions {
  final List<int> durations;
  final List<String> aspectRatios;
  final List<String> resolutions;
  final bool supportsImageInput;
  final bool supportsKeyframes;
  const VideoOptions(this.durations, this.aspectRatios, this.resolutions, this.supportsImageInput, this.supportsKeyframes);
}

VideoOptions? intersectVideoOptions(List<String> ids) {
  final specs = [for (final id in ids) if (kVideoSpecs[id] != null) kVideoSpecs[id]!];
  if (specs.isEmpty) return null;
  return VideoOptions(
    _inter(specs.map((s) => s.durations).toList(), specs.first.durations)..sort(),
    _inter(specs.map((s) => s.aspectRatios).toList(), specs.first.aspectRatios),
    _inter(specs.map((s) => s.resolutions).toList(), specs.first.resolutions),
    specs.every((s) => s.frameImages.contains('first_frame')),
    specs.every((s) => s.frameImages.contains('last_frame')),
  );
}

// ───────────────────────────── pricing.ts ─────────────────────────────

/// The composer's per-category settings, compiled the way PromptComposer
/// compiles them into GenFlags.
class GenFlags {
  final String? task;
  final String? ar;
  final String? quality;
  final String? resolution;
  final String? style;
  final String? negative;
  final int? duration;
  final int? count;
  final String? voice;
  final String? vocals;
  final String? bitrate;
  final String? format;
  final String? motion;
  final String? background;
  const GenFlags({this.task, this.ar, this.quality, this.resolution, this.style, this.negative, this.duration, this.count, this.voice, this.vocals, this.bitrate, this.format, this.motion, this.background});
}

class _Ref {
  final String unit;
  final int refQty;
  final List<int>? choices;
  final bool verified;
  const _Ref(this.unit, this.refQty, [this.choices, this.verified = false]);
}

const Map<String, _Ref> _reference = {
  'vid/veo-3': _Ref('per_second', 5, [4, 6, 8], true),
  'vid/veo-3-1-lite': _Ref('per_second', 5, [4, 6, 8]),
  'vid/sora-2': _Ref('per_second', 10, [4, 8, 12, 20]),
  'vid/kling-3-standard': _Ref('per_second', 5, [5, 10]),
  'vid/grok-imagine-video': _Ref('per_second', 5, [4, 6]),
  'vid/veo-3-1-fast': _Ref('per_second', 5, [4, 6, 8], true),
  'vid/hailuo-2-3': _Ref('per_second', 5, [6, 10], true),
  'vid/wan-2-6': _Ref('per_second', 5, [4, 8]),
  'aud/lyria-3-clip': _Ref('per_second', 30, [15, 30, 60]),
  'aud/lyria-3-pro': _Ref('per_second', 180, [60, 120, 180]),
  'aud/kokoro-82m': _Ref('per_second', 60),
  'aud/gpt-audio-mini': _Ref('per_second', 60),
  'aud/gpt-audio': _Ref('per_second', 60),
  'aud/gemini-3-1-flash-tts': _Ref('per_second', 60),
  'aud/voxtral-mini-tts': _Ref('per_second', 60),
};

const Map<ModelCategory, _Ref> _defaults = {
  ModelCategory.image: _Ref('per_image', 1),
  ModelCategory.video: _Ref('per_second', 5),
  ModelCategory.audio: _Ref('per_second', 60),
  ModelCategory.coding: _Ref('per_message', 1),
  ModelCategory.general: _Ref('per_message', 1),
};

_Ref _referenceFor(ModelDef m) => _reference[m.id] ?? _defaults[m.category] ?? _defaults[ModelCategory.general]!;

const Map<String, double> _videoResolution = {'standard': 1.0, 'hd': 1.0, 'full-hd': 1.6, '2k': 2.4, '4k': 3.6};
const Map<String, double> _imageQuality = {'standard': 1.0, 'hd': 2.0, 'ultra': 3.0};

String _labelForVideoQuality(String q) {
  if (q == 'full-hd' || q == '1080p') return '1080p';
  if (q == '4k' || q == '4K') return '4K';
  if (q == '480p') return '480p';
  return '720p';
}

String formatDuration(int sec) {
  if (sec < 60) return '${sec}s';
  final m = sec ~/ 60;
  final s = sec % 60;
  return s != 0 ? '${m}m ${s}s' : '${m}m';
}

int? _estimateSpeechSeconds(String? text) {
  if (text == null) return null;
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words == 0) return null;
  return math.max(1, (words / 2.5).round());
}

class CostBreakdown {
  final int credits;
  final String basis;
  const CostBreakdown(this.credits, this.basis);
}

/// pricing.ts costOf: what one send of [m] costs with these settings.
CostBreakdown costOf(ModelDef m, [GenFlags? f, String? promptText]) {
  final ref = _referenceFor(m);
  final cat = m.category;
  if (cat == ModelCategory.general || ref.unit == 'per_message') return CostBreakdown(m.weight, '');
  var qty = ref.refQty;
  var policy = 1.0;
  var basis = '';
  if (cat == ModelCategory.video) {
    qty = f?.duration ?? ref.refQty;
    final res = f?.quality ?? '720p';
    final label = _labelForVideoQuality(res);
    final spec = kVideoSpecs[m.id];
    if (spec != null) {
      final c = videoCredits(m.id, qty, label, spec.generatesAudio);
      if (c != null) return CostBreakdown(c, '${qty}s @ $label${spec.generatesAudio ? ' + audio' : ''}');
    }
    policy = _videoResolution[res] ?? 1;
    basis = '${qty}s @ $label';
  } else if (cat == ModelCategory.image) {
    qty = math.max(1, f?.count ?? 1);
    final q = f?.quality ?? 'standard';
    policy = _imageQuality[q] ?? 1;
    basis = '$qty image${qty > 1 ? 's' : ''} @ ${q == 'standard' ? 'standard' : q.toUpperCase()}';
  } else if (cat == ModelCategory.audio) {
    if (f?.task == 'speech-to-text') {
      final secs = f?.duration ?? 60;
      return CostBreakdown(math.max(1, (secs / 600).ceil()), '${formatDuration(secs)} transcribed');
    }
    qty = f?.duration ?? _estimateSpeechSeconds(promptText) ?? ref.refQty;
    basis = formatDuration(qty);
  }
  final perUnit = m.weight / ref.refQty;
  return CostBreakdown(math.max(1, (perUnit * qty * policy).ceil()), basis);
}

int costOfAll(List<ModelDef> models, [GenFlags? f, String? promptText]) => models.fold(0, (s, m) => s + costOf(m, f, promptText).credits);

/// durationChoicesFor: provider-published durations every selected model accepts.
List<int> durationChoicesFor(List<ModelDef> models) {
  final live = intersectVideoOptions(models.map((m) => m.id).toList());
  if (live != null && live.durations.isNotEmpty) return live.durations;
  final lists = [for (final m in models) if (_referenceFor(m).choices != null) _referenceFor(m).choices!];
  if (lists.isEmpty) return const [4, 8, 12];
  return lists.reduce((acc, l) => acc.where(l.contains).toList());
}
