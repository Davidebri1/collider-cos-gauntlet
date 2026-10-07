import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../theme/edge_fade.dart';
import '../theme/specular_border.dart';
import 'vision_tokens.dart';

export 'vision_tokens.dart';
export '../theme/edge_fade.dart';
export 'md_text.dart';

/// Glass material levels, mapped to the Collider depth planes.
enum VMaterial { prompt, resting, elevated, modal, work }

extension VMaterialX on VMaterial {
  Color get fill => switch (this) {
        VMaterial.prompt => VColors.glassPrompt,
        VMaterial.resting => VColors.glassResting,
        VMaterial.elevated => VColors.glassElevated,
        VMaterial.modal => VColors.glassModal,
        VMaterial.work => VColors.glassWork,
      };
  double get blur => switch (this) {
        VMaterial.prompt => 16,
        VMaterial.resting => 24,
        VMaterial.elevated => 28,
        VMaterial.modal => 32,
        VMaterial.work => 36,
      };
  Color get rim => switch (this) {
        VMaterial.prompt || VMaterial.resting => const Color(0x2EFFFFFF),
        VMaterial.elevated => const Color(0x3DFFFFFF),
        VMaterial.modal => const Color(0x47FFFFFF),
        VMaterial.work => const Color(0x52FFFFFF),
      };
  List<BoxShadow> get shadow => switch (this) {
        VMaterial.prompt || VMaterial.resting => VShadow.medium,
        _ => VShadow.heavy,
      };
}

/// One-pass glass surface: blur + material fill + hairline + specular rim.
/// Never nest a VGlass inside another VGlass; use plain fills inside.
class VGlass extends StatelessWidget {
  final Widget child;
  final VMaterial material;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? fill;
  final bool shadow;

  const VGlass({
    super.key,
    required this.child,
    this.material = VMaterial.resting,
    this.radius = VRadius.card,
    this.padding = EdgeInsets.zero,
    this.fill,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow ? material.shadow : null),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: material.blur, sigmaY: material.blur),
          child: CustomPaint(
            foregroundPainter: SpecularRimPainter(borderRadius: radius, strokeWidth: 0.6),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: fill ?? material.fill,
                borderRadius: r,
                border: Border.all(color: material.rim, width: 0.5),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Click-away layer behind an overlay: a light, unblurred dim (VOverlay.scrim)
/// so the wallpaper and resting content stay readable around the menu.
class VScrim extends StatelessWidget {
  final VoidCallback? onTap;
  final bool blur;
  // Focus windows push the world back with depth of field: blur by default.
  const VScrim({super.key, this.onTap, this.blur = true});

  @override
  Widget build(BuildContext context) {
    final dim = Container(color: VOverlay.scrim);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: blur
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: VBlur.medium, sigmaY: VBlur.medium), child: dim)
          : dim,
    );
  }
}

/// Press physics from the kit: scale 0.97, opacity 0.9.
class VPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  const VPress({super.key, required this.child, this.onTap, this.tooltip});

  @override
  State<VPress> createState() => _VPressState();
}

class _VPressState extends State<VPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled
            ? (_) {
                setState(() => _down = true);
                HapticFeedback.selectionClick();
              }
            : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: AnimatedScale(
          scale: _down ? VMotion.pressedScale : 1,
          duration: VMotion.fast,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _down ? VMotion.pressedOpacity : 1,
            duration: VMotion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 400), child: w);
    }
    return w;
  }
}

/// Circular glass icon button (close, back, more, rail and dock items).
class VCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool selected;
  final bool floating; // own blur when floating directly over the wallpaper
  final String? tooltip;
  final Color? iconColor;

  const VCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 36,
    this.selected = false,
    this.floating = false,
    this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? VColors.fillActive : (floating ? VColors.glassElevated : VColors.fillCell),
        border: Border.all(color: selected ? VColors.borderHeavy : VColors.borderLight, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.46,
        color: iconColor ?? (selected ? VColors.textPrimary : VColors.textSecondary),
      ),
    );
    final body = floating
        ? ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: VBlur.medium, sigmaY: VBlur.medium),
              child: core,
            ),
          )
        : core;
    return Semantics(button: true, label: tooltip, child: VPress(onTap: onTap, tooltip: tooltip, child: body));
  }
}

