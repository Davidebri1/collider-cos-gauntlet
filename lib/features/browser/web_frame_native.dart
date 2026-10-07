// Browser page surface on iOS / Android: the page itself in a WebView
// (webview_flutter). No proxy is needed natively: a WebView is not a frame,
// so sites that refuse framing load as they would in a browser.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebFrame extends StatefulWidget {
  final String url;
  final double zoom; // applied by the WebView's own text zoom where supported
  const WebFrame({super.key, required this.url, this.zoom = 1});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _ctrl.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _ctrl)),
          if (_loading)
            const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
        ],
      );
}
