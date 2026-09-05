import 'package:material_ui/material_ui.dart';

/// iOS-aligned glass surfaces, using Material 3 interactions on Android.
@immutable
class NewbiliVisualTheme extends ThemeExtension<NewbiliVisualTheme> {
  const NewbiliVisualTheme({
    required this.acrylicTint,
    required this.acrylicTintStrong,
    required this.stroke,
    required this.shadow,
  });

  factory NewbiliVisualTheme.from(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return NewbiliVisualTheme(
      acrylicTint: scheme.surface.withValues(alpha: isDark ? .72 : .90),
      acrylicTintStrong: scheme.surfaceContainerLow.withValues(
        alpha: .96,
      ),
      stroke: Colors.white.withValues(alpha: isDark ? .16 : .78),
      shadow: Colors.black.withValues(alpha: isDark ? .24 : .07),
    );
  }

  final Color acrylicTint;
  final Color acrylicTintStrong;
  final Color stroke;
  final Color shadow;

  @override
  NewbiliVisualTheme copyWith({
    Color? acrylicTint,
    Color? acrylicTintStrong,
    Color? stroke,
    Color? shadow,
  }) {
    return NewbiliVisualTheme(
      acrylicTint: acrylicTint ?? this.acrylicTint,
      acrylicTintStrong: acrylicTintStrong ?? this.acrylicTintStrong,
      stroke: stroke ?? this.stroke,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  NewbiliVisualTheme lerp(
    covariant ThemeExtension<NewbiliVisualTheme>? other,
    double t,
  ) {
    if (other is! NewbiliVisualTheme) return this;
    return NewbiliVisualTheme(
      acrylicTint: Color.lerp(acrylicTint, other.acrylicTint, t)!,
      acrylicTintStrong: Color.lerp(
        acrylicTintStrong,
        other.acrylicTintStrong,
        t,
      )!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension NewbiliVisualThemeContext on BuildContext {
  NewbiliVisualTheme get newbiliVisual =>
      Theme.of(this).extension<NewbiliVisualTheme>() ??
      NewbiliVisualTheme.from(Theme.of(this).colorScheme);
}

abstract final class NewbiliMotion {
  static const feedback = Duration(milliseconds: 160);
  static const container = Duration(milliseconds: 280);
  static const route = Duration(milliseconds: 320);
}

abstract final class NewbiliMetrics {
  static const minTouchTarget = 48.0;
  static const compactRadius = 14.0;
  static const cardRadius = 14.0;
  static const chromeRadius = 26.0;
  static const paneBreakpoint = 1024.0;
}