enum VButtonVariant { primary, secondary, ghost, destructive }

/// Kit Button: height 48 (36 dense), capsule, label 15/500.
class VButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VButtonVariant variant;
  final bool dense;
  final bool expand;

  const VButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.variant = VButtonVariant.secondary,
    this.dense = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (variant) {
      VButtonVariant.primary => (VColors.accentBlue, Colors.white, Colors.transparent),
      VButtonVariant.destructive => (VColors.accentRed, Colors.white, Colors.transparent),
      VButtonVariant.secondary => (VColors.overlayLight, VColors.textPrimary, VColors.borderLight),
      VButtonVariant.ghost => (Colors.transparent, VColors.textPrimary, Colors.transparent),
    };
    final h = dense ? 36.0 : 48.0;
    return VPress(
      onTap: onTap,
      child: Container(
        height: h,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: dense ? VSpace.md : VSpace.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(VRadius.full),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 15 : 17, color: fg),
              const SizedBox(width: VSpace.xs - 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VType.callout(color: fg, weight: FontWeight.w600).copyWith(fontSize: dense ? VType.sm : VType.md),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating capsule ornament (dock, toolbars, transport, URL bar).
class VOrnament extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Axis axis;
  const VOrnament({super.key, required this.child, this.padding = const EdgeInsets.all(6), this.axis = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    return VGlass(
        material: VMaterial.elevated,
        radius: VRadius.full,
        padding: padding,
        child: child,
      );
  }
}

class VRailItem {
  final IconData icon;
  final String label;
  const VRailItem(this.icon, this.label);
}

/// Vertical tab-bar ornament: circles in a glass capsule.
class VOrnamentRail extends StatelessWidget {
  final List<VRailItem> items;
  final int active;
  final ValueChanged<int> onSelect;
  final double size;
  const VOrnamentRail({super.key, required this.items, required this.active, required this.onSelect, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return VOrnament(
      padding: const EdgeInsets.all(VSpace.xxs + 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: VSpace.xs - 2),
            VCircleButton(
              icon: items[i].icon,
              tooltip: items[i].label,
              size: size,
              selected: i == active,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// Segmented capsule (bottom ornament tabs, filters). Scrolls when it overflows.
class VSegmented extends StatelessWidget {
  final List<String> labels;
  final int active;
  final ValueChanged<int> onSelect;
  final bool ornament; // true: floating glass capsule; false: recessed in-window track
  final bool dense; // tighter label padding, so a long tab row fits 430 px (D27)
  const VSegmented({super.key, required this.labels, required this.active, required this.onSelect, this.ornament = true, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            VPress(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: VMotion.fast,
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: dense ? VSpace.xs : VSpace.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == active ? VColors.fillActive : Colors.transparent,
                  borderRadius: BorderRadius.circular(VRadius.full),
                ),
                child: Text(
                  labels[i],
                  style: VType.callout(
                    color: i == active ? VColors.textPrimary : VColors.textSecondary,
                    weight: i == active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (ornament) return VOrnament(padding: const EdgeInsets.all(VSpace.xxs), child: row);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
      child: row,
    );
  }
}

/// Filter chip (capsule).
class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? dot;
  const VChip({super.key, required this.label, this.selected = false, this.onTap, this.dot});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VMotion.fast,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
        decoration: BoxDecoration(
          color: selected ? VColors.fillActive : VColors.fillCell,
          borderRadius: BorderRadius.circular(VRadius.full),
          border: Border.all(color: selected ? VColors.borderHeavy : VColors.borderLight, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: VType.callout(
                  color: selected ? VColors.textPrimary : VColors.textSecondary,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

/// Recessed capsule search field.
class VSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final double height;
  const VSearchField({super.key, this.controller, required this.hint, this.onChanged, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
      decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 17, color: VColors.textTertiary),
          const SizedBox(width: VSpace.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: VColors.textPrimary,
              style: VType.callout(weight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: VType.callout(color: VColors.textTertiary, weight: FontWeight.w400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped list container (account/settings rows).
class VListGroup extends StatelessWidget {
  final List<Widget> children;
  const VListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: VSpace.md, color: VColors.borderLight),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// List row: leading, title, subtitle, trailing / chevron.
class VListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? trailingText;
  final bool chevron;
  final bool selected;
  final VoidCallback? onTap;
  final int subtitleLines;
  /// null: the title wraps in full (model names, v8.3 D44).
  final int? titleLines;

  const VListRow({
    this.titleLines = 1,
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.chevron = false,
    this.selected = false,
    this.onTap,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? VColors.overlayLight : Colors.transparent,
        borderRadius: BorderRadius.circular(selected ? VRadius.md : 0),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: VSpace.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: titleLines, overflow: titleLines == null ? null : TextOverflow.ellipsis, style: VType.body(weight: FontWeight.w500).copyWith(height: VType.normal)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: subtitleLines, overflow: TextOverflow.ellipsis, style: VType.footnote()),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: VSpace.xs),
            Text(trailingText!, style: VType.footnote(color: VColors.textTertiary)),
          ],
          if (trailing != null) ...[const SizedBox(width: VSpace.xs), trailing!],
          if (chevron) ...[
            const SizedBox(width: VSpace.xxs),
            const Icon(Icons.chevron_right_rounded, size: 20, color: VColors.textTertiary),
          ],
        ],
      ),
    );
    return onTap == null ? body : VPress(onTap: onTap, child: body);
  }
}

/// Sidebar menu item: icon in a circle + label; selected = lighter capsule.
class VSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const VSidebarItem({super.key, required this.icon, required this.label, this.selected = false, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VMotion.fast,
        // v8.3 (D44): full labels wrap instead of an ellipsis.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.xs, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? VColors.overlayLight : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.full),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? VColors.fillActive : VColors.fillCell),
              child: Icon(icon, size: 15, color: selected ? VColors.textPrimary : VColors.textSecondary),
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Text(label,
                  style: VType.callout(
                    color: selected ? VColors.textPrimary : VColors.textSecondary,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Provider-colour disc. v8.3 (D44): no initials ("G3", "GN" read as
/// mangled abbreviations); the full name sits beside it.
class VAvatar extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  const VAvatar({super.key, required this.label, required this.color, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Media tile: rounded image, title and subtitle beneath (album grid).
class VTile extends StatelessWidget {
  final Widget media;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double aspect;
  final bool selected;
  const VTile({super.key, required this.media, required this.title, this.subtitle, this.onTap, this.aspect = 1, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? VColors.overlayLight : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.md + 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.md), child: media),
            ),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600)),
            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.caption()),
          ],
        ),
      ),
    );
  }
}

/// Kit toggle: accent blue track when on.
class VToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const VToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: VMotion.fast,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? VColors.accentBlue : VColors.overlayDark,
          borderRadius: BorderRadius.circular(VRadius.full),
        ),
        child: AnimatedAlign(
          duration: VMotion.fast,
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: VShadow.subtle),
          ),
        ),
      ),
    );
  }
}

/// visionOS window bar: dot + grabber capsule beneath a window.
class VWindowBar extends StatelessWidget {
  const VWindowBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.textTertiary)),
        const SizedBox(width: VSpace.xs),
        Container(width: 64, height: 5, decoration: BoxDecoration(color: VColors.textSecondary, borderRadius: BorderRadius.circular(VRadius.full))),
      ],
    );
  }
}

