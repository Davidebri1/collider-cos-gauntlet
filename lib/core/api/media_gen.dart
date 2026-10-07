// v8.3 media restore: a Dart port of the source app's provider client
// (collidermergedx3-glm/src/services/chat.ts ROUTES + callOpenRouterImage /
// callOpenRouterVideo / callOpenRouterSpeech / callOpenRouterAudio /
// generateImageUrl, and wire.ts wireFor). Same endpoints, same request
// bodies, same polling.
//
// Keys: the source ships its provider keys inline in the bundle. This build
// does NOT (DEVIATIONS D58): a public GitHub Pages bundle would hand them to
// anyone. v8.4: every call goes to the key proxy named by the one build-time
// define COLLIDER_PROXY (see proxy.dart); the proxy adds the keys. With the
// define empty (the hosted build) a run fails quietly at send time (D59).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/media_specs.dart';

import 'proxy.dart';

// Through the proxy: $COLLIDER_PROXY/openrouter/api/v1 and
// $COLLIDER_PROXY/crazyrouter/v1 (same paths as the providers).
// Proxy maps /openrouter/* -> https://openrouter.ai/api/*, so v1 sits directly under it.
String get _openRouterBase => '${ColliderProxy.base('openrouter')}/v1';
String get _crazyRouterBase => '${ColliderProxy.base('crazyrouter')}/v1';

class _Route {
  final String provider;
  final String remote;
  final bool crazy;
  final String? voice;
  const _Route(this.provider, this.remote, {this.crazy = false, this.voice});
}

