import SwiftUI

struct VideoDetailActionStripButtonRow: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let model: VideoDetailActionStripModel
    let layout: VideoDetailActionStripLayout
    let onFollow: () -> Void
    let onLike: (@escaping (VideoDetailSummaryCardLikeOutcome) -> Void) -> Void
    let onTriple: (@escaping (VideoDetailSummaryCardTripleOutcome) -> Void) -> Void
    let onCoin: () -> Void
    let onFavorite: () -> Void
    let onWatchLater: () -> Void
    let onShareTap: () -> Void

    var body: some View {
        HStack(spacing: layout.columnSpacing) {
            VideoDetailActionStripOwnerAvatar(owner: model.owner)
                .frame(width: layout.columnWidth, height: layout.rowHeight)

            VideoDetailActionStripFollowControl(
                isFollowing: model.isFollowing,
                canFollow: (model.owner?.mid ?? 0) > 0,
                isMutating: model.isMutatingFollow,
                action: onFollow
            )
                .frame(width: layout.columnWidth, height: layout.rowHeight)

            VideoDetailTriplePressIconButton(
                isLiked: model.isLiked,
                isDisabled: model.isMutatingLike,
                likeAction: onLike,
                tripleAction: onTriple
            )
            .frame(width: layout.columnWidth, height: layout.rowHeight)

            VideoDetailActionStripIconButton(
                accessibilityTitle: "投币",
                systemImage: "bitcoinsign.circle.fill",
                foregroundStyle: model.isCoined ? appTintColor : .primary,
                isDisabled: model.isMutatingCoin || model.coinCount >= 2,
                action: onCoin
            )
            .frame(width: layout.columnWidth, height: layout.rowHeight)

            VideoDetailFavoriteMenuButton(
                isFavorited: model.isFavorited,
                canFavorite: model.canFavorite,
                isDisabled: model.isMutatingFavorite,
                tintColor: appTintColor,
                favorite: onFavorite,
                watchLater: onWatchLater
            )
            .frame(width: layout.columnWidth, height: layout.rowHeight)

            VideoDetailActionStripShareButton(
                shareURL: model.shareURL,
                shareSubject: model.shareSubject,
                shareMessage: model.shareMessage,
                onShareTap: onShareTap
            )
                .frame(width: layout.columnWidth, height: layout.rowHeight)
        }
    }
}
