// Map row 18 (Settings → Account), Figma Vision OS Design System 417:8552:
// a grey sheet with a close circle and a centred title, the profile row,
// a single row with a trailing value and chevron, a grouped list, and a
// standalone row. Filled from the source's Account tab
// (components/SettingsPane.tsx: Plan / Credits / Pool, Upgrade, Sign in)
// and screens/UpgradeScreen.tsx (Free / Pro / Elite with the source prices
// and perks, Continue, Restore). Payments and sign-in need the native
// stores and an auth backend that this link does not have: those actions
// answer inline that they are not available here (H10, D60).
import 'package:flutter/material.dart';

import '../../core/figma/figma_stage.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';

class AccountSheet extends StatefulWidget {
  final ModelTier tier;
  final VoidCallback onClose;
  const AccountSheet({super.key, required this.tier, required this.onClose});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  bool _plans = false;
  String? _note;

  // Figma 417:8552: Menu 448 x 615 centred in the 1920 x 1080 scene; crop =
  // panel + 24 px margin each side (496), so the panel spans 448/496 of the
  // screen width, and 615 / 1080 of the height in Figma.
  static const panel = Size(448, 615);
  static const cropWidth = 496.0;

  void _unavailable(String what) => setState(() => _note = what);

  @override
  Widget build(BuildContext context) {
    final k = MediaQuery.sizeOf(context).width / cropWidth;
    return Stack(
      fit: StackFit.expand,
      children: [
        // No dimming in the frame: a clear tap-to-close layer.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose)),
        Center(
          child: SizedBox(
            width: panel.width * k,
            height: panel.height * k,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox.fromSize(
                size: panel,
                child: FigmaScale(
                  scale: k,
                  child: _Menu(
                    title: _plans ? 'Manage Subscription' : 'Account',
                    leadingIcon: _plans ? Icons.chevron_left_rounded : Icons.close_rounded,
                    leadingLabel: _plans ? 'Back' : 'Close',
                    onLeading: _plans ? () => setState(() => _plans = false) : widget.onClose,
                    children: _plans ? _plansList() : _account(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _account() {
    final info = TierInfo.all[widget.tier]!;
    return [
      // Frame 108: the avatar option row (px16 py12, avatar 60).
      _Group(rows: [
        _Option(
          avatar: true,
          title: 'Sign in',
          subtitle: 'Not signed in',
          onTap: () => showVAlert(context, icon: Icons.person_outline_rounded, title: "Sign-in isn't available on this link", actions: const [VAlertChoice('OK')]),
        ),
      ]),
      const SizedBox(height: 24),
      // Frame 109: one row with a trailing value and chevron.
      _Group(rows: [_Option(title: 'Plan', value: info.label, onTap: () => setState(() => _plans = true))]),
      const SizedBox(height: 24),
      // Frame 110: the grouped list of three.
      _Group(rows: [
        _Option(title: 'Manage Subscription', onTap: () => setState(() => _plans = true)),
        _Option(title: 'Credits', value: '${info.pool}'),
        _Option(title: 'Monthly pool', value: '${info.pool}'),
      ]),
      const SizedBox(height: 24),
      // Frame 112: a standalone row with its description.
      _Group(rows: [_Option(title: 'Restore Purchases', height: 54, onTap: () => _unavailable("Purchases aren't available on this link"))]),
      Padding(
        padding: const EdgeInsets.all(12),
        child: FText(_note ?? 'restore plans bought with this account', size: 13, height: 16, weight: FontWeight.w500, color: const Color(0x99EBEBF5), letterSpacing: -0.4),
      ),
      const SizedBox(height: 16),
      // Frame 43: the next section's title (the panel clips; scroll for it).
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: FText('Plans', size: 22, height: 28, weight: FontWeight.w700),
      ),
      ..._planRows(),
    ];
  }

  List<Widget> _planRows() => [
        for (final t in ModelTier.values) ...[
          _Group(rows: [
            _Option(
              title: '${TierInfo.all[t]!.label}${widget.tier == t ? ' (current)' : ''}',
              subtitle: UpgradePlans.perks[t]!.join(' · '),
              value: TierInfo.all[t]!.price,
              onTap: t == widget.tier ? null : () => _unavailable("Purchases aren't available on this link"),
            ),
          ]),
          const SizedBox(height: 12),
        ],
      ];

  List<Widget> _plansList() => [
        ..._planRows(),
        const SizedBox(height: 12),
        _Group(rows: [_Option(title: 'Restore Purchases', height: 54, onTap: () => _unavailable("Purchases aren't available on this link"))]),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: FText(_note!, size: 13, height: 16, weight: FontWeight.w500, color: const Color(0x99EBEBF5), letterSpacing: -0.4),
          ),
      ];
}

/// UpgradeScreen.tsx: the source's plan perks.
class UpgradePlans {
  static const perks = {
    ModelTier.free: ['Unlimited general chat', '3 models on the board', 'No media generation'],
    ModelTier.pro: ['Unlimited general', 'Image, video, audio', '3,000 media credits / mo'],
    ModelTier.elite: ['Every model', 'Sora, Veo, coding agents', '7,500 media credits / mo'],
  };
}

/// Menu 417:8552: p20, gap 16, radius 42, border rgba(222,222,222,.2), fill
/// rgba(202,202,202,.4) over blur 80, drop shadow 12 black .12, inner 2 px
/// white .8. Header 408 x 44: close 44 (white .2), title SF Bold 22 / 28.
class _Menu extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final String leadingLabel;
  final VoidCallback onLeading;
  final List<Widget> children;
  const _Menu({required this.title, required this.leadingIcon, required this.leadingLabel, required this.onLeading, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: FGlass(
          radius: BorderRadius.circular(42),
          fill: const Color(0x66CACACA),
          blur: 80,
          stroke: const Color(0x33DEDEDE),
          shadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12)],
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: const Color(0x33FFFFFF), width: 1),
            ),
          ),
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 44,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: leadingLabel,
                  child: GestureDetector(
                    onTap: onLeading,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: const Color(0x33E7E7E7), borderRadius: BorderRadius.circular(22)),
                      child: Icon(leadingIcon, size: 22, color: Colors.white),
                    ),
                  ),
                ),
                Expanded(child: Center(child: FText(title, size: 22, height: 28, weight: FontWeight.w700))),
                const SizedBox(width: 44),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Group extends StatelessWidget {
  final List<_Option> rows;
  const _Group({required this.rows});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: const Color(0x8C353631), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(border: i < rows.length - 1 ? const Border(bottom: BorderSide(color: Color(0x33DEDEDE), width: 0.5)) : null),
              child: rows[i],
            ),
        ]),
      );
}

