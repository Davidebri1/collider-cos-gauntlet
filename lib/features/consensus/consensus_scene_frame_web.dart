// Web host for the consensus scene. Port of collidermergedx3-glm
// src/components/ConsensusScene.tsx: an iframe with srcDoc = the bundled scene
// HTML, sandbox "allow-same-origin allow-scripts", updates pushed as
// JSON {type:'update', payload} every 100 ms for 1.5 s after each change, and
// 'close' / 'labels' / 'tab' messages read back from the scene.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

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
  static int _seq = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _listener;
  Timer? _tick;
  Timer? _stop;

  @override
  void initState() {
    super.initState();
    _viewType = 'collider-consensus-scene-${_seq++}';
    _iframe = web.HTMLIFrameElement()
      ..title = 'Consensus Scene'
      ..setAttribute('sandbox', 'allow-same-origin allow-scripts')
      ..srcdoc = widget.html.toJS;
    _iframe.style
      ..position = 'absolute'
      ..setProperty('inset', '0')
      ..width = '100%'
      ..height = '100%'
      ..border = '0'
      ..backgroundColor = 'transparent'
      ..setProperty('color-scheme', 'dark');
    _iframe.onLoad.listen((_) => _sendUpdate());
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _iframe);

    _listener = ((web.MessageEvent ev) {
      final data = ev.data?.dartify();
      if (data is! String) return;
      Map<String, dynamic>? msg;
      try {
        msg = jsonDecode(data) as Map<String, dynamic>?;
      } catch (_) {
        return;
      }
      if (msg == null) return;
      final type = msg['type'];
      final value = (msg['payload'] is Map) ? (msg['payload'] as Map)['value'] : null;
      if (type == 'close') {
        widget.onClose?.call();
      } else if (type == 'labels') {
        widget.onLabelsChange?.call(value == true);
      } else if (type == 'tab' && (value == 'dissent' || value == 'total')) {
        widget.onTabChange?.call(value as String);
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    _burst();
  }

  void _sendUpdate() {
    final w = _iframe.contentWindow;
    if (w == null) return;
    try {
      w.postMessage('{"type":"update","payload":${widget.payloadJson}}'.toJS, '*'.toJS);
    } catch (_) {}
  }

  void _burst() {
    _tick?.cancel();
    _stop?.cancel();
    _sendUpdate();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _sendUpdate());
    _stop = Timer(const Duration(milliseconds: 1500), () => _tick?.cancel());
  }

  @override
  void didUpdateWidget(covariant ConsensusSceneFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payloadJson != widget.payloadJson) _burst();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stop?.cancel();
    if (_listener != null) web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
