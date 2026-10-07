import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/figma/figma_stage.dart';

/// REQ-01 App Grid (Vision OS Design System 2:6774, visionOS Home 97:34752):
/// circular app icons float directly over the dimmed environment in offset
/// rows — no platter. Escapes: scrim tap and the floating close circle.
class AppsPopupPane extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSmartGen;
  final VoidCallback onOpenDiscoverMarket;
  final VoidCallback onOpenThemeGallery;
  final VoidCallback onOpenPremiumMarketplace;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenMusicPlayer;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenSettings;
  /// The tab bar's Account tab (People in 97:34752).
  final VoidCallback? onOpenAccount;

  const AppsPopupPane({
    this.onOpenAccount,
    super.key,
    required this.onClose,
    required this.onOpenSmartGen,
    required this.onOpenDiscoverMarket,
    required this.onOpenThemeGallery,
    required this.onOpenPremiumMarketplace,
    required this.onOpenFiles,
    required this.onOpenMusicPlayer,
    required this.onOpenBrowser,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final apps = [
      // v8.3 (D45, D48): one-word names (an icon alone is ambiguous in a
      // launcher); full-colour icons and a Settings app, as in Figma 97-34752.
      _App('Smart Gen', Icons.auto_awesome_mosaic_rounded, const [Color(0xFFC4B5FD), Color(0xFF7C3AED)], onOpenSmartGen),
      _App('Market', Icons.explore_rounded, const [Color(0xFFFDBA74), Color(0xFFEA580C)], onOpenDiscoverMarket),
      _App('Themes', Icons.landscape_rounded, const [Color(0xFF6EE7B7), Color(0xFF059669)], onOpenThemeGallery),
      _App('Premium', Icons.diamond_rounded, const [Color(0xFFFDE68A), Color(0xFFD97706)], onOpenPremiumMarketplace),
      _App('Files', Icons.folder_rounded, const [Color(0xFF93C5FD), Color(0xFF2563EB)], onOpenFiles),
      // No songs in the catalog: no Music app (v8.3, D46).
      if (MusicPlayer.library.isNotEmpty) _App('Music', Icons.music_note_rounded, const [Color(0xFFFF7A90), Color(0xFFF2213B)], onOpenMusicPlayer),
      _App('Browser', Icons.explore_outlined, const [Color(0xFF7DD3FC), Color(0xFF0369A1)], onOpenBrowser),
      _App('Settings', Icons.settings_rounded, const [Color(0xFFE5E7EB), Color(0xFF8E8E93)], onOpenSettings, glyph: const Color(0xFF3A3A3C)),
    ];

    // v8.4: visionOS Home 97:34752 (1920 x 1080) at its own geometry,
    // scaled as one unit: tab bar (510, centred) + the offset 4-column grid
    // (84 px icons, 72 gap, label Inter Medium 12 at 8, rows 131 apart),
    // cropped symmetric about the frame centre (510 .. 1410 + 24 margin).
    const colX = [684.0, 840.0, 996.0, 1152.0];
    const rowY = [333.0, 464.0, 595.0];
    final cells = <Widget>[];
    for (var i = 0; i < apps.length; i++) {
      final r = i ~/ 4, c = i % 4;
      if (r > 2) break;
      final x = colX[c] + (r.isOdd ? 78 : 0);
      final a = apps[i];
      cells.add(Positioned(
        left: x - 36,
        top: rowY[r],
        width: 156,
        child: _AppIcon(
          index: i,
          app: a,
          size: 84,
          onTap: () {
            onClose();
            a.onTap();
          },
        ),
      ));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // The frame has no dimming: a clear tap-to-close layer.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose)),
        FigmaStage(
          frame: frame,
          cropWidth: cropWidth,
          center: center,
          children: [
            ...cells,
            // Tab bar 97:34752 at left 510, vertically centred.
            Positioned(
              left: 510,
              top: 540 - tabBarHeight / 2,
              child: FGlass(
                radius: BorderRadius.circular(34),
                stroke: const Color(0x66FFFFFF),
                strokeWidth: 1.4,
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _tab(Icons.apps_rounded, 'Apps', true, onClose),
                  const SizedBox(height: 8),
                  _tab(Icons.person_rounded, 'Account', false, () {
                    onClose();
                    onOpenAccount?.call();
                  }),
                  const SizedBox(height: 8),
                  _tab(Icons.landscape_rounded, 'Environments', false, () {
                    onClose();
                    onOpenThemeGallery();
                  }),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const frame = Size(1920, 1080);
  static const cropWidth = 900.0; // the window's own width, no margin
  static const center = Offset(960, 540);
  static const tabBarHeight = 12 * 2 + 44 * 3 + 8 * 2.0;

  Widget _tab(IconData icon, String label, bool active, VoidCallback onTap) => Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 196,
            height: 44,
            decoration: active ? BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(22)) : null,
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: active ? const BoxDecoration(shape: BoxShape.circle, color: Color(0x2EFFFFFF)) : null,
                child: Icon(icon, size: 24, color: Colors.white.withValues(alpha: active ? 1 : 0.6)),
              ),
              const SizedBox(width: 8),
              FText(label, size: 19, height: 24, weight: FontWeight.w500, opacity: active ? 1 : 0.6),
            ]),
          ),
        ),
      );
}

class _App {
  final String label;
  final IconData icon;
  /// Top and bottom of the icon's colour fill.
  final List<Color> colors;
  final VoidCallback onTap;
  final Color glyph;
  const _App(this.label, this.icon, this.colors, this.onTap, {this.glyph = Colors.white});
}

class _AppIcon extends StatelessWidget {
  final _App app;
  final double size;
  final int index;
  final VoidCallback onTap;
  const _AppIcon({required this.app, required this.size, required this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Icons rise into place one after another when the overlay is summoned.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 45),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: Transform.scale(scale: 0.85 + 0.15 * t, child: child)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // visionOS home icon: an opaque full-colour disc, a soft top
            // highlight and a drop shadow (Figma 97-34752).
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: app.colors),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))],
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                ),
              ),
              child: Icon(app.icon, size: size * 0.5, color: app.glyph),
            ),
            const SizedBox(height: 8),
            FText(app.label, size: 12, weight: FontWeight.w500, align: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
