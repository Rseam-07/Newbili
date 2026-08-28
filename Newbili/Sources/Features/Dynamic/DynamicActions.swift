import SwiftUI

struct DynamicFeedActionBar: View {
    let display: DynamicFeedCardDisplayModel
    @ObservedObject var likeController: DynamicLikeController
    let onShowComments: () -> Void
    @State private var actionMessage: String?
    @State private var actionMessageTask: Task<Void, Never>?

    init(
        display: DynamicFeedCardDisplayModel,
        likeController: DynamicLikeController,
        onShowComments: @escaping () -> Void
    ) {
        self.display = display
        self.likeController = likeController
        self.onShowComments = onShowComments
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                shareActionPill
                    .frame(maxWidth: .infinity)

                DynamicActionPill(
                    title: display.commentTitle,
                    systemImage: "bubble.left",
                    isSelected: false
                ) {
                    playActionFeedback()
                    onShowComments()
                }
                .frame(maxWidth: .infinity)

                DynamicActionPill(
                    title: likeActionTitle,
                    systemImage: likeController.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    isSelected: likeController.isLiked
                ) {
                    performLikeAction()
                }
                .disabled(likeController.isLoading || likeController.isHydrating || likeController.isMutating)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 3)
        .overlay(alignment: .bottomTrailing) {
            if let actionMessage {
                DynamicActionFeedbackToast(message: actionMessage)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
                    .allowsHitTesting(false)
            }
        }
        .onDisappear {
            actionMessageTask?.cancel()
            actionMessageTask = nil
        }
        .task(id: likeController.dynamicID) {
            await likeController.hydrateIfNeeded()
        }
    }

    private var likeActionTitle: String {
        switch likeController.status {
        case .loading:
            return "加载中"
        case .failed:
            return "重试"
        case .ready:
            return likeController.isMutating
                ? "提交中"
                : DynamicFeedCardDisplayModel.statTitle(
                    count: likeController.likeCount,
                    fallback: "点赞"
                )
        }
    }

    @ViewBuilder
    private var shareActionPill: some View {
        if let url = display.shareURL {
            ShareLink(
                item: url,
                subject: Text(display.shareTitle),
                message: Text(display.shareMessage)
            ) {
                DynamicActionPillLabel(
                    title: "分享",
                    systemImage: "arrowshape.turn.up.right"
                )
            }
            .biliGlassButtonStyle()
            .controlSize(.small)
            .tint(.secondary)
            .frame(maxWidth: .infinity)
            .simultaneousGesture(TapGesture().onEnded { playActionFeedback() })
            .accessibilityLabel("分享动态")
        } else {
            DynamicActionPill(
                title: "分享",
                systemImage: "arrowshape.turn.up.right",
                isSelected: false
            ) {
                showActionMessage("暂无可分享链接")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func performLikeAction() {
        playActionFeedback()
        Task {
            if likeController.hydrationFailureMessage != nil {
                await likeController.hydrateIfNeeded(retryingFailure: true)
                if let message = likeController.hydrationFailureMessage {
                    showActionMessage("状态加载失败：\(message)", playsFeedback: false)
                }
                return
            }
            let outcome = await likeController.toggle()
            switch outcome {
            case .updated(let isLiked):
                showActionMessage(isLiked ? "点赞成功" : "已取消点赞", playsFeedback: false)
            case .failed(let message):
                showActionMessage("操作失败：\(message)", playsFeedback: false)
            case .ignored:
                break
            }
        }
    }

    private func playActionFeedback() {
        Haptics.light()
    }

    private func showActionMessage(_ message: String, playsFeedback: Bool = true) {
        if playsFeedback {
            playActionFeedback()
        }
        actionMessageTask?.cancel()
        withAnimation(.snappy(duration: 0.18)) {
            actionMessage = message
        }
        actionMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.18)) {
                actionMessage = nil
            }
        }
    }
}
