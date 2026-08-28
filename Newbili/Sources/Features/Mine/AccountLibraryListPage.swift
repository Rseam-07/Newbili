import SwiftUI

struct AccountLibraryListPage: View {
    let kind: AccountLibraryKind
    @ObservedObject var viewModel: MineViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        List {
            Section {
                content
            }
        }
        .nativeTopScrollEdgeEffect()
        .hiddenInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!sessionStore.isLoggedIn || state.isLoading)
            }
        }
        .task {
            await loadIfNeeded()
        }
        .refreshable {
            await reload()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !sessionStore.isLoggedIn {
            LibraryEmptyRow(title: kind.loggedOutTitle, systemImage: kind.systemImage)
        } else if kind == .favorites {
            favoriteFolderContent
        } else {
            historyContent
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if historyItems.isEmpty && state.isLoading {
            LibraryLoadingRow(title: kind.loadingTitle)
        } else if historyItems.isEmpty, case .failed(let message) = state {
            LibraryErrorRow(title: kind.errorTitle, message: message) {
                Task { await reload() }
            }
        } else if historyItems.isEmpty {
            LibraryEmptyRow(title: kind.emptyTitle, systemImage: kind.systemImage)
        } else {
            ForEach(historyItems) { item in
                VideoRouteLink(item.videoItem) {
                    LibraryVideoRow(item: item, timestampTitle: kind.timestampTitle)
                }
                .task {
                    await loadMoreIfNeeded(current: item)
                }
            }

            if state.isLoading {
                LibraryLoadingRow(title: kind.loadingTitle)
            } else if loadMoreState.isLoading {
                LibraryLoadingRow(title: kind.loadMoreTitle)
            } else if case .failed(let message) = state {
                LibraryErrorRow(title: kind.errorTitle, message: message) {
                    Task { await reload() }
                }
            } else if case .failed(let message) = loadMoreState {
                LibraryErrorRow(title: kind.loadMoreErrorTitle, message: message) {
                    Task { await loadMore() }
                }
            } else if hasMore {
                LibraryLoadMoreTriggerRow(title: kind.loadMoreTitle) {
                    Task { await loadMore() }
                }
            }
        }
    }

    @ViewBuilder
    private var favoriteFolderContent: some View {
        if favoriteFolders.isEmpty && state.isLoading {
            LibraryLoadingRow(title: kind.loadingTitle)
        } else if favoriteFolders.isEmpty, case .failed(let message) = state {
            LibraryErrorRow(title: kind.errorTitle, message: message) {
                Task { await reload() }
            }
        } else if favoriteFolders.isEmpty {
            LibraryEmptyRow(title: kind.emptyTitle, systemImage: kind.systemImage)
        } else {
            ForEach(favoriteFolders) { folder in
                NavigationLink {
                    FavoriteFolderContentPage(folder: folder, viewModel: viewModel)
                } label: {
                    FavoriteFolderRow(folder: folder)
                }
            }

            if state.isLoading {
                LibraryLoadingRow(title: kind.loadingTitle)
            } else if case .failed(let message) = state {
                LibraryErrorRow(title: kind.errorTitle, message: message) {
                    Task { await reload() }
                }
            }
        }
    }

    private var historyItems: [AccountVideoEntry] {
        viewModel.accountHistory
    }

    private var state: LoadingState {
        switch kind {
        case .history:
            return viewModel.historyState
        case .favorites:
            return viewModel.favoriteState
        }
    }

    private var favoriteFolders: [FavoriteFolder] {
        viewModel.favoriteFolders
    }

    private var loadMoreState: LoadingState {
        switch kind {
        case .history:
            return viewModel.historyLoadMoreState
        case .favorites:
            return .idle
        }
    }

    private var hasMore: Bool {
        switch kind {
        case .history:
            return viewModel.historyHasMore
        case .favorites:
            return false
        }
    }

    private func loadIfNeeded() async {
        await viewModel.loadAccountLibrary(loadRequest)
    }

    private func reload() async {
        await viewModel.loadAccountLibrary(loadRequest, policy: .reload)
    }

    private func loadMoreIfNeeded(current item: AccountVideoEntry) async {
        switch kind {
        case .history:
            await viewModel.loadMoreHistoryIfNeeded(current: item)
        case .favorites:
            break
        }
    }

    private func loadMore() async {
        switch kind {
        case .history:
            await viewModel.loadMoreHistory()
        case .favorites:
            break
        }
    }

    private var loadRequest: AccountLibraryLoadRequest {
        switch kind {
        case .history:
            return .history
        case .favorites:
            return .favorites
        }
    }
}
