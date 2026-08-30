import SwiftUI

struct PlayerNativeGlassIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let systemName: String
    let accessibilityLabel: String
    let metrics: PlayerNativeControlMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .contentTransition(
                    reduceMotion
                        ? .opacity
                        : .symbolEffect(.replace)
                )
                .frame(
                    width: metrics.controlHeight,
                    height: metrics.controlHeight
                )
        }
        .buttonStyle(PlayerNativePressFeedbackButtonStyle(reduceMotion: reduceMotion))
        .contentShape(Circle())
        .biliPlayerClearGlass(interactive: true, in: Circle(), isEnabled: true)
        .biliPlayerExpandedHitTarget(metrics: metrics)
        .animation(
            AppMotion.feedback(reduceMotion: reduceMotion),
            value: systemName
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconSize: CGFloat {
        metrics.iconSize
    }
}

private struct PlayerNativePressFeedbackButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.94)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                AppMotion.feedback(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}
