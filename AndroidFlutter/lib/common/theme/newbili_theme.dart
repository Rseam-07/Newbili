import 'package:material_ui/material_ui.dart';

/// Fluent visual aliases layered on Material 3 without forking business views.
@immutable
class NewbiliVisualTheme extends ThemeExtension<NewbiliVisualTheme> {
  const NewbiliVisualTheme({
    required this.canvasGradient,
    required this.acrylicTint,
    required this.acrylicTintStrong,
    required this.stroke,
    required this.strokeStrong,
    required this.glow,
    required this.shadow,
  });

  factory NewbiliVisualTheme.from(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return NewbiliVisualTheme(
      canvasGradient: [
        Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? .10 : .07),
          scheme.surface,
        ),
        Color.alphaBlend(
          scheme.tertiary.withValues(alpha: isDark ? .07 : .045),
          scheme.surface,
        ),
        scheme.surface,
      ],
      acrylicTint: scheme.surface.withValues(alpha: isDark ? .72 : .66),
      acrylicTintStrong: scheme.surfaceContainerHigh.withValues(
        alpha: isDark ? .88 : .82,
      ),
      stroke: scheme.outlineVariant.withValues(alpha: isDark ? .34 : .42),
      strokeStrong: scheme.onSurface.withValues(alpha: isDark ? .20 : .14),
      glow: scheme.primary.withValues(alpha: isDark ? .22 : .16),
      shadow: Colors.black.withValues(alpha: isDark ? .34 : .12),
    );
  }

  final List<Color> canvasGradient;
  final Color acrylicTint;
  final Color acrylicTintStrong;
  final Color stroke;
  final Color strokeStrong;
  final Color glow;
  final Color shadow;

  @override
  NewbiliVisualTheme copyWith({
    List<Color>? canvasGradient,
    Color? acrylicTint,
    Color? acrylicTintStrong,
    Color? stroke,
    Color? strokeStrong,
    Color? glow,
    Color? shadow,
  }) {
    return NewbiliVisualTheme(
      canvasGradient: canvasGradient ?? this.canvasGradient,
      acrylicTint: acrylicTint ?? this.acrylicTint,
      acrylicTintStrong: acrylicTintStrong ?? this.acrylicTintStrong,
      stroke: stroke ?? this.stroke,
      strokeStrong: strokeStrong ?? this.strokeStrong,
      glow: glow ?? this.glow,
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
      canvasGradient: List<Color>.generate(
        canvasGradient.length,
        (index) => Color.lerp(
          canvasGradient[index],
          other.canvasGradient[index],
          t,
        )!,
      ),
      acrylicTint: Color.lerp(acrylicTint, other.acrylicTint, t)!,
      acrylicTintStrong: Color.lerp(
        acrylicTintStrong,
        other.acrylicTintStrong,
        t,
      )!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
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
  static const cardRadius = 20.0;
  static const chromeRadius = 26.0;
  static const paneBreakpoint = 1024.0;
}
