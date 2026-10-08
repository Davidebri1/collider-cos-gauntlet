import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../theme/smartgen_glass.dart';

/// A glass context menu — ported from the faded-edges reference (01 – Menu):
/// dark frosted panel, 44pt rows with icon + label, the highlighted row a
/// white pill. Presented as a floating overlay anchored near the tap.
class SGMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool highlighted;

  const SGMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.highlighted = false,
  });
}

class SGMenu extends StatelessWidget {
  final List<SGMenuItem> items;
  final double width;
  final VoidCallback? onDismiss;

  const SGMenu(
      {super.key, required this.items, this.width = 216, this.onDismiss});

  /// Shows the menu as a floating overlay anchored at [at] (global coords),
  /// nudged on-screen. Tapping outside dismisses.
  static Future<void> show(
    BuildContext context, {
    required Offset at,
    required List<SGMenuItem> items,
    double width = 216,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        var dx = at.dx - width + 24;
        var dy = at.dy + 8;
        dx = dx.clamp(8.0, screen.width - width - 8.0);
        final estH = items.length * 50.0 + 24;
        dy = dy.clamp(
            8.0, (screen.height - estH - 8.0).clamp(8.0, screen.height));
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => entry.remove(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: dx,
              top: dy,
              child: Material(
                color: Colors.transparent,
                child: SGMenu(
                  items: items,
                  width: width,
                  onDismiss: () => entry.remove(),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    const danger = SGGlass.sysRed;
    return GlassPanel.menu(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _Row(
                item: item,
                danger: danger,
                onDismiss: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final SGMenuItem item;
  final Color danger;
  final VoidCallback? onDismiss;

  const _Row({required this.item, required this.danger, this.onDismiss});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = item.destructive ? widget.danger : Colors.white;
    final highlighted = item.highlighted || _pressed;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        widget.onDismiss?.call();
        item.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SGGlass.rPill),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: AppFonts.instrumentSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
