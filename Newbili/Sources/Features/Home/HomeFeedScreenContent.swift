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
        .homeFeedNavigationChrome(
            viewModel: viewModel,
            modeActions: actionStore.mode,
            accountMessageViewModel: accountMessageViewModel,
            isModeSwitcherExperimentEnabled: libraryStore.homeNavigationModeSwitcherExperimentEnabled,
            onOpenAccountMessages: onOpenAccountMessages
        )
    }
}
