import SwiftUI

struct HomeFeedContentActions {
    let onVideoSelect: ((VideoItem) -> Void)?
    let onVideoTap: (VideoItem) -> Void
    let onVideoPress: (VideoItem) -> Void
    let onCardAppear: (VideoItem, Int) -> Void
    let onCardDisappear: (VideoItem) -> Void
    let onFeaturedItemTap: (HomeFeaturedItem) -> Void
    let onFeaturedCardAppear: (HomeFeaturedItem) -> Void
    let onFeaturedCardDisappear: (HomeFeaturedItem) -> Void
    let onLoadMore: (VideoItem) async -> Void
    let onRefreshFromLastSeenMarker: () async -> Void
}