/// option list: p16 (avatar rows px16 py12), SF Medium 17/22 #ededf2,
/// note 15/20 rgba(235,235,245,.6), chevron 28.
class _Option extends StatelessWidget {
  final bool avatar;
  final String title;
  final String? subtitle;
  final String? value;
  final double height;
  final VoidCallback? onTap;
  const _Option({this.avatar = false, required this.title, this.subtitle, this.value, this.onTap, this.height = 60});
  @override
  Widget build(BuildContext context) {
    const label2 = Color(0xFFEDEDF2), label4 = Color(0x99EBEBF5);
    final body = Container(
      constraints: BoxConstraints(minHeight: avatar ? 84 : height),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: avatar ? 12 : 16),
      child: Row(children: [
        if (avatar) ...[
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
            child: const Icon(Icons.person_rounded, size: 34, color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FText(title, size: 17, height: 22, weight: FontWeight.w500, color: label2, letterSpacing: -0.4),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              FText(subtitle!, size: 15, height: 20, weight: FontWeight.w500, color: label4, letterSpacing: -0.4, maxLines: 2),
            ],
          ]),
        ),
        if (value != null) FText(value!, size: 15, height: 20, weight: FontWeight.w500, color: label4, letterSpacing: -0.4),
        if (onTap != null) const SizedBox(width: 28, height: 28, child: Icon(Icons.chevron_right_rounded, size: 22, color: label4)),
      ]),
    );
    if (onTap == null) return body;
    return Semantics(button: true, label: title, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body));
  }
}
