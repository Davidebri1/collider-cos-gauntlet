import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../music/floating_music.dart';

/// Settings (map row 26, VisionOS Autolayout Menu 0-1): a glass menu of
/// icon + label rows; a highlighted row is a setting that is on. Tap a row to
/// switch it. No title, no server-status lines (v8.3, D47).
class SettingsDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;
  /// Opens Account (map row 18).
  final VoidCallback? onAccount;

  const SettingsDrawer({
    this.onAccount,
    super.key,
    required this.onClose,
    required this.incognito,
    required this.autosave,
    required this.onIncognito,
    required this.onAutosave,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Figma 1:2 has no dimming behind the menu: a clear tap-to-close layer.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose)),
        Center(
          child: ListenableBuilder(
            listenable: Listenable.merge([FloatingMusic.enabled, ThemeCatalog.instance]),
            builder: (_, __) => GlassMenu(
              rows: [
                if (onAccount != null) GlassMenuRow(icon: Icons.person_outline_rounded, label: 'Account', onTap: onAccount, toggle: false),
                GlassMenuRow(icon: Icons.visibility_off_outlined, label: 'Incognito', on: incognito, onTap: () => onIncognito(!incognito)),
                GlassMenuRow(icon: Icons.history_rounded, label: 'Save to History', on: autosave && !incognito, onTap: incognito ? null : () => onAutosave(!autosave)),
                // The one switch for the floating music widget; absent while
                // the catalog has no songs (D46).
                if (MusicPlayer.library.isNotEmpty)
                  GlassMenuRow(
                    icon: Icons.music_note_rounded,
                    label: 'Music widget',
                    on: FloatingMusic.enabled.value,
                    onTap: () => FloatingMusic.setEnabled(!FloatingMusic.enabled.value),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
