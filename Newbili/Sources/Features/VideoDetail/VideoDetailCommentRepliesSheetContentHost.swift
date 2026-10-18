import SwiftUI

struct CommentRepliesSheetContentHost: View {
    let rootComment: Comment
    let store: VideoDetailCommentThreadRenderStore
    let reloadReplies: CommentReplyLoadAction
    let loadMoreReplies: CommentReplyLoadAction
    let showDialog: (Comment) -> Void
    let toggleLike: (Comment) -> Void
    let loadReplies: CommentReplyLoadAction

    init(
        rootComment: Comment,
        store: VideoDetailCommentThreadRenderStore,
        reloadReplies: @escaping CommentReplyLoadAction,
        loadMoreReplies: @escaping CommentReplyLoadAction,
        showDialog: @escaping (Comment) -> Void,
        toggleLike: @escaping (Comment) -> Void,
        loadReplies: @escaping CommentReplyLoadAction
    ) {
        self.rootComment = rootComment
        self.store = store
        self.reloadReplies = reloadReplies
        self.loadMoreReplies = loadMoreReplies
        self.showDialog = showDialog
        self.toggleLike = toggleLike
        self.loadReplies = loadReplies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CommentReplyRootView(comment: rootComment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                Divider()

                CommentRepliesContent(
                    rootComment: rootComment,
                    store: store,
                    reloadReplies: { @MainActor [reloadReplies] rootID in await reloadReplies(rootID) },
                    loadMoreReplies: { @MainActor [loadMoreReplies] rootID in await loadMoreReplies(rootID) },
                    showDialog: showDialog,
                    toggleLike: toggleLike
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppSurfaceColors.page)
        .defersRemoteImageLoadsDuringFastScroll()
        .hiddenInlineNavigationTitle()
        .nativeTopScrollEdgeEffect()
        .commentSheetLoadLifecycle { @MainActor [loadReplies, rootID = rootComment.id] in
            await loadReplies(rootID)
        }
    }
}
