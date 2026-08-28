import SwiftUI

struct UploaderView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let owner: VideoOwner
    let hidesRootTabBar: Bool
    let allowsPullToRefresh: Bool
    let showsToolbarRefreshButton: Bool

    @StateObject private var holder = UploaderViewModelHolder()

    init(
        owner: VideoOwner,
        hidesRootTabBar: Bool = true,
        allowsPullToRefresh: Bool = true,
        showsToolbarRefreshButton: Bool = false
    ) {
        self.owner = owner
        self.hidesRootTabBar = hidesRootTabBar
        self.allowsPullToRefresh = allowsPullToRefresh
        self.showsToolbarRefreshButton = showsToolbarRefreshButton
    }

    @ViewBuilder
    var body: some View {
        if hidesRootTabBar {
            content.hidesRootTabBarOnPush()
        } else {
            content
        }
    }

    private var content: some View {
        UploaderAccountAwareContent(
            owner: owner,
            allowsPullToRefresh: allowsPullToRefresh,
            showsToolbarRefreshButton: showsToolbarRefreshButton,
            api: dependencies.api,
            sessionStore: dependencies.sessionStore,
            libraryStore: dependencies.libraryStore,
            holder: holder
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UploaderAccountAwareContent: View {
    let owner: VideoOwner
    let allowsPullToRefresh: Bool
    let showsToolbarRefreshButton: Bool
    let api: BiliAPIClient
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var libraryStore: LibraryStore
    @ObservedObject var holder: UploaderViewModelHolder

    private var accountContext: UploaderAccountContext {
        UploaderAccountContext(sessionStore: sessionStore, libraryStore: libraryStore)
    }

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                UploaderContentView(
                    owner: owner,
                    viewModel: viewModel,
                    allowsPullToRefresh: allowsPullToRefresh,
                    showsToolbarRefreshButton: showsToolbarRefreshButton
                )
            } else {
                UploaderInitialLoadingView()
            }
        }
        .task(id: UploaderViewModelIdentity(ownerMID: owner.mid, accountContext: accountContext)) {
            holder.configure(
                owner: owner,
                api: api,
                sessionStore: sessionStore,
                libraryStore: libraryStore,
                accountContext: accountContext
            )
        }
    }
}

private struct UploaderViewModelIdentity: Equatable {
    let ownerMID: Int
    let accountContext: UploaderAccountContext
}

private struct UploaderInitialLoadingView: View {
    var body: some View {
        GeometryReader { proxy in
            let metrics = HomeFeedLayoutMetrics(mode: .doubleColumn, containerWidth: proxy.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    UploaderHeaderSkeletonCard()

                    SkeletonBlock(height: 32, shape: .rounded(8))
                        .padding(.horizontal, 12)

                    HomeFeedSkeletonSection(metrics: metrics)
                }
                .padding(.vertical, 12)
            }
            .scrollDisabled(true)
            .background(Color(.systemBackground))
        }
        .allowsHitTesting(false)
        .accessibilityLabel("正在加载 UP 主主页")
    }
}

private struct UploaderHeaderSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SkeletonBlock(width: 56, height: 56, shape: .circle)

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 148, height: 18, shape: .rounded(5))
                    SkeletonBlock(width: 96, height: 12, shape: .capsule)
                }

                Spacer(minLength: 0)
            }

            SkeletonBlock(height: 14, shape: .rounded(5))
            SkeletonBlock(width: 220, height: 14, shape: .rounded(5))

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 36, shape: .rounded(10))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .biliGlassEffect(
            interactive: false,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.8)
        }
        .padding(.horizontal, 12)
    }
}
