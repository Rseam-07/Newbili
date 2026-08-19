import Combine
import SwiftUI

@MainActor
final class HomeFeedScrollActions: ObservableObject {
    @Published private(set) var topScrollRequestID = 0

    func requestScrollToTop() {
        topScrollRequestID &+= 1
    }

    func updateFeedContainerWidth(
        _ width: CGFloat,
        state: HomeFeedViewportState
    ) -> HomeFeedViewportState {
        var updatedState = state
        updatedState.updateFeedContainerWidth(width)
        return updatedState
    }

    func updateViewportHeight(
        _ height: CGFloat,
        state: HomeFeedViewportState
    ) -> HomeFeedViewportState {
        var updatedState = state
        _ = updatedState.updateViewportHeight(height)
        return updatedState
    }

    func updatePullRefreshDistance(
        pullDistance: CGFloat,
        state: HomeFeedViewportState,
        triggerDistance: CGFloat,
        isRefreshing: Bool,
        refreshActions: HomeFeedRefreshActions,
        refresh: @escaping @MainActor () async -> Bool
    ) -> HomeFeedViewportState {
        var updatedState = state
        updatedState.currentPullRefreshDistance = pullDistance
        refreshActions.handleConfiguredPullRefresh(
            pullDistance: pullDistance,
            triggerDistance: triggerDistance,
            isRefreshing: isRefreshing,
            refresh: refresh
        )
        return updatedState
    }
}
