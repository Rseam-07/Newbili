import SwiftUI

private enum HomeFeedScrollAnchor {
    static let top = "home-feed-top"
}

struct HomeFeedScrollView<FeedContent: View>: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var runtimeSettings: HomeRuntimeSettingsStore
    @Binding var viewportState: HomeFeedViewportState
    @ObservedObject var scrollActions: HomeFeedScrollActions
    let refreshActions: HomeFeedRefreshActions
    let layout: HomeFeedLayout
    @ViewBuilder let feedContent: () -> FeedContent

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(HomeFeedScrollAnchor.top)

                HomePullRefreshOffsetReader()
                HomeFeedWidthReader()

                HomeFeedScrollContent(
                    isShowingInitialPlaceholder: viewModel.videos.isEmpty && (viewModel.state == .idle || viewModel.state.isLoading),
                    isEmpty: viewModel.videos.isEmpty,
                    feedContent: feedContent
                )
            }
            .coordinateSpace(name: HomePullRefreshCoordinateSpace.name)
            .rootFloatingTabBarContentPadding()
            .background(HomeViewportHeightReader())
            .homeFeedScrollPreferenceHandling(
                viewModel: viewModel,
                runtimeSettings: runtimeSettings,
                viewportState: $viewportState,
                scrollActions: scrollActions,
                refreshActions: refreshActions
            )
            .scrollBounceBehavior(.always, axes: .vertical)
            .defersRemoteImageLoadsDuringFastScroll()
            .background(layout.homeFeedBackground)
            .nativeTopScrollEdgeEffect()
            .animation(.smooth(duration: 0.24), value: layout)
            .homeFeedScrollOverlays(
                viewModel: viewModel,
                runtimeSettings: runtimeSettings,
                viewportState: viewportState,
                refreshActions: refreshActions
            )
            .onChange(of: scrollActions.topScrollRequestID) { _, _ in
                scrollToTop(proxy)
            }
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        withAnimation(.smooth(duration: 0.34)) {
            proxy.scrollTo(HomeFeedScrollAnchor.top, anchor: .top)
        }
    }
}
