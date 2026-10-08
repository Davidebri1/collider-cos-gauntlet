import 'package:flutter/material.dart';
import '../theme/smartgen_glass.dart';

/// The Smart Gen view filter — a literal port of the Photos VR floating
/// segmented toolbar: a dark glass capsule holding outline pill segments,
/// the active segment filled. All / Active / Urgent filter the board's
/// cards; the underlying order is never disturbed (filtering is render-only).
class SGFilterBar extends StatelessWidget {
  final String value; // 'all' | 'active' | 'urgent'
  final ValueChanged<String> onChanged;

  const SGFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _options = [
    ('all', 'All'),
    ('active', 'Active'),
    ('urgent', 'Urgent'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPanel.bar(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            GlassSegment(
              label: _options[i].$2,
              selected: value == _options[i].$1,
              onTap: () => onChanged(_options[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}
