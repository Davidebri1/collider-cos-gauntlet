import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Market switches, all off (David put the 2026-09-29 asks on hold, v8.3).
///
/// TEST PRICING: while true, every theme pack and the store subscription
/// cost $0.00 so the purchase flow can be tested end to end. Off: packs show
/// the catalog / S-C19 price.
const bool kTestFreePricing = false;

/// SUBSCRIPTION GATE (DEVIATIONS.md D6): while true, non-subscribers see the
/// first 3 themes only, with a subscription line and a Subscribe capsule
/// instead of Buy. Off: every theme, Buy / Apply, no subscription text.
const bool kSubscriptionGate = false;

/// A real store backend (StoreKit / Play Billing) is wired. Off on the web
/// link: Buy says purchases aren't available rather than unlocking for free.

/// OWNED BRIGHTER STATE (DEVIATIONS.md D5): while true, covers and the
/// background preview of themes the user does not own are dimmed and an
/// owned theme's preview lifts to full brightness. Off: the export's look
/// (brightness 0.5 / opacity 0.7 preview, undimmed covers) for every theme.
const bool kOwnedBrighterState = false;

/// Theme pack IAP scaffold — productId per Designer premium slug.
/// Web/sandbox: mock buy unlocks locally via SharedPreferences.
class ThemePackStore extends ChangeNotifier {
  ThemePackStore._();
  static final ThemePackStore instance = ThemePackStore._();

  static const _prefsKey = 'theme_pack_unlocked_ids';
  static const _subKey = 'theme_store_subscription_active';

  /// Price label shown while [kTestFreePricing] is on.
  static const String freePriceLabel = r'$0.00';

  /// Store subscription price label; null when no price is configured.
  static String? get subscriptionPriceLabel => kTestFreePricing ? freePriceLabel : null;

  /// Non-subscribers see this many themes (dimmed live previews) and no store.
  static const int previewCountWithoutSubscription = 3;

  bool _subscribed = false;

  /// Paid store subscription (mock entitlement; persisted like pack unlocks).
  bool get isSubscribed => _subscribed;

  /// The whole store is open: no gate ([kSubscriptionGate] off), or subscribed.
  bool get storeOpen => !kSubscriptionGate || _subscribed;

  final Set<String> _unlocked = {};
  bool _ready = false;
  bool get isReady => _ready;

  static const bool purchasesAvailable = bool.fromEnvironment('COLLIDER_STORE');

  static const Map<String, String> productIds = {
    'obsidian-rain': 'collider.theme.obsidian-rain',
    'limestone-dust': 'collider.theme.limestone-dust',
    'glasshouse-fog': 'collider.theme.glasshouse-fog',
    'copper-kiln': 'collider.theme.copper-kiln',
    'tide-concrete': 'collider.theme.tide-concrete',
    'paper-lantern-alley': 'collider.theme.paper-lantern-alley',
    'snowmelt-atrium': 'collider.theme.snowmelt-atrium',
    'lantern-alley': 'collider.theme.lantern-alley',
    'tide-glass': 'collider.theme.tide-glass',
    'observatory': 'collider.theme.observatory',
    'brutal-atrium': 'collider.theme.brutal-atrium',
    'bamboo-corridor': 'collider.theme.bamboo-corridor',
    'canopy-shafts': 'collider.theme.canopy-shafts',
    'salt-flat-dusk': 'collider.theme.salt-flat-dusk',
    'harbor-crane-night': 'collider.theme.harbor-crane-night',
    'gilt-arcade': 'collider.theme.gilt-arcade',
    'indigo-dye-vat': 'collider.theme.indigo-dye-vat',
    'earthen-kiln': 'collider.theme.earthen-kiln',
    'subway-platform': 'collider.theme.subway-platform',
  };

  /// Fallback pack price when the catalog carries none (live wallpaper + 5 tracks).
  static const String packPriceLabel = r'$5.99';

  /// S-C19 price band for one pack.
  static const double minPackPrice = 2.99;
  static const double maxPackPrice = 7.99;

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _subscribed = prefs.getBool(_subKey) ?? false;
    _ready = true;
    notifyListeners();
  }

  bool isUnlocked(String slug) => _unlocked.contains(slug);

  /// Store product id: `collider.theme.<slug>`.
  String productIdFor(String slug) => 'collider.theme.$slug';

  /// The catalog's per-theme price (themes.json `price`) when it is a valid
  /// label inside the S-C19 band ($2.99-$7.99); otherwise [packPriceLabel].
  String priceLabelFor(String slug, {String? catalogPrice}) {
    if (kTestFreePricing) return freePriceLabel;
    final m = RegExp(r'^\$(\d+(?:\.\d{2})?)$').firstMatch(catalogPrice?.trim() ?? '');
    final v = m == null ? null : double.tryParse(m.group(1)!);
    if (v != null && v >= minPackPrice && v <= maxPackPrice) return catalogPrice!.trim();
    return packPriceLabel;
  }

  Future<bool> buyPack(String slug) async {
    await init();
    _unlocked.add(slug);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Mock store subscription ($0 while [kTestFreePricing]). Same sandbox path as
  /// [buyPack]: the entitlement is recorded locally.
  Future<bool> subscribe() async {
    await init();
    _subscribed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subKey, true);
    notifyListeners();
    return true;
  }

  /// Test hook: `?store=reset` clears the subscription and every pack unlock.
  Future<void> resetForTesting() async {
    await init();
    _subscribed = false;
    _unlocked.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subKey);
    await prefs.remove(_prefsKey);
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _subscribed = prefs.getBool(_subKey) ?? false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _unlocked.toList()..sort());
  }
}
