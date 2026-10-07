import '../core/media/theme_catalog.dart';

/// One track in a theme pack's 5-track soundscape.
class AmbientTrack {
  final int number;
  final String title;
  final String duration;
  final String mood;

  /// Optional streamable audio URL (absolute). Null when the pack ships titles only.
  final String? audioUrl;

  const AmbientTrack({
    required this.number,
    required this.title,
    required this.duration,
    this.mood = 'Ambient',
    this.audioUrl,
  });

  factory AmbientTrack.fromJson(Map<String, dynamic> j, {Uri? base}) => AmbientTrack(
        number: (j['number'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        duration: (j['duration'] as String?) ?? '',
        mood: (j['mood'] as String?) ?? 'Ambient',
        audioUrl: ThemeCatalog.resolve(j['audio'] as String?, base),
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'duration': duration,
        'mood': mood,
        if (audioUrl != null) 'audio': audioUrl,
      };
}

/// A wallpaper theme (free still or premium live pack).
///
/// Media fields hold either an absolute https URL (streamed from the
/// collider-media host) or a bundled asset path. Use [ThemeMedia.isNetwork]
/// to tell them apart; the widgets in `features/theme/theme_living_media.dart`
/// handle both.
class WallpaperTheme {
  final String id;
  final String name;

  /// Poster image (about 720px wide). Used for covers, thumbnails, and as the
  /// first frame while [videoPath] streams in. Historically named assetPath.
  final String assetPath;

  /// Optional looping live wallpaper (H.264 mp4, 720p, muted).
  final String? videoPath;

  /// Optional higher resolution still for full-bleed use (free themes).
  final String? stillPath;

  final bool isPremium;
  final String creator;
  final String tier;
  final String collection;
  final List<AmbientTrack> tracks;
  final String? productId;
  final String? priceLabel;

  const WallpaperTheme({
    required this.id,
    required this.name,
    required this.assetPath,
    this.videoPath,
    this.stillPath,
    this.isPremium = false,
    this.creator = 'Studio Nebula',
    this.tier = 'Standard Spatial',
    this.collection = 'Spatial Ambient Series',
    this.productId,
    this.priceLabel,
    this.tracks = const [],
  });

  /// Slug in the media catalog (same as [id]).
  String get slug => id;

  /// Poster URL or asset path.
  String get posterUrl => assetPath;

  /// Video URL or asset path, when the theme is live.
  String? get videoUrl => videoPath;

  /// Best source for a full-bleed still: [stillPath] when present, else poster.
  String get wallpaperStill => stillPath ?? assetPath;

  bool get isLive => videoPath != null && videoPath!.isNotEmpty;

  factory WallpaperTheme.fromJson(Map<String, dynamic> j, {Uri? base}) {
    final premium = j['premium'] == true;
    final tracks = (j['tracks'] as List? ?? const [])
        .whereType<Map>()
        .map((t) => AmbientTrack.fromJson(t.cast<String, dynamic>(), base: base))
        .toList(growable: false);
    return WallpaperTheme(
      id: j['slug'] as String,
      name: (j['name'] as String?) ?? (j['slug'] as String),
      assetPath: ThemeCatalog.resolve(j['poster'] as String?, base) ?? ThemeCatalog.offlineWallpaperAsset,
      videoPath: ThemeCatalog.resolve(j['video'] as String?, base),
      stillPath: ThemeCatalog.resolve(j['still'] as String?, base),
      isPremium: premium,
      creator: (j['creator'] as String?) ?? 'Collider Studio',
      tier: (j['tier'] as String?) ?? (premium ? 'Elite 4K Live Pack' : 'Free Spatial Canvas'),
      collection: (j['collection'] as String?) ?? 'Spatial Ambient Series',
      productId: (j['productId'] as String?) ?? (premium ? 'collider.theme.${j['slug']}' : null),
      priceLabel: j['price'] as String?,
      tracks: tracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': id,
        'name': name,
        'collection': collection,
        'creator': creator,
        'tier': tier,
        'premium': isPremium,
        'price': priceLabel,
        'productId': productId,
        'poster': assetPath,
        'video': videoPath,
        if (stillPath != null) 'still': stillPath,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

/// Compatibility facade over [ThemeCatalog] (runtime-loaded catalog).
/// Existing call sites keep working; new code should use ThemeCatalog.instance.
class WallpaperCatalog {
  WallpaperCatalog._();

  static List<WallpaperTheme> get freeThemes => ThemeCatalog.instance.freeThemes;
  static List<WallpaperTheme> get premiumThemes => ThemeCatalog.instance.premiumThemes;
  static WallpaperTheme get defaultTheme => ThemeCatalog.instance.defaultTheme;
}
