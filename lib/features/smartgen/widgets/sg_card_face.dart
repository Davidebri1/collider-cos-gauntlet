import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../models/smartgen_models.dart';
import '../theme/smartgen_glass.dart';

/// Shared card face — the Figma "Widgets Board" recipe every card surface
/// renders: a frosted [GlassPanel.card] with a tinted type icon, the title,
/// an urgent dot, and (when present) a content snippet and due chip.
///
/// The kanban column cards and the swimlane chips both use this widget so the
/// two surfaces render the identical card. Callers supply the [title] widget
/// (static text, or an inline [TextField] for the kanban's tap-to-rename) and
/// an optional [onMenuAt] for the "…" affordance; when [onMenuAt] is null the
/// button is hidden (the swimlane opens its menu on tap-anywhere instead).
class SGCardFace extends StatelessWidget {
  final SmartCard card;
  final ComponentTemplate? template;
  final Widget title;
  final String snippet;
  final ValueChanged<Offset>? onMenuAt;

  const SGCardFace({
    super.key,
    required this.card,
    required this.template,
    required this.title,
    this.snippet = '',
    this.onMenuAt,
  });

  static const _tints = [
    SGGlass.sysBlue,
    SGGlass.sysPurple,
    SGGlass.sysTeal,
    SGGlass.sysOrange,
    SGGlass.sysGreen,
    SGGlass.sysPink,
  ];

  /// Type tint for a card, from its template id. Matches the tint the
  /// swimlane chips and every other surface derive.
  static Color tintFor(String templateId) =>
      _tints[templateId.hashCode.abs() % _tints.length];

  static IconData iconFor(String? name) {
    switch (name) {
      case 'checklist_rounded':
        return Icons.checklist_rounded;
      case 'note_rounded':
        return Icons.note_rounded;
      case 'bug_report_rounded':
        return Icons.bug_report_rounded;
      default:
        return Icons.style_rounded;
    }
  }

  /// First non-default prose-ish field value — the card's content preview.
  static String snippetFor(SmartCard card, ComponentTemplate? tpl) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    String? valueOf(FieldDef f) {
      final v = (card.values[f.id]?.toString() ?? '').trim();
      if (v.isEmpty || v == card.title) return null;
      // Untouched template defaults (Status: To Do, Priority: P2, …)
      // and anything mirroring the card's own column are not content.
      if (v == (f.defaultValue?.toString() ?? '').trim()) return null;
      if (norm(v) == norm(card.status)) return null;
      return v;
    }

    if (tpl == null) return '';
    const prose = {'description', 'body', 'notes', 'entry', 'content'};
    for (final f in tpl.fields) {
      if (!prose.contains(f.label.toLowerCase())) continue;
      final v = valueOf(f);
      if (v != null) return v;
    }
    for (final f in tpl.fields) {
      final v = valueOf(f);
      if (v != null) return v;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(card.templateId);
    return GlassPanel.card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(iconFor(template?.iconName), size: 15, color: tint),
              ),
              const SizedBox(width: 9),
              Expanded(child: title),
              if (card.urgent)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: const BoxDecoration(
                    color: SGGlass.sysRed,
                    shape: BoxShape.circle,
                  ),
                ),
              if (onMenuAt != null)
                GestureDetector(
                  onTapDown: (d) => onMenuAt!(d.globalPosition),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz_rounded,
                        size: 16, color: SGGlass.ink3),
                  ),
                ),
            ],
          ),
          if (snippet.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.instrumentSans(
                  fontSize: 12.5, color: SGGlass.ink2, height: 1.35),
            ),
          ],
          if (card.dueAt != null) ...[
            const SizedBox(height: 8),
            SGDueChip(dueAt: card.dueAt!),
          ],
        ],
      ),
    );
  }
}

/// Due-date chip shared by every card face: calendar icon + "Mon DD",
/// red when overdue, orange when due within 24h.
class SGDueChip extends StatelessWidget {
  final DateTime dueAt;
  const SGDueChip({super.key, required this.dueAt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = dueAt.isBefore(now);
    final soon = !overdue && dueAt.difference(now) < const Duration(hours: 24);
    final color =
        overdue ? SGGlass.sysRed : soon ? SGGlass.sysOrange : SGGlass.ink3;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SGGlass.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 11, color: color),
          const SizedBox(width: 5),
          Text('${months[dueAt.month - 1]} ${dueAt.day}',
              style: AppFonts.instrumentSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
