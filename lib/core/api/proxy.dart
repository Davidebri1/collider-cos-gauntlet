// v8.4: one build-time define points every provider call at the key proxy:
//   flutter build web --dart-define=COLLIDER_PROXY=https://proxy.example.com
// No provider key is ever compiled into the bundle. With the define empty
// (the default, and the hosted build) every provider call fails quietly at
// send time, as before (D58 / D59).
//
// Paths under the proxy (the proxy adds the key and forwards):
//   $COLLIDER_PROXY/openrouter/...    -> https://openrouter.ai/api/...
//   $COLLIDER_PROXY/crazyrouter/...   -> https://crazyrouter.com/...
//   $COLLIDER_PROXY/pollinations/image/... -> https://image.pollinations.ai/...
//   $COLLIDER_PROXY/api/...           -> the Collider chat API, served by the Worker itself (/api/models,
//                                        /api/ask, /api/job/:id, /api/reply,
//                                        /api/history)
const String kColliderProxy = String.fromEnvironment('COLLIDER_PROXY');

class ColliderProxy {
  static bool get enabled => kColliderProxy.trim().isNotEmpty;
  /// The proxy root (no trailing slash); the chat API is \$root/api/...
  static String get root => _root;
  static String get _root {
    final p = kColliderProxy.trim();
    return p.endsWith('/') ? p.substring(0, p.length - 1) : p;
  }

  /// Base URL for [provider] ('openrouter' | 'crazyrouter' | 'pollinations' | 'api').
  static String base(String provider) => '$_root/$provider';
}
