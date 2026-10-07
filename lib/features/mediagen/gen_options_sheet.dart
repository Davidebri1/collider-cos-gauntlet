// Map row 17 (Image/Video/Music Gen Options Overlay/Expansion), Figma
// Vision OS Design System 417:15864, stacked for a phone: the big media card
// with floating pills and a dots pager (one dot per selected model), the dark
// detail panel (title, divider, detail lines, the task row with the model's
// badge, outlined option tiles), and the total pill with the red action.
// Every value comes from the source's specs (media_specs.dart); each choice
// shows its credit price, as the source composer does.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/figma/figma_stage.dart';
import '../../models/media_specs.dart';
import '../../models/model_def.dart';
import '../theme/theme_living_media.dart';
import 'gen_settings.dart';
import 'media_view.dart';

class GenOptionsSheet extends StatefulWidget {
  final ModelCategory category;
  final List<ModelDef> models;
  final GenSettings settings;
  final List<String> references;
  final ValueChanged<List<String>> onReferences;
  /// Shown in the media card: the latest result for this category, or the
  /// current wallpaper's poster when there is none yet.
  final String? previewUrl;
  final String posterFallback;
  final VoidCallback onChanged;
  final VoidCallback onGenerate;
  final VoidCallback onClose;

  const GenOptionsSheet({
    super.key,
    required this.category,
    required this.models,
    required this.settings,
    required this.references,
    required this.onReferences,
    required this.previewUrl,
    required this.posterFallback,
    required this.onChanged,
    required this.onGenerate,
    required this.onClose,
  });

  @override
  State<GenOptionsSheet> createState() => _GenOptionsSheetState();
}

class _Opt {
  final String key;
  final IconData icon;
  final String label;
  final String value;
  final List<(String, String)> choices; // (value, shown)
  final void Function(String) apply;
  /// Settings override used to price a choice (null: the choice is not billed).
  final GenFlags Function(String)? price;
  const _Opt(this.key, this.icon, this.label, this.value, this.choices, this.apply, [this.price]);
}

class _GenOptionsSheetState extends State<GenOptionsSheet> {
  int _page = 0;
  String? _open;

  GenSettings get s => widget.settings;
  ModelCategory get cat => widget.category;

  void _set(void Function() f) {
    setState(f);
    s.fitTo(cat, widget.models);
    widget.onChanged();
  }

