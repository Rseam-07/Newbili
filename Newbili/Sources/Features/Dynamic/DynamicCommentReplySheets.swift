import SwiftUI

struct DynamicCommentRepliesSheet: View {
    let rootComment: Comment
    let replyStore: DynamicCommentReplyStore
    @Environment(\.commentContentOwnerMID) private var commentContentOwnerMID
    @State private var dialogReply: Comment?

    var body: some View {
        CommentOwnerProfileNavigationContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DynamicCommentReplyRootView(comment: rootComment)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider()

                        DynamicCommentRepliesContent(rootComment: rootComment, replyStore: replyStore) { reply in
                            dialogReply = reply
                        }
                    }
                }
                .defersRemoteImageLoadsDuringFastScroll()
                .hiddenInlineNavigationTitle()
                .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)

                Divider()

                DynamicCommentReplyComposer(
                    placeholder: "回复 @\(rootComment.member?.uname ?? "该用户")",
                    rootComment: rootComment,
                    parentComment: nil,
                    replyStore: replyStore
                )
            }
            .task {
                await replyStore.loadReplies(for: rootComment)
            }
        }
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
        .sheet(item: $dialogReply) { reply in
            DynamicCommentDialogSheet(rootComment: rootComment, focusReply: reply, replyStore: replyStore)
                .environment(\.commentContentOwnerMID, commentContentOwnerMID)
        }
    }
}

private struct DynamicCommentDialogSheet: View {
    let rootComment: Comment
    let focusReply: Comment
    let replyStore: DynamicCommentReplyStore

    var body: some View {
        CommentOwnerProfileNavigationContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DynamicCommentReplyRootView(comment: rootComment)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider()

                        DynamicCommentDialogContent(rootComment: rootComment, focusReply: focusReply, replyStore: replyStore)
                    }
                }
                .defersRemoteImageLoadsDuringFastScroll()
                .hiddenInlineNavigationTitle()
                .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)

                Divider()

                DynamicCommentReplyComposer(
                    placeholder: "回复 @\(focusReply.member?.uname ?? "该用户")",
                    rootComment: rootComment,
                    parentComment: focusReply,
                    replyStore: replyStore
                )
            }
            .task {
                await replyStore.loadDialog(for: rootComment, reply: focusReply)
            }
        }
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
    }
}

private struct DynamicCommentReplyComposer: View {
    let placeholder: String
    let rootComment: Comment
    let parentComment: Comment?
    @ObservedObject var replyStore: DynamicCommentReplyStore

    var body: some View {
        CommentComposerBar(
            placeholder: placeholder,
            submissionState: replyStore.submissionState
        ) { message in
            await replyStore.submitReply(
                message,
                to: rootComment,
                parent: parentComment
            )
        }
    }
}
