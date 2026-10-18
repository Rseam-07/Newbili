import SwiftUI

@MainActor
struct VideoDetailReplySheetHost: View {
    let rootComment: Comment
    @ObservedObject var viewModel: VideoDetailViewModel
    let initialReplyID: Int?
    let renderPack: VideoDetailReplySheetRenderPack

    init(
        rootComment: Comment,
        viewModel: VideoDetailViewModel,
        initialReplyID: Int? = nil,
        actions: VideoDetailReplySheetActions
    ) {
        self.rootComment = rootComment
        self.viewModel = viewModel
        self.initialReplyID = initialReplyID
        viewModel.registerReplyRoot(rootComment)
        renderPack = VideoDetailReplySheetRenderPack(
            viewModel: viewModel,
            actions: actions
        )
    }

    var body: some View {
        CommentRepliesSheet(
            rootComment: rootComment,
            store: renderPack.store,
            initialReplyID: initialReplyID,
            loadReplies: { @MainActor [viewModel] rootID in
                await viewModel.loadReplies(for: rootID)
            },
            reloadReplies: { @MainActor [viewModel] rootID in
                await viewModel.reloadReplies(for: rootID)
            },
            loadMoreReplies: { @MainActor [viewModel] rootID in
                await viewModel.loadMoreReplies(for: rootID)
            },
            loadDialog: { @MainActor [viewModel] rootID, replyID in
                await viewModel.loadDialog(for: rootID, replyID: replyID)
            },
            reloadDialog: { @MainActor [viewModel] rootID, replyID in
                await viewModel.reloadDialog(for: rootID, replyID: replyID)
            },
            toggleLike: renderPack.actions.toggleCommentLike
        )
        .environment(\.videoCommentComposerContext, VideoCommentComposerContext(viewModel: viewModel, rootComment: rootComment))
    }
}