/// chat.ts ROUTES: the media and OpenRouter-text rows, verbatim.
const Map<String, _Route> _routes = {
  // General / coding over OpenRouter (the text routes the source sends there).
  'free/mistral-small': _Route('openrouter', 'mistralai/mistral-small-3.2-24b-instruct'),
  'free/command-r': _Route('openrouter', 'cohere/command-r-08-2024'),
  'free/ling-2-6-flash': _Route('openrouter', 'inclusionai/ling-2.6-flash'),
  'free/mistral-nemo': _Route('openrouter', 'mistralai/mistral-nemo'),
  'free/gemma-4-31b': _Route('openrouter', 'google/gemma-4-31b-it'),
  'free/gpt-5-nano': _Route('openrouter', 'openai/gpt-5-nano', crazy: true),
  'free/laguna-s-2-1': _Route('openrouter', 'poolside/laguna-s-2.1'),
  'pro/mercury-2': _Route('openrouter', 'inception/mercury-2'),
  'pro/mimo-v2-5-pro': _Route('openrouter', 'xiaomi/mimo-v2.5-pro'),
  'pro/gpt-5-6-luna': _Route('openrouter', 'openai/gpt-5.6-luna', crazy: true),
  'pro/qwen-3-6-plus': _Route('openrouter', 'qwen/qwen3.6-plus', crazy: true),
  'pro/grok-latest': _Route('openrouter', 'x-ai/grok-4.3', crazy: true),
  'pro/grok-4-5': _Route('openrouter', 'x-ai/grok-4.5'),
  'pro/sonar-reasoning-pro': _Route('openrouter', 'perplexity/sonar-reasoning-pro'),
  'pro/mistral-large': _Route('openrouter', 'mistralai/mistral-large'),
  'pro/laguna-s-2-1': _Route('openrouter', 'poolside/laguna-s-2.1'),
  'pro/kat-coder-air': _Route('openrouter', 'kwaipilot/kat-coder-air-v2.5'),
  'pro/codestral-2508': _Route('openrouter', 'mistralai/codestral-2508'),
  'pro/qwen-3-coder-plus': _Route('openrouter', 'qwen/qwen3-coder-plus', crazy: true),
  'pro/gpt-5-3-codex': _Route('openrouter', 'openai/gpt-5.3-codex', crazy: true),
  'pro/glm-5v-turbo': _Route('openrouter', 'z-ai/glm-5v-turbo', crazy: true),
  'elite/kat-coder-pro': _Route('openrouter', 'kwaipilot/kat-coder-pro-v2.5'),
  'elite/kimi-k2-7-code': _Route('openrouter', 'moonshotai/kimi-k2.7-code'),
  'elite/kimi-k3': _Route('openrouter', 'moonshotai/kimi-k3', crazy: true),
  'elite/qwen-3-7-max': _Route('openrouter', 'qwen/qwen3.7-max', crazy: true),
  // Image
  'img/flux-free': _Route('pollinations-image', 'flux'),
  'img/gemini-3-1-flash-image': _Route('openrouter-image', 'google/gemini-3.1-flash-image-preview'),
  'img/gpt-5-image-mini': _Route('openrouter-image', 'openai/gpt-5-image-mini'),
  'img/gemini-3-pro-image': _Route('openrouter-image', 'google/gemini-3-pro-image-preview'),
  'img/seedream-4-5': _Route('openrouter-image', 'bytedance-seed/seedream-4.5'),
  'img/nano-banana-2': _Route('openrouter-image', 'nano-banana-2', crazy: true),
  'img/nano-banana-pro': _Route('openrouter-image', 'nano-banana-pro', crazy: true),
  'img/seedream-5-0': _Route('openrouter-image', 'doubao-seedream-5-0', crazy: true),
  'img/qwen-image-2-0': _Route('openrouter-image', 'qwen-image-2.0', crazy: true),
  'img/gpt-image-2': _Route('openrouter-image', 'openai/gpt-5.4-image-2', crazy: true),
  'img/dall-e-3': _Route('openrouter-image', 'dall-e-3', crazy: true),
  'img/kling-3-image': _Route('openrouter-image', 'aigc-image-kling-3.0', crazy: true),
  'img/mj-upscale': _Route('openrouter-image', 'mj_upscale', crazy: true),
  'img/flux-2-klein': _Route('openrouter-image', 'black-forest-labs/flux.2-klein-4b'),
  'img/flux-2-max': _Route('openrouter-image', 'black-forest-labs/flux.2-max'),
  'img/gpt-5-4-image-2': _Route('openrouter-image', 'openai/gpt-5.4-image-2'),
  // Video
  'vid/veo-3-1-lite': _Route('openrouter-video', 'google/veo-3.1-lite'),
  'vid/kling-3-standard': _Route('openrouter-video', 'kwaivgi/kling-v3.0-std'),
  'vid/grok-imagine-video': _Route('openrouter-video', 'x-ai/grok-imagine-video'),
  'vid/sora-2': _Route('openrouter-video', 'openai/sora-2-pro'),
  'vid/veo-3': _Route('openrouter-video', 'google/veo-3.1'),
  'vid/wan-2-6': _Route('openrouter-video', 'alibaba/wan-2.6'),
  'vid/veo-3-1-fast': _Route('openrouter-video', 'google/veo-3.1-fast'),
  'vid/hailuo-2-3': _Route('openrouter-video', 'minimax/hailuo-2.3'),
  'vid/wan-2-2-flash': _Route('openrouter-video', 'wan2.2-i2v-flash', crazy: true),
  'vid/wan-2-2-plus': _Route('openrouter-video', 'wan2.2-t2v-plus', crazy: true),
  'vid/wan-2-5-preview': _Route('openrouter-video', 'alibaba/wan-2.6', crazy: true),
  'vid/kling-2-5-turbo': _Route('openrouter-video', 'aigc-video-kling-2.5-turbo', crazy: true),
  'vid/kling-3-turbo': _Route('openrouter-video', 'aigc-video-kling-3.0-turbo', crazy: true),
  // Audio
  'aud/lyria-3-clip': _Route('openrouter-audio', 'google/lyria-3-clip-preview'),
  'aud/gpt-audio-mini': _Route('openrouter-audio', 'openai/gpt-audio-mini'),
  'aud/sesame-csm-1b': _Route('openrouter-speech', 'sesame/csm-1b', voice: 'conversational_a'),
  'aud/gpt-audio': _Route('openrouter-audio', 'openai/gpt-audio'),
  'aud/kokoro-82m': _Route('openrouter-speech', 'hexgrad/kokoro-82m', voice: 'af_bella'),
  'aud/gemini-3-1-flash-tts': _Route('openrouter-speech', 'google/gemini-3.1-flash-tts-preview', voice: 'Zephyr'),
  'aud/voxtral-mini-tts': _Route('openrouter-speech', 'mistralai/voxtral-mini-tts-2603'),
  'aud/lyria-3-pro': _Route('openrouter-audio', 'google/lyria-3-pro-preview'),
};

