import SwiftUI

@MainActor
struct HomeFeedScreenContentActionsBuilder {
    let viewModel: HomeViewModel
    let detailPath: Binding<NavigationPath>
    let launchConfiguration: HomeFeedLaunchConfiguration
    let preloadContext: HomeFeedPreloadContext
    let actionStore: HomeFeedScreenActionStore

    var actions: HomeFeedContentActions {
        HomeFeedContentActions(
            onVideoSelect: launchConfiguration.onVideoSelect,
            onVideoTap: openVideo,
            onVideoPress: beginPressedPreload,
            onCardAppear: recordExposure,
            onCardDisappear: recordCardDisappearance,
            onFeaturedVideoTap: openFeaturedVideo,
            onFeaturedCardAppear: recordFeaturedExposure,
            onFeaturedCardDisappear: recordFeaturedDisappearance,
            onLoadMore: loadMoreIfNeeded,
            onRefreshFromLastSeenMarker: refreshFromLastSeenMarker
        )
    }

    private func openVideo(_ video: VideoItem) {
        beginPressedPreload(video)
        viewModel.recordRecommendClick(video)
        actionStore.card.openVideo(
            video,
            onVideoSelect: launchConfiguration.onVideoSelect,
            detailOpenActions: actionStore.detailOpen,
            appendDetailPath: appendDetailPath
        )
    }

    private func beginPressedPreload(_ video: VideoItem) {
        actionStore.card.beginPressedPreload(
            for: video,
            context: preloadContext,
            preloadActions: actionStore.preload
        )
    }

    private func openFeaturedVideo(_ item: HomeFeaturedItem) {
        beginPressedPreload(item.cell.video)
        if item.source == .currentFeed {
            viewModel.recordRecommendClick(item.cell.video)
        }
        actionStore.card.openVideo(
            item.cell.video,
            onVideoSelect: launchConfiguration.onVideoSelect,
            detailOpenActions: actionStore.detailOpen,
            appendDetailPath: appendDetailPath
        )
    }

    private func recordExposure(_ video: VideoItem, index: Int) {
        viewModel.recordRecommendExposure(video, index: index)
        viewModel.scheduleImageLookahead(visibleIndex: index)
        actionStore.preload.recordVisibleCard(
            video,
            index: index,
            context: preloadContext
        )
    }

    private func recordCardDisappearance(_ video: VideoItem) {
        actionStore.preload.recordCardDisappearance(video)
    }

    private func recordFeaturedExposure(_ item: HomeFeaturedItem) {
        if item.source == .currentFeed {
            recordExposure(item.cell.video, index: item.cell.index)
        } else {
            actionStore.preload.recordVisibleCard(
                item.cell.video,
                index: 2,
                context: preloadContext
            )
        }
    }

    private func recordFeaturedDisappearance(_ item: HomeFeaturedItem) {
        recordCardDisappearance(item.cell.video)
    }

    private func loadMoreIfNeeded(_ video: VideoItem) async {
        await actionStore.card.loadMoreIfNeeded(
            current: video,
            viewModel: viewModel
        )
    }

    private func refreshFromLastSeenMarker() async {
        actionStore.scroll.requestScrollToTop()
        await viewModel.refreshFromUserPull()
        actionStore.scroll.requestScrollToTop()
    }

    private func appendDetailPath(_ video: VideoItem) {
        detailPath.wrappedValue.append(video)
    }
}
