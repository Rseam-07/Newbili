import SwiftUI

struct HomeImmersiveFeedScreen: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var runtimeSettings: HomeRuntimeSettingsStore
    @ObservedObject var libraryStore: LibraryStore
    @Binding var viewportState: HomeFeedViewportState
    @Binding var detailPath: NavigationPath
    @Binding var primarySection: HomePrimarySection
    let onSelectPrimarySection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void
    let contentActions: HomeFeedContentActions
    let actionStore: HomeFeedScreenActionStore
    let launchConfiguration: HomeFeedLaunchConfiguration

    var body: some View {
        let usesCinematicWideLayout = HomeCinematicWideLayoutPolicy.usesCinematicShelves(
            containerWidth: viewportState.feedContainerWidth,
            viewportHeight: viewportState.viewportHeight
        )
        let layout = effectiveLayout
        let metrics = viewportState.layoutMetrics(for: layout)
        let imagePrefetchProfile = HomeFeedCoverPrefetchProfile.make(
            layout: layout,
            metrics: metrics,
            displayScale: displayScale
        )
        ZStack(alignment: .top) {
            HomeImmersiveBackdrop(
                mode: viewModel.mode,
                usesCinematicWideLayout: usesCinematicWideLayout
            )

            HomeFeedScrollView(
                viewModel: viewModel,
                runtimeSettings: runtimeSettings,
                viewportState: $viewportState,
                scrollActions: actionStore.scroll,
                refreshActions: actionStore.refresh,
                layout: layout,
                background: .clear
            ) {
                Group {
                    if usesCinematicWideLayout {
                        HomeCinematicWideFeed(
                            cells: viewModel.videoCells,
                            featuredItems: viewModel.featuredItems,
                            currentFeedStartIndex: viewModel.featuredCurrentFeedItemCount,
                            mode: viewModel.mode,
                            containerWidth: viewportState.feedContainerWidth,
                            viewportHeight: viewportState.viewportHeight,
                            primarySection: $primarySection,
                            onSelectPrimarySection: onSelectPrimarySection,
                            accountMessageViewModel: accountMessageViewModel,
                            onOpenAccountMessages: onOpenAccountMessages,
                            lastSeenMarkerCellIndex: viewModel.lastSeenMarkerIndex,
                            isLoadingMore: viewModel.state.isLoading
                                && !viewModel.isRefreshing
                                && !viewModel.isUserRefreshing,
                            actions: contentActions
                        )
                    } else {
                        VStack(spacing: 0) {
                            if !viewModel.featuredItems.isEmpty {
                                HomeFeaturedCarousel(
                                    items: viewModel.featuredItems,
                                    mode: viewModel.mode,
                                    style: .compact,
                                    actions: contentActions
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 22)
                            }

                            if viewModel.videoCells.count > viewModel.featuredCurrentFeedItemCount {
                                HomeImmersiveFeedHeading(mode: viewModel.mode)

                                HomeFeedContentSection(
                                    metrics: metrics,
                                    cells: viewModel.videoCells,
                                    cellStartIndex: viewModel.featuredCurrentFeedItemCount,
                                    lastSeenMarkerIndex: viewModel.lastSeenMarkerIndex,
                                    isLoadingMore: viewModel.state.isLoading
                                        && !viewModel.isRefreshing
                                        && !viewModel.isUserRefreshing,
                                    actions: contentActions
                                )
                            }
                        }
                    }
                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: imagePrefetchProfile.cacheIdentity) {
            viewModel.updateImagePrefetchProfile(imagePrefetchProfile)
        }
        .task(id: viewModel.mode) {
            await viewModel.loadFeaturedSupplementaryContentIfNeeded()
        }
        .homeFeedScreenLifecycle(
            viewModel: viewModel,
            runtimeSettings: runtimeSettings,
            libraryStore: libraryStore,
            detailPath: $detailPath,
            configuration: lifecycleConfiguration
        )
    }

    private var effectiveLayout: HomeFeedLayout {
        HomeImmersiveAdaptiveLayoutPolicy.resolve(
            preferredLayout: runtimeSettings.homeFeedLayout,
            containerWidth: viewportState.feedContainerWidth,
            usesAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var lifecycleConfiguration: HomeFeedScreenLifecycleConfiguration {
        HomeFeedScreenLifecycleConfiguration(
            launchConfiguration: launchConfiguration,
            lifecycleActions: actionStore.lifecycle,
            detailOpenActions: actionStore.detailOpen
        )
    }
}

nonisolated enum HomeCinematicWideLayoutPolicy {
    static let minimumWidth: CGFloat = 760
    static let minimumLandscapeWidth: CGFloat = 600

    static func usesCinematicShelves(
        containerWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        containerWidth >= minimumWidth
            || (
                containerWidth >= minimumLandscapeWidth
                    && viewportHeight > 0
                    && containerWidth > viewportHeight
            )
    }

    static func usesCompactCinemaHeight(viewportHeight: CGFloat) -> Bool {
        viewportHeight > 0 && viewportHeight < 600
    }

    static func heroHeight(containerWidth: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        if usesCompactCinemaHeight(viewportHeight: viewportHeight) {
            return min(max(viewportHeight * 0.92, 320), 420)
        }
        return min(max(viewportHeight * 0.68, containerWidth * 0.48, 500), 720)
    }
}

nonisolated enum HomeCinematicShelfPlan {
    static func itemRanges(totalItemCount: Int, itemsPerShelf: Int = 8) -> [Range<Int>] {
        guard totalItemCount > 0, itemsPerShelf > 0 else { return [] }
        return stride(from: 0, to: totalItemCount, by: itemsPerShelf).map { lowerBound in
            lowerBound..<min(lowerBound + itemsPerShelf, totalItemCount)
        }
    }
}

nonisolated enum HomeImmersiveAdaptiveLayoutPolicy {
    static func resolve(
        preferredLayout: HomeFeedLayout,
        containerWidth: CGFloat,
        usesAccessibilitySize: Bool
    ) -> HomeFeedLayout {
        if usesAccessibilitySize {
            switch preferredLayout {
            case .doubleColumn, .borderedDoubleColumn:
                return .singleColumn
            case .singleColumn, .borderedSingleColumn:
                return preferredLayout
            }
        }

        guard containerWidth >= 760 else {
            return preferredLayout
        }

        switch preferredLayout {
        case .singleColumn:
            return .doubleColumn
        case .borderedSingleColumn:
            return .borderedDoubleColumn
        case .doubleColumn, .borderedDoubleColumn:
            return preferredLayout
        }
    }
}

private struct HomeCinematicWideFeed: View {
    let cells: [HomeVideoCellModel]
    let featuredItems: [HomeFeaturedItem]
    let currentFeedStartIndex: Int
    let mode: HomeFeedMode
    let containerWidth: CGFloat
    let viewportHeight: CGFloat
    @Binding var primarySection: HomePrimarySection
    let onSelectPrimarySection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void
    let lastSeenMarkerCellIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    var body: some View {
        let shelfRanges = HomeCinematicShelfPlan.itemRanges(
            totalItemCount: max(cells.count - currentFeedStartIndex, 0)
        )

        LazyVStack(alignment: .leading, spacing: 0) {
            HomeCinematicNavigationHeader(
                selection: $primarySection,
                containerWidth: containerWidth,
                onSelect: onSelectPrimarySection,
                accountMessageViewModel: accountMessageViewModel,
                onOpenAccountMessages: onOpenAccountMessages
            )

            if !featuredItems.isEmpty {
                HomeFeaturedCarousel(
                    items: featuredItems,
                    mode: mode,
                    style: .cinematic(
                        containerWidth: containerWidth,
                        viewportHeight: viewportHeight
                    ),
                    actions: actions
                )
            }

            ForEach(shelfRanges.indices, id: \.self) { shelfIndex in
                let range = shelfRanges[shelfIndex]
                let shelfCells = cells[
                    (range.lowerBound + currentFeedStartIndex)..<(range.upperBound + currentFeedStartIndex)
                ]
                HomeCinematicShelf(
                    title: shelfTitle(at: shelfIndex),
                    cells: shelfCells,
                    mode: mode,
                    cardWidth: cardWidth,
                    horizontalPadding: horizontalPadding,
                    lastSeenMarkerCellIndex: lastSeenMarkerCellIndex,
                    loadMoreTriggerCellID: cells.last?.id,
                    actions: actions
                )
                .padding(.top, shelfIndex == 0 ? firstShelfTopPadding : shelfSpacing)
            }

            if isLoadingMore {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("正在为你加载更多内容")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
            }
        }
        .padding(.bottom, 42)
    }

    private var horizontalPadding: CGFloat {
        min(max(containerWidth * 0.038, 26), 56)
    }

    private var cardWidth: CGFloat {
        min(
            max(
                containerWidth * (usesCompactCinemaHeight ? 0.32 : 0.29),
                usesCompactCinemaHeight ? 238 : 288
            ),
            420
        )
    }

    private var firstShelfTopPadding: CGFloat {
        usesCompactCinemaHeight ? -16 : -58
    }

    private var shelfSpacing: CGFloat {
        usesCompactCinemaHeight ? 28 : 44
    }

    private var usesCompactCinemaHeight: Bool {
        HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(viewportHeight: viewportHeight)
    }

    private func shelfTitle(at index: Int) -> String {
        let recommendTitles = ["为你推荐", "此刻热门", "新鲜内容", "继续发现"]
        let popularTitles = ["全站热榜", "热度上升", "大家正在看", "更多精彩"]
        let titles = mode == .popular ? popularTitles : recommendTitles
        return titles[index % titles.count]
    }

}


private struct HomeCinematicShelf: View {
    let title: String
    let cells: ArraySlice<HomeVideoCellModel>
    let mode: HomeFeedMode
    let cardWidth: CGFloat
    let horizontalPadding: CGFloat
    let lastSeenMarkerCellIndex: Int?
    let loadMoreTriggerCellID: String?
    let actions: HomeFeedContentActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(cells) { cell in
                        if lastSeenMarkerCellIndex == cell.index {
                            HomeCinematicLastSeenMarker(cardWidth: cardWidth, action: actions.onRefreshFromLastSeenMarker)
                        }

                        HomeCinematicShelfCard(
                            cell: cell,
                            mode: mode,
                            cardWidth: cardWidth,
                            actions: actions
                        )
                        .homeFeedCardLifecycle(
                            cell: cell,
                            loadMoreTriggerCellID: loadMoreTriggerCellID,
                            actions: actions
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct HomeCinematicShelfCard: View {
    @Environment(\.displayScale) private var displayScale
    let cell: HomeVideoCellModel
    let mode: HomeFeedMode
    let cardWidth: CGFloat
    let actions: HomeFeedContentActions

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    CachedRemoteImage(
                        url: cell.display.coverThumbnailURL(
                            fitting: coverSize,
                            scale: displayScale,
                            maximumPixelLength: 960
                        ),
                        targetPixelSize: cell.display.coverTargetPixelSize(
                            fitting: coverSize,
                            scale: displayScale,
                            maximumPixelLength: 960
                        ),
                        animatesAppearance: false
                    ) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [.white.opacity(0.14), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(width: coverSize.width, height: coverSize.height)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.70)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: 7) {
                        if mode == .popular {
                            Text("#\(cell.index + 1)")
                                .font(.caption.bold())
                        }
                        Spacer(minLength: 0)
                        Text(cell.display.durationText)
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(12)
                }
                .frame(width: coverSize.width, height: coverSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.32), radius: 14, y: 7)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cell.display.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text("\(cell.display.authorName) · \(cell.display.viewText)次观看")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
            .frame(width: cardWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonStyle(
            PressPreloadButtonStyle(
                pressedScale: 0.96,
                pressedOpacity: 0.90,
                pressAnimation: .spring(duration: 0.30, bounce: 0.22)
            ) {
                actions.onVideoPress(cell.video)
            }
        )
        .hoverEffect(.lift)
        .accessibilityLabel("\(cell.display.title)，\(cell.display.metadataSummaryText)")
    }

    private var coverSize: CGSize {
        CGSize(width: cardWidth, height: cardWidth * 9 / 16)
    }

    private func open() {
        if let onVideoSelect = actions.onVideoSelect {
            onVideoSelect(cell.video)
        } else {
            actions.onVideoTap(cell.video)
        }
    }
}

private struct HomeCinematicLastSeenMarker: View {
    let cardWidth: CGFloat
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: cardWidth, height: cardWidth * 9 / 16)
                    .overlay {
                        VStack(spacing: 9) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 25, weight: .semibold))
                            Text("刷新推荐")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("上次看到这里")
                        .font(.headline)
                    Text("点击从这里获取新推荐")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("上次看到这里，点击刷新推荐")
    }
}


private struct HomeImmersiveFeedHeading: View {
    let mode: HomeFeedMode

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .popular ? "全站热榜" : "继续发现")
                    .font(.title3.bold())
                Text(mode == .popular ? "此刻大家都在看" : "根据你的内容偏好持续更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.down")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

private struct HomeImmersiveBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(HomeRealtimeBlurSettings.storageKey)
    private var realtimeAmbientBlurEnabled = HomeRealtimeBlurSettings.defaultIsEnabled
    let mode: HomeFeedMode
    let usesCinematicWideLayout: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: usesCinematicWideLayout
                    ? [Color.black, Color(red: 0.07, green: 0.06, blue: 0.10), Color.black]
                    : colorScheme == .dark
                    ? [Color(red: 0.04, green: 0.05, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.12), .black]
                    : [Color(red: 0.98, green: 0.98, blue: 1), Color(red: 1, green: 0.96, blue: 0.98), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if realtimeAmbientBlurEnabled {
                Circle()
                    .fill((mode == .popular ? Color.orange : Color.pink).opacity(usesCinematicWideLayout || colorScheme == .dark ? 0.24 : 0.16))
                    .frame(width: usesCinematicWideLayout ? 620 : 360, height: usesCinematicWideLayout ? 620 : 360)
                    .blur(radius: usesCinematicWideLayout ? 128 : 84)
                    .offset(x: usesCinematicWideLayout ? -260 : -160, y: usesCinematicWideLayout ? -330 : -250)

                Circle()
                    .fill(Color.cyan.opacity(usesCinematicWideLayout || colorScheme == .dark ? 0.17 : 0.12))
                    .frame(width: usesCinematicWideLayout ? 680 : 380, height: usesCinematicWideLayout ? 680 : 380)
                    .blur(radius: usesCinematicWideLayout ? 142 : 88)
                    .offset(x: usesCinematicWideLayout ? 360 : 170, y: usesCinematicWideLayout ? 460 : 310)
            } else {
                HomeAmbientGradientGlow(
                    color: mode == .popular ? .orange : .pink,
                    innerOpacity: usesCinematicWideLayout || colorScheme == .dark ? 0.24 : 0.16,
                    middleOpacity: usesCinematicWideLayout || colorScheme == .dark ? 0.11 : 0.07,
                    endRadius: usesCinematicWideLayout ? 420 : 260
                )
                .frame(width: usesCinematicWideLayout ? 840 : 520, height: usesCinematicWideLayout ? 840 : 520)
                .offset(x: usesCinematicWideLayout ? -260 : -160, y: usesCinematicWideLayout ? -330 : -250)

                HomeAmbientGradientGlow(
                    color: .cyan,
                    innerOpacity: usesCinematicWideLayout || colorScheme == .dark ? 0.17 : 0.12,
                    middleOpacity: usesCinematicWideLayout || colorScheme == .dark ? 0.08 : 0.05,
                    endRadius: usesCinematicWideLayout ? 450 : 280
                )
                .frame(width: usesCinematicWideLayout ? 900 : 560, height: usesCinematicWideLayout ? 900 : 560)
                .offset(x: usesCinematicWideLayout ? 360 : 170, y: usesCinematicWideLayout ? 460 : 310)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct HomeAmbientGradientGlow: View {
    let color: Color
    let innerOpacity: Double
    let middleOpacity: Double
    let endRadius: CGFloat

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(innerOpacity),
                        color.opacity(middleOpacity),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: endRadius
                )
            )
    }
}