  List<_Opt> _opts() {
    final ids = widget.models.map((m) => m.id).toList();
    switch (cat) {
      case ModelCategory.image:
        final o = intersectImageOptions(ids);
        final ratios = (o != null && o.aspectRatios.isNotEmpty) ? o.aspectRatios : const ['9:16', '4:5', '1:1', '16:9'];
        int pf(String r) {
          final p = r.split(':').map(int.parse).toList();
          return p[0] < p[1] ? 0 : (p[0] == p[1] ? 1 : 2);
        }
        final sorted = [...ratios]..sort((a, b) => pf(a) - pf(b));
        return [
          _Opt('ar', Icons.crop_portrait_rounded, 'Aspect ratio', s.ar, [for (final r in sorted) (r, r)], (v) => s.ar = v),
          if (o != null && o.resolutions.isNotEmpty)
            _Opt('res', Icons.high_quality_outlined, 'Resolution', s.resolution ?? o.resolutions.first, [for (final r in o.resolutions) (r, r)], (v) => s.resolution = v),
          _Opt('quality', Icons.auto_awesome_outlined, 'Quality', _q(s.quality), const [('standard', 'Standard'), ('hd', 'HD'), ('ultra', 'Ultra')], (v) => s.quality = v,
              (v) => GenFlags(task: s.task, ar: s.ar, quality: v, count: 1)),
          _Opt('style', Icons.palette_outlined, 'Style', _style(s.style), const [('neutral', 'Neutral'), ('photorealistic', 'Realistic'), ('3d-render', '3D Render'), ('anime', 'Anime'), ('cyberpunk', 'Cyberpunk')], (v) => s.style = v),
        ];
      case ModelCategory.video:
        final o = intersectVideoOptions(ids);
        final durs = durationChoicesFor(widget.models);
        return [
          _Opt('ar', Icons.crop_portrait_rounded, 'Aspect ratio', s.ar, [for (final r in (o?.aspectRatios ?? const ['9:16', '16:9'])) (r, r)], (v) => s.ar = v),
          _Opt('dur', Icons.timer_outlined, 'Duration', '${s.duration}s', [for (final d in durs) ('$d', '${d}s')], (v) => s.duration = int.parse(v),
              (v) => GenFlags(task: s.task, ar: s.ar, quality: s.quality, duration: int.parse(v))),
          _Opt('res', Icons.high_quality_outlined, 'Resolution', s.quality.toUpperCase(), [for (final r in (o?.resolutions ?? const ['720p'])) (r, r.toUpperCase())], (v) => s.quality = v,
              (v) => GenFlags(task: s.task, ar: s.ar, quality: v, duration: s.duration)),
          _Opt('motion', Icons.waves_rounded, 'Motion', _cap(s.motion), const [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')], (v) => s.motion = v),
        ];
      case ModelCategory.audio:
        final caps = unionCapabilities(widget.models);
        final speech = s.task == 'text-to-speech' || s.task == 'dubbing';
        return [
          _Opt('len', Icons.timer_outlined, 'Length', formatDuration(s.duration), const [('15', '15s'), ('30', '30s'), ('60', '1m'), ('120', '2m'), ('180', '3m')], (v) => s.duration = int.parse(v),
              (v) => GenFlags(task: s.task, duration: int.parse(v))),
          if (speech && caps.voices.isNotEmpty)
            _Opt('voice', Icons.record_voice_over_outlined, 'Voice', s.voice ?? caps.voices.first, [for (final v in caps.voices) (v, v)], (v) => s.voice = v),
          _Opt('vocals', Icons.mic_none_rounded, 'Vocals', s.vocals == 'vocal' ? 'Vocal track' : 'Instrumental', const [('vocal', 'Vocal track'), ('instrumental', 'Instrumental')], (v) => s.vocals = v),
          _Opt('bitrate', Icons.equalizer_rounded, 'Bitrate', s.bitrate == 'high' ? '320 kbps' : '128 kbps', const [('standard', '128 kbps'), ('high', '320 kbps')], (v) => s.bitrate = v),
          if (caps.outputFormats.isNotEmpty)
            _Opt('format', Icons.audio_file_outlined, 'Format', s.format == 'wav' ? 'WAV lossless' : s.format.toUpperCase(), [for (final f in caps.outputFormats) (f, f == 'wav' ? 'WAV lossless' : f.toUpperCase())], (v) => s.format = v),
        ];
      default:
        return const [];
    }
  }

  static String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
  static String _q(String v) => switch (v) { 'hd' => 'HD', 'ultra' => 'Ultra', _ => 'Standard' };
  static String _style(String v) => switch (v) { 'photorealistic' => 'Realistic', '3d-render' => '3D Render', 'neutral' => 'Neutral', _ => _cap(v) };

  Future<void> _attach() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (r == null) return;
      final uris = [
        for (final f in r.files)
          if (f.bytes != null) 'data:image/${(f.extension ?? 'png').toLowerCase() == 'jpg' ? 'jpeg' : (f.extension ?? 'png').toLowerCase()};base64,${base64Encode(f.bytes!)}',
      ];
      widget.onReferences([...widget.references, ...uris]);
      setState(() {});
    } catch (_) {}
  }

  // Figma 417:15864 Property Page, 1288 x 690 at (316, 195) in the 1920 x
  // 1080 scene; crop = the page's own width, centred, no margin.
  static const _frame = Size(1920, 1080);
  static const _crop = 1288.0;
  static const _center = Offset(960, 540);
  static const _ox = 316.0, _oy = 195.0;

