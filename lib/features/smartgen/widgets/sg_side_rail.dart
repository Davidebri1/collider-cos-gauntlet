import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../theme/smartgen_glass.dart';

/// The Smart Gen side navigation — a literal port of the Photos VR side
/// bar: a slim vertical glass capsule; icons stack vertically; the active
/// icon sits in a white circle.
///
/// Entry stays contextual: Cards / Canvases / Boards unfold their drawer,
/// Genie opens the agentic panel, New deploys a card. No hub, no board menu.
class SGSideRail extends StatelessWidget {
  final VoidCallback onClose;
  final List<SGRailEntry> entries;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew;
  final bool newHighlighted;

  const SGSideRail({
    super.key,
    required this.onClose,
    required this.entries,
    required this.activeIndex,
    required this.onSelect,
    required this.onNew,
    this.newHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel.bar(
      radius: 34,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailButton(
            icon: Icons.close_rounded,
            active: false,
            onTap: onClose,
          ),
          const _Divider(),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _RailButton(
                icon: entries[i].icon,
                label: entries[i].label,
                active: activeIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          const _Divider(),
          _RailButton(
            icon: Icons.add_rounded,
            label: 'New',
            active: newHighlighted,
            onTap: onNew,
          ),
        ],
      ),
    );
  }
}

class SGRailEntry {
  final IconData icon;
  final String label;
  const SGRailEntry(this.icon, this.label);
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label ?? '',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: active
                ? [
                    const BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 3))
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color:
                    active ? SGGlass.ink : Colors.white.withValues(alpha: 0.78),
              ),
              if (label != null) ...[
                const SizedBox(height: 1),
                Text(
                  label!,
                  style: AppFonts.instrumentSans(
                    fontSize: 8,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? SGGlass.ink
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
