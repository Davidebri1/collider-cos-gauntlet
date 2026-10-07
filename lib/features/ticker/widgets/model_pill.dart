import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/ticker_item.dart';
import '../../../core/files/file_store.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/media/theme_catalog.dart';
import '../../theme/theme_living_media.dart';

/// REQ-03 Multi-Model Response card (Vision OS Design System 417:6826 comment
/// card; WeChat visionOS 0:639 elevation). Avatar → model mark, bold name →
/// model name, timestamp → response time, message → the model's thesis,
/// reaction row → the per-model tools. Cards gain elevation as they rise.
/// v8.3 (map row 15, WeChat 0-639, D51): a [ModelPill] is either a collapsed
/// card in the left column (full model name, two lines of the answer) or,
/// with [pane], the opened answer in the middle with its own close button.
class ModelPill extends StatefulWidget {
  final TickerItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Function(String replyText)? onSendInlineReply;
  final VoidCallback? onOpenBrowser;
  final Function(TickerMessage message)? onTapMessage;
  final VoidCallback? onOpenLocalHistory;

  /// 0 = resting (bottom of the stack) … 1 = highest card.
  final double elevation;

  /// The opened answer (middle area) rather than a left-column card.
  final bool pane;

  /// A card in the narrow column beside an open answer: no time, one line.
  final bool narrow;

  const ModelPill({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onSendInlineReply,
    this.onOpenBrowser,
    this.onTapMessage,
    this.onOpenLocalHistory,
    this.elevation = 0,
    this.pane = false,
    this.narrow = false,
  });

