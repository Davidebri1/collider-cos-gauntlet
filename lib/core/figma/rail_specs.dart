import 'package:flutter/material.dart';

import '../../features/nav/contextual_side_nav.dart' show ActiveWorkSurface;

typedef RailSpec = ({Size frame, double crop, Offset center, Rect rail, Offset inset, double pitch, double tab, double bottomPad});

/// Where each surface's Figma frame puts its side tab bar (frame coords), with
/// the crop that surface's stage uses, so the rail scales with its screen.
class RailSpecs {
  /// Files — Vision Pro Spatial UI Kit 71:7502 (group 1336 x 835): rail
  /// 71:7503 at (0, 198.3), 65.4 x 343.4, 40.9 px tabs 53.15 apart.
  static const RailSpec files = (
    frame: Size(1336.4, 835.2),
    crop: 1336.4,
    center: Offset(668.2, 417.6),
    rail: Rect.fromLTWH(0, 198.3, 65.4, 343.4),
    inset: Offset(12.24, 18.36),
    pitch: 53.15,
    tab: 40.9,
    bottomPad: 18.4,
  );
  /// Market — Video Platforms on visionOS 203:5891 (2610 x 1468): rail
  /// 290:4411 at (569, 622), 68 x 224, four 44 px tabs 52 apart.
  static const RailSpec market = (
    frame: Size(2610, 1468),
    crop: 1376,
    center: Offset(1257, 734),
    rail: Rect.fromLTWH(569, 622, 68, 224),
    inset: Offset(12, 12),
    pitch: 52,
    tab: 44,
    bottomPad: 12,
  );
  static final Map<ActiveWorkSurface, RailSpec> _specs = {ActiveWorkSurface.files: files, ActiveWorkSurface.market: market};
  static void register(ActiveWorkSurface s, RailSpec spec) => _specs[s] = spec;
  static RailSpec? of(ActiveWorkSurface s) => _specs[s];
}
