import Combine
import SwiftUI

struct MineView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var libraryStore: LibraryStore
    @ObservedObject var holder: MineViewModelHolder
    let onOpenRoute: (MineOverlayRoute) -> Void
    @State private var loginSheet: LoginSheet?
    @State private var loadedMainAccountCredentialVersion: Int?
    @State private var loadedHistoryAccountCredentialVersion: Int?
    @State private var loadedInteractionAccountCredentialVersion: Int?
    @State private var loadedMultiAccountExperimentEnabled: Bool?

    var body: some View {
        Group {
            if let viewModel = holder.viewModel,
               let accountMessageViewModel = holder.accountMessageViewModel {
                content(viewModel, accountMessageViewModel: accountMessageViewModel)
            } else {
                ProgressView()
                    .task {
                        holder.configure(
                            api: dependencies.api,
                            sessionStore: sessionStore,
                            accountMessageService: dependencies.accountMessageService
                        )
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .rootNavigationTitle("我的")
        .nativeTopNavigationChrome()
        .environment(\.scrollEdgeEffectPreference, libraryStore.scrollEdgeEffectPreference)
        .sheet(item: $loginSheet) { sheet in
            if let viewModel = holder.viewModel {
                switch sheet {
                case .web:
                    BiliWebLoginView { cookies in
                        Task {
                            await viewModel.completeWebLogin(with: cookies)
                            loginSheet = nil
                        }
                    }
                case .qrCode:
                    QRCodeLoginView(viewModel: viewModel)
                case .sms:
                    SMSLoginView(viewModel: viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private func content(
        _ viewModel: MineViewModel,
        accountMessageViewModel: AccountMessageCenterViewModel
    ) -> some View {
        MineContentView(
            viewModel: viewModel,
            accountMessageViewModel: accountMessageViewModel,
            sessionStore: sessionStore,
            libraryStore: libraryStore,
            onQRCodeLogin: { loginSheet = .qrCode },
            onSMSLogin: { loginSheet = .sms },
            onWebLogin: { loginSheet = .web },
            onOpenRoute: onOpenRoute
        )
        .task(id: MineAccountRefreshTaskID(
            mainCredentialVersion: sessionStore.playbackCredentialVersion,
            historyCredentialVersion: sessionStore.historyAccountCredentialVersion,
            interactionCredentialVersion: sessionStore.interactionAccountCredentialVersion,
            multiAccountExperimentEnabled: libraryStore.multiAccountExperimentEnabled
        )) {
            guard sessionStore.isLoggedIn else {
                loadedMainAccountCredentialVersion = nil
                loadedHistoryAccountCredentialVersion = nil
                loadedInteractionAccountCredentialVersion = nil
                loadedMultiAccountExperimentEnabled = nil
                return
            }
            let mainCredentialVersion = sessionStore.playbackCredentialVersion
            let historyCredentialVersion = sessionStore.historyAccountCredentialVersion
            let interactionCredentialVersion = sessionStore.interactionAccountCredentialVersion
            let mainAccountChanged = loadedMainAccountCredentialVersion != mainCredentialVersion
            let historyAccountChanged = loadedHistoryAccountCredentialVersion != historyCredentialVersion
            let interactionAccountChanged = loadedInteractionAccountCredentialVersion != interactionCredentialVersion
            let experimentModeChanged = loadedMultiAccountExperimentEnabled != libraryStore.multiAccountExperimentEnabled
            loadedMainAccountCredentialVersion = mainCredentialVersion
            loadedHistoryAccountCredentialVersion = historyCredentialVersion
            loadedInteractionAccountCredentialVersion = interactionCredentialVersion
            loadedMultiAccountExperimentEnabled = libraryStore.multiAccountExperimentEnabled

            if mainAccountChanged {
                viewModel.invalidateAccountLibraries([
                    .history,
                    .favorites,
                    .watchLater(filter: .all, keyword: "", sortOrder: .newest)
                ])
            } else {
                var invalidatedLibraries: [AccountLibraryLoadRequest] = []
                if historyAccountChanged || experimentModeChanged {
                    invalidatedLibraries.append(.history)
                }
                if interactionAccountChanged || experimentModeChanged {
                    invalidatedLibraries.append(.favorites)
                    invalidatedLibraries.append(
                        .watchLater(filter: .all, keyword: "", sortOrder: .newest)
                    )
                }
                viewModel.invalidateAccountLibraries(invalidatedLibraries)
            }

            if mainAccountChanged {
                async let userRefresh: Void = viewModel.refreshUser()
                async let unreadRefresh: Void = accountMessageViewModel.refreshUnread()
                _ = await (userRefresh, unreadRefresh)
            }
        }
    }
}

private struct MineAccountRefreshTaskID: Hashable {
    let mainCredentialVersion: Int
    let historyCredentialVersion: Int
    let interactionCredentialVersion: Int
    let multiAccountExperimentEnabled: Bool
}

private enum LoginSheet: Identifiable, Hashable {
    case qrCode
    case sms
    case web

    var id: Self { self }
}

@MainActor
final class MineViewModelHolder: ObservableObject {
    @Published var viewModel: MineViewModel?
    @Published var accountMessageViewModel: AccountMessageCenterViewModel?
    private var cancellable: AnyCancellable?
    private var lastSnapshot: MineRenderSnapshot?

    func configure(
        api: BiliAPIClient,
        sessionStore: SessionStore,
        accountMessageService: AccountMessageService
    ) {
        if viewModel == nil {
            let viewModel = MineViewModel(api: api, sessionStore: sessionStore)
            self.viewModel = viewModel
            lastSnapshot = MineRenderSnapshot(viewModel)
            cancellable = viewModel.objectWillChange.sink { [weak self, weak viewModel] _ in
                Task { @MainActor [weak self, weak viewModel] in
                    guard let self, let viewModel else { return }
                    let snapshot = MineRenderSnapshot(viewModel)
                    guard snapshot != self.lastSnapshot else { return }
                    self.lastSnapshot = snapshot
                    self.objectWillChange.send()
                }
            }
        }
        if accountMessageViewModel == nil {
            accountMessageViewModel = AccountMessageCenterViewModel(
                service: accountMessageService,
                sessionStore: sessionStore
            )
        }
    }
}

private struct MineRenderSnapshot: Equatable {
    let state: LoadingState
    let loginMessage: String
    let qrLoginState: QRCodeLoginState

    init(_ viewModel: MineViewModel) {
        state = viewModel.state
        loginMessage = viewModel.loginMessage
        qrLoginState = viewModel.qrLoginState
    }
}
