import 'package:flutter/material.dart';
import 'vision_kit.dart';

/// Durable work-surface frame shared by Smart Gen, Discover and Files
/// (Vision Pro UI Kit 30:75 Keynote window; Nimo Spatial OS 2012:201531):
/// one bounded glass window with a toolbar row, content, and a floating
/// segmented ornament beneath it. The side rail ornament sits outside, left.
///
/// v8.3 (map row 21, D52): with no [title] the window has no header row; the
/// content runs to the window edge with the close circle floating over it,
/// and the window hugs its content ([hug]).
class VWorkSurface extends StatelessWidget {
  final String? title;
  final bool hug;
  final VoidCallback onClose;
  final List<Widget> toolbarActions;
  final Widget? search;
  final Widget child;
  final List<String> tabs;
  /// Tighter tab padding (Files: six tabs at 430 px).
  final bool denseTabs;
  final int activeTab;
  final ValueChanged<int>? onTab;

  const VWorkSurface({
    super.key,
    this.title,
    this.hug = false,
    required this.onClose,
    required this.child,
    this.toolbarActions = const [],
    this.search,
    this.tabs = const [],
    this.denseTabs = false,
    this.activeTab = 0,
    this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isMobile ? 56 : 0, 40, 0, 0),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: VOverlay.toolWidth(context), height: hug ? null : VOverlay.toolMaxHeight(context))
                    .copyWith(maxHeight: VOverlay.toolMaxHeight(context)),
                child: VGlass(
                    material: VMaterial.work,
                    radius: VRadius.xl,
                    child: title == null
                        ? Stack(children: [
                            ClipRRect(borderRadius: BorderRadius.circular(VRadius.xl), child: child),
                            Positioned(
                              left: VSpace.sm,
                              top: VSpace.sm,
                              child: VCircleButton(icon: Icons.close_rounded, floating: true, tooltip: 'Close', onTap: onClose),
                            ),
                          ])
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
                          child: Row(
                            children: [
                              VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: onClose),
                              const SizedBox(width: VSpace.sm),
                              Expanded(
                                child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.headline()),
                              ),
                              for (final a in toolbarActions) ...[const SizedBox(width: 6), a],
                            ],
                          ),
                        ),
                        if (search != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xxs, VSpace.md, VSpace.xs),
                            child: search!,
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            if (tabs.isNotEmpty) ...[
              const SizedBox(height: VSpace.sm),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: VOverlay.toolWidth(context)),
                child: VSegmented(labels: tabs, dense: denseTabs, active: activeTab, onSelect: (i) => onTab?.call(i)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
