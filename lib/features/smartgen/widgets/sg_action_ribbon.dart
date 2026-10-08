import 'package:flutter/material.dart';
import '../theme/smartgen_glass.dart';

/// A contextual action ribbon — a demure, floating vertical glass capsule
/// that holds view-specific actions. Per the master spec, contextual options
/// live here (or in the side nav), never in the permanent bottom dock.
///
/// Cinematic treatment: frosted blur, faded edges, content-hugging size.
/// Non-invasive: it floats at the content edge, collapsible.
class SGActionRibbon extends StatelessWidget {
  final List<SGRibbonAction> actions;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  const SGActionRibbon({
    super.key,
    required this.actions,
    this.collapsed = false,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel.bar(
      radius: 24,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse handle — demure, just a chevron.
          GlassPressable(
            onTap: onToggleCollapse,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                collapsed
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 4),
            // Faded edges: actions dissolve at top/bottom.
            Flexible(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.12, 0.88, 1.0],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 2),
                        _RibbonButton(action: actions[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SGRibbonAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  const SGRibbonAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });
}

class _RibbonButton extends StatelessWidget {
  final SGRibbonAction action;

  const _RibbonButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final opacity = action.enabled ? 1.0 : 0.3;
    return Tooltip(
      message: action.label,
      child: GlassPressable(
        onTap: action.enabled ? action.onTap : () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: action.active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(
              action.icon,
              size: 16,
              color: (action.active
                      ? const Color(0xFF1A1A1A)
                      : Colors.white.withValues(alpha: 0.85))
                  .withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }
}
