import 'package:flutter/material.dart';
import 'package:collider_flutter/core/theme/app_fonts.dart';
import '../theme/smartgen_glass.dart';
import '../models/smartgen_models.dart';
import '../state/smartgen_store.dart';
import 'sg_menu.dart';
import 'smartgen_icons.dart';

/// The searchable component drawer: slides out when a side-nav icon
/// (Cards / Canvases / Boards) is tapped. Shows every configured type with
/// a thumbnail + label; tapping a type instantly deploys an instance.
/// The type's overflow menu opens the edit / duplicate / delete submenu.
/// "Create custom type" sits at the bottom.
class ComponentDrawer extends StatefulWidget {
  final ComponentKind kind;
  final SmartGenStore store;
  final VoidCallback onClose;
  final void Function(ComponentTemplate template)? onDeploy;

  const ComponentDrawer({
    super.key,
    required this.kind,
    required this.store,
    required this.onClose,
    this.onDeploy,
  });

  @override
  State<ComponentDrawer> createState() => _ComponentDrawerState();
}

class _ComponentDrawerState extends State<ComponentDrawer> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _renamingTemplateId;
  bool _creatingType = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _kindLabel {
    switch (widget.kind) {
      case ComponentKind.card:
        return 'Cards';
      case ComponentKind.canvas:
        return 'Canvases';
      case ComponentKind.board:
        return 'Boards';
    }
  }

  String get _kindSingular {
    switch (widget.kind) {
      case ComponentKind.card:
        return 'card';
      case ComponentKind.canvas:
        return 'canvas';
      case ComponentKind.board:
        return 'board';
    }
  }

  List<ComponentTemplate> get _templates {
    final all = widget.store.templatesOf(widget.kind);
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.typeKey.toLowerCase().contains(q))
        .toList();
  }

  void _deploy(ComponentTemplate t) {
    var refused = false;
    switch (widget.kind) {
      case ComponentKind.card:
        refused =
            widget.store.instantiateCard(t.id, title: 'New ${t.name}') == null;
        break;
      case ComponentKind.canvas:
        refused =
            widget.store.instantiateCanvas(t.id, title: 'New ${t.name}') ==
                null;
        break;
      case ComponentKind.board:
        widget.store.instantiateBoard(t.id, title: 'New ${t.name}');
        break;
    }
    if (refused && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.kind == ComponentKind.card
                ? 'Card limit reached (999). Delete something first.'
                : 'This board already holds 10 canvases.'),
            behavior: SnackBarBehavior.floating),
      );
    }
    widget.onDeploy?.call(t);
  }

  void _showTypeMenu(ComponentTemplate t, Offset at) {
    SGMenu.show(
      context,
      at: at,
      items: [
        SGMenuItem(
          icon: smartGenIcon(t.iconName),
          label: t.name,
          highlighted: true,
          onTap: () {},
        ),
        SGMenuItem(
          icon: Icons.add_rounded,
          label: 'Deploy instance',
          onTap: () => _deploy(t),
        ),
        SGMenuItem(
          icon: Icons.edit_outlined,
          label: 'Rename type',
          onTap: () => setState(() {
            _renamingTemplateId = t.id;
            _creatingType = false;
          }),
        ),
        SGMenuItem(
          icon: Icons.copy_rounded,
          label: 'Duplicate type',
          onTap: () => widget.store.duplicateTemplate(t.id),
        ),
        SGMenuItem(
          icon: Icons.delete_outline_rounded,
          label: t.isBuiltIn ? 'Hide type' : 'Delete type',
          destructive: true,
          onTap: () => widget.store.deleteTemplate(t.id),
        ),
      ],
    );
  }

  void _createCustomType() {
    setState(() {
      _creatingType = true;
      _renamingTemplateId = null;
    });
  }

  void _commitNewType(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      setState(() => _creatingType = false);
      return;
    }
    final typeKey =
        'custom_${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final tpl = widget.store.createTemplate(widget.kind, trimmed, typeKey);
    // Seed with a title field so the type is usable immediately.
    widget.store.addField(tpl.id, 'Title', FieldKind.text);
    setState(() => _creatingType = false);
    // Open the type menu where the old sheet used to appear.
    final box = context.findRenderObject() as RenderBox?;
    final at = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height - 180))
        : Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height - 220);
    _showTypeMenu(tpl, at);
  }

  @override
  Widget build(BuildContext context) {
    final templates = _templates;
    final screenW = MediaQuery.of(context).size.width;
    // Narrow phones: the drawer shares the window Row with the side rail,
    // so its width must leave room for the rail + window chrome (~112pt).
    // A bare 0.72 * screenW overflows the Row by a hair on 390pt phones.
    final drawerW = screenW > 480 ? 340.0 : screenW - 112;
    return GlassPanel.window(
      child: SizedBox(
        width: drawerW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_kindLabel,
                        style: AppFonts.instrumentSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.2)),
                  ),
                  GlassPressable(
                    onTap: widget.onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: GlassField(
                controller: _searchCtrl,
                hintText: 'Search ${_kindLabel.toLowerCase()}…',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Existing board instances live here — board switching
                  // happens through the side nav, never a separate menu.
                  if (widget.kind == ComponentKind.board) ...[
                    _sectionLabel('Your boards'),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        itemCount: widget.store.boards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final b = widget.store.boards[i];
                          final active = b.id == widget.store.activeBoardId;
                          return _BoardRow(
                            board: b,
                            active: active,
                            canDelete: widget.store.boards.length > 1,
                            onTap: () {
                              widget.store.setActiveBoard(b.id);
                              widget.onClose();
                            },
                            onDelete: () => widget.store.deleteBoard(b.id),
                          );
                        },
                      ),
                    ),
                    _sectionLabel('Start from a type'),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_creatingType)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                            child: _InlineNameField(
                              key: const ValueKey('new-type'),
                              hint: 'New $_kindSingular type name',
                              onCancel: () =>
                                  setState(() => _creatingType = false),
                              onSubmit: _commitNewType,
                            ),
                          ),
                        Expanded(
                          child: templates.isEmpty && !_creatingType
                              ? Center(
                                  child: Text(
                                    _query.isEmpty
                                        ? 'No types yet.'
                                        : 'No matches for "$_query".',
                                    style: AppFonts.instrumentSans(
                                        fontSize: 12, color: Colors.white38),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 2, 14, 12),
                                  itemCount: templates.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, i) {
                                    final t = templates[i];
                                    if (_renamingTemplateId == t.id) {
                                      return _InlineNameField(
                                        key: ValueKey('rename-${t.id}'),
                                        initial: t.name,
                                        onCancel: () => setState(
                                            () => _renamingTemplateId = null),
                                        onSubmit: (name) {
                                          final trimmed = name.trim();
                                          if (trimmed.isNotEmpty) {
                                            widget.store
                                                .renameTemplate(t.id, trimmed);
                                          }
                                          setState(
                                              () => _renamingTemplateId = null);
                                        },
                                      );
                                    }
                                    return _TypeRow(
                                      template: t,
                                      onDeploy: () => _deploy(t),
                                      onMenu: (at) => _showTypeMenu(t, at),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: GlassPressable(
                onTap: _createCustomType,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.5),
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Create custom $_kindSingular type',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.instrumentSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        child: Text(text,
            style: AppFonts.instrumentSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white38)),
      );
}

