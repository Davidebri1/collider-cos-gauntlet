// Light Markdown renderer for model answers. Made by Claude.
// Headings, bold, bullets and numbered lists, rendered as calm text (no raw symbols).
import 'package:flutter/material.dart';
import 'vision_tokens.dart';

class MdText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const MdText(this.text, {super.key, this.style});

  static final _bold = RegExp(r'\*\*(.+?)\*\*|__(.+?)__');

  List<InlineSpan> _inline(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _bold.allMatches(s)) {
      if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start)));
      spans.add(TextSpan(text: m.group(1) ?? m.group(2), style: base.copyWith(fontWeight: FontWeight.w700)));
      i = m.end;
    }
    if (i < s.length) spans.add(TextSpan(text: s.substring(i)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? VType.callout(weight: FontWeight.w400).copyWith(height: 1.45);
    final lines = text.replaceAll('\r', '').split('\n');
    final children = <Widget>[];
    for (var raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      if (RegExp(r'^\s*(---+|\*\*\*+)\s*$').hasMatch(line)) continue;
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (h != null) {
        final level = h.group(1)!.length;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text.rich(TextSpan(children: _inline(h.group(2)!.replaceAll('*', ''), base)),
              style: base.copyWith(fontWeight: FontWeight.w700, fontSize: (base.fontSize ?? 13) + (level <= 2 ? 3 : 1))),
        ));
        continue;
      }
      final b = RegExp(r'^(\s*)[-*•]\s+(.*)$').firstMatch(line);
      final n = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (b != null || n != null) {
        final indent = ((b ?? n)!.group(1)!.length / 2).clamp(0, 3) * 12.0;
        final marker = b != null ? '•' : '${n!.group(2)}.';
        final body = b != null ? b.group(2)! : n!.group(3)!;
        children.add(Padding(
          padding: EdgeInsets.only(left: indent, top: 1, bottom: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 18, child: Text(marker, style: base.copyWith(color: VColors.textSecondary))),
            Expanded(child: Text.rich(TextSpan(children: _inline(body, base)), style: base)),
          ]),
        ));
        continue;
      }
      if (line.startsWith('|')) {
        // Tables become readable rows.
        if (RegExp(r'^\|[\s:|-]+\|$').hasMatch(line)) continue;
        final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).join('  ·  ');
        children.add(Text.rich(TextSpan(children: _inline(cells, base)), style: base));
        continue;
      }
      children.add(Text.rich(TextSpan(children: _inline(line, base)), style: base));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}
