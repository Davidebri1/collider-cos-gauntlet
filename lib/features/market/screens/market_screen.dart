import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/figma/figma_stage.dart';
import '../../../models/theme_def.dart';
import '../../mediagen/media_view.dart';
import '../../theme/theme_living_media.dart';

/// Discover Market (map row 21, Video Platforms on visionOS 203:5891), with
/// the source's content and behaviour (screens/MarketScreen.tsx): the hero
/// is the featured theme still, the shelf and the photographic grid are the
/// catalog's stills (PHOTO_SEED), the kinds are the source's Stills /
/// Templates / Cinematic / Night as the bottom tab ornament, a tile opens
/// full size with Remix, and the market's own composer generates an image
/// with the source's keyless FLUX route. v8.3: the invented prompt cards
/// (Term Life Plan, Heat Pump Sizing, Family Recipes; not in the source)
/// are gone. The source's Supabase feed is dead (D62), so the market shows
/// the catalog stills and this session's own generations.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String prompt) onUsePrompt;
  /// One quiet line (e.g. a generation that cannot run on this link).
  final void Function(String text)? onNotice;

  /// Remix: the title goes into the app composer as an image prompt.
  final ValueChanged<String>? onRemix;
  /// Rail selection: 'discover' | 'search' | 'mine'.
  final String view;
  /// The session's finished image generations as (prompt, url).
  final List<(String, String)> generated;

  const MarketScreen({super.key, required this.onClose, required this.onUsePrompt, this.onNotice, this.onRemix, this.view = 'discover', this.generated = const []});

  // Video Platforms on visionOS 203:5891 (2610 x 1468): rail 290:4411 at
  // 569 .. window right 1945, no extra margin.
  static const frame = Size(2610, 1468);
  static const cropWidth = 1376.0;
  static const center = Offset(1257, 734);

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _Tile {
  final String id;
  final String title;
  final String src; // theme media path or data: URI
  final bool generated;
  const _Tile(this.id, this.title, this.src, {this.generated = false});
}

class _MarketScreenState extends State<MarketScreen> {
  static const _kinds = ['Stills', 'Templates', 'Cinematic', 'Night'];
  int _kind = 0;
  String _query = '';
  /// This session's image generations (title = prompt), newest first.
  List<_Tile> get _generated => [
        for (var i = 0; i < widget.generated.length; i++) _Tile('gen_$i', widget.generated[i].$1, widget.generated[i].$2, generated: true),
      ];
  _Tile? _open;


