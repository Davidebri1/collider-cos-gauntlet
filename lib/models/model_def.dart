import 'package:flutter/material.dart';

// v8.3 media restore: a straight port of the source app's roster
// (collidermergedx3-glm/src/models.ts): the same five categories, the same
// models with the same ids, names, tiers, credit weights and colours. D35 is
// revoked; nothing here is invented.
enum ModelCategory { general, image, video, audio, coding }

extension ModelCategoryX on ModelCategory {
  /// models.ts CATEGORIES labels.
  String get label => switch (this) {
        ModelCategory.general => 'General',
        ModelCategory.image => 'Image',
        ModelCategory.video => 'Video',
        ModelCategory.audio => 'Audio',
        ModelCategory.coding => 'Coding',
      };
  bool get isMedia => this == ModelCategory.image || this == ModelCategory.video || this == ModelCategory.audio;
}

enum ModelTier { free, pro, elite }

/// models.ts TIER_RANK / TIER_INFO.
class TierInfo {
  final String label;
  final int pool;
  final String price;
  final Color color;
  const TierInfo(this.label, this.pool, this.price, this.color);
  static const Map<ModelTier, TierInfo> all = {
    ModelTier.free: TierInfo('Free', 0, '\$0', Color(0xFFE2E8F0)),
    ModelTier.pro: TierInfo('Pro', 3000, '\$19.99/mo', Color(0xFFDC2626)),
    ModelTier.elite: TierInfo('Elite', 7500, '\$49.99/mo', Color(0xFFF5E000)),
  };
  static int rank(ModelTier t) => t.index;
}

class ModelDef {
  final String id;
  /// Full model name exactly as the source roster writes it. No short forms.
  final String label;
  final String provider;
  /// models.ts `desc` (kept as data; not shown as helper copy).
  final String desc;
  final ModelTier tier;
  final List<ModelCategory> categories;
  /// Credits per call for the model's reference output (models.ts `weight`).
  final int weight;
  /// Colour carried by the source roster (several models share one there).
  final Color seedColor;

  /// v8.4 (David, Oct 5): every model has its own colour; no two alike.
  /// Assigned from [ModelColors] by roster position, so it is stable.
  Color get providerColor => ModelColors.of(id);

  const ModelDef({
    required this.id,
    required this.label,
    required this.provider,
    this.desc = '',
    required this.tier,
    required this.categories,
    this.weight = 1,
    required Color providerColor,
  }) : seedColor = providerColor;

  ModelCategory get category => categories.isEmpty ? ModelCategory.general : categories.first;
  bool get isMedia => categories.any((c) => c.isMedia);
}

/// One distinct colour per model: hues stepped by the golden angle (137.5°)
/// over the roster order, alternating two lightness levels, so neighbouring
/// models (the ones shown together) are far apart and no two are equal.
class ModelColors {
  static final Map<String, Color> _assigned = {};
  static Color of(String id) {
    final c = _assigned[id];
    if (c != null) return c;
    var i = ModelRoster.source.indexWhere((m) => m.id == id);
    if (i < 0) i = ModelRoster.source.length + _assigned.length;
    final hue = (i * 137.508 + 12) % 360;
    final light = i.isEven ? 0.66 : 0.74;
    final col = HSLColor.fromAHSL(1, hue, 0.72, light).toColor();
    return _assigned[id] = col;
  }
}

