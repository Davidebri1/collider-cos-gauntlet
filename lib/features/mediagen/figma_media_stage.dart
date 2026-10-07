// Map row 13 (Media Gen Ticker Layout) — v8.4: a straight copy of wechat
// IMAGE 2013:71 at its own size (scene 2610 x 1468), scaled as one unit.
// Media window = Rectangle 22 (638,308, 1285 x 754); action tab bar 36:1867
// (1102,1030, 358 x 76); window controls (pager) 35:1826; side panel 59:498
// (1943,314, 348 x 748) with the "likes" avatar grid (-> the models that ran)
// and the "comments" cards (-> each generation: model, time, prompt).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/figma/figma_stage.dart';
import '../../core/files/file_store.dart';
import '../ticker/widgets/figma_ticker.dart' show ModelDisc;
import 'media_ticker.dart' show MediaGeneration;
import 'media_view.dart';

class Row13 {
  static const frame = Size(2610, 1468);
  // Crop: tab bar (540) .. side panel right edge (2291), no extra margin.
  static const cropWidth = 1751.0;
  static const center = Offset(1415.5, 734);
  static const rail = Rect.fromLTWH(540, 624, 76, 220);
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class MediaStageContent extends StatefulWidget {
  const MediaStageContent({super.key, required this.items, required this.onRemix, required this.onNotice, required this.onOptions});
  final List<MediaGeneration> items;
  final ValueChanged<String> onRemix;
  final void Function(String) onNotice;
  final VoidCallback onOptions;
  @override
  State<MediaStageContent> createState() => _MediaStageContentState();
}

class _MediaStageContentState extends State<MediaStageContent> {
  int _i = 0;

  Future<void> _save(MediaGeneration g) async {
    final u = g.url;
    if (u == null || !u.startsWith('data:')) return;
    final comma = u.indexOf(',');
    final mime = u.substring(5, u.indexOf(';'));
    final ext = mime.split('/').last.replaceAll('jpeg', 'jpg');
    final name = '${g.model.label} ${g.at.millisecondsSinceEpoch}.$ext';
    final note = await FileStore.instance.addBytes(name, base64Decode(u.substring(comma + 1)), 'model');
    widget.onNotice(note ?? 'Saved to Files');
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 26, color: Colors.white.withOpacity(onTap == null ? 0.4 : 1))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final i = _i.clamp(0, items.length - 1);
    final g = items[i];
    return FigmaStage(
      frame: Row13.frame,
      cropWidth: Row13.cropWidth,
      center: Row13.center,
      children: [
        // Media window (Rectangle 22).
        Positioned(
          left: 638,
          top: 308,
          width: 1285,
          height: 754,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(46),
            child: g.pending || g.url == null
                ? const FGlass(child: Center(child: SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white))))
                : GenMediaView(key: ValueKey(g.url!.hashCode), url: g.url!, kind: g.kind),
          ),
        ),
        // Action tab bar 36:1867: forward / heart / download / comment ->
        // Remix / Options / Save to Files / Copy prompt.
        Positioned(
          left: 1102,
          top: 1030,
          width: 358,
          height: 76,
          child: FGlass(
            radius: BorderRadius.circular(38),
            stroke: const Color(0x66FFFFFF),
            strokeWidth: 1.4,
            child: Stack(children: [
              Positioned(left: 22, top: 15, child: _action(Icons.reply_rounded, 'Remix', () => widget.onRemix(g.prompt))),
              Positioned(left: 115, top: 15, child: _action(Icons.tune_rounded, 'Options', widget.onOptions)),
              Positioned(left: 199, top: 15, child: _action(Icons.download_rounded, 'Save to Files', g.url == null ? null : () => _save(g))),
              Positioned(left: 282, top: 15, child: _action(Icons.content_copy_rounded, 'Copy prompt', () {
                Clipboard.setData(ClipboardData(text: g.prompt));
                widget.onNotice('Copied');
              })),
            ]),
          ),
        ),
        // Window controls 35:1826 -> pager: dot + bar (centre 1278).
        Positioned(
          left: 1168,
          top: 1146,
          child: Row(children: [
            for (var k = 0; k < items.length; k++) ...[
              if (k > 0) const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _i = k),
                child: Container(
                  width: k == i ? 133 : 12,
                  height: 12,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ]),
        ),
        // Side panel 59:498.
        Positioned(
          left: 1943,
          top: 314,
          width: 348,
          height: 748,
          child: FGlass(
            radius: BorderRadius.circular(46),
            stroke: const Color(0x66FFFFFF),
            child: Stack(children: [
              // "Likes 16" -> Models N.
              const Positioned(left: 22, top: 32, child: FText('Models', size: 20, height: 24, weight: FontWeight.w700)),
              Positioned(left: 100, top: 32, child: FText('${items.length}', size: 16, height: 24, weight: FontWeight.w700, opacity: 0.4)),
              // 37 px avatars, 31.6 px apart (overlapping), rows at 71 / 114.
              for (var k = 0; k < items.length && k < 18; k++)
                Positioned(
                  left: 22 + (k % 9) * 31.6,
                  top: 71 + (k ~/ 9) * 43,
                  child: GestureDetector(
                    onTap: () => setState(() => _i = k),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k == i ? Colors.white : const Color(0x00000000), width: 2)),
                      child: ModelDisc(color: items[k].model.providerColor, label: items[k].model.label, size: 37),
                    ),
                  ),
                ),
              // "Comments 2" -> the generations.
              const Positioned(left: 22, top: 192, child: FText('Prompts', size: 20, height: 24, weight: FontWeight.w700)),
              Positioned(left: 108, top: 192, child: FText('${items.length}', size: 16, height: 24, weight: FontWeight.w700, opacity: 0.4)),
              Positioned(
                left: 0,
                top: 238,
                right: 0,
                bottom: 0,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 26),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (var k = 0; k < items.length; k++)
                      GestureDetector(
                        onTap: () => setState(() => _i = k),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 22, right: 22, bottom: 26),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(
                              height: 40,
                              child: Row(children: [
                                const SizedBox(width: 2),
                                ModelDisc(color: items[k].model.providerColor, label: items[k].model.label, size: 40),
                                const SizedBox(width: 9),
                                Expanded(child: FText(items[k].model.label, size: 17, height: 24, weight: FontWeight.w700)),
                                FText(_hm(items[k].at), size: 16, height: 24, weight: FontWeight.w700, opacity: 0.6),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            FGlass(
                              width: 304,
                              radius: BorderRadius.circular(20),
                              padding: const EdgeInsets.fromLTRB(18, 18, 27, 17),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (items[k].basis.isNotEmpty) ...[
                                  FText(items[k].basis, size: 12, height: 15, weight: FontWeight.w700, opacity: 0.6),
                                  const SizedBox(height: 12),
                                ],
                                FText(items[k].prompt, size: 15, height: 26, weight: FontWeight.w700, maxLines: 4),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
