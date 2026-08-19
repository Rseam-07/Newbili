import SwiftUI

struct HomeView: View {
    let launchConfiguration: HomeFeedLaunchConfiguration
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void
    @ObservedObject private var viewModel: HomeViewModel
    @Binding var detailPath: NavigationPath

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
        HomeFeedScreenContent(
            viewModel: viewModel,
            detailPath: $detailPath,
            launchConfiguration: launchConfiguration,
            accountMessageViewModel: accountMessageViewModel,
            onOpenAccountMessages: onOpenAccountMessages
        )
    }
}
