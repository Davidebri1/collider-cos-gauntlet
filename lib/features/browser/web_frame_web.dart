// Browser page surface (web). Made by Claude.
// Pages load through the local Collider server so sites that refuse framing
// still render. Without that server (static hosting, /api 404) the page is
// framed directly instead of showing the host's 404 (v8.3, D41).
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../core/api/collider_api.dart';
import '../../core/api/proxy.dart';

final Set<String> _registered = {};

class WebFrame extends StatelessWidget {
  final String url;
  /// Page zoom (the address bar's aA): the page lays out at 1/zoom of the
  /// frame and is scaled up, like a browser's zoom.
  final double zoom;
  const WebFrame({super.key, required this.url, this.zoom = 1});

  @override
  Widget build(BuildContext context) {
    // /api/page exists only on the local Collider server (same origin). The
    // Worker proxy does not serve pages (it would be an open proxy), so with
    // COLLIDER_PROXY set pages are framed directly.
    final src = ColliderApi.instance.online && !ColliderProxy.enabled ? '/api/page?url=${Uri.encodeComponent(url)}' : url;
    final type = 'collider-frame-${src.hashCode}-$zoom';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final f = web.HTMLIFrameElement()
          ..src = src
          ..style.border = '0'
          ..style.width = '${100 / zoom}%'
          ..style.height = '${100 / zoom}%'
          ..style.transform = 'scale($zoom)'
          ..style.transformOrigin = '0 0'
          ..style.background = 'white';
        return f;
      });
    }
    return HtmlElementView(key: ValueKey(type), viewType: type);
  }
}
