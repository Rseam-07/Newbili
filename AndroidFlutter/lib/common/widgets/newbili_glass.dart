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
    return ListenableBuilder(
      listenable: NewbiliGlassCapability.instance,
      builder: (context, _) {
        final visual = context.newbiliVisual;
        final tier = NewbiliGlassCapability.instance.tier;
        final radius =
            borderRadius ??
            BorderRadius.circular(
              role == NewbiliGlassRole.card
                  ? NewbiliMetrics.cardRadius
                  : NewbiliMetrics.chromeRadius,
            );
        final realtime = _isRealtime && tier != NewbiliGlassTier.staticMaterial;
        final blur = tier == NewbiliGlassTier.enhanced ? 22.0 : 15.0;
        final tint = realtime ? visual.acrylicTint : visual.acrylicTintStrong;

        Widget content = DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
            border: Border.all(color: visual.stroke),
            boxShadow: [
              BoxShadow(
                color: visual.shadow,
                blurRadius: role == NewbiliGlassRole.card ? 12 : 24,
                offset: const Offset(0, 8),
              ),
              if (tier == NewbiliGlassTier.enhanced)
                BoxShadow(color: visual.glow, blurRadius: 18),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .12),
                tint,
                Theme.of(context).colorScheme.primary.withValues(alpha: .055),
              ],
              stops: const [0, .46, 1],
            ),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        );

        if (realtime) {
          content = ClipRRect(
            borderRadius: radius,
            child: BackdropFilter.grouped(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            ),
          );
        }

        return Padding(padding: margin ?? EdgeInsets.zero, child: content);
      },
    );
  }
}

class NewbiliAtmosphere extends StatelessWidget {
  const NewbiliAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visual = context.newbiliVisual;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.canvasGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(.75, -.92),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.glow,
                  boxShadow: [BoxShadow(color: visual.glow, blurRadius: 100)],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
