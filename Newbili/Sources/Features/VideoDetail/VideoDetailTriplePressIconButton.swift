import SwiftUI

struct VideoDetailTriplePressIconButton: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isLiked: Bool
    let isDisabled: Bool
    let likeAction: () -> Void
    let tripleAction: () -> Void

    var body: some View {
        HoldProgressButton(
            isDisabled: isDisabled,
            tapAction: likeAction,
            holdAction: tripleAction,
            milestoneFeedback: { _ in Haptics.light() },
            commitFeedback: Haptics.medium
        ) {
            VideoDetailActionStripIconLabel(
                systemImage: "hand.thumbsup.fill",
                foregroundStyle: isLiked ? appTintColor : .primary
            )
        } progressIndicator: { progress in
            VideoDetailTriplePressProgressIndicator(
                progress: progress,
                tintColor: appTintColor,
                reduceMotion: reduceMotion
            )
        }
        .buttonBorderShape(.circle)
        .controlSize(.mini)
        .biliGlassButtonStyle()
        .opacity(isDisabled ? 0.52 : 1)
        .accessibilityLabel(isLiked ? "已点赞，按住可一键三连" : "点赞，按住可一键三连")
        .accessibilityHint("按住直到进度完成会点赞、投币并收藏；中途松手只会点赞")
        .accessibilityAction(named: "一键三连") {
            guard !isDisabled else { return }
            tripleAction()
        }
        .zIndex(10)
    }
}

private struct VideoDetailTriplePressProgressIndicator: View {
    let progress: Double
    let tintColor: Color
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)

            HStack(spacing: 9) {
                progressIcon("hand.thumbsup.fill", threshold: 1.0 / 3.0)
                progressIcon("bitcoinsign.circle.fill", threshold: 2.0 / 3.0)
                progressIcon("star.fill", threshold: 0.98)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
            .offset(y: -42)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: completedStage)
    }

    @ViewBuilder
    private func progressIcon(_ systemName: String, threshold: Double) -> some View {
        let isCompleted = progress >= threshold
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(isCompleted ? tintColor : .secondary)
            .scaleEffect(reduceMotion || !isCompleted ? 1 : 1.12)
            .frame(width: 18, height: 18)
    }

    private var completedStage: Int {
        if progress >= 0.98 { return 3 }
        if progress >= 2.0 / 3.0 { return 2 }
        if progress >= 1.0 / 3.0 { return 1 }
        return 0
    }
}
