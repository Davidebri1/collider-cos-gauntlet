import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-12 / G6 Permanent 3-icon bottom dock (Settings | Compose | Apps), shown on
/// every screen including the Premium Theme Market — a compact glass capsule ornament
/// (WeChat visionOS 0:639). Swipe up summons the composer, swipe down tucks it.
class PermanentNavBar extends StatelessWidget {
  final bool isComposerSummoned;
  final VoidCallback onToggleComposer;
  final VoidCallback onHome;
  final VoidCallback onApps;
  final VoidCallback onSettings;
  final String? activeDrawer;

  const PermanentNavBar({
    super.key,
    required this.isComposerSummoned,
    required this.onToggleComposer,
    required this.onHome,
    required this.onApps,
    required this.onSettings,
    this.activeDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        if (velocity < -200 && !isComposerSummoned) {
          onToggleComposer();
        } else if (velocity > 200 && isComposerSummoned) {
          onToggleComposer();
        }
      },
      child: VOrnament(
        padding: const EdgeInsets.all(VSpace.xs - 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VCircleButton(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              size: 44,
              selected: activeDrawer == 'settings',
              onTap: onSettings,
            ),
            const SizedBox(width: VSpace.sm),
            VCircleButton(
              icon: Icons.mode_comment_outlined, // S-N6 Compose glyph
              tooltip: 'Compose / Home',
              size: 44,
              selected: activeDrawer == null || isComposerSummoned,
              onTap: onHome,
            ),
            const SizedBox(width: VSpace.sm),
            VCircleButton(
              icon: Icons.apps_rounded,
              tooltip: 'Apps',
              size: 44,
              selected: activeDrawer == 'apps',
              onTap: onApps,
            ),
          ],
        ),
      ),
    );
  }
}
