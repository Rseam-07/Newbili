import SwiftUI

extension View {
    @ViewBuilder
    func biliPlayerCompactGlassCircle(
        metrics: PlayerNativeControlMetrics,
        isEnabled: Bool = true
    ) -> some View {
        buttonStyle(.plain)
            .contentShape(Circle())
            .biliPlayerClearGlass(interactive: true, in: Circle(), isEnabled: isEnabled)
            .biliPlayerExpandedHitTarget(metrics: metrics)
    }

    @ViewBuilder
    func biliPlayerCompactGlassCapsule(
        metrics: PlayerNativeControlMetrics,
        isEnabled: Bool = true
    ) -> some View {
        buttonStyle(.plain)
            .contentShape(Capsule())
            .biliPlayerClearGlass(interactive: true, in: Capsule(), isEnabled: isEnabled)
            .biliPlayerExpandedHitTarget(metrics: metrics)
    }

    @ViewBuilder
    func biliPlayerClearGlass<S: Shape>(
        interactive: Bool,
        in shape: S,
        isEnabled: Bool = true
    ) -> some View {
        if isEnabled {
            modifier(BiliPlayerClearGlassModifier(interactive: interactive, shape: shape))
        } else {
            self
        }
    }

    func biliPlayerExpandedHitTarget(horizontal: CGFloat = 4, vertical: CGFloat = 8) -> some View {
        padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .contentShape(Rectangle())
            .padding(.horizontal, -horizontal)
            .padding(.vertical, -vertical)
    }

    func biliPlayerExpandedHitTarget(metrics: PlayerNativeControlMetrics) -> some View {
        // Occupy the hit area in layout; negative padding made adjacent 28 pt
        // buttons claim overlapping 44 pt tap regions.
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct BiliPlayerGlassSheetBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .biliRegularGlassEffect(interactive: false, in: Rectangle())
    }
}

private struct BiliPlayerClearGlassModifier<GlassShape: Shape>: ViewModifier {
    let interactive: Bool
    let shape: GlassShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                .clear
                    .interactive(interactive),
                in: shape
            )
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}
