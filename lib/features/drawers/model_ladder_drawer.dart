import 'package:flutter/material.dart';
import '../../../models/model_def.dart';
import '../../../core/vision/vision_kit.dart';

/// REQ-17 Model Hierarchy Ladder — library list (Vision OS Design System
/// 417:6219 "Your Library"): filter chips, recessed search, rows with a
/// circular avatar, name and tier line, toggle trailing.
class ModelLadderDrawer extends StatefulWidget {
  final ModelCategory activeCategory;
  final List<String> selectedModelIds;
  final Function(ModelCategory cat) onSelectCategory;
  final Function(String modelId) onToggleModel;
  final VoidCallback onClose;

  const ModelLadderDrawer({
    super.key,
    required this.activeCategory,
    required this.selectedModelIds,
    required this.onSelectCategory,
    required this.onToggleModel,
    required this.onClose,
  });

  @override
  State<ModelLadderDrawer> createState() => _ModelLadderDrawerState();
}

class _ModelLadderDrawerState extends State<ModelLadderDrawer> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final models = ModelRoster.forCategory(widget.activeCategory)
        .where((m) => q.isEmpty || m.label.toLowerCase().contains(q) || m.provider.toLowerCase().contains(q))
        .toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.md, 56, VSpace.md, 0),
            child: VWindow(
              title: 'Models',
              maxWidth: VOverlay.menuWidth(context),
              maxHeight: VOverlay.menuMaxHeight(context),
              actions: [VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: ModelCategory.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                      itemBuilder: (_, i) {
                        final c = ModelCategory.values[i];
                        return VChip(label: c.label, selected: c == widget.activeCategory, onTap: () => widget.onSelectCategory(c));
                      },
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),
                  VSearchField(
                    controller: _searchCtrl,
                    hint: 'Search',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                  const SizedBox(height: VSpace.xs),
                  Flexible(
                    child: models.isEmpty
                        ? const SizedBox(height: VSpace.xl)
                        : EdgeFade(
                            fadeHeight: 14,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
                              itemCount: models.length,
                              itemBuilder: (_, i) {
                                final m = models[i];
                                final on = widget.selectedModelIds.contains(m.id);
                                // models.ts row: full name, then the tier (ModelLadder.tsx).
                                return VListRow(
                                  title: m.label,
                                  titleLines: null,
                                  subtitle: TierInfo.all[m.tier]!.label,
                                  leading: VAvatar(label: m.label, color: m.providerColor, size: 40),
                                  selected: on,
                                  trailing: VToggle(value: on, onChanged: (_) => widget.onToggleModel(m.id)),
                                  onTap: () => widget.onToggleModel(m.id),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
