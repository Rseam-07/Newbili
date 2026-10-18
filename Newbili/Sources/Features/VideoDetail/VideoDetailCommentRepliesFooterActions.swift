import Foundation

@MainActor
struct CommentRepliesFooterActions {
    let rootComment: Comment
    let loadMoreReplies: CommentReplyLoadAction

    func performLoadMoreReplies() {
        let rootID = rootComment.id
        let load = loadMoreReplies
        Task { @MainActor in await load(rootID) }
    }
}
