import SwiftUI

struct CommentRowHeader: View {
    let display: VideoDetailCommentDisplayModel
    let toggleLike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                CommentAuthorIdentity(name: display.authorName, owner: display.authorOwner)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !display.timeText.isEmpty {
                    Text(display.timeText)
                        .appTypography(.metadata, fallback: .caption)
                        .foregroundStyle(.secondary)
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
    }
}