/// A bounded glass window with a visionOS header: leading circle, title, trailing circles.
class VWindow extends StatelessWidget {
  final String? title;
  final bool largeTitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry contentPadding;
  final VMaterial material;
  final bool centerTitle;
  final bool windowBar;

  const VWindow({
    super.key,
    this.title,
    this.largeTitle = false,
    this.leading,
    this.actions = const [],
    required this.child,
    this.maxWidth = 420,
    this.maxHeight,
    this.contentPadding = const EdgeInsets.fromLTRB(VSpace.md, 0, VSpace.md, VSpace.md),
    this.material = VMaterial.modal,
    this.centerTitle = false,
    this.windowBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = (title != null || leading != null || actions.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
            child: SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (title != null)
                    Positioned.fill(
                      left: centerTitle ? 48 : (leading != null ? 48 : VSpace.xxs),
                      right: centerTitle ? 48 : (actions.length * 42.0),
                      child: Align(
                        alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: largeTitle ? VType.title() : VType.headline(),
                        ),
                      ),
                    ),
                  if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
                  if (actions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          actions[i],
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          )
        : const SizedBox(height: VSpace.md);

    final window = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight ?? double.infinity),
        child: VGlass(
        material: material,
        radius: VRadius.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Flexible(child: Padding(padding: contentPadding, child: child)),
          ],
        ),
      ),
    );
    if (!windowBar) return window;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: window),
      const SizedBox(height: VSpace.sm),
      const VWindowBar(),
    ]);
  }
}

