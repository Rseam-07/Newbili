import SwiftUI

struct CommentDialogRow: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let item: VideoDetailCommentDialogDisplayItem
    let isFocused: Bool
    let toggleLike: () -> Void

    private var reply: Comment { item.reply }
    private var display: VideoDetailCommentDisplayModel { item.display }

    init(
        item: VideoDetailCommentDialogDisplayItem,
        isFocused: Bool,
        toggleLike: @escaping () -> Void
    ) {
        self.item = item
        self.isFocused = isFocused
        self.toggleLike = toggleLike
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAvatar(
                urlString: display.avatarURLString,
                owner: display.authorOwner,
                size: 36
            )

            VStack(alignment: .leading, spacing: 11) {
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
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                CommentImageButton(
                    images: display.pictures,
                    transitionScope: reply.id.description
                )
                VideoCommentComposerButton(parent: reply)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, isFocused ? 10 : 0)
        .background(isFocused ? appTintColor.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .commentCopyContextMenu(text: reply.content?.message, title: "复制回复")
    }
}
