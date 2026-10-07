// Collider composer. Made by Claude.
// v8.3 (D43): one text field, an attach button and a send button, like any
// chat composer. No placeholder text, no depth chips, no model chips: the
// models are chosen only in the model selector (side rail > Models).
// Map row 8 (v8.3, D50): everything else is in the + menu, as in ChatGPT and
// Claude: Attach file, Internet, Research, Deep Research (one of the three,
// or none) and Private. The bar itself has no chips; a lit dot on + says a
// mode is on.
// v8.3 media restore (D35 revoked): the + menu also carries Create image,
// Create video and Create audio (the source's Image / Video / Audio tabs)
// and, on a media tab, Options (the generation settings, map row 17). Send
// stays live; a run that cannot happen on this link fails quietly at send
// time (D59), replacing the dimmed send of D51.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api/collider_api.dart';
import '../../models/model_def.dart';
import '../../core/files/file_store.dart';
import '../../core/vision/vision_kit.dart';

class FloatingPrompt extends StatefulWidget {
  /// Focused (tapped, swiped up on the dock, or a new conversation).
  final bool summoned;
  final bool busy;
  final void Function(String prompt, List<String> attachments) onSubmitPrompt;
  final VoidCallback onSummon;
  final VoidCallback onTuck;
  final AskMode mode;
  final ValueChanged<AskMode> onMode;
  final bool private;
  final ValueChanged<bool> onPrivate;
  /// No model server answers (kept for callers; send stays live, D59).
  final bool offline;
  /// The active model category (models.ts CATEGORIES).
  final ModelCategory category;
  final ValueChanged<ModelCategory>? onCategory;
  /// Opens the generation options (row 17) for the active media category.
  final VoidCallback? onOpenOptions;
  /// Text put back into the field when a send could not run.
  final ValueNotifier<String?>? restoreText;
  /// Bumped from outside (the options sheet's Generate) to send the field.
  final ValueNotifier<int>? generateTick;

  const FloatingPrompt({
    super.key,
    required this.summoned,
    required this.onSubmitPrompt,
    required this.onSummon,
    required this.onTuck,
    this.busy = false,
    required this.mode,
    required this.onMode,
    required this.private,
    required this.onPrivate,
    this.offline = false,
    this.category = ModelCategory.general,
    this.onCategory,
    this.onOpenOptions,
    this.restoreText,
    this.generateTick,
  });

  @override
  State<FloatingPrompt> createState() => _FloatingPromptState();
}