  @override
  State<ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<ModelPill> {
  // Real theme posters (streamed + cached) stand in for generated media thumbs.
  static const List<String> _mediaSlugs = ['lantern-alley', 'copper-kiln', 'glasshouse-fog', 'tide-glass'];
  String _mediaPosterFor(int i) {
    final slug = _mediaSlugs[i % _mediaSlugs.length];
    return ThemeCatalog.instance.bySlug(slug)?.posterUrl ?? '${ThemeCatalog.mediaBaseUrl}themes/$slug/poster.webp';
  }

  final TextEditingController _inlineCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  String _searchFilter = '';
  final List<String> _attachedFiles = [];

  @override
  void dispose() {
    _inlineCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: VColors.glassDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      content: Text(text, style: VType.callout()),
    ));
  }

  void _submitInline() {
    final text = _inlineCtrl.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;
    widget.onSendInlineReply?.call(text);
    _inlineCtrl.clear();
    setState(() => _attachedFiles.clear());
  }

  Future<void> _pickLocalFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (res != null && res.files.isNotEmpty) {
        setState(() => _attachedFiles.addAll(res.files.map((f) => f.name)));
        final note = await FileStore.instance.addPicked(res.files, 'model'); // listed in Files (D22)
        if (!mounted) return;
        if (note != null) {
          await showVAlert(context, icon: Icons.error_outline_rounded, title: note, actions: const [VAlertChoice('OK')]);
        } else {
          _toast('Attached ${res.files.length} file(s)');
        }
      }
    } catch (_) {}
  }

  void _copyLastMessage() {
    if (widget.item.conversation.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.item.conversation.last.text));
    _toast('Copied ${widget.item.modelDef.label}');
  }

  @override
  Widget build(BuildContext context) => widget.pane ? _buildPane(context) : _buildCard(context);

  /// The opened answer: name and close on top, the tools, the whole
  /// conversation (fills the pane) and the reply field for this model.
  Widget _buildPane(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(VSpace.sm, 10, VSpace.xs, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(VRadius.lg - 4),
        border: Border.all(color: c.withValues(alpha: 0.30), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: VAvatar(label: item.modelDef.label, color: c, size: 22)),
              const SizedBox(width: VSpace.xs),
              Expanded(child: Text(item.modelDef.label, maxLines: 2, style: VType.callout(weight: FontWeight.w600))),
              VCircleButton(icon: Icons.close_rounded, size: 28, tooltip: 'Close', onTap: widget.onToggleExpand),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            runSpacing: 6,
            children: [
              _Tool(
                icon: _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                tooltip: 'Search conversation',
                selected: _isSearching,
                onTap: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchFilter = '';
                }),
              ),
              _Tool(icon: Icons.attach_file_rounded, tooltip: 'Local model files', onTap: _pickLocalFiles),
              if (widget.onOpenLocalHistory != null) _Tool(icon: Icons.history_rounded, tooltip: 'Local history', onTap: widget.onOpenLocalHistory),
              _Tool(icon: Icons.copy_rounded, tooltip: 'Copy answer', onTap: _copyLastMessage),
              if (widget.onOpenBrowser != null) _Tool(icon: Icons.language_rounded, tooltip: 'Model browser', onTap: widget.onOpenBrowser),
            ],
          ),
          ..._expanded(item, fill: true),
        ],
      ),
    );
  }

  /// A collapsed card in the left column.
  Widget _buildCard(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    final e = widget.isExpanded ? 1.0 : widget.elevation.clamp(0.0, 1.0);
    // Colour-coded card: each model owns a tint; higher cards sit higher (brighter, deeper shadow).
    final top = Color.lerp(c.withValues(alpha: 0.20), c.withValues(alpha: 0.30), e)!;
    final bottom = Color.lerp(c.withValues(alpha: 0.07), c.withValues(alpha: 0.12), e)!;
    final waiting = item.isStreaming;

    return AnimatedContainer(
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
        borderRadius: BorderRadius.circular(VRadius.lg - 4),
        border: Border.all(color: c.withValues(alpha: 0.18 + 0.14 * e), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10 + 0.16 * e),
            blurRadius: 10 + 18 * e,
            offset: Offset(0, 3 + 7 * e),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VPress(
            onTap: widget.onToggleExpand,
            child: Row(
              children: [
                VAvatar(label: item.modelDef.label, color: c, size: 18),
                const SizedBox(width: 6),
                // Full model name, wrapping (D44).
                Expanded(
                  child: Text(item.modelDef.label, maxLines: 2, style: VType.footnote(color: VColors.textPrimary, weight: FontWeight.w600)),
                ),
                if (waiting) ...[
                  const SizedBox(width: 6),
                  _Pulse(color: c),
                ] else if (!widget.narrow) ...[
                  const SizedBox(width: 6),
                  Text(item.relativeTime, style: VType.caption()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          VPress(
            onTap: widget.onToggleExpand,
            child: AnimatedSwitcher(
              duration: VMotion.base,
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
              child: waiting
                  ? _SkeletonLines(key: const ValueKey('wait'), color: c)
                  : Text(
                      item.summary,
                      key: ValueKey(item.summary),
                      maxLines: widget.narrow ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: VType.footnote(color: VColors.textSecondary, weight: FontWeight.w400).copyWith(height: 1.3),
                    ),
            ),
          ),
          if (item.mediaUrls != null && item.mediaUrls!.isNotEmpty) ...[
            const SizedBox(height: VSpace.xs),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.mediaUrls!.length,
                separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.sm),
                  child: ThemeImage(_mediaPosterFor(i), width: 58, height: 58, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The conversation fills the pane, or stays under 240 px elsewhere.
  Widget _fillOr(bool fill, {required Widget child}) =>
      fill ? Expanded(child: child) : ConstrainedBox(constraints: const BoxConstraints(maxHeight: 240), child: child);

  List<Widget> _expanded(TickerItem item, {bool fill = false}) {
    return [
      if (_isSearching) ...[
        const SizedBox(height: VSpace.xs),
        VSearchField(
          controller: _searchCtrl,
          hint: 'Search',
          height: 32,
          onChanged: (v) => setState(() => _searchFilter = v.toLowerCase()),
        ),
      ],
      if (_attachedFiles.isNotEmpty) ...[
        const SizedBox(height: VSpace.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _attachedFiles)
              VChip(label: f, selected: true, onTap: () => setState(() => _attachedFiles.remove(f))),
          ],
        ),
      ],
      const SizedBox(height: VSpace.xs),
      _fillOr(
        fill,
        child: EdgeFade(
          fadeHeight: 12,
          child: ListView.builder(
            shrinkWrap: !fill,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
            itemCount: item.conversation.length,
            itemBuilder: (_, i) {
              final msg = item.conversation[i];
              if (_searchFilter.isNotEmpty && !msg.text.toLowerCase().contains(_searchFilter)) {
                return const SizedBox.shrink();
              }
              final isUser = msg.sender == 'user';
              final t = msg.timestamp;
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: VPress(
                  onTap: () => widget.onTapMessage?.call(msg),
                  child: _TailedBubble(
                    isUser: isUser,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isUser ? 'You' : item.modelDef.label}  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                          style: VType.caption(color: VColors.textSecondary, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        isUser
                            ? Text(msg.text, style: VType.callout(weight: FontWeight.w400).copyWith(height: 1.4))
                            : MdText(msg.text.length > 1400 ? '${msg.text.substring(0, 1400)}…' : msg.text),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: VSpace.xs),
      // Isolated inline composer capsule (sends to this model only)
      Container(
        height: 40,
        padding: const EdgeInsets.only(left: VSpace.sm, right: 4),
        decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inlineCtrl,
                cursorColor: VColors.textPrimary,
                style: VType.callout(weight: FontWeight.w400),
                decoration: InputDecoration(
                  hintStyle: VType.callout(color: VColors.textTertiary, weight: FontWeight.w400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _submitInline(),
              ),
            ),
            VCircleButton(icon: Icons.arrow_upward_rounded, size: 32, selected: true, tooltip: 'Send', onTap: _submitInline),
          ],
        ),
      ),
    ];
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  const _Tool({required this.icon, required this.tooltip, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: VCircleButton(icon: icon, size: 28, tooltip: tooltip, selected: selected, onTap: onTap),
    );
  }
}

/// Speech bubble with a directional tail (no nested blur: plain fill on glass).
class _TailedBubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  const _TailedBubble({required this.isUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      constraints: const BoxConstraints(maxWidth: 260),
      child: ClipPath(
        clipper: _TailedBubbleClipper(isUser: isUser),
        child: Container(
          padding: EdgeInsets.fromLTRB(isUser ? 12 : 14, 8, isUser ? 14 : 12, 16),
          color: isUser ? VColors.overlayLight : VColors.fillCell,
          child: child,
        ),
      ),
    );
  }
}

class _TailedBubbleClipper extends CustomClipper<Path> {
  final bool isUser;
  const _TailedBubbleClipper({required this.isUser});

  @override
  Path getClip(Size size) {
    const radius = VRadius.md;
    const tail = 8.0;
    final bottom = size.height - tail;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, bottom), const Radius.circular(radius)));
    if (isUser) {
      path.moveTo(size.width - 18, bottom);
      path.lineTo(size.width - 2, size.height);
      path.lineTo(size.width - 24, bottom - 1);
    } else {
      path.moveTo(18, bottom);
      path.lineTo(2, size.height);
      path.lineTo(24, bottom - 1);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TailedBubbleClipper oldClipper) => oldClipper.isUser != isUser;
}


/// Quiet breathing dot while a model is answering.
class _Pulse extends StatefulWidget {
  final Color color;
  const _Pulse({required this.color});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

/// Shimmering loading lines shown until the answer arrives.
class _SkeletonLines extends StatefulWidget {
  final Color color;
  const _SkeletonLines({super.key, required this.color});
  @override
  State<_SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<_SkeletonLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        Widget line(double w) => FractionallySizedBox(
              widthFactor: w,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 9,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment(-1.5 + 3 * _c.value, 0),
                    end: Alignment(-0.5 + 3 * _c.value, 0),
                    colors: [Colors.white.withValues(alpha: 0.08), widget.color.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.08)],
                  ),
                ),
              ),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(0.92), line(0.64)]);
      },
    );
  }
}
