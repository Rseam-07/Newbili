import SwiftUI

struct CommentRowHeader: View {
    let display: VideoDetailCommentDisplayModel
    let toggleLike: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CommentAuthorIdentity(name: display.authorName, owner: display.authorOwner)
                .foregroundStyle(.primary)

            if !display.timeText.isEmpty {
                Text(display.timeText)
                    .appTypography(.metadata, fallback: .caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: toggleLike) {
                CommentMetricBadge(
                    text: display.likeText,
                    systemImage: display.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    isHighlighted: display.isLiked
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(display.isLiked ? "取消点赞" : "点赞")
        }
    }
}
