import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import '../../models/ticker_item.dart';
import '../browser/models/browser_tab.dart';

enum ActiveWorkSurface {
  chat,
  smartgen,
  market,
  themes,
  browser,
  files,
}

enum SideNavTab { local, global, consensus }

/// REQ-21 contextual panel beside the rail — the visionOS menu panel
/// (visionOS Apps 97:34752 "Home / People / Environments"): a glass panel of
/// icon-circle rows, selected row lit as a capsule; content follows the surface.
class ContextualSideNav extends StatefulWidget {
  final ActiveWorkSurface activeSurface;

  // AI Chat props
  final ModelCategory activeCategory;
  final List<String> selectedModelIds;
  final Map<String, List<ConversationHistorySession>> localHistory;
  final List<ConversationHistorySession> globalHistory;
  final String consensusRatio;
  final String consensusSummary;
  final String? expandedModelId;
  final ValueChanged<ModelCategory> onSelectCategory;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<ConversationHistorySession> onSelectSession;
  final VoidCallback onOpenConsensus;
  final VoidCallback onNewConversation;
  final String chatSection; // local | global | consensus | models

  // Smart Gen props
  final String activeSmartGenView;
  final String activeSmartGenBoardType;
  final ValueChanged<String>? onSelectSmartGenView;
  final ValueChanged<String>? onSelectSmartGenBoardType;

  // Market props
  final String activeMarketCategory;
  final ValueChanged<String>? onSelectMarketCategory;
  final ValueChanged<String>? onMarketSearch;

  // Themes props
  final String activeThemeSection;
  final ValueChanged<String>? onSelectThemeSection;

  // Browser props
  final List<BrowserTab>? browserTabs;
  final String? activeBrowserTabId;
  final ValueChanged<String>? onSelectBrowserTab;
  final ValueChanged<String>? onCloseBrowserTab;
  final VoidCallback? onClearBrowserCache;

  // Files props
  final String activeFilesCategory;
  final ValueChanged<String>? onSelectFilesCategory;

  final ValueChanged<ActiveWorkSurface>? onRequestSwitchSurface;
  final VoidCallback onPaneInteraction;
  final VoidCallback? onClose;

  const ContextualSideNav({
    super.key,
    this.activeSurface = ActiveWorkSurface.chat,
    required this.activeCategory,
    required this.selectedModelIds,
    required this.localHistory,
    required this.globalHistory,
    required this.consensusRatio,
    required this.consensusSummary,
    required this.expandedModelId,
    required this.onSelectCategory,
    required this.onToggleModel,
    required this.onSelectSession,
    required this.onOpenConsensus,
    required this.onNewConversation,
    this.chatSection = 'global',
    this.activeSmartGenView = 'cards',
    this.activeSmartGenBoardType = 'kanban',
    this.onSelectSmartGenView,
    this.onSelectSmartGenBoardType,
    this.activeMarketCategory = 'prompts',
    this.onSelectMarketCategory,
    this.onMarketSearch,
    this.activeThemeSection = 'gallery',
    this.onSelectThemeSection,
    this.browserTabs,
    this.activeBrowserTabId,
    this.onSelectBrowserTab,
    this.onCloseBrowserTab,
    this.onClearBrowserCache,
    this.activeFilesCategory = 'all',
    this.onSelectFilesCategory,
    this.onRequestSwitchSurface,
    required this.onPaneInteraction,
    this.onClose,
  });

  @override
  State<ContextualSideNav> createState() => _ContextualSideNavState();
}

