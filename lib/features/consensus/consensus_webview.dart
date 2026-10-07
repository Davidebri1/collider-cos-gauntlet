import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/vision/vision_kit.dart';
import 'consensus_scene_frame.dart';
import 'consensus_view.dart';
import '../../core/api/collider_api.dart' as api;
import '../../models/model_def.dart';

/// Consensus Topology screen.
///
/// Drop-in of the consensus scene from collidermergedx3-glm
/// (src/components/ConsensusScene.tsx + consensus-scene-template.ts +
/// src/services/consensusView.ts, payload built as in ConsensusDrawer.tsx).
/// The scene is a self-contained HTML/CSS 2.5D map; it has no mesh or model
/// assets. On web it is hosted in an iframe fed by postMessage, as in the
/// source; on iOS / Android the same scene runs in a WebView (ConsensusSceneFrame).
///
/// On phone widths the scene takes the whole surface, edge to edge, with its
/// own header (back / CONSENSUS / LABELS), as the source app does on mobile.
class ConsensusWebView extends StatefulWidget {
  final VoidCallback? onClose;
  final api.JobState? job;

  const ConsensusWebView({
    super.key,
    this.onClose,
    this.job,
  });

  @override
  State<ConsensusWebView> createState() => _ConsensusWebViewState();
}

class _SceneModel {
  final String id, label, color, view;
  const _SceneModel(this.id, this.label, this.color, this.view);
}

// v8.2 fix pass (D30): the bundled demo run (9 invented model answers and a
// made-up summary) is gone. With no real consensus job the screen says so.

class _ConsensusWebViewState extends State<ConsensusWebView> {
  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Models of the live session that have answered.
  List<_SceneModel> get _models {
    final j = widget.job;
    if (j == null) return const [];
    return [
      for (final e in j.results.entries)
        if (e.value.status == 'done' && ModelRoster.byId(e.key) != null)
          _SceneModel(e.key, ModelRoster.byId(e.key)!.label,
              _hex(ModelRoster.byId(e.key)!.providerColor), e.value.essence),
    ];
  }

  ConsensusResult get _result {
    final j = widget.job;
    if (j == null) return const ConsensusResult(claims: []);
    final done = j.results.entries.where((e) => e.value.status == 'done').toList();
    return ConsensusResult(
      claims: [
        for (final e in done) ConsensusClaim(modelId: e.key, essence: e.value.essence, chains: j.consensus.chains[e.key] ?? 3),
      ],
      groups: j.consensus.groups.isNotEmpty ? j.consensus.groups : [for (final e in done) [e.key]],
      need: j.consensus.need,
      tieBreakBecause: j.consensus.tieBasis.isEmpty ? null : j.consensus.tieBasis,
    );
  }

