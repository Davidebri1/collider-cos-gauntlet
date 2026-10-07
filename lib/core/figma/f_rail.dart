import 'package:flutter/material.dart';

import 'figma_stage.dart';

/// visionOS side tab bar, built at Figma size (wechat 0:1150 / Video
/// Platforms 290:4411 / Spatial UI Kit rails): 1.4 px rgba(255,255,255,.4)
/// stroke, radius = width / 2, Windows/Glass fill, 44 px tabs at [tabInset],
/// [pitch] apart; the active tab has the white 7 % + #5E5E5E 18 % disc, the
/// others are at 40 % opacity. Real Collider entries replace the sample tabs.
class FRail extends StatelessWidget {
  const FRail({
    super.key,
    required this.icons,
    required this.active,
    required this.onSelect,
    this.labels = const [],
    this.width = 76,
    this.tabInset = const Offset(14.6, 17.6),
    this.pitch = 69,
    this.bottomPad = 20.4,
    this.tab = 44,
    this.iconSize = 24,
  });
  final double tab;
  final double iconSize;
  final List<IconData> icons;
  final List<String> labels;
  final int active;
  final ValueChanged<int> onSelect;
  final double width;
  final Offset tabInset;
  final double pitch;
  final double bottomPad;

  double get height => tabInset.dy + tab + pitch * (icons.length - 1) + bottomPad;

  @override
  Widget build(BuildContext context) {
    return FGlass(
      width: width,
      height: height,
      radius: BorderRadius.circular(width / 2),
      stroke: const Color(0x66FFFFFF),
      strokeWidth: 1.4,
      child: Stack(children: [
        for (int i = 0; i < icons.length; i++)
          Positioned(
            left: tabInset.dx - 1.4,
            top: tabInset.dy - 1.4 + pitch * i,
            width: tab,
            height: tab,
            child: Semantics(
              button: true,
              label: i < labels.length ? labels[i] : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Opacity(
                  opacity: i == active ? 1 : 0.4,
                  child: Container(
                    decoration: i == active
                        ? const BoxDecoration(shape: BoxShape.circle, color: Color(0x2EFFFFFF))
                        : null,
                    alignment: Alignment.center,
                    child: Icon(icons[i], size: iconSize, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
