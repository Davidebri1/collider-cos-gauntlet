import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/vision/vision_kit.dart';
import '../models/browser_tab.dart';
import '../browser_urls.dart';
import '../web_frame.dart';

/// REQ-07 Durable In-App Browser (Apple VisionOS Apps Basic Design System
/// 1:71 "Safari"): the address bar floats as a capsule ornament above the
/// page window. One browser instance; tabs overview replaces the page.
class InAppBrowserSheet extends StatefulWidget {
  final String initialTabId;
  final List<BrowserTab> tabs;
  final Function(BrowserTab updatedTab)? onTabUpdated;
  final Function(BrowserTab newTab)? onNewUserTab;

  const InAppBrowserSheet({
    super.key,
    required this.initialTabId,
    required this.tabs,
    this.onTabUpdated,
    this.onNewUserTab,
  });

  @override
  State<InAppBrowserSheet> createState() => _InAppBrowserSheetState();
}

class _InAppBrowserSheetState extends State<InAppBrowserSheet> {
  late String _activeTabId;
  bool _overview = false;
  final TextEditingController _addr = TextEditingController();
  final Map<String, List<String>> _back = {};
  int _reload = 0;
  String? _shownUrl;

  BrowserTab get _tab => widget.tabs.firstWhere((t) => t.id == _activeTabId, orElse: () => widget.tabs.first);

  @override
  void initState() {
    super.initState();
    _activeTabId = widget.initialTabId;
  }

  void _switchTab(String id) => setState(() {
        _activeTabId = id;
        _overview = false;
      });

