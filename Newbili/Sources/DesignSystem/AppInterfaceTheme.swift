import SwiftUI

private struct AppInterfaceStyleKey: EnvironmentKey {
    static let defaultValue: AppLiquidGlassStylePreference = .current
}

extension EnvironmentValues {
    /// The style captured when the current app process started. Settings write
    /// the next-launch preference instead of rebuilding the active hierarchy.
    var appInterfaceStyle: AppLiquidGlassStylePreference {
        get { self[AppInterfaceStyleKey.self] }
        set { self[AppInterfaceStyleKey.self] = newValue }
    }
}

enum AppFluentSpacing {
    static let xxs = AppInterfaceTokenValues.spacingXXS
    static let xs = AppInterfaceTokenValues.spacingXS
    static let small = AppInterfaceTokenValues.spacingSmall
    static let medium = AppInterfaceTokenValues.spacingMedium
    static let large = AppInterfaceTokenValues.spacingLarge
    static let xlarge = AppInterfaceTokenValues.spacingXLarge
}

enum AppFluentShape {
    static let controlRadius = AppInterfaceTokenValues.controlRadius
    static let surfaceRadius = AppInterfaceTokenValues.surfaceRadius
    static let overlayRadius = AppInterfaceTokenValues.overlayRadius
}

enum AppMotion {
    static let feedbackDuration = AppInterfaceTokenValues.feedbackDuration
    static let enterDuration = AppInterfaceTokenValues.enterDuration
    static let exitDuration = AppInterfaceTokenValues.exitDuration
    static let containerDuration = AppInterfaceTokenValues.containerDuration

    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .timingCurve(
                AppInterfaceTokenValues.standardCurveX1,
                AppInterfaceTokenValues.standardCurveY1,
                AppInterfaceTokenValues.standardCurveX2,
                AppInterfaceTokenValues.standardCurveY2,
                duration: feedbackDuration
            )
    }

    static func topLevel(reduceMotion: Bool) -> Animation? {
        reduceMotion
            ? nil
            : .timingCurve(
                AppInterfaceTokenValues.standardCurveX1,
                AppInterfaceTokenValues.standardCurveY1,
                AppInterfaceTokenValues.standardCurveX2,
                AppInterfaceTokenValues.standardCurveY2,
                duration: feedbackDuration
            )
    }

    static func confirmation(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.24, dampingFraction: 0.72)
    }
}

struct AppFluentPalette {
    let canvas: Color
    let surface: Color
    let raisedSurface: Color
    let contentPrimary: Color
    let contentSecondary: Color
    let subtleStroke: Color
    let strongStroke: Color

    static func resolve(
        colorScheme: ColorScheme,
        contrast: ColorSchemeContrast
    ) -> Self {
        let isDark = colorScheme == .dark
        let isHighContrast = contrast == .increased
        return Self(
            canvas: Color(uiColor: isDark ? .black : .systemGroupedBackground),
            surface: Color(uiColor: isDark ? .secondarySystemBackground : .systemBackground),
            raisedSurface: Color(uiColor: isDark ? .tertiarySystemBackground : .secondarySystemBackground),
            contentPrimary: Color(uiColor: .label),
            contentSecondary: Color(uiColor: .secondaryLabel),
            subtleStroke: Color.primary.opacity(isHighContrast ? 0.28 : (isDark ? 0.18 : 0.10)),
            strongStroke: Color.primary.opacity(isHighContrast ? 0.52 : (isDark ? 0.30 : 0.20))
        )
    }
}

struct AppInterfaceCanvasBackground: View {
    @Environment(\.appInterfaceStyle) private var interfaceStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if interfaceStyle.isFluent {
            let palette = AppFluentPalette.resolve(colorScheme: colorScheme, contrast: contrast)
            ZStack {
                palette.canvas

                if !reduceTransparency {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.07),
                            .clear,
                            Color.blue.opacity(colorScheme == .dark ? 0.06 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()
        } else {
            Color.clear
        }
    }
}

struct AppFluentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        let palette = AppFluentPalette.resolve(colorScheme: colorScheme, contrast: contrast)
        configuration.label
            .foregroundStyle(prominent ? Color.white : palette.contentPrimary)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        prominent
                            ? Color.accentColor.opacity(configuration.isPressed ? 0.78 : 0.94)
                            : palette.raisedSurface.opacity(configuration.isPressed ? 0.78 : 0.92)
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        prominent
                            ? Color.white.opacity(0.16)
                            : (configuration.isPressed ? palette.strongStroke : palette.subtleStroke),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .shadow(
                color: Color.black.opacity(prominent ? 0.14 : 0.08),
                radius: configuration.isPressed ? 2 : 6,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.975)
            .opacity(isEnabled ? 1 : 0.46)
            .animation(
                AppMotion.feedback(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}
