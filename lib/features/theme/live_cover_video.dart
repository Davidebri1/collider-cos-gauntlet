// A live wallpaper playing inside a CoverFlow cover (Figma 417-1777, map row 4).
// Web: a muted, looping <video> outside the Flutter scene whose frames are
// copied into the canvas (createImageFromTextureSource), so the cover keeps
// its 3D transform, rounded clip and reflection. Native: video_player.
export 'live_cover_video_native.dart' if (dart.library.js_interop) 'live_cover_video_web.dart';
