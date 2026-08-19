import SwiftUI

struct CommentRowHeader: View {
    let display: VideoDetailCommentDisplayModel

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

            CommentMetricBadge(
                text: display.likeText,
                systemImage: display.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                isHighlighted: display.isLiked
            )
        }
    }
}
