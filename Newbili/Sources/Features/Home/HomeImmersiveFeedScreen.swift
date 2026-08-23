import SwiftUI

struct HomeImmersiveFeedScreen: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var runtimeSettings: HomeRuntimeSettingsStore
    @ObservedObject var libraryStore: LibraryStore
    @Binding var viewportState: HomeFeedViewportState
    @Binding var detailPath: NavigationPath
    let contentActions: HomeFeedContentActions
    let actionStore: HomeFeedScreenActionStore
    let launchConfiguration: HomeFeedLaunchConfiguration

    var body: some View {
        let layout = effectiveLayout
        let metrics = viewportState.layoutMetrics(for: layout)
        let imagePrefetchProfile = HomeFeedCoverPrefetchProfile.make(
            layout: layout,
            metrics: metrics,
            displayScale: displayScale
        )
        ZStack {
            HomeImmersiveBackdrop(mode: viewModel.mode)

            HomeFeedScrollView(
                viewModel: viewModel,
                runtimeSettings: runtimeSettings,
                viewportState: $viewportState,
                scrollActions: actionStore.scroll,
                refreshActions: actionStore.refresh,
                layout: layout,
                background: .clear
            ) {
                VStack(spacing: 0) {
                    if let featured = viewModel.videoCells.first {
                        HomeImmersiveHeroCard(
                            cell: featured,
                            mode: viewModel.mode,
                            actions: contentActions
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 22)
                    }

                    if viewModel.videoCells.count > 1 {
                        HomeImmersiveFeedHeading(mode: viewModel.mode)

                        HomeFeedContentSection(
                            metrics: metrics,
                            cells: viewModel.videoCells,
                            cellStartIndex: 1,
                            lastSeenMarkerIndex: adjustedLastSeenMarkerIndex,
                            isLoadingMore: viewModel.state.isLoading
                                && !viewModel.isRefreshing
                                && !viewModel.isUserRefreshing,
                            actions: contentActions
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: imagePrefetchProfile.cacheIdentity) {
            viewModel.updateImagePrefetchProfile(imagePrefetchProfile)
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
        guard dynamicTypeSize.isAccessibilitySize else {
            return runtimeSettings.homeFeedLayout
        }

        switch runtimeSettings.homeFeedLayout {
        case .doubleColumn, .borderedDoubleColumn:
            return .singleColumn
        case .singleColumn, .borderedSingleColumn:
            return runtimeSettings.homeFeedLayout
        }
    }

    private var adjustedLastSeenMarkerIndex: Int? {
        guard let index = viewModel.lastSeenMarkerIndex, index > 1 else { return nil }
        return index - 1
    }

    private var lifecycleConfiguration: HomeFeedScreenLifecycleConfiguration {
        HomeFeedScreenLifecycleConfiguration(
            launchConfiguration: launchConfiguration,
            lifecycleActions: actionStore.lifecycle,
            detailOpenActions: actionStore.detailOpen
        )
    }
}

private struct HomeImmersiveHeroCard: View {
    let cell: HomeVideoCellModel
    let mode: HomeFeedMode
    let actions: HomeFeedContentActions

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    CachedRemoteImage(
                        url: cell.display.largeThumbnailURL(
                            fitting: geometry.size,
                            scale: 2,
                            maximumPixelLength: 1_280
                        ),
                        targetPixelSize: 1_280,
                        animatesAppearance: false
                    ) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [.pink.opacity(0.52), .purple.opacity(0.32), .blue.opacity(0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.20), .black.opacity(0.88)],
                    startPoint: UnitPoint(x: 0.5, y: 0.28),
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        mode == .popular ? "正在流行" : "今日精选",
                        systemImage: mode == .popular ? "chart.line.uptrend.xyaxis" : "sparkles"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.88))

                    Text(cell.display.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(cell.display.metadataSummaryText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 246)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .buttonStyle(PressPreloadButtonStyle {
            actions.onVideoPress(cell.video)
        })
        .onAppear {
            actions.onCardAppear(cell.video, cell.index)
        }
        .onDisappear {
            actions.onCardDisappear(cell.video)
        }
        .accessibilityLabel("精选视频，\(cell.display.title)，\(cell.display.metadataSummaryText)")
    }

    private func open() {
        if let onVideoSelect = actions.onVideoSelect {
            onVideoSelect(cell.video)
        } else {
            actions.onVideoTap(cell.video)
        }
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.04, green: 0.05, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.12), .black]
                    : [Color(red: 0.98, green: 0.98, blue: 1), Color(red: 1, green: 0.96, blue: 0.98), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if realtimeAmbientBlurEnabled {
                Circle()
                    .fill((mode == .popular ? Color.orange : Color.pink).opacity(colorScheme == .dark ? 0.24 : 0.16))
                    .frame(width: 360, height: 360)
                    .blur(radius: 84)
                    .offset(x: -160, y: -250)

                Circle()
                    .fill(Color.cyan.opacity(colorScheme == .dark ? 0.17 : 0.12))
                    .frame(width: 380, height: 380)
                    .blur(radius: 88)
                    .offset(x: 170, y: 310)
            } else {
                HomeAmbientGradientGlow(
                    color: mode == .popular ? .orange : .pink,
                    innerOpacity: colorScheme == .dark ? 0.24 : 0.16,
                    middleOpacity: colorScheme == .dark ? 0.11 : 0.07,
                    endRadius: 260
                )
                .frame(width: 520, height: 520)
                .offset(x: -160, y: -250)

                HomeAmbientGradientGlow(
                    color: .cyan,
                    innerOpacity: colorScheme == .dark ? 0.17 : 0.12,
                    middleOpacity: colorScheme == .dark ? 0.08 : 0.05,
                    endRadius: 280
                )
                .frame(width: 560, height: 560)
                .offset(x: 170, y: 310)
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
