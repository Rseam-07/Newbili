import SwiftUI

extension PortraitCommentsSheet {
    init(
        store: VideoDetailCommentsRenderStore,
        threadStore: VideoDetailCommentThreadRenderStore,
        maximumHeight: CGFloat,
        beginInitialCommentsLoad: @escaping () -> Void,
        selectCommentSort: @escaping (CommentSort) async -> Void,
        retryComments: @escaping () async -> Void,
        loadMoreComments: @escaping () async -> Void,
        toggleLike: @escaping (Comment) -> Void = { _ in },
        loadReplies: @escaping CommentReplyLoadAction,
        reloadReplies: @escaping CommentReplyLoadAction,
        loadMoreReplies: @escaping CommentReplyLoadAction,
        loadDialog: @escaping CommentDialogLoadAction,
        reloadDialog: @escaping CommentDialogLoadAction
    ) {
        self.init(
            store: store,
            threadStore: threadStore,
            maximumHeight: maximumHeight,
            actions: PortraitCommentsSheetActions(
                beginInitialCommentsLoad: beginInitialCommentsLoad,
                selectCommentSort: selectCommentSort,
                retryComments: retryComments,
                loadMoreComments: loadMoreComments,
                toggleLike: toggleLike,
                replies: PortraitCommentsSheetReplyActions(
                    loadReplies: loadReplies,
                    reloadReplies: reloadReplies,
                    loadMoreReplies: loadMoreReplies,
                    loadDialog: loadDialog,
                    reloadDialog: reloadDialog,
                    toggleLike: toggleLike
                )
            )
        )
    }
}
