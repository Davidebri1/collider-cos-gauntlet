// Where a stored video plays from (map row 19): a blob: URL on web, a file in
// the app cache on iOS / Android.
export 'video_source_native.dart' if (dart.library.js_interop) 'video_source_web.dart';