  bool _isLoading = true;
  String? _html;
  // Live essences are full sentences; labels open on demand so the spheres stay readable.
  bool _labels = false;
  String _tab = 'total';

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/html/consensus.html').then((html) {
      if (mounted) {
        setState(() {
          _html = html;
          _isLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  /// Scene payload, built as ConsensusDrawer.tsx builds `scenePayload`.
  String _buildPayload(double fieldW, double fieldH) {
    final derived = deriveConsensus(_result)!;
    final mapScale = math.max(1.0, math.min(2.6, fieldH / 190));
    int scaled(num px) => (px * mapScale).round();
    var nucleusSize = scaled(derived.nucleusSize);
    final nucleusRadius = nucleusSize / 2;
    final centerX = fieldW / 2;
    final centerY = (fieldH * 0.44).roundToDouble();
    final bottomReserve = _labels ? 120.0 : 56.0;
    final innerR = math.max(nucleusRadius + 34, 58.0);
    final outerR = math.max(innerR + 40, math.min(fieldW / 2 - 52, fieldH - bottomReserve - centerY));
    final placements = layoutByMatches(
      derived,
      _result,
      Field(width: fieldW, height: fieldH, centerX: centerX, centerY: centerY, innerR: innerR, outerR: outerR),
    );
    // Fit to the viewport: if any sphere + its label (label box max 120px)
    // would cross the side edges, scale every offset from the nucleus, and the
    // nucleus itself, by one factor. Proportions stay as the source draws them.
    const edgePad = 64.0; // half of the 120px label box + 4px margin
    final maxHalf = fieldW / 2 - edgePad;
    var extent = innerR;
    for (final p in placements) {
      extent = math.max(extent, (p.x - centerX).abs());
    }
    final fit = extent > maxHalf && maxHalf > 0 ? maxHalf / extent : 1.0;
    if (fit < 1.0) nucleusSize = (nucleusSize * fit).round();
    final byId = {
      for (final p in placements)
        p.modelId: Placed(
          modelId: p.modelId,
          x: centerX + (p.x - centerX) * fit,
          y: centerY + (p.y - centerY) * fit,
          unanchored: p.unanchored,
          linksToConsensus: p.linksToConsensus,
          inConsensus: p.inConsensus,
        ),
    };
    final claimById = {for (final c in derived.claims) c.modelId: c};

    // No overlaps: resolve sphere/label collisions in screen space. The scene
    // bands y into 34%..92% of the height and puts the nucleus at 59.5%.
    final ms = <_SceneModel>[];
    final chains = <int>[];
    final agree = <bool>[];
    final meta = <Placed>[];
    final start = <Offset>[];
    for (final m in _models) {
      final p = byId[m.id];
      final c = claimById[m.id];
      if (p == null || c == null) continue;
      ms.add(m);
      chains.add(c.chains);
      agree.add(c.inConsensus);
      meta.add(p);
      start.add(Offset(p.x, fieldH * (0.34 + 0.58 * (p.y / fieldH).clamp(0.0, 1.0))));
    }
    final nuc = Offset(fieldW / 2, fieldH * 0.595);
    const label = 18.0;
    const gap = 8.0;
    final top = fieldH * 0.37, bottom = fieldH * 0.90;
    var sizeScale = 1.0;
    var pos = List<Offset>.of(start);
    for (var attempt = 0; attempt < 14; attempt++) {
      pos = List<Offset>.of(start);
      final r = [for (final k in chains) (30 + k * 10) * sizeScale / 2 + label / 2];
      final nr = nucleusSize * sizeScale / 2 + label / 2;
      var clear = false;
      for (var it = 0; it < 300 && !clear; it++) {
        clear = true;
        for (var i = 0; i < pos.length; i++) {
          var d = pos[i] - nuc;
          var need = r[i] + nr + gap;
          if (d.distance < need) {
            clear = false;
            final dir = d.distance < 0.01 ? Offset(math.cos(i * 1.7), math.sin(i * 1.7)) : d / d.distance;
            pos[i] = nuc + dir * need;
          }
          for (var j = i + 1; j < pos.length; j++) {
            d = pos[j] - pos[i];
            need = r[i] + r[j] + gap;
            if (d.distance < need) {
              clear = false;
              final dir = d.distance < 0.01 ? Offset(math.cos(j * 2.3), math.sin(j * 2.3)) : d / d.distance;
              final push = (need - d.distance) / 2 + 0.5;
              pos[i] -= dir * push;
              pos[j] += dir * push;
            }
          }
        }
        for (var i = 0; i < pos.length; i++) {
          final ri = r[i];
          pos[i] = Offset(
            pos[i].dx.clamp(ri + 6, math.max(ri + 6, fieldW - ri - 6)).toDouble(),
            pos[i].dy.clamp(top + ri, math.max(top + ri, bottom - ri)).toDouble(),
          );
        }
      }
      if (clear) break;
      sizeScale *= 0.9;
    }

    final models = <Map<String, dynamic>>[];
    for (var i = 0; i < ms.length; i++) {
      final m = ms[i];
      final yPct = (((pos[i].dy / fieldH) - 0.34) / 0.58 * 100).clamp(0.0, 100.0);
      models.add({
        'id': m.id,
        'label': m.label,
        'color': m.color,
        'tier': 'free',
        'view': m.view,
        'agree': agree[i],
        'chainDepth': chains[i],
        'unanchored': meta[i].unanchored,
        'x': (pos[i].dx / fieldW) * 100,
        'y': yPct,
      });
    }

    return jsonEncode({
      'models': models,
      'ratioN': derived.ratioN,
      'ratioM': derived.ratioM,
      'hasRun': true,
      'summary': derived.summary,
      'nucleusSize': (nucleusSize * sizeScale).round(),
      'sizeScale': sizeScale,
      'glowOpacity': derived.glowOpacity,
      'glowRadius': derived.glowRadius,
      'tieBecause': derived.tieBecause ?? '',
      'labels': _labels,
      'activeTab': _tab,
    });
  }

  Widget _scene(BoxConstraints c) {
    if (_models.isEmpty) return _empty();
    final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 390.0;
    final h = c.maxHeight.isFinite && c.maxHeight > 0 ? c.maxHeight : 700.0;
    final payload = _buildPayload(w, h);
    return Stack(
      children: [
        if (_html != null)
          Positioned.fill(
            child: ConsensusSceneFrame(
              html: _html!,
              payloadJson: payload,
              onClose: widget.onClose,
              onLabelsChange: (v) => setState(() => _labels = v),
              onTabChange: (t) => setState(() => _tab = t),
            ),
          ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: VColors.textSecondary, strokeWidth: 2)),
      ],
    );
  }

  // No real consensus job yet (or no model has answered): say so, with a way out.
  Widget _empty() => Stack(
        children: [
          if (MediaQuery.of(context).size.width < 768)
            Positioned(
              left: VSpace.sm,
              top: VSpace.sm,
              child: VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      // Source mobile layout: the scene IS the screen, edge to edge, on the
      // scene's own #07080b surface, with its own header and back control.
      return Container(
        color: const Color(0xFF07080B),
        child: SafeArea(child: LayoutBuilder(builder: (context, c) => _scene(c))),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: SizedBox(
                width: VOverlay.toolWidth(context),
                height: VOverlay.toolMaxHeight(context),
                child: VGlass(
                  material: VMaterial.work,
                  radius: VRadius.xl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
                        child: Row(
                          children: [
                            VCircleButton(
                              key: const Key('consensus_close_icon'),
                              icon: Icons.close_rounded,
                              tooltip: 'Close',
                              onTap: widget.onClose,
                            ),
                            const SizedBox(width: VSpace.sm),
                            Expanded(child: Text('Consensus', style: VType.headline())),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(VRadius.xl)),
                          child: LayoutBuilder(builder: (context, c) => _scene(c)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
