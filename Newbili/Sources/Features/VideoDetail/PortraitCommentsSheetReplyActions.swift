import Foundation

struct PortraitCommentsSheetReplyActions {
    let loadReplies: CommentReplyLoadAction
    let reloadReplies: CommentReplyLoadAction
    let loadMoreReplies: CommentReplyLoadAction
    let loadDialog: CommentDialogLoadAction
    let reloadDialog: CommentDialogLoadAction
    let toggleLike: (Comment) -> Void

    @MainActor
    func loadMoreRepliesAction(_ comment: Comment) {
        let rootID = comment.id
        let load = loadMoreReplies
        Task { @MainActor in await load(rootID) }
    }
}