/// One button of a [VAlert].
class VAlertChoice {
  final String label;
  final bool destructive;
  const VAlertChoice(this.label, {this.destructive = false});
}

/// Alert (map row 22, Prime Video visionOS 130:75006): a centred glass card,
/// 320 wide, radius 32: an icon in a white 56 circle, a bold title, one line,
/// a hairline, then the actions stacked as plain 52-high text rows.
class VAlert extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final List<VAlertChoice> actions;
  final ValueChanged<int> onSelect;
  final int messageLines;
  const VAlert({super.key, this.icon, required this.title, this.message, required this.actions, required this.onSelect, this.messageLines = 2});

  /// v8.4: Figma Alert 130:75006 (320 wide) built at its own geometry and
  /// scaled as one unit: crop = alert + 24 px margin each side (368).
  static const double cropWidth = 368;

  @override
  Widget build(BuildContext context) {
    final k = MediaQuery.sizeOf(context).width / cropWidth;
    return SizedBox(
      width: 320 * k,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        child: SizedBox(width: 320, child: _body()),
      ),
    );
  }

  // p20, gap 8, radius 32, 1.4 px white .4 stroke, glass rgba(128,128,128,.3)
  // over blur 50; icon 52; title SF Bold 19/24 white .96 and description
  // 15/20 #545454 (px16 py8, gap 2); separator; buttons 280 x 44, radius 16,
  // SF Semibold 17 white .96.
  Widget _body() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x4D808080),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0x66FFFFFF), width: 1.4),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Icon(icon ?? Icons.info_outline_rounded, size: 28, color: const Color(0xFF3A3A3C)),
              ),
              const SizedBox(height: 8),
              Container(
                width: 270,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 19, height: 24 / 19, fontWeight: FontWeight.w700, color: const Color(0xF5FFFFFF))),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(message!, textAlign: TextAlign.center, maxLines: messageLines, overflow: TextOverflow.ellipsis,
                        // Figma: #545454 with plus-lighter vibrancy, which reads as a
                        // light grey over the glass; Flutter text has no plus-lighter
                        // blend, so the rendered tone is used.
                        style: GoogleFonts.inter(fontSize: 15, height: 20 / 15, color: const Color(0xA6FFFFFF))),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(height: 1, decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(100))),
              ),
              for (int i = 0; i < actions.length; i++) ...[
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: actions[i].label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Container(
                      width: 280,
                      height: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        actions[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: actions[i].destructive ? const Color(0xFFFF6961) : const Color(0xF5FFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> showVAlert(
  BuildContext context, {
  IconData? icon,
  required String title,
  String? message,
  required List<VAlertChoice> actions,
  int messageLines = 2,
}) =>
    showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      // Figma 130:75006: no dimming behind the alert.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
      pageBuilder: (ctx, _, __) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: VAlert(icon: icon, title: title, message: message, actions: actions, messageLines: messageLines, onSelect: (i) => Navigator.of(ctx).pop(i)),
        ),
      ),
    );

/// Section title (window content headings: "My Albums", "Good morning").
class VSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final bool large;
  const VSectionTitle(this.text, {super.key, this.trailing, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: large ? VType.title() : VType.title2())),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Scroll view whose content dissolves at its edges (the faded-edge technique).
class VFadeScroll extends StatelessWidget {
  final Widget child;
  final double fade;
  final EdgeInsetsGeometry padding;
  final Axis axis;
  const VFadeScroll({super.key, required this.child, this.fade = 18, this.padding = EdgeInsets.zero, this.axis = Axis.vertical});

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      scrollDirection: axis,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: child,
    );
    if (axis == Axis.horizontal) {
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final f = (fade / (rect.width <= 0 ? 1 : rect.width)).clamp(0.0, 0.3);
          return LinearGradient(
            colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
            stops: [0, f, 1 - f, 1],
          ).createShader(rect);
        },
        child: scroll,
      );
    }
    return EdgeFade(fadeHeight: fade, child: scroll);
  }
}

