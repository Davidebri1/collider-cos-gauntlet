// Native host for the consensus scene (iOS / Android): the same bundled scene
// HTML in a WebView (webview_flutter), fed the same {type:'update', payload}
// JSON as the web iframe, and reading back the same 'close' / 'labels' /
// 'tab' messages, which the scene posts to the FlutterBridge channel when it
// has no parent frame.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ConsensusSceneFrame extends StatefulWidget {
  final String html;
  final String payloadJson;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onLabelsChange;
  final ValueChanged<String>? onTabChange;

  const ConsensusSceneFrame({
    super.key,
    required this.html,
    required this.payloadJson,
    this.onClose,
    this.onLabelsChange,
    this.onTabChange,
  });

  @override
  State<ConsensusSceneFrame> createState() => _ConsensusSceneFrameState();
}

class _ConsensusSceneFrameState extends State<ConsensusSceneFrame> {
  late final WebViewController _ctrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF07080B))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _loaded = true;
          _sendUpdate();
        },
        // The scene is self-contained: no navigation away from it.
        onNavigationRequest: (r) =>
            r.url.startsWith('about:') || r.url.startsWith('data:') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadHtmlString(widget.html);
  }

  void _onMessage(String data) {
    Map<String, dynamic>? msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>?;
    } catch (_) {
      return;
    }
    if (msg == null || !mounted) return;
    final type = msg['type'];
    final value = (msg['payload'] is Map) ? (msg['payload'] as Map)['value'] : null;
    if (type == 'close') {
      widget.onClose?.call();
    } else if (type == 'labels') {
      widget.onLabelsChange?.call(value == true);
    } else if (type == 'tab' && (value == 'dissent' || value == 'total')) {
      widget.onTabChange?.call(value as String);
    }
  }

  void _sendUpdate() {
    if (!_loaded) return;
    _ctrl.runJavaScript('window.ColliderConsensus && window.ColliderConsensus.update(${widget.payloadJson});');
  }

  @override
  void didUpdateWidget(covariant ConsensusSceneFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payloadJson != widget.payloadJson) _sendUpdate();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _ctrl);
}
