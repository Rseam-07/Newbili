import SwiftUI

struct CommentRepliesContent: View {
    let rootComment: Comment
    @ObservedObject var store: VideoDetailCommentThreadRenderStore
    let reloadReplies: CommentReplyLoadAction
    let loadMoreReplies: CommentReplyLoadAction
    let showDialog: (Comment) -> Void
    let toggleLike: (Comment) -> Void

    var body: some View {
        let snapshot = store.repliesSnapshot(for: rootComment)

        CommentRepliesContentStateView(
            state: CommentRepliesContentState(snapshot: snapshot),
            snapshot: snapshot,
            rootComment: rootComment,
            reloadReplies: reloadReplies,
            loadMoreReplies: loadMoreReplies,
            showDialog: showDialog,
            toggleLike: toggleLike
        )
    }
}