/// One row of a [GlassMenu].
class GlassMenuRow {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;
  /// A switch row (Incognito) vs a row that opens something (Account).
  final bool toggle;
  const GlassMenuRow({required this.icon, required this.label, this.on = false, this.onTap, this.toggle = true});
}

/// VisionOS Autolayout Menu (Figma 4CLz2H5l84ILrVUyskOnAS 1:3), built at its
/// own Figma geometry and scaled as one unit (v8.4): width 240, padding 16,
/// gap 4, rows 208 x 40 (icon wrapper p8 around a 24 icon, gap 16, Inter
/// Medium 16 white; inactive rows at 60 %), radius 24, 1 px white border,
/// backdrop blur 40, gradient fill rgba(79,79,79,.1) / white .1 at 127 deg.
/// The active row: gradient white .16 -> 0 (94.5 deg), icon disc white .3.
/// [scale] defaults to screen width / 637 (the Figma frame width), so the
/// menu covers the same 37.7 % of the screen width as in the frame.
class GlassMenu extends StatelessWidget {
  final List<GlassMenuRow> rows;
  /// Width in Figma px (240 in the frame).
  final double width;
  final double? scale;
  const GlassMenu({super.key, required this.rows, this.width = 240, this.scale});

  static const double frameWidth = 637;
  static double scaleFor(BuildContext context) => MediaQuery.sizeOf(context).width / frameWidth;
  static double heightFor(int n) => 32 + n * 40 + (n > 0 ? (n - 1) * 4 : 0);

  @override
  Widget build(BuildContext context) {
    final k = scale ?? scaleFor(context);
    final h = heightFor(rows.length);
    return SizedBox(
      width: width * k,
      height: h * k,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: width,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20 * k, sigmaY: 20 * k),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 1),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.8, -1),
                    end: Alignment(0.8, 1),
                    colors: [Color(0x1A4F4F4F), Color(0x1A4F4F4F), Color(0x1AFFFFFF), Color(0x1A4F4F4F)],
                    stops: [0.017, 0.0175, 0.33, 0.97],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _row(rows[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(GlassMenuRow r) {
    final op = r.on ? 1.0 : (r.onTap == null ? 0.3 : 0.6);
    return Semantics(
      button: true,
      toggled: r.toggle ? r.on : null,
      label: r.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: r.onTap,
        child: AnimatedContainer(
          duration: VMotion.fast,
          width: 208,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            gradient: r.on ? const LinearGradient(colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)], stops: [0.005, 1.4]) : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: VMotion.fast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(61), color: r.on ? const Color(0x4DFFFFFF) : Colors.transparent),
                child: Icon(r.icon, size: 24, color: Colors.white.withValues(alpha: op)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  r.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: op)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
