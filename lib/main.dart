import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/edge_fade.dart';
import 'core/theme/living_stardust_overlay.dart';
import 'core/vision/vision_kit.dart';
import 'core/api/collider_api.dart';
import 'core/audio/music_player.dart';
import 'features/music/floating_music.dart';
import 'models/model_def.dart';
import 'models/theme_def.dart';
import 'models/ticker_item.dart';
import 'features/ticker/widgets/model_pill.dart';
import 'features/ticker/widgets/consensus_row.dart';
import 'features/ticker/widgets/message_zoom_overlay.dart';
import 'features/ticker/widgets/local_history_pane.dart';
import 'features/prompt/floating_prompt.dart';
import 'features/nav/permanent_nav_bar.dart';
import 'features/nav/side_nav_rail.dart';
import 'features/nav/contextual_side_nav.dart';
import 'features/apps/apps_popup_pane.dart';
import 'features/wallpaper/widgets/windowless_theme_scroller.dart';
import 'features/drawers/history_drawer.dart';
import 'features/drawers/music_collection_drawer.dart';
import 'features/drawers/settings_drawer.dart';
import 'features/drawers/model_ladder_drawer.dart';
import 'features/consensus/consensus_webview.dart';
import 'features/smartgen/screens/smartgen_screen.dart';
import 'features/market/screens/market_screen.dart';
import 'features/files/screens/files_screen.dart';
import 'features/browser/browser_urls.dart';
import 'features/browser/models/browser_tab.dart';
import 'features/browser/screens/in_app_browser_sheet.dart';
import 'features/theme/premium_theme_market_view.dart';
import 'features/theme/premium_market_alt_view.dart';
import 'features/theme/theme_living_media.dart';
import 'core/media/theme_catalog.dart';
import 'core/media/theme_media_bundle.dart';
import 'core/api/media_gen.dart';
import 'models/media_specs.dart';
import 'features/mediagen/gen_settings.dart';
import 'features/mediagen/gen_options_sheet.dart';
import 'features/mediagen/media_ticker.dart';
import 'core/figma/figma_stage.dart';
import 'core/figma/f_rail.dart';
import 'features/ticker/widgets/figma_ticker.dart';
import 'features/mediagen/figma_media_stage.dart';
import 'core/figma/rail_specs.dart';
import 'features/account/account_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Theme catalog: bundled fallback + cached copy now, live themes.json in background.
  await ThemeCatalog.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ColliderApp());
}

class ColliderApp extends StatelessWidget {
  const ColliderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080B),
        textTheme: GoogleFonts.instrumentSansTextTheme(ThemeData.dark().textTheme),
      ),
      // Remote theme posters resolve through the same bundle as local assets.
      builder: (context, child) => DefaultAssetBundle(
        bundle: ThemeMediaAssetBundle.instance,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ColliderHomeScreen(),
    );
  }
}

class ColliderHomeScreen extends StatefulWidget {
  const ColliderHomeScreen({super.key});

  @override
  State<ColliderHomeScreen> createState() => _ColliderHomeScreenState();
}

class _ColliderHomeScreenState extends State<ColliderHomeScreen> {
  // Wallpaper state: Uninterrupted, star of the product
  WallpaperTheme _currentTheme = WallpaperCatalog.defaultTheme;
  WallpaperTheme _savedThemeBeforePreview = WallpaperCatalog.defaultTheme;

  // Selected models, per category, as the source keeps them (state.tsx
  // selectedModelIds: Record<Category, string[]>), max 9 each.
  final Map<ModelCategory, List<String>> _selByCat = {
    for (final c in ModelCategory.values) c: _defaultSelected(c),
  };
  List<String> get _selectedModelIds => _selByCat[_activeCategory]!;

  /// state.tsx defaultSelected: the first three usable on the starting tier
  /// (or the whole category when none is), reachable ones first.
  static List<String> _defaultSelected(ModelCategory c) {
    final all = ModelRoster.forCategory(c);
    final usable = all.where((m) => ModelRoster.canUse(ModelTier.free, m)).toList();
    final pool = usable.isNotEmpty ? usable : all;
    final ids = pool.map((m) => m.id).toList();
    final ordered = [
      ...ids.where((id) => MediaGen.instance.hasCredentials(id)),
      ...ids.where((id) => !MediaGen.instance.hasCredentials(id)),
    ];
    return ordered.take(3).toList();
  }

  // Media generation (D35 revoked): per-category settings, references and
  // the latest run's results (map rows 13 and 17).
  final Map<ModelCategory, GenSettings> _genSettings = {
    for (final c in [ModelCategory.image, ModelCategory.video, ModelCategory.audio]) c: GenSettings.defaultsFor(c),
  };
  final Map<ModelCategory, List<String>> _genRefs = {};
  final Map<ModelCategory, List<MediaGeneration>> _mediaGens = {};
  bool _genOptionsOpen = false;
  /// Put back into the composer when a send cannot run (D59).
  final ValueNotifier<String?> _restoreText = ValueNotifier<String?>(null);
  /// Bumped by the options sheet's Generate: the composer sends its text.
  final ValueNotifier<int> _generateTick = ValueNotifier<int>(0);

