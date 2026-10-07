// Shared state between the floating music widget and the market's web
// ambient (v8.2). Made by Claude.
import 'package:flutter/widgets.dart';

import '../theme/premium_market_ambient.dart' show AmbientGlass;

class MusicZones {
  MusicZones._();

  /// The widget's own rect (global) while it is shown over the market, so the
  /// market's DOM ambient can blur the video behind it like the bar's glass
  /// (BackdropFilter cannot reach the platform-view video on web).
  static final ValueNotifier<AmbientGlass?> widgetGlass = ValueNotifier<AmbientGlass?>(null);
}
