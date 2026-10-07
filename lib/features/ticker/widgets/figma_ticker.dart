import 'package:flutter/material.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../models/ticker_item.dart';

/// Map row 15 — Model Response Ticker, a straight copy of wechat CHAT 2013:75
/// at its own size (scene coordinates, 2610 x 1468). Collapsed answers are the
/// left column window (0:646: 476 x 720 at 639,361); the opened answer is the
/// middle window (9:338: 791 x 720 at 1114,362) with its close button and the
/// text box (54:296). Sample contacts are replaced by the real models; the
/// 64 px avatar is a flat disc in the model's own colour (no glow, no badge).
class Row15 {
  static const frame = Size(2610, 1468);
  // Crop: tab bar (540) .. middle window right edge (1905): the window
  // group's own width, no extra margin (v8.4 follow-up), so the scale is the
  // largest the frame allows.
  static const cropWidth = 1365.0;
  static const center = Offset(1222.5, 734);
  static const rail = Rect.fromLTWH(540, 624, 76, 220);
  static const leftWin = Rect.fromLTWH(639, 361, 476, 720);
  static const midWin = Rect.fromLTWH(1114, 362, 791, 720);
  static const textBox = Rect.fromLTWH(1136, 952, 726, 149);
}

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String initials(String label) {
  final parts = label.split(RegExp(r'[\s\-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.characters.first.toUpperCase();
  final b = parts.length > 1 ? parts[1].characters.first.toUpperCase() : '';
  return '$a$b';
}

class ModelDisc extends StatelessWidget {
  const ModelDisc({super.key, required this.color, required this.label, this.size = 64});
  final Color color;
  final String label;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        alignment: Alignment.center,
        child: FText(initials(label), size: size * 0.34, weight: FontWeight.w700, color: const Color(0xE6000000)),
      );
}

/// Left column window (collapsed answers).
class TickerColumnWindow extends StatelessWidget {
  const TickerColumnWindow({
    super.key,
    required this.items,
    required this.openId,
    required this.onOpen,
    required this.consensusTitle,
    required this.consensusLine,
    required this.onConsensus,
    required this.joined,
  });
  final List<TickerItem> items;
  final String? openId;
  final ValueChanged<String> onOpen;
  final String consensusTitle;
  final String consensusLine;
  final VoidCallback onConsensus;
  final bool joined; // middle window open: right corners square (0:646)

  @override
  Widget build(BuildContext context) {
    final r = joined
        ? const BorderRadius.only(topLeft: Radius.circular(46), bottomLeft: Radius.circular(46))
        : BorderRadius.circular(46);
    return FGlass(
      width: 476,
      height: 720,
      radius: r,
      stroke: const Color(0x66FFFFFF),
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        // Chat Summary Container 9:174 (32,31) 411 x 54 -> consensus.
        Positioned(
          left: 32,
          top: 31,
          width: 411,
          height: 54,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onConsensus,
            child: Stack(children: [
              Positioned(left: 0, top: 3, right: 70, child: FText(consensusTitle, size: 24, height: 24, weight: FontWeight.w700, opacity: 0.6)),
              Positioned(left: 0, top: 34, right: 70, child: FText(consensusLine, size: 15, height: 20, weight: FontWeight.w700, opacity: 0.4)),
              Positioned(
                right: 0,
                top: 0,
                width: 53,
                height: 53,
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
                  child: const Icon(Icons.balance_rounded, size: 26, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
        // Rows: 420 x 96 at x 27, y 105 + 108 i (9:127, 9:231, 9:239 ...).
        Positioned(
          left: 0,
          top: 105,
          right: 0,
          bottom: 0,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.only(left: 27, right: 29, bottom: 12),
              child: _Row(item: items[i], selected: items[i].modelDef.id == openId, onTap: () => onOpen(items[i].modelDef.id)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.selected, required this.onTap});
  final TickerItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final last = item.conversation.isNotEmpty ? item.conversation.last : null;
    final time = item.isStreaming ? '…' : (last != null ? _clock(last.timestamp) : item.relativeTime);
    final msg = item.summary.isNotEmpty ? item.summary : (last?.text ?? '');
    return Semantics(
      button: true,
      label: item.modelDef.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FGlass(
          width: 420,
          height: 96,
          radius: BorderRadius.circular(20),
          stroke: selected ? const Color(0x66FFFFFF) : null,
          shadow: selected ? const [BoxShadow(color: Color(0x2B000000), offset: Offset(0, 52), blurRadius: 25.8, spreadRadius: -9)] : null,
          gradient: selected
              ? const RadialGradient(center: Alignment(-0.92, -1), radius: 1.6, colors: [Color(0x809C8585), Color(0x806C6C6C)])
              : null,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            ModelDisc(color: item.modelDef.providerColor, label: item.modelDef.label),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  height: 24,
                  child: Row(children: [
                    Expanded(child: FText(item.modelDef.label, size: 20, height: 24, weight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: 0.6,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                        const SizedBox(width: 6),
                        FText(time, size: 16, height: 24, weight: FontWeight.w700),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                FText(msg.replaceAll('\n', ' '), size: 16, height: 16, weight: FontWeight.w700, opacity: 0.6),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Middle window (the opened answer) — 9:338, 791 x 720, plus text box 54:296.
class TickerAnswerWindow extends StatefulWidget {
  const TickerAnswerWindow({super.key, required this.item, required this.onClose, required this.onReply, required this.onTapMessage});
  final TickerItem item;
  final VoidCallback onClose;
  final ValueChanged<String> onReply;
  final ValueChanged<TickerMessage> onTapMessage;
  @override
  State<TickerAnswerWindow> createState() => _TickerAnswerWindowState();
}

class _TickerAnswerWindowState extends State<TickerAnswerWindow> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    _ctl.clear();
    widget.onReply(t);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final m = item.modelDef;
    return SizedBox(
      width: 791,
      height: 739,
      child: Stack(clipBehavior: Clip.none, children: [
        FGlass(
          width: 791,
          height: 720,
          radius: const BorderRadius.only(topRight: Radius.circular(46), bottomRight: Radius.circular(46)),
          stroke: const Color(0x66FFFFFF),
          child: Stack(children: [
            // User Status Container 9:339 at (33,38).
            Positioned(
              left: 33,
              top: 38,
              right: 100,
              height: 24,
              child: Row(children: [
                Flexible(child: FText(m.label, size: 24, height: 24, weight: FontWeight.w700)),
                const SizedBox(width: 11),
                FText(item.isStreaming ? 'Answering' : item.relativeTime, size: 15, height: 20, weight: FontWeight.w700, opacity: 0.4),
              ]),
            ),
            // Close Button Container 10:438 at (711,26), 48 x 48.
            Positioned(
              left: 711,
              top: 26,
              width: 48,
              height: 48,
              child: Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
                    child: const Icon(Icons.close_rounded, size: 24, color: Colors.white),
                  ),
                ),
              ),
            ),
            // Messages from y 110 (9:414) to the text box (y 590).
            Positioned(
              left: 0,
              right: 0,
              top: 110,
              height: 470,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 21),
                children: [
                  for (final msg in item.conversation)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 21),
                      child: msg.sender == 'user'
                          ? _Outgoing(msg: msg)
                          : GestureDetector(onTap: () => widget.onTapMessage(msg), child: _Incoming(msg: msg, color: m.providerColor, label: m.label)),
                    ),
                  if (item.isStreaming)
                    const Padding(padding: EdgeInsets.only(left: 114), child: FText('…', size: 18, height: 24, weight: FontWeight.w700, opacity: 0.6)),
                ],
              ),
            ),
          ]),
        ),
        // Text Box Container 54:296: (22, 590) relative, 726 x 149, rgba(0,0,0,.3), r 36.
        Positioned(
          left: 22,
          top: 590,
          width: 726,
          height: 149,
          child: FGlass(
            radius: BorderRadius.circular(36),
            fill: const Color(0x4D000000),
            child: Stack(children: [
              Positioned(
                left: 25,
                top: 22,
                right: 25,
                height: 50,
                child: TextField(
                  controller: _ctl,
                  onSubmitted: (_) => _send(),
                  cursorColor: Colors.white,
                  style: const TextStyle(fontSize: 20, height: 1.2, color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                ),
              ),
              // Send 54:301 at (597,81); attachment 54:298 at (654,81).
              Positioned(left: 597, top: 81, width: 48, height: 48, child: _CircleButton(icon: Icons.arrow_upward_rounded, label: 'Send', onTap: _send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ),
      );
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.msg, required this.color, required this.label});
  final TickerMessage msg;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 32),
        ModelDisc(color: color, label: label, size: 50),
        const SizedBox(width: 12),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(right: 32),
            child: FGlass(
              radius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FText(msg.text, size: 18, height: 24, weight: FontWeight.w700, maxLines: null, ellipsis: false),
                const SizedBox(height: 4),
                FText(_clock(msg.timestamp), size: 16, height: 16, weight: FontWeight.w700, opacity: 0.4),
              ]),
            ),
          ),
        ),
      ]);
}

class _Outgoing extends StatelessWidget {
  const _Outgoing({required this.msg});
  final TickerMessage msg;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 120),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF347552),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(4), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              FText(msg.text, size: 18, height: 24, weight: FontWeight.w700, maxLines: null, ellipsis: false, align: TextAlign.right),
              const SizedBox(height: 4),
              FText(_clock(msg.timestamp), size: 16, height: 16, weight: FontWeight.w700, opacity: 0.4),
            ]),
          ),
        ),
        const SizedBox(width: 13),
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
          child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 32),
      ]);
}
