import SwiftUI

struct CommentRepliesSheet: View {
    let rootComment: Comment
    @ObservedObject var store: VideoDetailCommentThreadRenderStore
    let initialReplyID: Int?
    let loadReplies: CommentReplyLoadAction
    let reloadReplies: CommentReplyLoadAction
    let loadMoreReplies: CommentReplyLoadAction
    let loadDialog: CommentDialogLoadAction
    let reloadDialog: CommentDialogLoadAction
    let toggleLike: (Comment) -> Void
    @State private var dialogReply: Comment?
    @State private var didPresentInitialReply = false
    @State private var selectedDetent: PresentationDetent = .large

    init(
        rootComment: Comment,
        store: VideoDetailCommentThreadRenderStore,
        initialReplyID: Int? = nil,
        loadReplies: @escaping CommentReplyLoadAction,
        reloadReplies: @escaping CommentReplyLoadAction,
        loadMoreReplies: @escaping CommentReplyLoadAction,
        loadDialog: @escaping CommentDialogLoadAction,
        reloadDialog: @escaping CommentDialogLoadAction,
        toggleLike: @escaping (Comment) -> Void
    ) {
        self.rootComment = rootComment
        self.store = store
        self.initialReplyID = initialReplyID
        self.loadReplies = loadReplies
        self.reloadReplies = reloadReplies
        self.loadMoreReplies = loadMoreReplies
        self.loadDialog = loadDialog
        self.reloadDialog = reloadDialog
        self.toggleLike = toggleLike
    }

    var body: some View {
        CommentOwnerProfileNavigationContainer {
            CommentRepliesSheetContentHost(
                rootComment: rootComment,
                store: store,
                reloadReplies: reloadReplies,
                loadMoreReplies: loadMoreReplies,
                showDialog: showDialog,
                toggleLike: toggleLike,
                loadReplies: loadReplies
            )
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationBackground(AppSurfaceColors.page)
        .presentationDragIndicator(.visible)
        .sheet(item: $dialogReply) { reply in
            CommentDialogSheet(
                rootComment: rootComment,
                focusReply: reply,
                store: store,
                loadDialog: loadDialog,
                reloadDialog: reloadDialog,
                toggleLike: toggleLike
            )
        }
        .onChange(of: replyIDs) { _, _ in
            presentInitialReplyIfAvailable()
        }
        .onAppear {
            presentInitialReplyIfAvailable()
        }
    }

    private func showDialog(_ reply: Comment) {
        dialogReply = reply
    }

    private var replyIDs: [Int] {
        store.replies(for: rootComment).map(\.id)
    }

    private func presentInitialReplyIfAvailable() {
        guard !didPresentInitialReply,
              dialogReply == nil,
              let initialReplyID,
              let reply = store.replies(for: rootComment).first(where: { $0.id == initialReplyID })
        else {
            return
        }
        didPresentInitialReply = true
        dialogReply = reply
    }
}