  void _notice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 168), // above the composer and the bar
      backgroundColor: VColors.glassDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      content: Text(text, textAlign: TextAlign.center, style: VType.callout()),
    ));
  }

  /// A send that cannot run on this link: one quiet line, the prompt goes
  /// back into the composer, nothing else changes (D59).
  bool get _mediaShowing => _activeCategory.isMedia && (_mediaGens[_activeCategory]?.isNotEmpty ?? false);

  void _cannotRun(String prompt) {
    _restoreText.value = prompt;
    _notice("Can't run on this link");
  }

  // Active Model Category
  ModelCategory _activeCategory = ModelCategory.general;

  // Active temporary pane / drawer: 'themes', 'settings', 'consensus', 'apps', 'history', 'market', 'smartgen', 'files', 'model_ladder'
  String? _activeDrawer;

  // Local Model History modal state
  ModelDef? _localHistoryModel;

  // Zoomed message overlay state
  TickerMessage? _zoomedMessage;
  ModelDef? _zoomedModelDef;

  // Expanded accordion model IDs
  final Set<String> _expandedModelIds = {};

  // Swipe/tap-summoned global broadcast composer
  bool _isComposerSummoned = false;

  // Mobile slide-out contextual side nav state
  bool _isMobileSideNavOpen = false;

  // Current floating user prompt (floats un-framed on wallpaper)
  String _currentPrompt = '';

  // Consensus state: ratio of agreeing models (e.g. "7/7")
  String _consensusRatio = 'Consensus';
  String _consensusSummary = '';
  bool _isConsensusGenerating = false;

  // Live session state (Collider server)
  AskMode _mode = AskMode.chat;
  bool _incognito = false;
  bool _autosave = true;
  bool _busy = false;
  DateTime? _promptTime;
  final Map<String, JobState> _jobsById = {};
  String? _currentJobId;

  // Ticker items
  late List<TickerItem> _tickerItems;

  // Global History Sessions
  late List<ConversationHistorySession> _globalHistorySessions;

  // Local Model History Sessions map
  late Map<String, List<ConversationHistorySession>> _localHistorySessions;

  // Browser Tabs (only 1 active at a time)
  late List<BrowserTab> _browserTabs;

  // Contextual work surface state
  String _smartGenView = 'cards';
  String _smartGenBoardType = 'kanban';
  String _marketCategory = 'discover';
  String _marketSearchQuery = '';
  String _themeSection = 'gallery';
  String _filesCategory = 'all';
  String _chatSection = 'global';

  /// The rail ornament shows on the resting canvas and durable work surfaces only.
  bool get _railVisible {
    if (_localHistoryModel != null || _zoomedMessage != null || _browserOpen || _genOptionsOpen) return false;
    // v8.4: the tab bar is part of each Figma frame (wechat 2013:75 / 2013:71
    // at 540,624; Files 71-7502; Discover Market 290:4411), so it shows
    // wherever that frame does, at the frame's own position and size.
    if (_activeDrawer == null) return true;
    return RailSpecs.of(_currentActiveSurface) != null && const {'files', 'market', 'smartgen', 'themes'}.contains(_activeDrawer);
  }

  ActiveWorkSurface get _currentActiveSurface {
    if (_activeDrawer == 'smartgen') return ActiveWorkSurface.smartgen;
    if (_activeDrawer == 'market') return ActiveWorkSurface.market;
    if (_activeDrawer == 'themes' || _activeDrawer == 'premium' || _activeDrawer == 'music') return ActiveWorkSurface.themes;
    if (_activeDrawer == 'files') return ActiveWorkSurface.files;
    return ActiveWorkSurface.chat;
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    final cat = ThemeCatalog.instance;
    setState(() {
      _currentTheme = cat.bySlug(_currentTheme.id) ?? _currentTheme;
      _savedThemeBeforePreview = cat.bySlug(_savedThemeBeforePreview.id) ?? _savedThemeBeforePreview;
    });
  }

  @override
  void dispose() {
    ThemeCatalog.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ThemeCatalog.instance.addListener(_onCatalogChanged);
    if (Uri.base.queryParameters['drawer'] == 'premium') {
      _activeDrawer = 'premium';
      // Seed Plane 0 to a live premium loop before CoverFlow preview callback
      _currentTheme = WallpaperCatalog.premiumThemes.isNotEmpty
          ? WallpaperCatalog.premiumThemes.first
          : WallpaperCatalog.defaultTheme;
      _savedThemeBeforePreview = _currentTheme;
    } else if (Uri.base.queryParameters['drawer'] != null) {
      _activeDrawer = Uri.base.queryParameters['drawer'];
    }
    if (Uri.base.queryParameters['composer'] == '1') _isComposerSummoned = true;
    final cq = Uri.base.queryParameters['cat'];
    if (cq != null) _activeCategory = ModelCategory.values.firstWhere((c) => c.name == cq, orElse: () => ModelCategory.general);
    if (Uri.base.queryParameters['genopts'] == '1' && _activeCategory.isMedia) _genOptionsOpen = true;
    if (Uri.base.queryParameters['rail'] == '1') _isMobileSideNavOpen = true;
    _initializeTickerItems();
    _initializeHistorySessions();
    _initializeBrowserTabs();
    _boot().whenComplete(() {
      if (!_booted.isCompleted) _booted.complete();
      if (mounted) setState(() => _apiChecked = true);
    });
    final qp = Uri.base.queryParameters;
    if (qp['zoom'] == '1' && _tickerItems.isNotEmpty) {
      _zoomedMessage = _tickerItems.first.conversation.last;
      _zoomedModelDef = _tickerItems.first.modelDef;
    }
    if (qp['local'] == '1' && _tickerItems.isNotEmpty) {
      _localHistoryModel = _tickerItems.first.modelDef;
    }
    if (qp['expand'] == '1') {
      if (_tickerItems.isNotEmpty) _expandedModelIds.add(_tickerItems.first.modelDef.id);
    }
    if (qp['browser'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowserForTab('user_default'));
    }
  }

  void _initializeTickerItems() {
    _tickerItems = [];
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }

  final Completer<void> _booted = Completer<void>();
  /// The server probe has answered (or failed): [ColliderApi.online] is known.
  bool _apiChecked = false;

  Future<void> _boot() async {
    final ok = await ColliderApi.instance.loadRoster();
    if (!mounted) return;
    if (!ok) {
      // No backend: the untouched start tab moves to a page that can be
      // framed (browser_urls.dart, v8.3 D41).
      if (_browserTabs.isNotEmpty && _browserTabs.first.id == 'user_default' && _browserTabs.first.url.contains('duckduckgo.com')) {
        setState(() => _browserTabs[0] = _browserTabs.first.copyWith(url: browserStartUrl()));
      }
      return;
    }
    // Default selection: one model per provider, so every card carries a distinct colour.
    final seen = <String>{};
    final live = <String>[
      for (final m in ModelRoster.allModels.where((m) => !m.isMedia))
        if (seen.add(m.provider)) m.id,
    ];
    setState(() {
      _selByCat[ModelCategory.general] = live.take(6).toList();
    });
    await _reloadHistory(restoreLatest: true);
    // Deep links used by the launcher and the screenshot tour: ?ask=...&mode=research
    final qp = Uri.base.queryParameters;
    if (qp['mode'] != null) {
      _mode = AskMode.values.firstWhere((m) => m.wire == qp['mode'], orElse: () => AskMode.chat);
    }
    if (qp['ask'] != null && qp['ask']!.trim().isNotEmpty) _onSendPrompt(qp['ask']!);
    if (_tickerItems.isNotEmpty) {
      setState(() {
        if (qp['expand'] == '1') _expandedModelIds.add(_tickerItems.first.modelDef.id);
        if (qp['local'] == '1') _localHistoryModel = _tickerItems.first.modelDef;
        if (qp['zoom'] == '1') {
          _zoomedMessage = _tickerItems.first.conversation.last;
          _zoomedModelDef = _tickerItems.first.modelDef;
        }
      });
    }
  }

  Future<void> _reloadHistory({bool restoreLatest = false}) async {
    final hist = await ColliderApi.instance.history();
    if (!mounted) return;
    setState(() {
      for (final j in hist) {
        _jobsById[j.id] = j;
      }
      _globalHistorySessions = [for (final j in hist) _sessionFromJob(j)];
      final local = <String, List<ConversationHistorySession>>{};
      for (final j in hist) {
        j.results.forEach((mid, r) {
          if (r.status != 'done') return;
          (local[mid] ??= []).add(ConversationHistorySession(
            id: '${j.id}_$mid',
            title: j.prompt,
            targetModelId: mid,
            relativeTime: _ago(j.created),
            timestamp: j.created,
            summary: r.essence,
            messages: [
              TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
              TickerMessage(id: '${j.id}_$mid', sender: 'model', text: r.text, timestamp: j.created),
            ],
          ));
        });
      }
      _localHistorySessions = local;
      if (restoreLatest && hist.isNotEmpty && _tickerItems.isEmpty) _applyJob(hist.first, restored: true);
    });
  }

  ConversationHistorySession _sessionFromJob(JobState j) {
    final firstEssence = j.results.values.map((r) => r.essence).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return ConversationHistorySession(
      id: j.id,
      title: j.prompt,
      relativeTime: _ago(j.created),
      timestamp: j.created,
      summary: j.consensus.summary.isNotEmpty ? j.consensus.summary : firstEssence,
      modelIds: j.results.keys.toList(),
      messages: [
        TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
        if (j.consensus.summary.isNotEmpty) TickerMessage(id: '${j.id}_c', sender: 'model', text: j.consensus.summary, timestamp: j.created),
      ],
    );
  }

  /// Maps a server job onto the ticker: one colour-coded card per model, consensus pinned on top.
  void _applyJob(JobState j, {bool restored = false}) {
    _jobsById[j.id] = j;
    _currentJobId = j.id;
    _currentPrompt = j.prompt;
    _promptTime = j.created;
    final items = <TickerItem>[];
    j.results.forEach((mid, r) {
      final def = ModelRoster.byId(mid);
      if (def == null) return;
      // A model that failed simply has no card (row 15): no error text.
      if (r.status == 'error') return;
      final prev = _tickerItems.where((t) => t.modelDef.id == mid).toList();
      final waiting = r.status == 'pending';
      items.add(TickerItem(
        modelDef: def,
        relativeTime: restored ? _ago(j.created) : 'just now',
        summary: r.essence.isNotEmpty ? r.essence : r.text.split('\n').first,
        isStreaming: waiting,
        conversation: prev.isNotEmpty && prev.first.isIsolated
            ? prev.first.conversation
            : [
                TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
                if (r.text.isNotEmpty) TickerMessage(id: '${j.id}_$mid', sender: 'model', text: r.text, timestamp: j.created),
              ],
      ));
    });
    _tickerItems = items;
    if (j.sources.isNotEmpty) {
      _browserTabs = [
        _browserTabs.first,
        for (var i = 0; i < j.sources.length; i++)
          BrowserTab(
            id: 'src_$i',
            title: '${j.sources[i]['title'] ?? ''}',
            url: '${j.sources[i]['url'] ?? ''}',
            isModelAssigned: true,
            modelName: 'Source ${i + 1}',
          ),
      ];
    }
    if (restored) {
      _selByCat[ModelCategory.general] = j.results.keys.where((k) => ModelRoster.byId(k) != null).toList();
    }
    final c = j.consensus;
    _isConsensusGenerating = !j.done;
    _consensusRatio = c.status == 'done' && c.score.isNotEmpty ? c.score : 'Consensus';
    _consensusSummary = c.summary;
  }

  void _initializeHistorySessions() {
    _globalHistorySessions = [];
    _localHistorySessions = {};
  }

  void _initializeBrowserTabs() {
    // One user tab; research sources are added as tabs when a question uses the web.
    _browserTabs = [
      BrowserTab(id: 'user_default', title: 'Search', url: 'https://html.duckduckgo.com/html/', isUserControlling: true),
    ];
  }

  void _closeAllPanes() {
    _activeDrawer = null;
    _localHistoryModel = null;
    _zoomedMessage = null;
    _zoomedModelDef = null;
    _isMobileSideNavOpen = false;
  }

  void _requestSwitchSurface(String? targetDrawer) {
    // No "Unsaved Changes" prompt (removed 2026-09-27): switching surfaces just proceeds.
    // Drafts and inputs are kept in memory as before.
    _proceedSwitchSurface(targetDrawer);
  }

  void _proceedSwitchSurface(String? targetDrawer) {
    setState(() {
      _closeAllPanes();
      _activeDrawer = targetDrawer;
      _isComposerSummoned = (targetDrawer == null);
      if (targetDrawer == 'themes') {
        _savedThemeBeforePreview = _currentTheme;
      }
    });
  }

  void _openDrawer(String drawer) {
    _requestSwitchSurface(drawer);
  }

  void _openHomeComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = true;
    });
  }

  void _toggleComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = !_isComposerSummoned;
    });
  }

  void _newConversation() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = true;
    });
  }

  // One answer open at a time (row 15): tapping a card opens it in the
  // middle; tapping it again, or the pane's close button, closes it.
  void _onTogglePill(String id) {
    setState(() {
      if (_expandedModelIds.contains(id)) {
        _expandedModelIds.clear();
      } else {
        _expandedModelIds
          ..clear()
          ..add(id);
      }
    });
  }

  TickerItem? _openPill(List<TickerItem> pills) {
    for (final p in pills) {
      if (_expandedModelIds.contains(p.modelDef.id)) return p;
    }
    return null;
  }

  ModelPill _pill(TickerItem item, {required double elevation, bool pane = false, bool narrow = false}) => ModelPill(
        narrow: narrow,
        key: ValueKey('${pane ? 'pane' : 'card'}-${item.modelDef.id}'),
        item: item,
        pane: pane,
        elevation: elevation,
        isExpanded: _expandedModelIds.contains(item.modelDef.id),
        onToggleExpand: () => _onTogglePill(item.modelDef.id),
        onSendInlineReply: (reply) => _onSendInlineReply(item.modelDef.id, reply),
        onOpenBrowser: () => _openBrowserForTab(_browserTabs.length > 1 ? _browserTabs[1].id : 'user_default'),
        onTapMessage: (msg) => setState(() {
          _zoomedMessage = msg;
          _zoomedModelDef = item.modelDef;
        }),
        onOpenLocalHistory: () => setState(() => _localHistoryModel = item.modelDef),
      );

  Widget _buildTicker(List<TickerItem> pills, bool isMobile) {
    final open = _openPill(pills);
    Widget column() => EdgeFade(
          fadeHeight: 16,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < pills.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _pill(pills[i], elevation: pills.length <= 1 ? 1.0 : 1.0 - i / (pills.length - 1), narrow: open != null),
                ],
              ],
            ),
          ),
        );
    if (open == null) return column();
    final h = (MediaQuery.of(context).size.height * (_isComposerSummoned ? 0.62 : 0.52) - 120).clamp(220.0, 520.0);
    return SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: isMobile ? 124 : 200, child: column()),
          const SizedBox(width: 6),
          Expanded(child: _pill(open, elevation: 1, pane: true)),
        ],
      ),
    );
  }

  Future<void> _onSendInlineReply(String modelId, String text) async {
    final idx = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
    if (idx == -1 || text.trim().isEmpty) return;
    final now = DateTime.now();
    final before = _tickerItems[idx];
    setState(() {
      final cur = _tickerItems[idx];
      _tickerItems[idx] = cur.copyWith(
        isIsolated: true,
        isStreaming: true,
        conversation: [...cur.conversation, TickerMessage(id: 'u$now', sender: 'user', text: text, timestamp: now)],
      );
    });
    final conv = _tickerItems[idx].conversation;
    try {
      final r = await ColliderApi.instance.reply(
        model: modelId,
        mode: _mode,
        messages: [for (final m in conv) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text}],
      );
      if (!mounted) return;
      setState(() {
        final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
        if (i == -1) return;
        final cur = _tickerItems[i];
        _tickerItems[i] = cur.copyWith(
          isStreaming: false,
          relativeTime: 'just now',
          summary: r.essence,
          conversation: [...cur.conversation, TickerMessage(id: 'm${DateTime.now()}', sender: 'model', text: r.text, timestamp: DateTime.now())],
        );
      });
    } catch (_) {
      // No backend (e.g. static hosting, /api 404) or no answer: quietly put
      // the card back as it was (v8.3, D41). No error text, no spinner.
      if (!mounted) return;
      setState(() {
        final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
        if (i != -1) _tickerItems[i] = before;
      });
    }
  }

  /// Media send (source sendChat media routes): one generation per selected
  /// model with the category's settings. Runs that cannot happen fail
  /// quietly (D59); the board keeps the previous results.
  Future<void> _onSendMedia(String prompt) async {
    final cat = _activeCategory;
    final models = [for (final id in _selByCat[cat]!) if (ModelRoster.byId(id) != null) ModelRoster.byId(id)!];
    if (models.isEmpty) return;
    final settings = _genSettings[cat]!..fitTo(cat, models);
    final flags = settings.flags(cat);
    final runnable = models.where((m) => MediaGen.instance.hasCredentials(m.id)).toList();
    if (runnable.isEmpty) {
      _cannotRun(prompt);
      return;
    }
    final kind = switch (cat) { ModelCategory.video => 'video', ModelCategory.audio => 'audio', _ => 'image' };
    final now = DateTime.now();
    final prev = _mediaGens[cat];
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _mediaGens[cat] = [
        for (final m in runnable) MediaGeneration(model: m, kind: kind, prompt: prompt, basis: costOf(m, flags, prompt).basis, at: now, pending: true),
      ];
    });
    final refs = _genRefs[cat] ?? const [];
    await Future.wait([
      for (final m in runnable)
        MediaGen.instance.generate(m.id, prompt, flags, imageDataUris: refs).then((r) {
          if (!mounted) return;
          setState(() {
            final l = _mediaGens[cat]!;
            final i = l.indexWhere((g) => g.model.id == m.id && g.pending);
            if (i != -1) l[i] = l[i].done(r.url);
          });
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _mediaGens[cat]!.removeWhere((g) => g.model.id == m.id && g.pending));
        }),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_mediaGens[cat]!.isEmpty) {
        if (prev == null) {
          _mediaGens.remove(cat);
        } else {
          _mediaGens[cat] = prev;
        }
      }
    });
    if (!_mediaGens.containsKey(cat) || identical(_mediaGens[cat], prev)) _cannotRun(prompt);
  }

  /// No Collider server, but this build has a provider key: the source's own
  /// direct OpenRouter path (chat.ts callOpenRouter).
  Future<void> _onSendDirect(String prompt, List<String> models) async {
    final now = DateTime.now();
    final prevItems = _tickerItems;
    final prevPrompt = _currentPrompt;
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _closeAllPanes();
      _expandedModelIds.clear();
      _currentPrompt = prompt;
      _promptTime = now;
      _tickerItems = [
        for (final id in models)
          TickerItem(modelDef: ModelRoster.byId(id)!, relativeTime: '', summary: '', isStreaming: true, conversation: [TickerMessage(id: 'u$id', sender: 'user', text: prompt, timestamp: now)]),
      ];
    });
    await Future.wait([
      for (final id in models)
        MediaGen.instance.chat(id, [
          {'role': 'system', 'content': 'You are Collider, a concise, helpful assistant.'},
          {'role': 'user', 'content': prompt},
        ]).then((text) {
          if (!mounted) return;
          setState(() {
            final i = _tickerItems.indexWhere((t) => t.modelDef.id == id);
            if (i == -1) return;
            final cur = _tickerItems[i];
            _tickerItems[i] = cur.copyWith(isStreaming: false, relativeTime: 'just now', summary: text.split('\n').first,
                conversation: [...cur.conversation, TickerMessage(id: 'm$id', sender: 'model', text: text, timestamp: DateTime.now())]);
          });
        }).catchError((_) {
          if (mounted) setState(() => _tickerItems.removeWhere((t) => t.modelDef.id == id));
        }),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_tickerItems.isEmpty) {
        _tickerItems = prevItems;
        _currentPrompt = prevPrompt;
      }
    });
    if (identical(_tickerItems, prevItems)) _cannotRun(prompt);
  }

  Future<void> _onSendPrompt(String prompt, [List<String> files = const []]) async {
    if (_activeCategory.isMedia) return _onSendMedia(prompt);
    final models = _selectedModelIds.where((id) {
      final d = ModelRoster.byId(id);
      return d != null && !d.isMedia;
    }).toList();
    if (models.isEmpty) return;
    if (!ColliderApi.instance.online) {
      final direct = models.where((id) => MediaGen.instance.hasCredentials(id)).toList();
      if (direct.isNotEmpty) return _onSendDirect(prompt, direct);
      // Nothing can answer on this link: say so once, quietly (D59).
      _cannotRun(prompt);
      return;
    }
    final now = DateTime.now();
    // Restored as-is if there is no backend to answer (D41).
    final prevItems = _tickerItems;
    final prevPrompt = _currentPrompt;
    final prevTime = _promptTime;
    final prevRatio = _consensusRatio;
    final prevSummary = _consensusSummary;
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _closeAllPanes();
      _expandedModelIds.clear();
      _currentPrompt = prompt;
      _promptTime = now;
      _isConsensusGenerating = true;
      _consensusRatio = 'Consensus';
      _consensusSummary = '';
      _tickerItems = [
        for (final id in models)
          TickerItem(
            modelDef: ModelRoster.byId(id)!,
            relativeTime: '',
            summary: '',
            isStreaming: true,
            conversation: [TickerMessage(id: 'u$id', sender: 'user', text: prompt, timestamp: now)],
          ),
      ];
    });
    try {
      final id = await ColliderApi.instance.ask(prompt: prompt, models: models, mode: _mode, autosave: _autosave, incognito: _incognito);
      await for (final j in ColliderApi.instance.watch(id)) {
        if (!mounted) return;
        setState(() => _applyJob(j));
      }
      await _reloadHistory();
    } catch (_) {
      // No backend (static hosting: /api answers 404) or the server dropped:
      // fail quietly (v8.3, D41). The screen goes back to how it was, with
      // no error text and no spinner left running.
      if (!mounted) return;
      setState(() {
        _isConsensusGenerating = false;
        _tickerItems = prevItems;
        _currentPrompt = prevPrompt;
        _promptTime = prevTime;
        _consensusRatio = prevRatio;
        _consensusSummary = prevSummary;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Load conversation and immediately send user there in expanded view
  void _loadAndExpandSession(ConversationHistorySession session) {
    final jobId = session.id.split('_').first;
    if (_jobsById.containsKey(jobId)) {
      setState(() {
        _closeAllPanes();
        _tickerItems = [];
        _applyJob(_jobsById[jobId]!, restored: true);
        _expandedModelIds.clear();
        if (session.targetModelId != null) _expandedModelIds.add(session.targetModelId!);
      });
      return;
    }
    setState(() {
      _activeDrawer = null;
      _localHistoryModel = null;
      _zoomedMessage = null;
      _isMobileSideNavOpen = false;

      final targetId = session.targetModelId ?? (session.modelIds.isNotEmpty ? session.modelIds.first : _selectedModelIds.first);
      
      // Ensure target model is in selected list so it appears in the active rows
      if (!_selectedModelIds.contains(targetId)) {
        _selectedModelIds.insert(0, targetId);
      }

      // Ensure active category matches target model's category
      final targetDef = ModelRoster.byId(targetId);
      if (targetDef != null && !targetDef.categories.contains(_activeCategory) && targetDef.categories.isNotEmpty) {
        _activeCategory = targetDef.categories.first;
      }

      final idx = _tickerItems.indexWhere((it) => it.modelDef.id == targetId);
      if (idx != -1) {
        _tickerItems[idx] = _tickerItems[idx].copyWith(
          conversation: session.messages,
          summary: session.summary,
          relativeTime: session.relativeTime,
        );
      }

      _expandedModelIds.clear();
      _expandedModelIds.add(targetId);
    });
  }

  bool _browserOpen = false;

  Future<void> _openBrowserForTab(String tabId) async {
    // The start page depends on whether the server answered (browser_urls.dart).
    await _booted.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    if (!mounted) return;
    setState(() {
      _activeDrawer = null;
      _browserOpen = true;
    });
    showDialog(
      context: context,
      // Row 10 (v8.3): a tap outside must not close the browser; only its
      // close control (or Escape) does.
      barrierDismissible: false,
      // v8.4: 1:71 shows the room undimmed behind the browser window.
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) {
        return InAppBrowserSheet(
          initialTabId: tabId,
          tabs: _browserTabs,
          onTabUpdated: (updated) {
            setState(() {
              final idx = _browserTabs.indexWhere((t) => t.id == updated.id);
              if (idx != -1) _browserTabs[idx] = updated;
            });
          },
          onNewUserTab: (newTab) {
            setState(() {
              _browserTabs.add(newTab);
            });
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _browserOpen = false);
    });
  }

  String? _railKey() {
    // REQ-21 visual language: a slim detached rail of circular glass buttons sits at
    // the screen edge; the contextual panel content opens beside it when summoned.
    final surface = _currentActiveSurface;
    final String? railKey = switch (surface) {
      ActiveWorkSurface.chat => _isMobileSideNavOpen ? _chatSection : null,
      ActiveWorkSurface.smartgen => _smartGenView,
      ActiveWorkSurface.market => _marketCategory,
      ActiveWorkSurface.themes => _activeDrawer == 'premium' ? 'premium' : (_activeDrawer == 'music' ? 'music' : 'gallery'),
      ActiveWorkSurface.browser => null,
      ActiveWorkSurface.files => _filesCategory,
    };

    return railKey;
  }

  void _togglePanel(void Function() apply, bool same) {
      setState(() {
        apply();
        _isMobileSideNavOpen = same ? !_isMobileSideNavOpen : true;
      });
  }


  void _onRailSelect(String key) {
    final surface = _currentActiveSurface;

    switch (surface) {
      case ActiveWorkSurface.chat:
        if (key == 'new') {
          setState(() => _isMobileSideNavOpen = false);
          _openHomeComposer();
        } else {
          _togglePanel(() => _chatSection = key, key == _chatSection);
        }
      case ActiveWorkSurface.smartgen:
        setState(() {
          _isMobileSideNavOpen = false;
          if (key != 'new') _smartGenView = key;
        });
      case ActiveWorkSurface.market:
        if (key == 'gallery') {
          _requestSwitchSurface('themes');
        } else {
          setState(() {
            _isMobileSideNavOpen = false;
            _marketCategory = key;
          });
        }
      case ActiveWorkSurface.themes:
        setState(() {
          _isMobileSideNavOpen = false;
          _themeSection = key;
          _activeDrawer = key == 'gallery' ? 'themes' : key;
        });
      case ActiveWorkSurface.browser:
        break;
      case ActiveWorkSurface.files:
        setState(() {
          _isMobileSideNavOpen = false;
          _filesCategory = key;
        });
    }
  }

  /// v8.4: the side tab bar is the Figma frame's own tab bar, at its own
  /// position and size in the frame of the screen it is on, scaled with it.
  RailSpec? _railSpec() {
    const wechat = (inset: Offset(14.6, 17.6), pitch: 69.0, tab: 44.0, bottomPad: 20.4);
    switch (_currentActiveSurface) {
      case ActiveWorkSurface.chat:
        if (_activeCategory.isMedia && (_mediaGens[_activeCategory]?.isNotEmpty ?? false)) {
          return (frame: Row13.frame, crop: Row13.cropWidth, center: Row13.center, rail: Row13.rail, inset: wechat.inset, pitch: wechat.pitch, tab: wechat.tab, bottomPad: wechat.bottomPad);
        }
        return (frame: Row15.frame, crop: Row15.cropWidth, center: Row15.center, rail: Row15.rail, inset: wechat.inset, pitch: wechat.pitch, tab: wechat.tab, bottomPad: wechat.bottomPad);
      default:
        return RailSpecs.of(_currentActiveSurface);
    }
  }

  Widget _buildRailLayer() {
    final spec = _railSpec();
    if (spec == null) return const SizedBox.shrink();
    final surface = _currentActiveSurface;
    final entries = sideRailEntries(surface);
    final key = _railKey();
    return FigmaStage(
      frame: spec.frame,
      cropWidth: spec.crop,
      center: spec.center,
      children: [
        Positioned(
          left: spec.rail.left,
          top: spec.rail.top,
          child: FRail(
            key: ValueKey(surface),
            width: spec.rail.width,
            tabInset: spec.inset,
            pitch: spec.pitch,
            tab: spec.tab,
            bottomPad: spec.bottomPad,
            iconSize: spec.tab * 0.55,
            icons: [for (final e in entries) e.icon],
            labels: [for (final e in entries) e.label],
            active: entries.indexWhere((e) => e.key == key),
            onSelect: (i) => _onRailSelect(entries[i].key),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaStage() => MediaStageContent(
        key: ValueKey('media-${_activeCategory.name}'),
        items: _mediaGens[_activeCategory]!,
        onRemix: (p) => _restoreText.value = p,
        onNotice: _notice,
        onOptions: () => setState(() => _genOptionsOpen = true),
      );

  Widget _buildSideNav({required bool isMobile}) {
    final surface = _currentActiveSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_isMobileSideNavOpen && surface == ActiveWorkSurface.chat) ...[
          const SizedBox(width: 10),
          ContextualSideNav(
            activeSurface: _currentActiveSurface,
            activeCategory: _activeCategory,
            selectedModelIds: _selectedModelIds,
            localHistory: _localHistorySessions,
            globalHistory: _globalHistorySessions,
            consensusRatio: _consensusRatio,
            consensusSummary: _consensusSummary,
            expandedModelId: _expandedModelIds.isNotEmpty ? _expandedModelIds.first : null,
            chatSection: _chatSection,
            onClose: () => setState(() => _isMobileSideNavOpen = false),
      onSelectCategory: (cat) => setState(() => _activeCategory = cat),
      onToggleModel: (modelId) {
        setState(() {
          if (_selectedModelIds.contains(modelId)) {
            if (_selectedModelIds.length > 1) {
              _selectedModelIds.remove(modelId);
            }
          } else {
            if (_selectedModelIds.length < 9) {
              _selectedModelIds.add(modelId);
            }
          }
        });
      },
      onSelectSession: (sess) => _loadAndExpandSession(sess),
      onOpenConsensus: () => _requestSwitchSurface('consensus'),
      onNewConversation: _openHomeComposer,
      activeSmartGenView: _smartGenView,
      activeSmartGenBoardType: _smartGenBoardType,
      onSelectSmartGenView: (v) => setState(() => _smartGenView = v),
      onSelectSmartGenBoardType: (b) => setState(() => _smartGenBoardType = b),
      activeMarketCategory: _marketCategory,
      onSelectMarketCategory: (c) => setState(() => _marketCategory = c),
      onMarketSearch: (q) => setState(() => _marketSearchQuery = q),
      activeThemeSection: _themeSection,
      onSelectThemeSection: (s) {
        setState(() {
          _themeSection = s;
          if (s == 'gallery') _activeDrawer = 'themes';
          else if (s == 'premium') _activeDrawer = 'premium';
          else if (s == 'music') _activeDrawer = 'music';
        });
      },
      browserTabs: _browserTabs,
      activeBrowserTabId: 'user_default',
      onCloseBrowserTab: (id) => setState(() => _browserTabs.removeWhere((t) => t.id == id)),
      onClearBrowserCache: () {},
      activeFilesCategory: _filesCategory,
      onSelectFilesCategory: (c) => setState(() => _filesCategory = c),
      onRequestSwitchSurface: (surface) {
        final target = switch (surface) {
          ActiveWorkSurface.chat => null,
          ActiveWorkSurface.smartgen => 'smartgen',
          ActiveWorkSurface.market => 'market',
          ActiveWorkSurface.themes => 'themes',
          ActiveWorkSurface.browser => null,
          ActiveWorkSurface.files => 'files',
        };
        _requestSwitchSurface(target);
      },
      onPaneInteraction: () {},
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Max 9 active model rows filtered by active category with fallback
    var categoryPills = _tickerItems
        .where((it) => it.modelDef.categories.contains(_activeCategory) && _selectedModelIds.contains(it.modelDef.id))
        .take(9)
        .toList();

    if (categoryPills.isEmpty) {
      categoryPills = _tickerItems
          .where((it) => it.modelDef.categories.contains(_activeCategory))
          .take(9)
          .toList();
    }

    final activePills = categoryPills;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ================= PLANE 0: BACKGROUND WALLPAPER & AMBIENT PARTICLES =================
          // Not built under the Premium Theme Market: the market paints its own
          // opaque #000 -> #111 root and its own ambient loop over the whole
          // viewport, so Plane 0 and the stardust were invisible there while
          // still decoding a full-bleed still on every swipe and forcing a
          // Flutter frame every vsync (stardust ticker) during idle playback.
          if (_activeDrawer != 'premium') ...[
          Positioned.fill(
            child: ThemeLivingBackdrop(
              key: ValueKey('live-${_currentTheme.id}-${_currentTheme.videoPath ?? _currentTheme.assetPath}-${_activeDrawer == 'premium' ? 'ambient' : 'live'}'),
              theme: _currentTheme,
              // Asset-swap: live loop + Builder BackgroundVideo filter when Premium Market
              // (supersedes prior H6 sharp-tint / preferVideo:false)
              // The premium market renders its own ambient loop of the focused theme;
              // Plane 0 stays on the poster there so only one stream is open.
              // The Theme Gallery paints its own room and preview (row 6).
              preferVideo: _activeDrawer != 'premium' && _activeDrawer != 'themes',
              builderAmbient: _activeDrawer == 'premium',
            ),
          ),

          // Ambient drifting stardust particles in Plane 0
          const Positioned.fill(
            child: IgnorePointer(
              child: LivingStardustOverlay(),
            ),
          ),
          ],

          // Base ambient dim. Overlays and work surfaces bring their own VScrim
          // (kit overlay 0.35 + medium blur) so the wallpaper stays visible;
          // the theme gallery keeps a light tint.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: Colors.black.withOpacity(
                _activeDrawer == 'themes' ? 0.10 : 0.0,
              ),
            ),
          ),
          // ================= PLANE 1: RESTING WORKSPACE =================
          // v8.4 scaled-frame method: the model ticker is wechat CHAT 2013:75
          // at its own size, scaled as one unit (map row 15).
          if (!_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'music'}.contains(_activeDrawer) && !_activeCategory.isMedia && activePills.isNotEmpty)
            Positioned.fill(
              child: Builder(builder: (context) {
                final open = _openPill(activePills);
                return FigmaStage(
                  frame: Row15.frame,
                  cropWidth: Row15.cropWidth,
                  center: Row15.center,
                  children: [
                    // "Chat" window title 59:464 (643,282).
                    const Positioned(left: 643, top: 282, child: FText('Answers', size: 28, height: 33, weight: FontWeight.w700)),
                    Positioned.fromRect(
                      rect: Row15.leftWin,
                      child: TickerColumnWindow(
                        items: activePills,
                        openId: open?.modelDef.id,
                        joined: open != null,
                        onOpen: _onTogglePill,
                        consensusTitle: _consensusRatio.contains('Consensus') ? _consensusRatio : '$_consensusRatio Consensus',
                        consensusLine: _isConsensusGenerating ? 'Comparing answers' : _consensusSummary,
                        onConsensus: () => setState(() => _activeDrawer = 'consensus'),
                      ),
                    ),
                    if (open != null)
                      Positioned(
                        left: Row15.midWin.left,
                        top: Row15.midWin.top,
                        width: 791,
                        height: 739,
                        child: TickerAnswerWindow(
                          key: ValueKey('answer-${open.modelDef.id}'),
                          item: open,
                          onClose: () => _onTogglePill(open.modelDef.id),
                          onReply: (t) => _onSendInlineReply(open.modelDef.id, t),
                          onTapMessage: (msg) => setState(() {
                            _zoomedMessage = msg;
                            _zoomedModelDef = open.modelDef;
                          }),
                        ),
                      ),
                  ],
                );
              }),
            ),
          // Map row 13: the media ticker (wechat IMAGE 2013:71) at its own size.
          if (!_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'music'}.contains(_activeDrawer) && _activeCategory.isMedia && (_mediaGens[_activeCategory]?.isNotEmpty ?? false))
            Positioned.fill(child: _buildMediaStage()),

          // Map row 8: the composer (Figma 1-240, 760 x 116) scaled as one unit
          // to the device width, its bottom edge on the dock's top (74 px).
          if (!_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'music'}.contains(_activeDrawer))
            Positioned(
              left: 0,
              right: 0,
              bottom: 74,
              child:
              FloatingPrompt(
                summoned: _isComposerSummoned,
                busy: _busy,
                onSubmitPrompt: (text, files) => _onSendPrompt(text, files),
                onSummon: () => setState(() {
                  _closeAllPanes();
                  _isComposerSummoned = true;
                }),
                onTuck: () => setState(() => _isComposerSummoned = false),
                mode: _mode,
                onMode: (m) => setState(() => _mode = m),
                private: _incognito,
                onPrivate: (v) => setState(() => _incognito = v),
                offline: _apiChecked && !ColliderApi.instance.online,
                category: _activeCategory,
                onCategory: (c) => setState(() => _activeCategory = c),
                onOpenOptions: () => setState(() => _genOptionsOpen = true),
                restoreText: _restoreText,
                generateTick: _generateTick,
              ),
            ),

          // ================= PLANE 2: APPS POPUP PANE =================
          // Middle neutral area, no visible canvas, blurred background, clickaway + close icon
          if (_activeDrawer == 'apps')
            Positioned.fill(
              child: AppsPopupPane(
                onClose: () => setState(() => _activeDrawer = null),
                onOpenSmartGen: () => _requestSwitchSurface('smartgen'),
                onOpenDiscoverMarket: () => _requestSwitchSurface('market'),
                onOpenThemeGallery: () => _requestSwitchSurface('themes'),
                onOpenPremiumMarketplace: () => _requestSwitchSurface('premium'),
                onOpenFiles: () => _requestSwitchSurface('files'),
                onOpenMusicPlayer: () => _requestSwitchSurface('music'),
                onOpenBrowser: () => _openBrowserForTab('user_default'),
                onOpenSettings: () => _openDrawer('settings'),
                onOpenAccount: () => setState(() => _activeDrawer = 'account'),
              ),
            ),

          // ================= PLANE 3: LOCAL MODEL HISTORY PANE =================
          // Centered popup pane, searches body & title, relative timestamps
          if (_localHistoryModel != null)
            Positioned.fill(
              child: LocalHistoryPane(
                modelDef: _localHistoryModel!,
                // Real history only (D30): no invented fallback session.
                sessions: _localHistorySessions[_localHistoryModel!.id] ?? const [],
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _localHistoryModel = null),
              ),
            ),

          // ================= PLANE 4: MESSAGE ZOOM OVERLAY =================
          // Dimmed/blurred backdrop, no visible window, faded edges, bottom actions
          if (_zoomedMessage != null && _zoomedModelDef != null)
            Positioned.fill(
              child: MessageZoomOverlay(
                message: _zoomedMessage!,
                modelName: _zoomedModelDef!.label,
                providerColor: _zoomedModelDef!.providerColor,
                onClose: () => setState(() => _zoomedMessage = null),
                onBranchIsolated: () {
                  _onSendInlineReply(_zoomedModelDef!.id, "Branched branch from zoomed message.");
                },
              ),
            ),

          // ================= PLANE 5: DRAWERS & DURABLE WORK SURFACES =================
          if (_activeDrawer == 'history')
            Positioned.fill(
              child: HistoryDrawer(
                sessions: _globalHistorySessions,
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'model_ladder')
            Positioned.fill(
              child: ModelLadderDrawer(
                activeCategory: _activeCategory,
                selectedModelIds: _selectedModelIds,
                onSelectCategory: (cat) {
                  setState(() {
                    _activeCategory = cat;
                  });
                },
                onToggleModel: (modelId) {
                  setState(() {
                    if (_selectedModelIds.contains(modelId)) {
                      if (_selectedModelIds.length > 1) {
                        _selectedModelIds.remove(modelId);
                      }
                    } else {
                      if (_selectedModelIds.length < 9) {
                        _selectedModelIds.add(modelId);
                      }
                    }
                  });
                },
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'themes')
            Positioned.fill(
              child: WindowlessThemeScroller(
                currentTheme: _currentTheme,
                onLivePreview: (theme) => setState(() => _currentTheme = theme),
                onConfirmTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onCancel: () => setState(() {
                  _currentTheme = _savedThemeBeforePreview;
                  _activeDrawer = null;
                }),
                onUpgradeTier: () => setState(() => _activeDrawer = 'premium'),
              ),
            ),

          if (_activeDrawer == 'premium')
            Positioned.fill(
              // Swipe down returns to the free Theme Gallery.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300) setState(() => _activeDrawer = 'themes');
                },
                // v8.4: row 4 (417:1777) while the music widget is on (or
                // ?market=alt), else row 1 laid out at Figma 1:3's own width
                // (401.48) and scaled.
                child: ValueListenableBuilder<bool>(
                  valueListenable: FloatingMusic.enabled,
                  builder: (context, musicOn, _) => (musicOn || Uri.base.queryParameters['market'] == 'alt')
                      ? PremiumMarketAltView(
                          currentTheme: _currentTheme,
                          onApplyTheme: (theme) => setState(() {
                            _currentTheme = theme;
                            _savedThemeBeforePreview = theme;
                            _activeDrawer = null;
                          }),
                          onPreviewTheme: (theme) {
                            ThemeMediaPrefetch.precacheNeighbors(context, WallpaperCatalog.premiumThemes, theme);
                            setState(() => _currentTheme = theme);
                          },
                          onClose: () => setState(() => _activeDrawer = null),
                          onOpenMusic: () => _openDrawer('music'),
                        )
                      : FigmaViewport(width: 401.48, child: PremiumThemeMarketView(
                currentTheme: _currentTheme,
                onApplyTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onPreviewTheme: (theme) {
                  // Only the focused theme streams video; warm neighbour posters.
                  ThemeMediaPrefetch.precacheNeighbors(context, WallpaperCatalog.premiumThemes, theme);
                  setState(() {
                    _currentTheme = theme;
                  });
                },
                onClose: () => setState(() => _activeDrawer = null),
              )),
                ),
              ),
            ),

          // No songs in the catalog: no Music drawer (v8.3, D46).
          if (_activeDrawer == 'music' && MusicPlayer.library.isNotEmpty)
            Positioned.fill(
              child: MusicCollectionDrawer(
                onClose: () => setState(() => _activeDrawer = null),
                onOpenMarket: () => setState(() => _activeDrawer = 'premium'),
                onOpenAccount: () => setState(() => _activeDrawer = 'account'),
                onOpenSettings: () => setState(() => _activeDrawer = 'settings'),
              ),
            ),

          if (_activeDrawer == 'settings')
            Positioned.fill(
              child: SettingsDrawer(
                onClose: () => setState(() => _activeDrawer = null),
                incognito: _incognito,
                autosave: _autosave,
                onIncognito: (v) => setState(() => _incognito = v),
                onAutosave: (v) => setState(() => _autosave = v),
                onAccount: () => setState(() => _activeDrawer = 'account'),
              ),
            ),

          if (_activeDrawer == 'account')
            Positioned.fill(
              child: AccountSheet(tier: ModelTier.free, onClose: () => setState(() => _activeDrawer = null)),
            ),

          // Durable work surfaces sit over one shared scrim (kit overlay + medium blur).

          if (_activeDrawer == 'smartgen')
            // v8.4: the Keynote frame (30:75) is a stage on the whole screen.
            Positioned.fill(
              child: SmartGenScreen(
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          // v8.4: Market is Figma 203:5891 scaled as one unit (FigmaStage).
          if (_activeDrawer == 'market')
            Positioned.fill(
              child: MarketScreen(
                onClose: () => _requestSwitchSurface(null),
                onUsePrompt: (p) => _onSendPrompt(p),
                onNotice: _notice,
                view: _marketCategory,
                generated: [
                  for (final g in (_mediaGens[ModelCategory.image] ?? const <MediaGeneration>[]))
                    if (g.url != null) (g.prompt, g.url!),
                ],
                onRemix: (p) {
                  _requestSwitchSurface(null);
                  setState(() => _activeCategory = ModelCategory.image);
                  _restoreText.value = p;
                },
              ),
            ),

          // v8.2 round 3 (D31): the Tiers screen (invented prices, dead
          // upgrade buttons) and the Skills screen (toggles wired to nothing)
          // were reachable only by deep link; both are deleted.

          // Map row 7: Files 71:7502 at its own size, scaled as one unit.
          if (_activeDrawer == 'files')
            Positioned.fill(
              child: FilesScreen(
                category: _filesCategory,
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'consensus')
            Positioned.fill(
              // The app shell bar stays on every screen (requirement 7).
              bottom: isMobile ? 78 : 0,
              child: ConsensusWebView(
                job: _currentJobId == null ? null : _jobsById[_currentJobId],
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          // Map row 17: generation options for the active media category.
          if (_genOptionsOpen && _activeCategory.isMedia && _activeDrawer == null)
            Positioned.fill(
              child: GenOptionsSheet(
                category: _activeCategory,
                models: [for (final id in _selectedModelIds) if (ModelRoster.byId(id) != null) ModelRoster.byId(id)!],
                settings: _genSettings[_activeCategory]!,
                references: _genRefs[_activeCategory] ?? const [],
                onReferences: (r) => setState(() => _genRefs[_activeCategory] = r),
                previewUrl: _mediaGens[_activeCategory]?.where((g) => g.url != null).firstOrNull?.url,
                posterFallback: _currentTheme.stillPath ?? _currentTheme.assetPath,
                onChanged: () => setState(() {}),
                onGenerate: () => setState(() {
                  _genOptionsOpen = false;
                  _isComposerSummoned = true;
                  _generateTick.value++;
                }),
                onClose: () => setState(() => _genOptionsOpen = false),
              ),
            ),

          // ================= PLANE 3: CONTEXTUAL SIDE NAV =================
          if (_isMobileSideNavOpen && _railVisible)
            Positioned.fill(
              child: VScrim(onTap: () => setState(() => _isMobileSideNavOpen = false)),
            ),
          // The tab bar ornament: the screen's own Figma tab bar (v8.4).
          if (_railVisible) Positioned.fill(child: _buildRailLayer()),
          if (_railVisible && _isMobileSideNavOpen && _currentActiveSurface == ActiveWorkSurface.chat)
            Positioned(
              left: 10,
              bottom: 84,
              child: _buildSideNav(isMobile: isMobile),
            ),

          // ================= MUSIC WIDGET: the one instance =================
          // v8.3 (DEVIATIONS.md D38): shown only while switched on in Settings;
          // own layer + own drag state; pinned wherever the user puts it
          // inside the safe area above the bar; position persisted.
          Positioned.fill(
              // Keyed: the conditional layers before it come and go, and the
              // widget's expanded / drag state must survive that.
              key: const ValueKey('floating-music'),
              child: FloatingMusic(
                overMarket: _activeDrawer == 'premium',
                // Full-screen focused surfaces own the screen (D26).
                // Row 4: over the market the widget is docked as the frame's play bar.
                hidden: const {'music', 'consensus', 'premium'}.contains(_activeDrawer) ||
                    _zoomedMessage != null ||
                    _localHistoryModel != null,
                onOpenCollection: () => _openDrawer('music'),
              ),
            ),

          // ================= PLANE 4: PERMANENT BOTTOM DOCK =================
          // Shown on every screen, the Premium Theme Market included (the market
          // reserves its height; see PremiumThemeMarketView.bottomBarReserve).
          // Hidden on phone widths while consensus is open: the scene has its own back control.
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Center(
                child: PermanentNavBar(
                  isComposerSummoned: _isComposerSummoned,
                  onToggleComposer: _toggleComposer,
                  onHome: () {
                    if (_activeDrawer != null) {
                      _requestSwitchSurface(null);
                    } else {
                      _openHomeComposer();
                    }
                  },
                  onApps: () => _openDrawer('apps'),
                  onSettings: () => _openDrawer('settings'),
                  activeDrawer: _activeDrawer,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