class _FloatingPromptState extends State<FloatingPrompt> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<String> _files = [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && !widget.summoned) widget.onSummon();
    });
    if (widget.summoned) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    widget.restoreText?.addListener(_onRestore);
    widget.generateTick?.addListener(_onGenerate);
  }

  void _onRestore() {
    final t = widget.restoreText?.value;
    if (t == null) return;
    _ctrl.text = t;
    _ctrl.selection = TextSelection.collapsed(offset: t.length);
    widget.restoreText!.value = null;
    if (mounted) setState(() {});
  }

  void _onGenerate() {
    if (_ctrl.text.trim().isEmpty) {
      _focus.requestFocus();
      return;
    }
    _submit();
  }

  @override
  void didUpdateWidget(covariant FloatingPrompt old) {
    super.didUpdateWidget(old);
    if (widget.summoned && !old.summoned) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
    if (!widget.summoned && old.summoned) _focus.unfocus();
  }

  @override
  void dispose() {
    widget.restoreText?.removeListener(_onRestore);
    widget.generateTick?.removeListener(_onGenerate);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.busy) return;
    final files = List.of(_files);
    // Clear first: a send that cannot run puts the prompt straight back
    // (restoreText), and that must not be wiped afterwards.
    _ctrl.clear();
    setState(() => _files.clear());
    widget.onSubmitPrompt(text, files);
  }

  Future<void> _attach() async {
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (r != null) {
        setState(() => _files.addAll(r.files.map((f) => f.name)));
        // Real attachments show up in Files (DEVIATIONS.md D22).
        final note = await FileStore.instance.addPicked(r.files, 'composer');
        if (note != null && mounted) {
          // Map row 22: the centred alert (D49).
          await showVAlert(context, icon: Icons.error_outline_rounded, title: note, actions: const [VAlertChoice('OK')]);
        }
      }
    } catch (_) {}
  }

  final GlobalKey _plusKey = GlobalKey();

  /// The + menu, opening upward from the + button.
  Future<void> _openMenu() async {
    final box = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final at = box.localToGlobal(Offset.zero, ancestor: overlay);
    final screen = overlay.size;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          alignment: Alignment.bottomLeft,
          scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) {
        // The menu keeps its own copy: it may rebuild before the composer does.
        var cur = widget.mode;
        var priv = widget.private;
        var cat = widget.category;
        return StatefulBuilder(builder: (ctx, setMenu) {
        void create(ModelCategory c) {
          cat = cat == c ? ModelCategory.general : c;
          widget.onCategory?.call(cat);
          setMenu(() {});
        }

        void mode(AskMode m) {
          cur = cur == m ? AskMode.chat : m;
          widget.onMode(cur);
          setMenu(() {});
        }

        final m = cur;
        return Stack(children: [
          Positioned(
            left: at.dx.clamp(8.0, screen.width - 240 * GlassMenu.scaleFor(context) - 8),
            bottom: screen.height - at.dy + 8,
            child: Material(
              type: MaterialType.transparency,
              child: GlassMenu(width: 240, rows: [
                GlassMenuRow(
                  icon: Icons.attach_file_rounded,
                  label: 'Attach file',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _attach();
                  },
                ),
                GlassMenuRow(icon: Icons.image_outlined, label: 'Create image', on: cat == ModelCategory.image, onTap: () => create(ModelCategory.image)),
                GlassMenuRow(icon: Icons.movie_outlined, label: 'Create video', on: cat == ModelCategory.video, onTap: () => create(ModelCategory.video)),
                GlassMenuRow(icon: Icons.graphic_eq_rounded, label: 'Create audio', on: cat == ModelCategory.audio, onTap: () => create(ModelCategory.audio)),
                if (cat.isMedia)
                  GlassMenuRow(
                    icon: Icons.tune_rounded,
                    label: 'Options',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onOpenOptions?.call();
                    },
                  ),
                // Web search is a text-model option in the source composer.
                if (!cat.isMedia) ...[
                  GlassMenuRow(icon: Icons.language_rounded, label: 'Internet', on: m == AskMode.internet, onTap: () => mode(AskMode.internet)),
                  GlassMenuRow(icon: Icons.travel_explore_rounded, label: 'Research', on: m == AskMode.research, onTap: () => mode(AskMode.research)),
                  GlassMenuRow(icon: Icons.manage_search_rounded, label: 'Deep Research', on: m == AskMode.deep, onTap: () => mode(AskMode.deep)),
                ],
                GlassMenuRow(
                  icon: Icons.visibility_off_outlined,
                  label: 'Private',
                  on: priv,
                  onTap: () {
                    priv = !priv;
                    widget.onPrivate(priv);
                    setMenu(() {});
                  },
                ),
              ]),
            ),
          ),
        ]);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // v8.4: Figma 1-240 (760 x 116) built at its own size and scaled as one
    // unit to the width it is given (factor = width / 760): padding 16 / 40 /
    // 40, attach circle 60 (white 30 %), gap 16, field pill 60 high
    // (black 30 %, radius 32, 1 px white-50 % lip, inset shade), action
    // button 48 (white 30 %). Text 24. No placeholder (D43).
    return GestureDetector(
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 200 && widget.summoned) widget.onTuck();
        if (v < -200 && !widget.summoned) widget.onSummon();
      },
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 760,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 16, 40, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Attached files: the file names are the only way to tell them apart.
                if (_files.isNotEmpty) ...[
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final f in _files)
                      GestureDetector(
                        onTap: () => setState(() => _files.remove(f)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(32)),
                          child: Text(f, style: const TextStyle(fontSize: 20, color: Colors.white)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Semantics(
                      button: true,
                      label: 'More',
                      child: GestureDetector(
                        key: _plusKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: _openMenu,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(32)),
                          child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 60),
                        padding: const EdgeInsets.fromLTRB(24, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: const Color(0x4D000000),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), offset: Offset(0, 1), blurRadius: 1)],
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment(0.2, 0.6),
                            colors: [Color(0x26000000), Color(0x00000000)],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: TextField(
                                  controller: _ctrl,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: 5,
                                  cursorColor: Colors.white,
                                  textInputAction: TextInputAction.send,
                                  style: const TextStyle(fontSize: 24, height: 1.17, fontWeight: FontWeight.w500, color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _submit(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _SendButton(busy: widget.busy, onTap: _submit),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Send: clear shape, springs on press, turns into a spinner while models answer.
class _SendButton extends StatefulWidget {
  final bool busy;
  final VoidCallback onTap;
  const _SendButton({required this.busy, required this.onTap});
  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: VMotion.base,
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0x4DFFFFFF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: VMotion.fast,
              child: widget.busy
                  ? const SizedBox(key: ValueKey('b'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.arrow_upward_rounded, key: ValueKey('s'), size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
