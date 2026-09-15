import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

enum NewbiliSurfaceRole { navigation, toolbar, player, sheet, card, button }

/// Opaque Material surfaces: depth comes from tonal roles and modest elevation.
class NewbiliSurface extends StatelessWidget {
  const NewbiliSurface({
    super.key,
    required this.child,
    this.role = NewbiliSurfaceRole.card,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  final Widget child;
  final NewbiliSurfaceRole role;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      NewbiliSurfaceRole.navigation => scheme.surfaceContainer,
      NewbiliSurfaceRole.toolbar ||
      NewbiliSurfaceRole.button => scheme.surfaceContainerHigh,
      NewbiliSurfaceRole.sheet => scheme.surfaceContainerLow,
      NewbiliSurfaceRole.player => const Color(0xFF202124),
      NewbiliSurfaceRole.card => scheme.surfaceContainerLow,
    };
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color,
        surfaceTintColor: Colors.transparent,
        elevation: role == NewbiliSurfaceRole.sheet ? 2 : 0,
        borderRadius:
            borderRadius ??
            BorderRadius.circular(
              role == NewbiliSurfaceRole.card
                  ? NewbiliMetrics.cardRadius
                  : NewbiliMetrics.compactRadius,
            ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