class ModelRoster {
  /// models.ts MODELS, in source order.
  static const List<ModelDef> source = [
    ModelDef(id: 'free/gemini-3-6-flash-lite', label: 'Gemini 3.6 Flash Lite', provider: 'Google', desc: 'Google\'s lightweight flash model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'free/mistral-small', label: 'Mistral Small 3.2', provider: 'Mistral AI', desc: 'Mistral\'s current small model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFFFB066)),
    ModelDef(id: 'free/command-r', label: 'Command R', provider: 'Cohere', desc: 'Cohere\'s generalist model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFF2C14E)),
    ModelDef(id: 'free/minimax-m3', label: 'MiniMax M3', provider: 'MiniMax', desc: 'MiniMax\'s current flagship. 1M ctx.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'free/ling-2-6-flash', label: 'Ling 2.6 Flash', provider: 'inclusionAI', desc: 'InclusionAI. Fastest responder in the roster.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF9ECBFF)),
    ModelDef(id: 'free/mistral-nemo', label: 'Mistral Nemo', provider: 'Mistral AI', desc: 'Mistral + NVIDIA. 128k context.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFFFB066)),
    ModelDef(id: 'free/gemma-4-31b', label: 'Gemma 4 31B', provider: 'Google', desc: 'Google\'s open-weight model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'free/qwen-3-6-27b', label: 'Qwen 3.6 27B', provider: 'Alibaba', desc: 'Alibaba\'s mid-size generalist.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'free/gpt-5-nano', label: 'GPT-5 Nano', provider: 'OpenAI', desc: 'OpenAI\'s smallest model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'free/laguna-s-2-1', label: 'Laguna S 2.1', provider: 'Poolside', desc: 'Poolside. Code-capable generalist.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'pro/gemini-3-6-flash', label: 'Gemini 3.6 Flash', provider: 'Google', desc: 'Google\'s current flash model. 1M ctx.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'pro/mercury-2', label: 'Mercury 2', provider: 'Inception', desc: 'Inception. Diffusion LLM — very fast output.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'pro/mimo-v2-5-pro', label: 'MiMo V2.5 Pro', provider: 'Xiaomi', desc: 'Xiaomi\'s flagship. Long-context generalist.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'pro/glm-5-2', label: 'GLM 5.2', provider: 'Z.ai', desc: 'Zhipu\'s flagship.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFF7EE2A8)),
    ModelDef(id: 'pro/gpt-5-6-luna', label: 'GPT-5.6 Luna', provider: 'OpenAI', desc: 'OpenAI\'s reasoning tier at a mid-tier price.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'pro/qwen-3-6-plus', label: 'Qwen 3.6 Plus', provider: 'Alibaba', desc: 'Alibaba\'s generalist.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'pro/grok-latest', label: 'Grok 4.3', provider: 'xAI', desc: 'xAI\'s latest. Real-time knowledge, 2:1 pricing.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFF4DCAFF)),
    ModelDef(id: 'pro/grok-4-5', label: 'Grok 4.5', provider: 'xAI', desc: 'xAI\'s flagship. Real-time knowledge.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 3, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'pro/sonar-reasoning-pro', label: 'Sonar Reasoning Pro', provider: 'Perplexity', desc: 'Perplexity\'s reasoning model. Live web-grounded.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 4, providerColor: Color(0xFF6BB8FF)),
    ModelDef(id: 'pro/mistral-large', label: 'Mistral Large 2512', provider: 'Mistral AI', desc: 'Mistral\'s current flagship.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 3, providerColor: Color(0xFFFFB066)),
    ModelDef(id: 'pro/laguna-s-2-1', label: 'Laguna S 2.1', provider: 'Poolside', desc: 'Poolside. Purpose-built for code.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'pro/kat-coder-air', label: 'KAT Coder Air 2.5', provider: 'Kwaipilot', desc: 'Kwaipilot. Agentic coding, low latency.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFFF6A4C9)),
    ModelDef(id: 'pro/codestral-2508', label: 'Codestral 2508', provider: 'Mistral AI', desc: 'Mistral\'s dedicated coder. 256k ctx.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFFFFB066)),
    ModelDef(id: 'pro/qwen-3-coder-plus', label: 'Qwen3 Coder Plus', provider: 'Alibaba', desc: 'Alibaba\'s coding flagship.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'pro/gpt-5-3-codex', label: 'GPT-5.3 Codex', provider: 'OpenAI', desc: 'OpenAI\'s coding model. Deep reasoning.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 4, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'pro/glm-5v-turbo', label: 'GLM 5V Turbo', provider: 'Z.ai', desc: 'Zhipu. Vision-capable coder, fast.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFF7EE2A8)),
    ModelDef(id: 'elite/kat-coder-pro', label: 'KAT Coder Pro 2.5', provider: 'Kwaipilot', desc: 'Kwaipilot\'s flagship. Multi-file refactors.', tier: ModelTier.elite, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFFF6A4C9)),
    ModelDef(id: 'elite/kimi-k2-7-code', label: 'Kimi K2.7 Code', provider: 'Moonshot AI', desc: 'Moonshot\'s dedicated coding model.', tier: ModelTier.elite, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFF4BE6B1)),
    ModelDef(id: 'elite/kimi-k3', label: 'Kimi K3', provider: 'Moonshot AI', desc: 'Moonshot\'s flagship. Deepest code reasoning.', tier: ModelTier.elite, categories: [ModelCategory.coding], weight: 8, providerColor: Color(0xFF4BE6B1)),
    ModelDef(id: 'elite/qwen-3-7-max', label: 'Qwen 3.7 Max', provider: 'Alibaba', desc: 'Alibaba\'s top coder. Flat.', tier: ModelTier.elite, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'img/flux-free', label: 'FLUX', provider: 'Black Forest Labs', desc: 'Fast, free-to-generate image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/gemini-3-1-flash-image', label: 'Gemini 3.1 Flash Image', provider: 'Google', desc: 'Google\'s fast image generator.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 5, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'img/gpt-5-image-mini', label: 'GPT-5 Image Mini', provider: 'OpenAI', desc: 'OpenAI\'s compact image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 2, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/flux-2-klein', label: 'FLUX.2 Klein', provider: 'Black Forest Labs', desc: 'Fastest FLUX.2 tier; high-throughput.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 5, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/nano-banana-2', label: 'Nano Banana 2', provider: 'Google', desc: 'Google\'s image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 19, providerColor: Color(0xFFF5E000)),
    ModelDef(id: 'img/kling-3-image', label: 'Kling 3.0 Image', provider: 'Kuaishou', desc: 'Kuaishou. Fast image generation.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 13, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'img/gpt-image-2', label: 'GPT Image 2', provider: 'OpenAI', desc: 'OpenAI\'s current image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 19, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/seedream-5-0', label: 'Seedream 5.0', provider: 'ByteDance', desc: 'ByteDance\'s newest.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 16, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'img/qwen-image-2-0', label: 'Qwen Image 2.0', provider: 'Alibaba', desc: 'Alibaba.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 15, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'img/dall-e-3', label: 'DALL·E 3', provider: 'OpenAI', desc: 'OpenAI\'s classic.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 20, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/mj-upscale', label: 'Midjourney Upscale', provider: 'Midjourney', desc: 'Upscales a Midjourney render.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 25, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'img/nano-banana-pro', label: 'Nano Banana Pro', provider: 'Google', desc: 'Top Nano Banana tier.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 37, providerColor: Color(0xFFF5E000)),
    ModelDef(id: 'img/gemini-3-pro-image', label: 'Gemini 3 Pro Image', provider: 'Google', desc: 'Google\'s flagship image model.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 67, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'img/flux-2-max', label: 'FLUX.2 Max', provider: 'Black Forest Labs', desc: 'Black Forest Labs\' top tier; peak fidelity.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 10, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/gpt-5-4-image-2', label: 'GPT-5.4 Image 2', provider: 'OpenAI', desc: 'OpenAI\'s newest image model, GPT Image 2.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 10, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/seedream-4-5', label: 'Seedream 4.5', provider: 'ByteDance', desc: 'ByteDance; strong editing consistency.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 20, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'vid/veo-3-1-lite', label: 'Veo 3.1 Lite', provider: 'Google', desc: 'Lightweight video generation.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 75, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/wan-2-6', label: 'Wan 2.6', provider: 'Alibaba', desc: 'Multi-shot, native audio, 480p–1080p.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 100, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/grok-imagine-video', label: 'Grok Imagine Video', provider: 'xAI', desc: 'xAI; 7 aspect ratios, 1–15s clips.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 125, providerColor: Color(0xFF4DCAFF)),
    ModelDef(id: 'vid/kling-3-standard', label: 'Kling Video v3.0', provider: 'Kuaishou', desc: 'Start+end keyframes, native audio, to 15s.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 211, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'vid/wan-2-2-flash', label: 'Wan 2.2 Flash', provider: 'Alibaba', desc: '480p–1080p, image-to-video.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 36, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/wan-2-2-plus', label: 'Wan 2.2 Plus', provider: 'Alibaba', desc: 'Text-to-video, 480p and 1080p.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 50, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/kling-2-5-turbo', label: 'Kling 2.5 Turbo', provider: 'Kuaishou', desc: '720p–4K. t2v, i2v, keyframes and reference.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 90, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'vid/hailuo-2-3', label: 'Hailuo 2.3', provider: 'MiniMax', desc: 'MiniMax; native 1080p, 6s and 10s.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 205, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'vid/veo-3-1-fast', label: 'Veo 3.1 Fast', provider: 'Google', desc: 'Veo quality with 4K.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 200, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/veo-3', label: 'Veo 3.1', provider: 'Google', desc: 'Flagship fidelity. 4K, native synced audio.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 500, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/sora-2', label: 'Sora 2 Pro', provider: 'OpenAI', desc: 'Up to 20s, synced audio. The longest clips.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 750, providerColor: Color(0xFF3B82F6)),
    ModelDef(id: 'vid/wan-2-5-preview', label: 'Wan 2.5 Preview', provider: 'Alibaba', desc: 'Newest Wan. 480p–1080p text-to-video.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 108, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/kling-3-turbo', label: 'Kling 3.0 Turbo', provider: 'Kuaishou', desc: 'Kling\'s flagship. Up to 4K, keyframes.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 179, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'aud/lyria-3-clip', label: 'Lyria 3 Clip', provider: 'Google', desc: '30s AI-generated instrumental/vocal clip.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 15, providerColor: Color(0xFFFF69C8)),
    ModelDef(id: 'aud/kokoro-82m', label: 'Kokoro 82M', provider: 'hexgrad', desc: 'Lightweight TTS; 8 languages, 54 preset voices.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'aud/gpt-audio-mini', label: 'GPT Audio Mini', provider: 'OpenAI', desc: 'Conversational voice output, low latency.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 5, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'aud/sesame-csm-1b', label: 'Sesame CSM 1B', provider: 'Sesame', desc: 'Conversational speech — dialogue-tuned, not narration.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 4, providerColor: Color(0xFF9ECBFF)),
    ModelDef(id: 'aud/lyria-3-pro', label: 'Lyria 3 Pro', provider: 'Google', desc: 'Full AI-generated song, up to ~3 min, vocals.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 30, providerColor: Color(0xFFFF8A65)),
    ModelDef(id: 'aud/gemini-3-1-flash-tts', label: 'Gemini 3.1 Flash TTS', provider: 'Google', desc: '70+ languages, 200+ emotion tags, 2 speakers.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 5, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'aud/voxtral-mini-tts', label: 'Voxtral Mini TTS', provider: 'Mistral AI', desc: 'Zero-shot voice cloning, multilingual.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 6, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'aud/gpt-audio', label: 'GPT Audio', provider: 'OpenAI', desc: 'OpenAI\'s flagship conversational audio model.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 25, providerColor: Color(0xFFD9D3C7)),
  ];

  /// Live roster. Starts as the source roster. When the Collider server
  /// answers, its text models replace the General list; every other
  /// category stays exactly as the source has it (as before commit 8a0ae71).
  static List<ModelDef> allModels = List.of(source);

  static void setLive(List<ModelDef> live) {
    allModels = [...live, ...source.where((m) => !m.categories.contains(ModelCategory.general))];
  }

  /// models.ts modelsForCategory: tier first, then weight.
  static List<ModelDef> forCategory(ModelCategory category) {
    // Stable, like Array.prototype.sort: ties keep roster order.
    final l = allModels.where((m) => m.categories.contains(category)).toList();
    final idx = {for (var i = 0; i < l.length; i++) l[i].id: i};
    l.sort((a, b) {
      final t = a.tier.index - b.tier.index;
      if (t != 0) return t;
      final w = a.weight - b.weight;
      return w != 0 ? w : idx[a.id]! - idx[b.id]!;
    });
    return l;
  }

  static ModelDef? byId(String id) {
    for (final m in allModels) {
      if (m.id == id) return m;
    }
    for (final m in source) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// models.ts CATEGORY_MIN_TIER / effectiveMinTier.
  static ModelTier effectiveMinTier(ModelDef m) {
    const catMin = {
      ModelCategory.image: ModelTier.pro,
      ModelCategory.video: ModelTier.pro,
      ModelCategory.audio: ModelTier.pro,
      ModelCategory.coding: ModelTier.pro,
    };
    var min = ModelTier.free;
    for (final c in m.categories) {
      final t = catMin[c];
      if (t != null && t.index > min.index) min = t;
    }
    return min.index > m.tier.index ? min : m.tier;
  }

  /// models.ts canUse.
  static bool canUse(ModelTier tier, ModelDef m) => tier.index >= effectiveMinTier(m).index;
}
