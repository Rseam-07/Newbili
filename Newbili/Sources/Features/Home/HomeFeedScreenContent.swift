import SwiftUI

struct HomeFeedScreenContent: View {
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var libraryStore: LibraryStore
    @StateObject var runtimeSettings = HomeRuntimeSettingsStore()
    @ObservedObject var viewModel: HomeViewModel
    @Binding var detailPath: NavigationPath
    let launchConfiguration: HomeFeedLaunchConfiguration
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void
    @State var viewportState = HomeFeedViewportState()
    @State var actionStore = HomeFeedScreenActionStore()
    @State private var primarySection = HomePrimarySection.recommend
    @State private var usesCinematicNavigationChrome = false

    init(
        viewModel: HomeViewModel,
        detailPath: Binding<NavigationPath>,
        launchConfiguration: HomeFeedLaunchConfiguration,
        accountMessageViewModel: AccountMessageCenterViewModel?,
        onOpenAccountMessages: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        _detailPath = detailPath
        self.launchConfiguration = launchConfiguration
        self.accountMessageViewModel = accountMessageViewModel
        self.onOpenAccountMessages = onOpenAccountMessages
    }

    var body: some View {
        let renderPack = renderPack

        Group {
            switch primarySection {
            case .recommend, .popular:
                if libraryStore.homePresentationStyle == .immersive {
                    HomeImmersiveFeedScreen(
                        viewModel: viewModel,
                        runtimeSettings: runtimeSettings,
                        libraryStore: dependencies.libraryStore,
                        viewportState: $viewportState,
                        detailPath: $detailPath,
                        usesCinematicNavigationChrome: $usesCinematicNavigationChrome,
                        primarySection: $primarySection,
                        onSelectPrimarySection: selectPrimarySection,
                        accountMessageViewModel: accountMessageViewModel,
                        onOpenAccountMessages: onOpenAccountMessages,
                        contentActions: renderPack.contentActions,
                        actionStore: actionStore,
                        launchConfiguration: launchConfiguration
                    )
                } else {
                    HomeFeedScreenBody(
                        viewModel: viewModel,
                        runtimeSettings: runtimeSettings,
                        libraryStore: dependencies.libraryStore,
                        viewportState: $viewportState,
                        detailPath: $detailPath,
                        contentActions: renderPack.contentActions,
                        actionStore: actionStore,
                        launchConfiguration: launchConfiguration
                    )
                }
            case .regions:
                HomeRegionRankingView()
            case .bangumi:
                HomePgcBrowseView(kind: .bangumi)
            case .cinema:
                HomePgcBrowseView(kind: .cinema)
            }
        }
        .homeFeedNavigationChrome(
            primarySection: $primarySection,
            onSelectSection: selectPrimarySection,
            accountMessageViewModel: accountMessageViewModel,
            isModeSwitcherExperimentEnabled: true,
            prefersCinematicChrome: prefersCinematicChrome,
            onOpenAccountMessages: onOpenAccountMessages
        )
    }

    private var prefersCinematicChrome: Bool {
        libraryStore.homePresentationStyle == .immersive
            && primarySection.feedMode != nil
            && usesCinematicNavigationChrome
    }

    private func selectPrimarySection(_ section: HomePrimarySection) {
        primarySection = section
        guard let mode = section.feedMode, mode != viewModel.mode else { return }
        actionStore.mode.switchMode(mode, viewModel: viewModel)
    }
}
