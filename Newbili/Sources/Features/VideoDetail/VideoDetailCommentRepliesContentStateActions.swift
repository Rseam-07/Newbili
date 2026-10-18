import Foundation

@MainActor
struct CommentRepliesContentStateActions {
    let rootComment: Comment
    let reloadReplies: CommentReplyLoadAction

    func reloadRepliesAction() {
        let rootID = rootComment.id
        let reload = reloadReplies
        Task { @MainActor in await reload(rootID) }
    }
}
