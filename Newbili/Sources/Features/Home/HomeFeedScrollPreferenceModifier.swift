import SwiftUI

struct HomeFeedScrollPreferenceModifier: ViewModifier {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var runtimeSettings: HomeRuntimeSettingsStore
    @Binding var viewportState: HomeFeedViewportState
    let scrollActions: HomeFeedScrollActions
    let refreshActions: HomeFeedRefreshActions

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(HomeFeedWidthPreferenceKey.self, perform: updateFeedContainerWidth)
            .onPreferenceChange(HomeViewportHeightPreferenceKey.self, perform: updateViewportHeight)
            .onPreferenceChange(HomePullRefreshDistancePreferenceKey.self, perform: updatePullRefreshDistance)
    }
}

extension View {
    func homeFeedScrollPreferenceHandling(
        viewModel: HomeViewModel,
        runtimeSettings: HomeRuntimeSettingsStore,
        viewportState: Binding<HomeFeedViewportState>,
        scrollActions: HomeFeedScrollActions,
        refreshActions: HomeFeedRefreshActions
    ) -> some View {
        modifier(
            HomeFeedScrollPreferenceModifier(
                viewModel: viewModel,
                runtimeSettings: runtimeSettings,
                viewportState: viewportState,
                scrollActions: scrollActions,
                refreshActions: refreshActions
            )
        )
    }
}
