import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';
import 'contextual_side_nav.dart';

/// One affordance on the side nav. [key] is what the surface acts on.
class SideRailEntry {
  final String key;
  final IconData icon;
  final String label;
  const SideRailEntry(this.key, this.icon, this.label);
}

/// Master Spec §6.2: the side nav reshapes to the active work surface.
/// Surfaces themselves are reached from the Apps overlay, never from here.
List<SideRailEntry> sideRailEntries(ActiveWorkSurface s) => switch (s) {
      ActiveWorkSurface.chat => const [
          SideRailEntry('new', Icons.add_rounded, 'New Chat'),
          SideRailEntry('local', Icons.history_rounded, 'Local History'),
          SideRailEntry('global', Icons.public_rounded, 'Global History'),
          SideRailEntry('consensus', Icons.balance_rounded, 'Consensus History'),
          SideRailEntry('models', Icons.hub_outlined, 'Models'),
        ],
      ActiveWorkSurface.smartgen => const [
          SideRailEntry('cards', Icons.style_rounded, 'Cards'),
          SideRailEntry('boards', Icons.dashboard_rounded, 'Boards'),
          SideRailEntry('canvas', Icons.crop_free_rounded, 'Canvas'),
          SideRailEntry('genie', Icons.assistant_rounded, 'Genie'),
          SideRailEntry('new', Icons.add_rounded, 'New Card'),
        ],
      ActiveWorkSurface.market => const [
          // v8.4 (rail 290:4411, four tabs): discover, search, this
          // session's generations, the theme gallery.
          SideRailEntry('discover', Icons.play_arrow_rounded, 'Discover'),
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('mine', Icons.bookmark_rounded, 'My Generations'),
          SideRailEntry('gallery', Icons.collections_rounded, 'Theme Gallery'),
        ],
      ActiveWorkSurface.themes => [
          const SideRailEntry('premium', Icons.workspace_premium_rounded, 'Premium Marketplace'),
          const SideRailEntry('gallery', Icons.collections_rounded, 'Theme Gallery'),
          // No songs in the catalog: no Music entry (v8.3, D46).
          if (MusicPlayer.library.isNotEmpty) const SideRailEntry('music', Icons.library_music_rounded, 'Music Collection'),
        ],
      ActiveWorkSurface.browser => const [
          SideRailEntry('tabs', Icons.tab_rounded, 'Tabs'),
          SideRailEntry('engine', Icons.travel_explore_rounded, 'Search Engine'),
          SideRailEntry('clear', Icons.cleaning_services_outlined, 'Clear Cache'),
        ],
      // v8.4 (Files 71:7502 rail): where the files came from, plus search.
      ActiveWorkSurface.files => [
          const SideRailEntry('all', Icons.folder_open_rounded, 'All Files'),
          const SideRailEntry('files', Icons.upload_file_rounded, 'Added Here'),
          const SideRailEntry('composer', Icons.attach_file_rounded, 'Attachments'),
          const SideRailEntry('model', Icons.hub_rounded, 'Model Outputs'),
          if (MusicPlayer.library.isNotEmpty) const SideRailEntry('music', Icons.library_music_rounded, 'Music'),
          const SideRailEntry('search', Icons.search_rounded, 'Search'),
        ],
    };

/// Vertical tab-bar ornament on the left edge, as in every visionOS app.
class SideNavRail extends StatelessWidget {
  final ActiveWorkSurface surface;
  final String? activeKey;
  final ValueChanged<String> onSelect;
  final bool compact;

  const SideNavRail({
    super.key,
    required this.surface,
    required this.activeKey,
    required this.onSelect,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final entries = sideRailEntries(surface);
    return AnimatedSwitcher(
      duration: VMotion.base,
      child: VOrnamentRail(
        key: ValueKey(surface),
        size: compact ? 36 : 40,
        items: [for (final e in entries) VRailItem(e.icon, e.label)],
        active: entries.indexWhere((e) => e.key == activeKey),
        onSelect: (i) => onSelect(entries[i].key),
      ),
    );
  }
}
