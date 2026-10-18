import SwiftUI

@MainActor
final class VideoCommentComposerContext {
    private let viewModel: VideoDetailViewModel
    private let rootComment: Comment?

    init(viewModel: VideoDetailViewModel, rootComment: Comment? = nil) {
        self.viewModel = viewModel
        self.rootComment = rootComment
    }

    func makeSubmission(root: Comment?, parent: Comment?) -> VideoCommentSubmissionModel? {
        guard let target = viewModel.commentTarget, !viewModel.isPlaybackInvalidatedForNavigation else { return nil }
        let resolvedRoot = root ?? (parent == nil ? nil : rootComment)
        if let resolvedRoot { viewModel.registerReplyRoot(resolvedRoot) }
        let recipient = parent ?? resolvedRoot
        let snapshot = viewModel.sessionStore.credentialSnapshot(
            for: BiliCommentAccountPolicy.submission,
            multiAccountEnabled: viewModel.libraryStore.multiAccountExperimentEnabled
        )
        let accountVersion = snapshot.version
        let accountMID = snapshot.accountMID
        let multiAccountEnabled = viewModel.libraryStore.multiAccountExperimentEnabled
        let rootID = resolvedRoot?.id
        let replyID = parent?.id
        return VideoCommentSubmissionModel(
            target: target, rootID: rootID, parentID: recipient?.id, recipientName: recipient?.member?.uname,
            service: viewModel.api,
            isCurrent: { [weak viewModel] in
                guard let viewModel else { return false }
                let current = viewModel.sessionStore.credentialSnapshot(
                    for: BiliCommentAccountPolicy.submission,
                    multiAccountEnabled: viewModel.libraryStore.multiAccountExperimentEnabled
                )
                return viewModel.commentTarget == target && !viewModel.isPlaybackInvalidatedForNavigation
                    && current.version == accountVersion && current.accountMID == accountMID
                    && viewModel.libraryStore.multiAccountExperimentEnabled == multiAccountEnabled
            },
            didSubmit: { [weak viewModel] in
                guard let viewModel else { return }
                viewModel.interactionMessage = "评论已提交，显示可能稍有延迟"
                let refresh = Task { @MainActor [weak viewModel] in
                    guard let viewModel, viewModel.commentTarget == target, !viewModel.isPlaybackInvalidatedForNavigation else { return }
                    if let rootID {
                        viewModel.commentThreadState.replyThreadLoadTokens[rootID] = nil
                        viewModel.commentThreadState.replyThreadStates[rootID] = .idle
                        await viewModel.reloadReplies(for: rootID)
                        if let replyID { await viewModel.reloadDialog(for: rootID, replyID: replyID) }
                    } else {
                        viewModel.selectedCommentSort = .time
                        await viewModel.retryComments()
                    }
                }
                viewModel.trackBackgroundTask(refresh)
            }
        )
    }

}

private struct VideoCommentComposerContextKey: EnvironmentKey {
    static let defaultValue: VideoCommentComposerContext? = nil
}

extension EnvironmentValues {
    var videoCommentComposerContext: VideoCommentComposerContext? {
        get { self[VideoCommentComposerContextKey.self] }
        set { self[VideoCommentComposerContextKey.self] = newValue }
    }
}