class _ContextualSideNavState extends State<ContextualSideNav> {
  SideNavTab _chatTab = SideNavTab.global;
  final TextEditingController _chatSearchCtrl = TextEditingController();
  String _chatQuery = '';
  final TextEditingController _marketSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _chatSearchCtrl.dispose();
    _marketSearchCtrl.dispose();
    super.dispose();
  }

  List<ConversationHistorySession> _sessions() {
    final q = _chatQuery.toLowerCase().trim();
    final source = widget.chatSection == 'local'
        ? widget.localHistory.entries
            .expand((e) => e.value)
            .where((s) => widget.selectedModelIds.contains(s.targetModelId))
            .toList()
        : widget.globalHistory;
    if (q.isEmpty) return source;
    return source
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.summary.toLowerCase().contains(q) ||
            s.messages.any((m) => m.text.toLowerCase().contains(q)))
        .toList();
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final width = isMobile ? math.min(240.0, size.width - 104) : 260.0;
    final maxHeight = math.min(440.0, size.height * 0.52);

    final (title, _) = switch (widget.activeSurface) {
      ActiveWorkSurface.chat => (switch (widget.chatSection) {
          'local' => 'Local History',
          'consensus' => 'Consensus History',
          'models' => 'Models',
          _ => 'Global History',
        }, 0),
      ActiveWorkSurface.smartgen => ('Smart Gen', 0),
      // v8.3 (D45): one or two words, only to tell the panels apart.
      ActiveWorkSurface.market => ('Market', 0),
      ActiveWorkSurface.themes => ('Themes', 0),
      ActiveWorkSurface.browser => ('Tabs', 0),
      ActiveWorkSurface.files => ('Files', 0),
    };

    return SizedBox(
      width: width,
      height: maxHeight,
      child: VGlass(
        material: VMaterial.elevated,
        radius: VRadius.card,
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: VSpace.xxs),
                  Expanded(child: Text(title, style: VType.headline())),
                  if (widget.onClose != null)
                    VCircleButton(icon: Icons.close_rounded, size: 32, tooltip: 'Close', onTap: widget.onClose),
                ],
              ),
            ),
            const SizedBox(height: VSpace.xs),
            Expanded(
              child: AnimatedSwitcher(
                duration: VMotion.base,
                child: KeyedSubtree(key: ValueKey(widget.activeSurface), child: _content()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() => switch (widget.activeSurface) {
        ActiveWorkSurface.chat => _chat(),
        ActiveWorkSurface.themes => _themes(),
        ActiveWorkSurface.browser => _browser(),
        // v8.2 fix pass (D31): the Smart Gen views / boards, Market categories
        // and Files categories selected nothing; those panels are deleted.
        ActiveWorkSurface.smartgen || ActiveWorkSurface.market || ActiveWorkSurface.files => const SizedBox.shrink(),
      };

  // ---------------- AI Chat ----------------
  Widget _chat() {
    if (widget.chatSection == 'consensus') return _consensus();
    if (widget.chatSection == 'models') return _models();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(controller: _chatSearchCtrl, hint: 'Search', height: 34, onChanged: (v) => setState(() => _chatQuery = v)),
        const SizedBox(height: VSpace.xs),
        Expanded(child: _history()),
      ],
    );
  }

  Widget _models() {
    final models = ModelRoster.forCategory(widget.activeCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // models.ts CATEGORIES: General, Image, Video, Audio, Coding (D35 revoked).
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ModelCategory.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
            itemBuilder: (_, i) {
              final c = ModelCategory.values[i];
              return VChip(
                label: c.label,
                selected: c == widget.activeCategory,
                onTap: () {
                  widget.onPaneInteraction();
                  widget.onSelectCategory(c);
                },
              );
            },
          ),
        ),
        const SizedBox(height: VSpace.sm),
        Expanded(
          child: EdgeFade(
            fadeHeight: 12,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                for (final m in models)
                  VSidebarItem(
                    icon: widget.selectedModelIds.contains(m.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                    label: m.label,
                    selected: widget.selectedModelIds.contains(m.id),
                    onTap: () {
                      widget.onPaneInteraction();
                      widget.onToggleModel(m.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final sessions = _sessions();
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    return EdgeFade(
      fadeHeight: 12,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
        itemBuilder: (_, i) {
          final s = sessions[i];
          return VPress(
            onTap: () => widget.onSelectSession(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: VSpace.xs),
              decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600))),
                    const SizedBox(width: 6),
                    Text(s.relativeTime, style: VType.caption()),
                  ]),
                  const SizedBox(height: 2),
                  Text(s.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.caption(color: VColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _consensus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(VSpace.sm),
          decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.balance_rounded, size: 15, color: VColors.textPrimary),
                const SizedBox(width: 6),
                Text('${widget.consensusRatio} Convergence', style: VType.callout(weight: FontWeight.w600)),
              ]),
              const SizedBox(height: VSpace.xs),
              Text(widget.consensusSummary, style: VType.footnote()),
            ],
          ),
        ),
        const SizedBox(height: VSpace.sm),
        VButton(label: 'Open 3D Celestial Map', dense: true, expand: true, onTap: widget.onOpenConsensus),
      ],
    );
  }

  // ---------------- Themes ----------------
  Widget _themes() {
    final sections = [
      ('gallery', 'Theme Gallery', Icons.collections_rounded),
      ('premium', 'Premium Market', Icons.workspace_premium_rounded),
      if (MusicPlayer.library.isNotEmpty) ('music', 'Music Collection', Icons.graphic_eq_rounded),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final s in sections)
          VSidebarItem(
            icon: s.$3,
            label: s.$2,
            selected: widget.activeThemeSection == s.$1,
            onTap: () => widget.onSelectThemeSection?.call(s.$1),
          ),
      ],
    );
  }

  // ---------------- Browser ----------------
  Widget _browser() {
    final tabs = widget.browserTabs ?? const <BrowserTab>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: tabs.isEmpty
              ? const SizedBox.shrink()
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final t in tabs)
                      VSidebarItem(
                        icon: t.isModelAssigned ? Icons.terminal_rounded : Icons.person_outline_rounded,
                        label: t.title.isEmpty ? t.url : t.title,
                        selected: widget.activeBrowserTabId == t.id,
                        onTap: () => widget.onSelectBrowserTab?.call(t.id),
                        trailing: widget.onCloseBrowserTab == null
                            ? null
                            : VCircleButton(icon: Icons.close_rounded, size: 24, tooltip: 'Close tab', onTap: () => widget.onCloseBrowserTab!(t.id)),
                      ),
                  ],
                ),
        ),
        VButton(label: 'Clear Browser Cache', dense: true, expand: true, variant: VButtonVariant.ghost, onTap: widget.onClearBrowserCache),
      ],
    );
  }
}