  void _newTab() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Tab',
      url: browserStartUrl(),
      isModelAssigned: false,
      isUserControlling: true,
    );
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  String _host(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

  /// Address bar: a web address opens directly; anything else is searched.
  void _go(String input) {
    final q = input.trim();
    if (q.isEmpty) return;
    final isUrl = !q.contains(' ') && (q.contains('.') || q.startsWith('http'));
    final url = isUrl ? (q.startsWith('http') ? q : 'https://$q') : browserSearchUrl(q);
    final tab = _tab;
    (_back[tab.id] ??= []).add(tab.url);
    widget.onTabUpdated?.call(tab.copyWith(url: url, title: isUrl ? _host(url) : q));
    setState(() => _overview = false);
  }

  // ── Figma TRee 1:71 "Safari VisionOS" (frame 3840 x 2160) ───────────────
  // Group at (1280, 593), 1280 wide, column gap 40:
  //   toolbar 1280 x 80, radius 44, px 10, gap 48, glass rgba(128,128,128,.3)
  //   blur 75, 1 px white .3 border; groups of three 60 px circles (white .3,
  //   gap 20); address field h 64, px 16, black .3, radius 32: aA 25 | lock 20
  //   + domain SF Medium 24 | reload 25.
  //   page 1280 x 853 at y 713, radius 40, 1 px white .3 border.
  // Added (not in 1:71): the visionOS window bar under the page (dot closes),
  // because the frame has no close control and the browser must close.
  static const _frame = Size(3840, 2160);
  static const double _crop = 1280;
  static const Offset _center = Offset(1920, 1109.5);
  final Map<String, List<String>> _fwd = {};
  double _zoom = 1;

  void _goForward() {
    final stack = _fwd[_tab.id];
    if (stack == null || stack.isEmpty) return;
    final next = stack.removeLast();
    (_back[_tab.id] ??= []).add(_tab.url);
    widget.onTabUpdated?.call(_tab.copyWith(url: next, title: _host(next)));
    setState(() {});
  }

  void _duplicate() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: _tab.title,
      url: _tab.url,
      isModelAssigned: false,
      isUserControlling: true,
    );
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _tab.url));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
  bool _copied = false;

  Widget _circle(IconData icon, String tip, VoidCallback? onTap, {bool on = false, double turns = 0}) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: on ? const Color(0x80FFFFFF) : const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(32)),
            alignment: Alignment.center,
            child: RotatedBox(quarterTurns: (turns * 4).round(), child: Icon(icon, size: 28, color: onTap == null ? Colors.white38 : Colors.white)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    if (_shownUrl != tab.url) {
      _shownUrl = tab.url;
      _addr.text = _host(tab.url).split('/').first;
    }
    final canBack = (_back[tab.id] ?? const []).isNotEmpty;
    final canFwd = (_fwd[tab.id] ?? const []).isNotEmpty;
    final k = MediaQuery.sizeOf(context).width / _crop;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: FigmaStage(frame: _frame, cropWidth: _crop, center: _center, children: [
            // Toolbar ornament.
            Positioned(
              left: 1280,
              top: 593,
              width: 1280,
              height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: (75 / 2 * k).clamp(0.0, 40.0), sigmaY: (75 / 2 * k).clamp(0.0, 40.0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x4D808080),
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
                    ),
                    child: Row(children: [
                      _circle(Icons.view_sidebar_outlined, 'Open Windows & Tabs', () => setState(() => _overview = !_overview), on: _overview),
                      const SizedBox(width: 20),
                      _circle(Icons.chevron_left_rounded, 'Back', canBack ? () {
                        final stack = _back[tab.id]!;
                        (_fwd[tab.id] ??= []).add(tab.url);
                        final prev = stack.removeLast();
                        widget.onTabUpdated?.call(tab.copyWith(url: prev, title: _host(prev)));
                        setState(() {});
                      } : null),
                      const SizedBox(width: 20),
                      _circle(Icons.chevron_right_rounded, 'Forward', canFwd ? _goForward : null),
                      const SizedBox(width: 48),
                      Expanded(
                        child: Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0x4D000000),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), offset: Offset(0, 1), blurRadius: 1)],
                          ),
                          child: Row(children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _zoom = _zoom >= 2 ? 1 : _zoom + 0.5),
                              child: SizedBox(
                                width: 32,
                                height: 64,
                                child: Center(child: Text('Aa', style: GoogleFonts.inter(fontSize: 25, color: Colors.white, decoration: TextDecoration.none))),
                              ),
                            ),
                            Expanded(
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.lock_rounded, size: 20, color: Color(0x99FFFFFF)),
                                const SizedBox(width: 8),
                                Flexible(
                                  // Width of the domain text + caret room (IntrinsicWidth
                                  // clipped the last letter).
                                  child: SizedBox(
                                    width: (TextPainter(
                                          text: TextSpan(text: _addr.text, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500)),
                                          textDirection: TextDirection.ltr,
                                        )..layout())
                                            .width +
                                        12,
                                    child: TextField(
                                      controller: _addr,
                                      textAlign: TextAlign.center,
                                      cursorColor: Colors.white,
                                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                                      textInputAction: TextInputAction.go,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      onSubmitted: (v) {
                                        _fwd[tab.id]?.clear();
                                        _go(v);
                                      },
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _reload++),
                              child: const SizedBox(width: 32, height: 64, child: Icon(Icons.refresh_rounded, size: 28, color: Colors.white)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 48),
                      _circle(_copied ? Icons.check_rounded : Icons.ios_share_rounded, _copied ? 'Link copied' : 'Copy link', _share),
                      const SizedBox(width: 20),
                      _circle(Icons.add_rounded, 'New Tab', _newTab),
                      const SizedBox(width: 20),
                      _circle(Icons.filter_none_rounded, 'Duplicate Tab', _duplicate, turns: 0.25),
                    ]),
                  ),
                ),
              ),
            ),
            // Page.
            Positioned(
              left: 1280,
              top: 713,
              width: 1280,
              height: 853,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(
                    color: const Color(0x4D808080),
                    child: AnimatedSwitcher(duration: VMotion.base, child: _overview ? _tabsOverview() : _page(tab)),
                  ),
                ),
              ),
            ),
            // Window bar (added; dot closes, bar swipes down to close).
            Positioned(
              left: 1768,
              top: 1602,
              width: 304,
              height: 24,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
                  ),
                ),
                const SizedBox(width: 40),
                GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
                  },
                  child: Container(width: 240, height: 20, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(10))),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _page(BrowserTab tab) {
    return KeyedSubtree(
      key: ValueKey('page-${tab.url}-$_reload-$_zoom'),
      child: WebFrame(key: ValueKey('${tab.url}#$_reload#$_zoom'), url: _reload == 0 ? tab.url : '${tab.url}${tab.url.contains('?') ? '&' : '?'}_r=$_reload', zoom: _zoom),
    );
  }

  Widget _tabsOverview() {
    return LayoutBuilder(
      key: const ValueKey('tabs'),
      builder: (context, c) {
        const cols = 4;
        return Padding(
          padding: const EdgeInsets.all(40),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.9),
            itemCount: widget.tabs.length,
            itemBuilder: (_, i) {
              final t = widget.tabs[i];
              return VTile(
                selected: t.id == _activeTabId,
                onTap: () => _switchTab(t.id),
                aspect: 4 / 3,
                title: t.title,
                subtitle: t.isModelAssigned ? (t.modelName ?? 'Model') : _host(t.url),
                media: Container(
                  color: VColors.fillCell,
                  child: Icon(t.isModelAssigned ? Icons.terminal_rounded : Icons.person_outline_rounded, size: 26, color: VColors.textSecondary),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