  /// MarketScreen.tsx PHOTO_SEED: the catalog's stills, preferred ids first.
  List<_Tile> _seed() {
    const prefer = ['twilight', 'sanctuary', 'blade', 'cabin', 'transit', 'alley4', 'alley3', 'ocean', 'garden', 'neoncity', 'observatory', 'rainfall', 'dunehall', 'starbridge', 'twinsuns', 'deck'];
    final themes = WallpaperCatalog.freeThemes;
    final out = <_Tile>[];
    final seen = <String>{};
    for (final id in prefer) {
      for (final t in themes) {
        if (t.id.toLowerCase().contains(id) && seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath));
      }
    }
    for (final t in themes) {
      if (out.length >= 18) break;
      if (seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath));
    }
    return out;
  }

  List<_Tile> _masonry(List<_Tile> seed) {
    final merged = [..._generated, ...seed];
    return switch (_kinds[_kind]) {
      'Templates' => merged.take(10).toList(),
      'Cinematic' => [for (var i = 0; i < merged.length; i++) if (i % 2 == 0) merged[i]],
      'Night' => [for (var i = 0; i < merged.length; i++) if (i % 3 != 1) merged[i]],
      _ => merged,
    };
  }

  Widget _img(_Tile t, {BoxFit fit = BoxFit.cover}) =>
      t.generated ? GenMediaView(url: t.src, kind: 'image', fit: fit) : ThemeImage(t.src, fit: fit);

  static const _shadowGlass = [Color(0x1AFFFFFF), Color(0x2E5E5E5E)];

  Widget _pillButton(String label, IconData icon, VoidCallback onTap, {double? width, double fillA = 0.1}) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: width,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: Color.alphaBlend(_shadowGlass[1], Colors.white.withOpacity(fillA)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 24, color: const Color(0xF5FFFFFF)),
              const SizedBox(width: 6),
              FText(label, size: 19, height: 24, weight: FontWeight.w600, color: const Color(0xF5FFFFFF)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final seed = _seed();
    if (seed.isEmpty && _generated.isEmpty) return const SizedBox.shrink();
    final featured = seed.firstWhere((t) => RegExp('neon|alley4|blade|sanctuary', caseSensitive: false).hasMatch(t.id + t.title), orElse: () => seed.isNotEmpty ? seed.first : _generated.first);
    final q = widget.view == 'search' ? _query.trim().toLowerCase() : '';
    var shelf = _masonry(seed).where((t) => t.id != featured.id).toList();
    if (widget.view == 'mine') shelf = List.of(_generated);
    if (q.isNotEmpty) shelf = shelf.where((t) => t.title.toLowerCase().contains(q)).toList();
    return Stack(
      children: [
        FigmaStage(
          frame: MarketScreen.frame,
          cropWidth: MarketScreen.cropWidth,
          center: MarketScreen.center,
          children: [
            // Window_home 224:2314 at (665, 374), 1280 x 720.
            Positioned(left: 665, top: 374, width: 1280, height: 720, child: _window(featured, shelf)),
            // Controls > Bar (tabs) at (890, 1060), 830 x 68 -> the kinds.
            Positioned(
              left: 890,
              top: 1060,
              width: 830,
              height: 68,
              child: Center(
                child: FGlass(
                  radius: BorderRadius.circular(34),
                  stroke: const Color(0x66FFFFFF),
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < _kinds.length; i++)
                      Semantics(
                        button: true,
                        selected: _kind == i,
                        label: _kinds[i],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _kind = i),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: _kind == i ? BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(22)) : null,
                            child: FText(_kinds[i], size: 19, height: 24, weight: FontWeight.w600, opacity: _kind == i ? 1 : 0.6),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            // Window Controls (666, 1128): dot = close, bar = swipe down to close.
            Positioned(
              left: 1214,
              top: 1134,
              width: 181,
              height: 26,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 200) widget.onClose();
                  },
                  child: Container(width: 129, height: 12, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(6))),
                ),
              ]),
            ),
          ],
        ),
        if (_open != null) Positioned.fill(child: _exploder(_open!)),
      ],
    );
  }

  Widget _window(_Tile featured, List<_Tile> shelf) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(46), border: Border.all(color: const Color(0x66FFFFFF))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(46),
        child: Stack(children: [
          // Cover fills the window; the hero shows its top 440 px.
          Positioned.fill(child: _img(featured)),
          // gradientCover_left (670 wide) / gradientCover_right (180 wide).
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 670,
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x00000000)]))),
          ),
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 180,
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x00000000), Color(0x66000000)]))),
          ),
          // Window blur cover (y 439 .. 720): the cover blurred under black.
          Positioned(
            left: 0,
            right: 0,
            top: 439,
            bottom: 0,
            child: FGlass(
              blur: 100,
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99100B04), Color(0xE6100B04)]),
            ),
          ),
          // Content_Text+button at (90, 86).
          Positioned(
            left: 90,
            top: 86,
            width: 700,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 437,
                height: 140,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 387,
                    height: 124,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: FText(featured.title, size: 64, weight: FontWeight.w800, maxLines: 2, ellipsis: false),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FText(featured.generated ? 'Your generation' : 'Featured still', size: 30, weight: FontWeight.w600, color: const Color(0xF5FFFFFF)),
              ),
              const SizedBox(height: 30),
              Row(children: [
                _pillButton('Open', Icons.play_arrow_rounded, () => setState(() => _open = featured), width: 182),
                const SizedBox(width: 10),
                _pillButton('Remix', Icons.tune_rounded, () => _remix(featured), fillA: 0.02),
              ]),
            ]),
          ),
          // Other 143:4095: label + covers, bottom 50, padding 60 (+10 text).
          Positioned(
            left: 60,
            right: 0,
            bottom: 50,
            height: 209,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: widget.view == 'search'
                    ? SizedBox(
                        width: 600,
                        height: 31,
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          cursorColor: Colors.white,
                          style: GoogleFonts.inter(fontSize: 26, height: 31 / 26, color: Colors.white),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search',
                            hintStyle: GoogleFonts.inter(fontSize: 26, height: 31 / 26, color: Colors.white.withOpacity(0.4)),
                          ),
                        ),
                      )
                    : FText(widget.view == 'mine' ? 'My Generations' : _kinds[_kind], size: 26, height: 31),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 60),
                  itemCount: shelf.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 20),
                  itemBuilder: (_, i) {
                    final first = i == 0;
                    final w = first ? 240.0 : 220.0, h = first ? 160.0 : 146.0;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Semantics(
                        button: true,
                        label: shelf[i].title,
                        child: GestureDetector(
                          onTap: () => setState(() => _open = shelf[i]),
                          child: Container(
                            width: w,
                            height: h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(first ? 18 : 16),
                              border: Border.all(color: first ? Colors.white : const Color(0x66FFFFFF)),
                              boxShadow: first ? const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 8), blurRadius: 30)] : null,
                            ),
                            child: ClipRRect(borderRadius: BorderRadius.circular(first ? 17 : 15), child: _img(shelf[i])),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _remix(_Tile t) {
    // MarketScreen.tsx onRemix: the item's prompt goes into the composer
    // (v8.4: the app's composer; Figma 203:5891 has no market composer).
    setState(() => _open = null);
    widget.onRemix?.call(t.title);
  }

  /// MediaExploder: the asset full size over a blurred scrim, with Remix.
  Widget _exploder(_Tile t) {
    return Stack(fit: StackFit.expand, children: [
      VScrim(onTap: () => setState(() => _open = null)),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.md, 56, VSpace.md, 96),
          child: Column(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.card), child: _img(t, fit: BoxFit.contain))),
            const SizedBox(height: VSpace.sm),
            VGlass(
              material: VMaterial.elevated,
              radius: VRadius.full,
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                VCircleButton(icon: Icons.tune_rounded, size: 44, tooltip: 'Remix', onTap: () => _remix(t)),
                VCircleButton(icon: Icons.close_rounded, size: 44, tooltip: 'Close', onTap: () => setState(() => _open = null)),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
