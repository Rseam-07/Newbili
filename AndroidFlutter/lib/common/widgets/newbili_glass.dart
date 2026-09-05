import 'dart:ui';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/utils/android/glass_capability.dart';
import 'package:material_ui/material_ui.dart';

enum NewbiliGlassRole { navigation, toolbar, player, sheet, card, button }

class NewbiliGlassSurface extends StatelessWidget {
  const NewbiliGlassSurface({
    super.key,
    required this.child,
    this.role = NewbiliGlassRole.card,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  final Widget child;
  final NewbiliGlassRole role;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  bool get _isRealtime => switch (role) {
    NewbiliGlassRole.navigation ||
    NewbiliGlassRole.toolbar ||
    NewbiliGlassRole.player ||
    NewbiliGlassRole.sheet => true,
    NewbiliGlassRole.card || NewbiliGlassRole.button => false,
  };

  @override
  Widget build(BuildContext context) {
    // Scrolling cards are static material: no capability listener, backdrop
    // filter or per-card glow. Only fixed chrome needs the live effect tier.
    if (!_isRealtime) {
      return _surface(context, NewbiliGlassTier.staticMaterial, child);
    }
    return ListenableBuilder(
      listenable: NewbiliGlassCapability.instance,
      child: child,
      builder: (context, child) =>
          _surface(context, NewbiliGlassCapability.instance.tier, child!),
    );
  }

  Widget _surface(BuildContext context, NewbiliGlassTier tier, Widget child) {
    final visual = context.newbiliVisual;
    final radius =
        borderRadius ??
        BorderRadius.circular(
          role == NewbiliGlassRole.card
              ? NewbiliMetrics.cardRadius
              : NewbiliMetrics.chromeRadius,
        );
    final realtime = _isRealtime && tier != NewbiliGlassTier.staticMaterial;
    final blur = tier == NewbiliGlassTier.enhanced ? 22.0 : 15.0;
    // Player controls have white glyphs in both app appearances.
    final tint = role == NewbiliGlassRole.player
        ? const Color(0xFF1C1C1E).withValues(alpha: realtime ? .74 : .94)
        : realtime
        ? visual.acrylicTint
        : visual.acrylicTintStrong;

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: radius,
        border: Border.all(
          color: role == NewbiliGlassRole.player
              ? Colors.white.withValues(alpha: .22)
              : visual.stroke,
        ),
        boxShadow: _isRealtime
            ? [
                BoxShadow(
                  color: visual.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        gradient: _isRealtime
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: .12), tint),
                  tint,
                  Color.alphaBlend(
                    Theme.of(context).colorScheme.primary
                        .withValues(alpha: .025),
                    tint,
                  ),
                ],
                stops: const [0, .46, 1],
              )
            : null,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (realtime) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: content);
  }
}

class NewbiliAtmosphere extends StatelessWidget {
  const NewbiliAtmosphere({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return ColoredBox(
      color: backgroundColor ?? scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: backgroundColor != null
              ? null
              : RadialGradient(
                  center: const Alignment(-1.15, -.7),
                  radius: 1.1,
                  colors: [
                    scheme.primary.withValues(alpha: dark ? .13 : .22),
                    Colors.transparent,
                  ],
                ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: backgroundColor != null
                ? null
                : RadialGradient(
                    center: const Alignment(1.1, 1),
                    radius: .9,
                    colors: [
                      const Color(0xFF74DDF4)
                          .withValues(alpha: dark ? .07 : .10),
                      Colors.transparent,
                    ],
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}
