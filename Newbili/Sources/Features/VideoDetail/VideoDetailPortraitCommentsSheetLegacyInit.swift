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
        loadReplies: @escaping (Comment) async -> Void,
        reloadReplies: @escaping (Comment) async -> Void,
        loadMoreReplies: @escaping (Comment) async -> Void,
        loadDialog: @escaping (Comment, Comment) async -> Void,
        reloadDialog: @escaping (Comment, Comment) async -> Void
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
