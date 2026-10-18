import Foundation

typealias CommentReplyLoadAction = @MainActor @Sendable (Int) async -> Void
typealias CommentDialogLoadAction = @MainActor @Sendable (Int, Int) async -> Void

@MainActor
struct VideoDetailReplySheetActions {
    let viewModel: VideoDetailViewModel

    func loadReplies(for rootID: Int) async {
        await viewModel.loadReplies(for: rootID)
    }

    func reloadReplies(for rootID: Int) async {
        await viewModel.reloadReplies(for: rootID)
    }

    func loadMoreReplies(for rootID: Int) async {
        await viewModel.loadMoreReplies(for: rootID)
    }

    func loadDialog(for rootID: Int, replyID: Int) async {
        await viewModel.loadDialog(for: rootID, replyID: replyID)
    }

    func reloadDialog(for rootID: Int, replyID: Int) async {
        await viewModel.reloadDialog(for: rootID, replyID: replyID)
    }

    func toggleCommentLike(_ comment: Comment) {
        viewModel.toggleCommentLike(comment)
    }
}