/// A row for an existing board instance. Tapping switches to that board.
class _BoardRow extends StatelessWidget {
  final SmartBoard board;
  final bool active;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BoardRow({
    required this.board,
    required this.active,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.17)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded,
                  size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(board.title,
                  style: AppFonts.instrumentSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.1)),
            ),
            if (active)
              const Icon(Icons.check_rounded, size: 16, color: Colors.white70),
            if (canDelete) ...[
              const SizedBox(width: 2),
              GlassPressable(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 15, color: Colors.white38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final ComponentTemplate template;
  final VoidCallback onDeploy;
  final ValueChanged<Offset> onMenu;

  const _TypeRow({
    required this.template,
    required this.onDeploy,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onDeploy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(smartGenIcon(template.iconName),
                  size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name,
                      style: AppFonts.instrumentSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.1)),
                  const SizedBox(height: 2),
                  Text(
                    '${template.fields.length} fields · tap to deploy',
                    style: AppFonts.instrumentSans(
                        fontSize: 10.5, color: Colors.white38),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTapDown: (d) => onMenu(d.globalPosition),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert_rounded,
                    size: 15, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline text field for naming/renaming a component type.
class _InlineNameField extends StatefulWidget {
  final String? initial;
  final String? hint;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  const _InlineNameField(
      {super.key,
      this.initial,
      this.hint,
      required this.onSubmit,
      required this.onCancel});

  @override
  State<_InlineNameField> createState() => _InlineNameFieldState();
}

class _InlineNameFieldState extends State<_InlineNameField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial ?? '');

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppFonts.instrumentSans(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.hint ?? 'Name',
                hintStyle: AppFonts.instrumentSans(
                    fontSize: 13, color: Colors.white38),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: widget.onSubmit,
            ),
          ),
          GestureDetector(
            onTap: () => widget.onSubmit(_ctrl.text),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.check_rounded, size: 16, color: Colors.white70),
            ),
          ),
          GestureDetector(
            onTap: widget.onCancel,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}
