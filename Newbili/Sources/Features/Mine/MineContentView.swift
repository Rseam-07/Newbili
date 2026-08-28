import SwiftUI

struct MineContentView: View {
    @ObservedObject var viewModel: MineViewModel
    @ObservedObject var accountMessageViewModel: AccountMessageCenterViewModel
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var libraryStore: LibraryStore
    let onQRCodeLogin: () -> Void
    let onSMSLogin: () -> Void
    let onWebLogin: () -> Void
    let onOpenRoute: (MineOverlayRoute) -> Void

    var body: some View {
        Form {
            MineAccountSection(
                display: MineAccountProfileDisplayModel(
                    user: sessionStore.user,
                    fallbackAccount: sessionStore.mainAccount
                ),
                profileState: viewModel.state,
                loginMessage: viewModel.loginMessage,
                isLoggedIn: sessionStore.isLoggedIn,
                multiAccountExperimentEnabled: libraryStore.multiAccountExperimentEnabled,
                onQRCodeLogin: onQRCodeLogin,
                onSMSLogin: onSMSLogin,
                onWebLogin: onWebLogin,
                onOpenRoute: onOpenRoute,
                onRefreshProfile: {
                    Task {
                        await viewModel.refreshUser()
                    }
                },
                onLogout: viewModel.logout
            )

            MineAccountLibrarySection(
                accountMessageViewModel: accountMessageViewModel,
                isLoggedIn: sessionStore.isLoggedIn,
                onOpenRoute: onOpenRoute
            )

            MineSettingsSection(
                libraryStore: libraryStore,
                onOpenRoute: onOpenRoute
            )
            MineAboutSection()
        }
        .tint(libraryStore.appTintColor)
        .formStyle(.grouped)
        .nativeTopScrollEdgeEffect()
    }
}
