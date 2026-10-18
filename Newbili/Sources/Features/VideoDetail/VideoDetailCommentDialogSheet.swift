import SwiftUI

struct CommentDialogSheet: View {
    let rootComment: Comment
    let focusReply: Comment
    @ObservedObject var store: VideoDetailCommentThreadRenderStore
    let reloadDialog: CommentDialogLoadAction
    let toggleLike: (Comment) -> Void
    let loadDialog: CommentDialogLoadAction
    @State private var selectedDetent: PresentationDetent = .large

    init(
        rootComment: Comment,
        focusReply: Comment,
        store: VideoDetailCommentThreadRenderStore,
        loadDialog: @escaping CommentDialogLoadAction,
        reloadDialog: @escaping CommentDialogLoadAction,
        toggleLike: @escaping (Comment) -> Void
    ) {
        self.rootComment = rootComment
        self.focusReply = focusReply
        self.store = store
        self.reloadDialog = reloadDialog
        self.toggleLike = toggleLike
        self.loadDialog = loadDialog
    }

    var body: some View {
        CommentOwnerProfileNavigationContainer {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        CommentReplyRootView(comment: rootComment)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider()

                        CommentDialogContent(
                            rootComment: rootComment,
                            focusReply: focusReply,
                            store: store,
                            reloadDialog: { @MainActor [reloadDialog] rootID, replyID in
                                await reloadDialog(rootID, replyID)
                            },
                            toggleLike: toggleLike
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(AppSurfaceColors.page)
                .defersRemoteImageLoadsDuringFastScroll()
                .hiddenInlineNavigationTitle()
                .nativeTopScrollEdgeEffect()
                .commentSheetLoadLifecycle { @MainActor [loadDialog, rootID = rootComment.id, replyID = focusReply.id] in
                    await loadDialog(rootID, replyID)
                }
                .onAppear {
                    scrollToFocusedReply(using: proxy)
                }
                .onChange(of: dialogReplyIDs) { _, _ in
                    scrollToFocusedReply(using: proxy)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationBackground(AppSurfaceColors.page)
        .presentationDragIndicator(.visible)
    }

    private var dialogReplyIDs: [Int] {
        store.dialogSnapshot(for: rootComment, reply: focusReply).items.map(\.id)
    }

    private func scrollToFocusedReply(using proxy: ScrollViewProxy) {
        guard dialogReplyIDs.contains(focusReply.id) else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(focusReply.id, anchor: .center)
        }
    }
}
