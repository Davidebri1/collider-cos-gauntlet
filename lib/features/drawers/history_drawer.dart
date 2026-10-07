import 'package:flutter/material.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';

/// REQ-13 Global History Drawer — notes-list window (Vision OS Design System
/// 417:8104 "All iCloud"): large title, recessed search capsule, rows with
/// title, one-line summary and relative time; edges fade into the glass.
class HistoryDrawer extends StatefulWidget {
  final List<ConversationHistorySession> sessions;
  final Function(ConversationHistorySession session) onSelectSession;
  final VoidCallback onClose;

  const HistoryDrawer({
    super.key,
    required this.sessions,
    required this.onSelectSession,
    required this.onClose,
  });

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
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
    final sessions = widget.sessions
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.summary.toLowerCase().contains(q))
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
              title: 'History',
              maxWidth: VOverlay.menuWidth(context),
              maxHeight: VOverlay.menuMaxHeight(context),
              actions: [VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose)],
              child: HistorySessionList(
                sessions: sessions,
                searchController: _searchCtrl,
                onQuery: (v) => setState(() => _query = v.trim()),
                onSelect: widget.onSelectSession,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared notes-style session list (global + local history).
class HistorySessionList extends StatelessWidget {
  final List<ConversationHistorySession> sessions;
  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final ValueChanged<ConversationHistorySession> onSelect;
  final String searchHint;

  const HistorySessionList({
    super.key,
    required this.sessions,
    required this.searchController,
    required this.onQuery,
    required this.onSelect,
    this.searchHint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(controller: searchController, hint: searchHint, onChanged: onQuery),
        const SizedBox(height: VSpace.sm),
        Flexible(
          // Nothing saved: nothing shown (v8.3, D45).
          child: sessions.isEmpty
              ? const SizedBox(height: VSpace.xl)
              : EdgeFade(
                  fadeHeight: 14,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      return VPress(
                        onTap: () => onSelect(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 10),
                          decoration: BoxDecoration(
                            color: VColors.fillCell,
                            borderRadius: BorderRadius.circular(VRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: VType.callout(weight: FontWeight.w600).copyWith(fontSize: VType.md)),
                                  ),
                                  const SizedBox(width: VSpace.xs),
                                  Text(s.relativeTime, style: VType.caption()),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(s.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.footnote()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
