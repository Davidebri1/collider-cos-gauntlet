// Platform switch for the consensus scene host (source: ConsensusScene.tsx).
// Web: an <iframe srcdoc> fed by postMessage, exactly as in the source app.
// iOS / Android: the same scene in a WebView (webview_flutter).
export 'consensus_scene_frame_native.dart'
    if (dart.library.js_interop) 'consensus_scene_frame_web.dart';
