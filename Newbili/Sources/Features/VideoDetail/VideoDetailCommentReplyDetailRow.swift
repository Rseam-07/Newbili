import SwiftUI

struct CommentReplyDetailRow: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let item: VideoDetailCommentReplyDisplayItem
    let showDialog: (() -> Void)?
    let toggleLike: () -> Void

    private var reply: Comment { item.reply }
    private var display: VideoDetailCommentDisplayModel { item.display }

    init(
        item: VideoDetailCommentReplyDisplayItem,
        showDialog: (() -> Void)?,
        toggleLike: @escaping () -> Void = {}
    ) {
        self.item = item
        self.showDialog = showDialog
        self.toggleLike = toggleLike
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAvatar(
                urlString: display.avatarURLString,
                owner: display.authorOwner,
                size: 36
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        CommentAuthorIdentity(name: display.authorName, owner: display.authorOwner)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if !display.timeText.isEmpty {
                            Text(display.timeText)
                                .appTypography(.metadata, fallback: .caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: toggleLike) {
                        CommentMetricBadge(
                            text: display.likeText,
                            systemImage: display.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                            isHighlighted: display.isLiked
                        )
                    }
                    .buttonStyle(.plain)
                    .biliMinimumInteractiveTarget(alignment: .trailing)
                    .accessibilityLabel(display.isLiked ? "取消点赞" : "点赞")
                }

                BiliEmoteText(
                    content: reply.content,
                    font: .subheadline,
                    textColor: .primary,
                    emoteSize: 22,
                    typographyRole: .commentBody
                )
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                CommentImageButton(
                    images: display.pictures,
                    transitionScope: reply.id.description
                )

                HStack(spacing: 14) {
                    VideoCommentComposerButton(parent: reply)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let showDialog {
                        Button(action: showDialog) {
                            Label("查看对话", systemImage: "text.bubble")
                                .appTypography(.action, fallback: .caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(appTintColor)
                        .biliMinimumInteractiveTarget(alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .commentCopyContextMenu(text: reply.content?.message, title: "复制回复")
    }
}