/// wire.ts SLUG_OVERRIDES (text rows) for when a Crazyrouter key is set.
const Map<String, String> _slugOverrides = {
  'openai/gpt-5-nano': 'gpt-5-nano',
  'openai/gpt-5.6-luna': 'gpt-5.6-luna',
  'openai/gpt-5.3-codex': 'gpt-5.3-codex',
  'z-ai/glm-5.2': 'glm-5.2',
  'z-ai/glm-5v-turbo': 'glm-5v-turbo',
  'qwen/qwen3.6-plus': 'qwen3.6-plus',
  'qwen/qwen3-coder-plus': 'qwen3-coder-plus',
  'qwen/qwen3.7-max': 'qwen3.7-max',
  'x-ai/grok-4.3': 'grok-4.3',
};

/// One generated asset. [url] is a data: URI or a plain URL.
class MediaResult {
  final String kind; // image | video | audio | text
  final String url;
  final String text;
  const MediaResult(this.kind, {this.url = '', this.text = ''});
}

class MediaGenError implements Exception {
  final String reason;
  const MediaGenError(this.reason);
  @override
  String toString() => reason;
}

class MediaGen {
  MediaGen._();
  static final MediaGen instance = MediaGen._();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 6)));

  // wire.ts wireFor: the source's Crazyrouter rows go to Crazyrouter (with its
  // slug overrides), the rest to OpenRouter. The proxy holds both keys.
  ({String base, String key}) _wire(_Route r) {
    if (r.crazy) return (base: _crazyRouterBase, key: '');
    return (base: _openRouterBase, key: '');
  }

  String _slug(_Route r) => r.crazy ? (_slugOverrides[r.remote] ?? r.remote) : r.remote;

  bool isRoutable(String modelId) => _routes.containsKey(modelId);

  /// chat.ts hasCredentials: v8.4, a route can run only through the proxy.
  /// Without COLLIDER_PROXY nothing is sent and the run fails quietly.
  /// chat.ts hasCredentials. Pollinations is keyless in the source, so it
  /// runs with or without the proxy (straight to image.pollinations.ai when no
  /// proxy is set). Every keyed provider needs the proxy (D58 / D78).
  bool hasCredentials(String modelId) {
    final r = _routes[modelId];
    if (r == null) return false;
    if (r.provider == 'pollinations-image') return true;
    return ColliderProxy.enabled;
  }

  // The proxy adds `Authorization: Bearer <key>` for the upstream provider.
  Map<String, String> _headers(String key) => {
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://collider.app',
        'X-Title': 'Collider',
      };

  /// chat.ts arToSize: long edge ~1024, portrait fallback.
  static ({int width, int height}) arToSize(String? ar) {
    const map = {
      '1:1': [1024, 1024], '16:9': [1344, 768], '9:16': [768, 1344], '4:3': [1152, 896], '3:4': [896, 1152],
      '3:2': [1216, 832], '2:3': [832, 1216], '4:5': [896, 1120], '5:4': [1120, 896], '21:9': [1536, 640],
    };
    final s = map[ar ?? '9:16'] ?? map['9:16']!;
    return (width: s[0], height: s[1]);
  }

  /// chat.ts generateImageUrl.
  static String pollinationsUrl(String prompt, GenFlags f, {String model = 'flux', int? seed}) {
    final size = arToSize(f.ar);
    final sd = seed ?? math.Random().nextInt(1000000);
    final body = '${prompt.isEmpty ? 'abstract art' : prompt}${f.style != null && f.style != 'neutral' ? ', ${f.style}' : ''}';
    final neg = (f.negative ?? '').isNotEmpty ? '&negative=${Uri.encodeComponent(f.negative!)}' : '';
    final base = ColliderProxy.enabled ? ColliderProxy.base('pollinations/image') : 'https://image.pollinations.ai';
    return '$base/prompt/${Uri.encodeComponent(body)}?width=${size.width}&height=${size.height}&nologo=true&model=$model&seed=$sd$neg';
  }

  /// One generation for one model, exactly as the source's sendChat routes it.
  /// Throws [MediaGenError] when it cannot run (no key, provider refusal).
  Future<MediaResult> generate(String modelId, String prompt, GenFlags f, {List<String> imageDataUris = const []}) async {
    final r = _routes[modelId];
    if (r == null) throw const MediaGenError('not routed');
    if (!hasCredentials(modelId)) throw const MediaGenError('no credentials');
    try {
      switch (r.provider) {
        case 'pollinations-image':
          final url = pollinationsUrl(prompt, f, model: r.remote);
          // The source hands the URL straight to <Image>. Fetch it first so a
          // refusal (Pollinations now answers 402) fails here, quietly,
          // instead of leaving a broken image in the ticker.
          final res = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
          final ct = res.headers.value('content-type') ?? 'image/jpeg';
          if (!ct.startsWith('image/')) throw const MediaGenError('no image');
          return MediaResult('image', url: 'data:$ct;base64,${base64Encode(res.data!)}');
        case 'openrouter-image':
          return MediaResult('image', url: await _image(r, prompt, f, imageDataUris));
        case 'openrouter-video':
          return MediaResult('video', url: await _video(r, prompt, f, imageDataUris));
        case 'openrouter-speech':
          return MediaResult('audio', url: await _speech(r, prompt, f));
        case 'openrouter-audio':
          final p = f.task == 'sound-effect' ? 'A short sound effect, no music, no melody, no vocals: $prompt' : prompt;
          return MediaResult('audio', url: await _audio(r, p, f));
        case 'openrouter':
          return MediaResult('text', text: await chat(modelId, [
            {'role': 'system', 'content': 'You are Collider, a concise, helpful assistant.'},
            {'role': 'user', 'content': prompt},
          ]));
      }
    } on DioException catch (e) {
      throw MediaGenError('provider ${e.response?.statusCode ?? 'unreachable'}');
    }
    throw const MediaGenError('not routed');
  }

  /// callOpenRouter (non-streaming): text answer for General / Coding.
  Future<String> chat(String modelId, List<Map<String, String>> messages) async {
    final r = _routes[modelId];
    if (r == null || r.provider != 'openrouter' || !hasCredentials(modelId)) throw const MediaGenError('no credentials');
    final w = _wire(r);
    final res = await _dio.post('${w.base}/chat/completions',
        data: {'model': _slug(r), 'messages': messages}, options: Options(headers: _headers(w.key)));
    final text = res.data['choices']?[0]?['message']?['content'] as String? ?? '';
    if (text.trim().isEmpty) throw const MediaGenError('empty');
    return text;
  }

  // callOpenRouterImage
  Future<String> _image(_Route r, String prompt, GenFlags f, List<String> refs) async {
    final w = _wire(r);
    final size = arToSize(f.ar);
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      for (final u in refs.take(16)) {'type': 'image_url', 'image_url': {'url': u}},
    ];
    final res = await _dio.post('${w.base}/chat/completions',
        data: {
          'model': _slug(r),
          'messages': [
            {'role': 'user', 'content': refs.isNotEmpty ? content : prompt}
          ],
          'modalities': ['image', 'text'],
          'image_size': {'width': size.width, 'height': size.height},
          if (f.ar != null) 'aspect_ratio': f.ar,
          if (f.quality != null && f.quality != 'standard') 'quality': f.quality,
          if ((f.negative ?? '').isNotEmpty) 'negative_prompt': f.negative,
          if (f.resolution != null) 'resolution': f.resolution,
          if (f.background != null) 'background': f.background,
        },
        options: Options(headers: _headers(w.key)));
    final url = res.data['choices']?[0]?['message']?['images']?[0]?['image_url']?['url'] as String?;
    if (url == null || url.isEmpty) throw const MediaGenError('no image');
    return url;
  }

  // callOpenRouterVideo: create -> poll -> download.
  Future<String> _video(_Route r, String prompt, GenFlags f, List<String> frames) async {
    final w = _wire(r);
    final create = await _dio.post('${w.base}/videos',
        data: {
          'model': _slug(r),
          'prompt': prompt.isEmpty ? 'a short abstract scene' : prompt,
          'duration': f.duration ?? 4,
          'aspect_ratio': f.ar,
          if (f.quality != null) 'resolution': f.quality,
          if (frames.isNotEmpty) 'first_frame_image': frames.first,
          if (f.task == 'keyframe-video' && frames.length > 1) 'last_frame_image': frames[1],
        },
        options: Options(headers: _headers(w.key)));
    final job = create.data as Map;
    final pollUrl = _absolute((job['polling_url'] as String?) ?? '${w.base}/videos/${job['id']}', w.base);
    var status = (job['status'] as String?) ?? 'queued';
    String? contentUrl = (job['unsigned_urls'] as List?)?.cast<String>().firstOrNull;
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    const terminal = {'completed', 'failed', 'error', 'cancelled', 'expired'};
    while (!terminal.contains(status) && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 8));
      final p = await _dio.get(_viaProxy(pollUrl));
      status = p.data['status'] as String? ?? 'failed';
      contentUrl = (p.data['unsigned_urls'] as List?)?.cast<String>().firstOrNull;
    }
    if (contentUrl != null) contentUrl = _absolute(contentUrl, w.base);
    if (status != 'completed' || contentUrl == null) throw MediaGenError('video $status');
    final file = await _dio.get<List<int>>(_viaProxy(contentUrl), options: Options(responseType: ResponseType.bytes));
    return 'data:video/mp4;base64,${base64Encode(file.data!)}';
  }

  /// Provider-absolute URLs from a video job (polling_url / unsigned_urls)
  /// are rewritten onto the proxy so the key never leaves it.
  String _viaProxy(String url) {
    // The proxy already rewrites absolute provider URLs in JSON bodies; this
    // catches any that slip through. /openrouter/* -> openrouter.ai/api/*.
    if (url.startsWith('https://openrouter.ai/api/')) return '${ColliderProxy.base('openrouter')}/${url.substring('https://openrouter.ai/api/'.length)}';
    if (url.startsWith('https://crazyrouter.com/')) return '${ColliderProxy.base('crazyrouter')}/${url.substring('https://crazyrouter.com/'.length)}';
    return url;
  }

  /// OpenRouter may return polling_url relative ("/api/v1/videos/<id>").
  /// Relative paths resolve against the wire they came from, on the proxy.
  String _absolute(String url, String wireBase) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/api/v1/')) {
      final isCrazy = wireBase.startsWith(ColliderProxy.base('crazyrouter'));
      return isCrazy ? '${ColliderProxy.base('crazyrouter')}${url.substring('/api'.length)}' : '${ColliderProxy.base('openrouter')}${url.substring('/api'.length)}';
    }
    if (url.startsWith('/v1/')) {
      final isCrazy = wireBase.startsWith(ColliderProxy.base('crazyrouter'));
      return '${ColliderProxy.base(isCrazy ? 'crazyrouter' : 'openrouter')}$url';
    }
    return url;
  }

  // callOpenRouterSpeech: raw audio bytes back.
  Future<String> _speech(_Route r, String text, GenFlags f) async {
    final w = _wire(r);
    final format = f.format ?? 'mp3';
    final voice = f.voice ?? r.voice;
    final res = await _dio.post<List<int>>('${w.base}/audio/speech',
        data: {'model': _slug(r), 'input': text.isEmpty ? 'Hello from Collider.' : text, if (voice != null) 'voice': voice, 'response_format': format},
        options: Options(headers: _headers(w.key), responseType: ResponseType.bytes));
    final bytes = Uint8List.fromList(res.data ?? const []);
    if (bytes.isEmpty) throw const MediaGenError('no audio');
    return 'data:audio/$format;base64,${base64Encode(bytes)}';
  }

  // callOpenRouterAudio: streamed SSE, base64 audio chunks concatenated.
  Future<String> _audio(_Route r, String prompt, GenFlags f) async {
    final w = _wire(r);
    final finalPrompt = '${prompt.isEmpty ? 'a short instrumental piece' : prompt}.\nOptions:\n- Vocals: ${f.vocals ?? 'vocal'}\n- Quality: ${f.bitrate ?? 'standard'}\n- Format: ${f.format ?? 'mp3'}\n- Genre/Style tags: ';
    final res = await _dio.post<String>('${w.base}/chat/completions',
        data: {
          'model': _slug(r),
          'messages': [
            {'role': 'user', 'content': finalPrompt}
          ],
          'modalities': ['audio', 'text'],
          'stream': true,
        },
        options: Options(headers: _headers(w.key), responseType: ResponseType.plain));
    final b = StringBuffer();
    for (final line in (res.data ?? '').split('\n')) {
      if (!line.startsWith('data: ') || line.contains('[DONE]')) continue;
      try {
        final piece = jsonDecode(line.substring(6))['choices']?[0]?['delta']?['audio']?['data'];
        if (piece is String) b.write(piece);
      } catch (_) {}
    }
    if (b.isEmpty) throw const MediaGenError('no audio');
    return 'data:audio/mp3;base64,$b';
  }
}
