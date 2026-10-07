// Map row 13 (Media Gen Ticker Layout), wechat vision os IMAGE frame
// (OkuRCwJ6Hgz664K8YSe1zr 2013:71; the map's 26:1004 does not exist in that
// file, D63): the big media window, the action ornament under it, the pager
// handle, and the side panel with the model avatars row (one per model that
// ran) and the prompt card. Stacked for a phone: the panel sits under the
// media window instead of beside it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/files/file_store.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import 'media_view.dart';

class MediaGeneration {
  final ModelDef model;
  final String kind; // image | video | audio
  final String prompt;
  final String basis;
  final DateTime at;
  final String? url;
  final bool pending;
  const MediaGeneration({required this.model, required this.kind, required this.prompt, required this.basis, required this.at, this.url, this.pending = false});
  MediaGeneration done(String u) => MediaGeneration(model: model, kind: kind, prompt: prompt, basis: basis, at: at, url: u);
}

class MediaTicker extends StatefulWidget {
  final List<MediaGeneration> items;
  final ValueChanged<String> onRemix;
  final void Function(String message) onNotice;
  const MediaTicker({super.key, required this.items, required this.onRemix, required this.onNotice});

  @override
  State<MediaTicker> createState() => _MediaTickerState();
}

class _MediaTickerState extends State<MediaTicker> {
  int _i = 0;

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final i = _i.clamp(0, items.length - 1);
    final g = items[i];
    final w = MediaQuery.sizeOf(context).width;
    final mediaH = g.kind == 'audio' ? 180.0 : (w * 0.62).clamp(200.0, 380.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Media window.
        SizedBox(
          height: mediaH + 26,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: mediaH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.card),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(VRadius.card), border: Border.all(color: VColors.borderHeavy, width: 0.6)),
                  child: g.pending || g.url == null
                      ? const VGlass(material: VMaterial.resting, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                      : GenMediaView(key: ValueKey(g.url!.hashCode), url: g.url!, kind: g.kind),
                ),
              ),
            ),
            // Action ornament under the media (Figma: forward / heart / download / comment).
            Positioned(
              left: 0,
              right: 0,
              top: mediaH - 22,
              child: Center(
                child: VGlass(
                  material: VMaterial.elevated,
                  radius: VRadius.full,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    VCircleButton(icon: Icons.reply_rounded, size: 44, tooltip: 'Remix', onTap: () => widget.onRemix(g.prompt)),
                    VCircleButton(icon: Icons.download_rounded, size: 44, tooltip: 'Save to Files', onTap: g.url == null ? null : () => _save(g)),
                    VCircleButton(
                      icon: Icons.content_copy_rounded,
                      size: 44,
                      tooltip: 'Copy prompt',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: g.prompt));
                        widget.onNotice('Copied');
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        // Pager handle (Figma: dot + bar).
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Container(width: 56, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(3))),
          ]),
        ),
        const SizedBox(height: VSpace.sm),
        // Side panel: models row + the prompt card.
        VGlass(
          material: VMaterial.resting,
          radius: VRadius.card,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Models', style: VType.callout(weight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('${items.length}', style: VType.caption()),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var k = 0; k < items.length; k++)
                  VPress(
                    tooltip: items[k].model.label,
                    onTap: () => setState(() => _i = k),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: k == i ? Colors.white : Colors.transparent, width: 1.5),
                      ),
                      child: VAvatar(label: items[k].model.label, color: items[k].model.providerColor, size: 30),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                VAvatar(label: g.model.label, color: g.model.providerColor, size: 26),
                const SizedBox(width: 8),
                Expanded(child: Text(g.model.label, maxLines: 2, style: VType.callout(weight: FontWeight.w600))),
                Text(_hm(g.at), style: VType.caption()),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (g.basis.isNotEmpty) ...[
                    Text(g.basis, style: VType.caption(color: VColors.textSecondary)),
                    const SizedBox(height: 4),
                  ],
                  Text(g.prompt, maxLines: 4, overflow: TextOverflow.ellipsis, style: VType.footnote(color: VColors.textPrimary)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