  static const _pillFill = Color(0x40FFFFFF);
  static const _pillShadow = [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 8.3), blurRadius: 6.25)];

  @override
  Widget build(BuildContext context) {
    final models = widget.models;
    final page = models.isEmpty ? 0 : _page.clamp(0, models.length - 1);
    final m = models.isEmpty ? null : models[page];
    final flags = s.flags(cat);
    final total = costOfAll(models, flags);
    final cost = m == null ? null : costOf(m, flags);
    final tasks = tasksForCategory(cat);
    final task = taskById(s.task);
    final opts = _opts();
    final open = opts.where((o) => o.key == _open).firstOrNull;
    final supportsRefs = cat != ModelCategory.audio;
    final refs = widget.references;

    return Stack(
      fit: StackFit.expand,
      children: [
        // No dimming in the frame: a clear tap-to-close layer.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose)),
        FigmaStage(
          frame: _frame,
          cropWidth: _crop,
          center: _center,
          children: [
            // Image 834 x 624 at (0, 36), radius 24, inner highlights.
            Positioned(left: _ox, top: _oy + 36, width: 834, height: 624, child: _media()),
            // Down menu 430 x 624 at (858, 36).
            Positioned(left: _ox + 858, top: _oy + 36, width: 430, height: 624, child: _panel(m, cost, task, tasks, opts, open)),
            // Page controls (338, 634): one dot per selected model.
            Positioned(
              left: _ox + 338,
              top: _oy + 634,
              width: 158.86,
              height: 56,
              child: FGlass(
                radius: BorderRadius.circular(104.2),
                fill: _pillFill,
                blur: 52.1,
                shadow: _pillShadow,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < models.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      selected: i == page,
                      label: models[i].label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _page = i),
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i == page ? const Color(0xFFE61A1A) : const Color(0xFFF2F2F2))),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
            // Left pill (30, 0) "Favourite" -> add reference images.
            if (supportsRefs)
              Positioned(
                left: _ox + 30,
                top: _oy,
                height: 70.86,
                child: _pill(Icons.add_photo_alternate_outlined, refs.isEmpty ? 'Reference' : 'Reference ${refs.length}', _attach),
              ),
            // Right pill (1138.7, 4) "Share" -> close.
            Positioned(
              right: _frame.width - (_ox + 1288 - 12.15),
              top: _oy + 4,
              height: 70.86,
              child: _pill(Icons.close_rounded, 'Close', widget.onClose),
            ),
            // Price + Reserve (945, 606), 275 x 84 -> credits + Generate.
            Positioned(
              right: _frame.width - (_ox + 945 + 275),
              top: _oy + 606,
              height: 84,
              child: _totalPill(total),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: FGlass(
            radius: BorderRadius.circular(104.2),
            fill: _pillFill,
            blur: 52.1,
            shadow: _pillShadow,
            padding: const EdgeInsets.fromLTRB(10.42, 10.42, 24, 10.42),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 50.02, height: 50.02, child: Icon(icon, size: 24, color: Colors.white)),
              const SizedBox(width: 10.42),
              FText(label, size: 16, height: 24, weight: FontWeight.w600),
            ]),
          ),
        ),
      );

  Widget _media() {
    final refs = widget.references;
    final child = refs.isNotEmpty
        ? GenMediaView(url: refs.last, kind: 'image')
        : (widget.previewUrl != null
            ? GenMediaView(url: widget.previewUrl!, kind: cat == ModelCategory.video ? 'video' : (cat == ModelCategory.audio ? 'audio' : 'image'))
            : ThemeImage(widget.posterFallback, fit: BoxFit.cover));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 18.26), blurRadius: 11.4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          child,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x59FFFFFF), width: 0.76),
                gradient: const RadialGradient(radius: 1.2, colors: [Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x26FFFFFF)], stops: [0, 0.8, 1]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _panel(ModelDef? m, CostBreakdown? cost, TaskDef? task, List<TaskDef> tasks, List<_Opt> opts, _Opt? open) {
    final spec = m == null ? null : _specLine(m);
    final chips = _open == 'task'
        ? [
            for (final t in tasks) (t.label, t.id == s.task, t.routable ? () => _set(() => s.task = t.id) : null),
          ]
        : open == null
            ? const <(String, bool, VoidCallback?)>[]
            : [
                for (final (v, shown) in open.choices)
                  (open.price == null ? shown : '$shown · ${costOfAll(widget.models, open.price!(v))}', _isOn(open, v), () => _set(() => open.apply(v))),
              ];
    return FGlass(
      radius: BorderRadius.circular(24),
      fill: const Color(0x1AFFFFFF),
      blur: 52.1,
      stroke: const Color(0x30FFFFFF),
      shadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 8.3), blurRadius: 6.25)],
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Frame 39: title (SF Display Bold 27.4, two lines), divider, content.
        SizedBox(
          height: 66,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FText(cat.label, size: 27.39, height: 33, weight: FontWeight.w700, letterSpacing: 0.38),
            FText(m?.label ?? '', size: 27.39, height: 33, weight: FontWeight.w700, letterSpacing: 0.38),
          ]),
        ),
        const SizedBox(height: 16),
        Container(width: 366, height: 2, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(64))),
        const SizedBox(height: 16),
        SizedBox(
          width: 366,
          height: 72,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: FText(m?.provider ?? '', size: 16, height: 24, weight: FontWeight.w600, letterSpacing: -0.5)),
              if (m != null) ...[
                Icon(Icons.star_rounded, size: 16, color: TierInfo.all[m.tier]!.color),
                const SizedBox(width: 4),
                FText(TierInfo.all[m.tier]!.label, size: 16, height: 24),
              ],
            ]),
            const SizedBox(height: 4),
            FText(spec ?? '', size: 14, height: 20),
            const SizedBox(height: 4),
            FText(cost == null ? '' : '${cost.credits} credit${cost.credits == 1 ? '' : 's'}${cost.basis.isEmpty ? '' : ' · ${cost.basis}'}', size: 14, height: 20),
          ]),
        ),
        const SizedBox(height: 40),
        // Frame 40: the task (SF Display Bold 24) + the model "book" badge.
        Semantics(
          button: true,
          label: 'Task',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = _open == 'task' ? null : 'task'),
            child: SizedBox(
              width: 366,
              height: 80,
              child: Row(children: [
                Expanded(child: FText(task?.label ?? '', size: 24, height: 29, weight: FontWeight.w700, letterSpacing: 0.38, maxLines: 2)),
                const SizedBox(width: 40),
                if (m != null) _badge(m),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 40),
        // Frame 44: option tiles, 116.67 x 168 each, gap 8 (scrolls past 3).
        SizedBox(
          width: 366,
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            itemCount: opts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _tile(opts[i]),
          ),
        ),
        // The open tile's (or the task's) choices, in the panel's foot.
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 366,
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, on, tap) = chips[i];
                return Semantics(
                  button: true,
                  selected: on,
                  label: label,
                  child: GestureDetector(
                    onTap: tap,
                    child: Opacity(
                      opacity: tap == null ? 0.32 : 1,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(64),
                          border: Border.all(color: Colors.white),
                        ),
                        child: FText(label, size: 14, height: 20, weight: FontWeight.w600, color: on ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }

  // Price + Reserve pill: pl36 pr12 py12, gap 16, radius 64, white .25.
  Widget _totalPill(int total) => FGlass(
        radius: BorderRadius.circular(64),
        fill: _pillFill,
        blur: 52.1,
        shadow: _pillShadow,
        padding: const EdgeInsets.fromLTRB(36, 12, 12, 12),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                FText('$total ', size: 24, height: 24, weight: FontWeight.w600),
                const FText('credits', size: 16, height: 24),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(top: 4), child: FText(_totalBasis(), size: 16, height: 24)),
          ]),
          const SizedBox(width: 16),
          _GenerateButton(onTap: widget.onGenerate),
        ]),
      );

  bool _isOn(_Opt o, String v) => switch (o.key) {
        'ar' => s.ar == v,
        'res' => cat == ModelCategory.video ? s.quality == v : s.resolution == v,
        'quality' => s.quality == v,
        'style' => s.style == v,
        'dur' || 'len' => '${s.duration}' == v,
        'motion' => s.motion == v,
        'voice' => s.voice == v,
        'vocals' => s.vocals == v,
        'bitrate' => s.bitrate == v,
        'format' => s.format == v,
        _ => false,
      };

  String _totalBasis() {
    final n = widget.models.length;
    final models = '$n model${n == 1 ? '' : 's'}';
    return switch (cat) {
      ModelCategory.video => '$models · ${s.duration}s · ${s.quality}',
      ModelCategory.image => '$models · ${s.ar}',
      ModelCategory.audio => '$models · ${formatDuration(s.duration)}',
      _ => models,
    };
  }

  String? _specLine(ModelDef m) {
    final i = kImageSpecs[m.id];
    if (i != null) {
      final parts = <String>[
        if (i.aspectRatios.isNotEmpty) '${i.aspectRatios.length} ratios',
        if (i.resolutions.isNotEmpty) i.resolutions.join(' / '),
        if (i.maxReferences > 0) 'up to ${i.maxReferences} references',
      ];
      return parts.isEmpty ? null : parts.join(' • ');
    }
    final v = kVideoSpecs[m.id];
    if (v != null) {
      return [
        '${v.durations.first}–${v.durations.last}s',
        v.resolutions.join(' / '),
        if (v.generatesAudio) 'audio',
      ].join(' • ');
    }
    final c = capabilitiesFor(m);
    if (cat == ModelCategory.audio) return c.outputFormats.map((f) => f.toUpperCase()).join(' / ');
    return null;
  }

  // Book 64 x 80: cover 56 x 80 (model colour), white inside 12 x 72 at
  // (52, 4) with right radius 8, avatar 38 at (10, 21).
  Widget _badge(ModelDef m) => SizedBox(
        width: 64,
        height: 80,
        child: Stack(children: [
          Positioned(
            left: 52,
            top: 4,
            width: 12,
            height: 72,
            child: Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.horizontal(right: Radius.circular(8)))),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: 56,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                color: m.providerColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(4), right: Radius.circular(6)),
                boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 7), blurRadius: 10)],
              ),
            ),
          ),
          Positioned(left: 3.5, top: 5, width: 1, height: 70, child: Container(color: const Color(0x33000000))),
          Positioned(
            left: 10,
            top: 21,
            width: 38,
            height: 38,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1C1C1E)),
              alignment: Alignment.center,
              child: FText(m.label.isEmpty ? '' : m.label.substring(0, 1).toUpperCase(), size: 18, weight: FontWeight.w700, color: m.providerColor),
            ),
          ),
        ]),
      );

  // Tile: border white 1, radius 12, p12, icon 24, gap 80, text 14 / 20.
  Widget _tile(_Opt o) {
    final on = _open == o.key;
    return Semantics(
      button: true,
      selected: on,
      label: o.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = on ? null : o.key),
        child: Container(
          width: 116.67,
          height: 168,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? const Color(0x26FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(o.icon, size: 24, color: Colors.white),
            const Spacer(),
            FText(o.value, size: 14, height: 20, weight: FontWeight.w600),
            FText(o.label, size: 14, height: 20, opacity: 0.8),
          ]),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GenerateButton({required this.onTap});
  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFD23756), borderRadius: BorderRadius.circular(64)),
            child: const FText('Generate', size: 16, height: 24, weight: FontWeight.w600),
          ),
        ),
      );
}
