import SwiftUI

struct FavoriteFolderSelectionSheet: View {
    @ObservedObject var store: VideoDetailFavoriteFolderRenderStore
    let loadFavoriteFolders: (Bool) async -> Void
    let saveFavoriteFolders: (Set<Int>) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var presentationState = FavoriteFolderSelectionPresentationState()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FavoriteFolderEditButton { folder in
                        // Preserve all pending choices while refreshing the server list.
                        presentationState.newlyCreatedFolderIDs.insert(folder.id)
                        presentationState.selectedFolderIDs.insert(folder.id)
                        viewActions.retryLoadingAction()
                    }
                }
                FavoriteFolderSelectionContent(
                    folders: store.favoriteFolders,
                    state: store.favoriteFolderState,
                    selectedFolderIDs: $presentationState.selectedFolderIDs,
                    retry: viewActions.retryLoadingAction
                )
            }
            .disabled(presentationState.saveTask != nil)
            .navigationTitle("选择收藏夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FavoriteFolderSelectionToolbar(
                    canSave: viewActions.canSaveFavoriteFolders,
                    cancel: viewActions.dismissFavoriteFolderSelection,
                    save: viewActions.saveFavoriteFoldersSelection
                )
            }
            .favoriteFolderSelectionLifecycle(
                favoriteFolders: store.favoriteFolders,
                actions: sheetActions
            )
        }
        .favoriteFolderManagement()
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(presentationState.saveTask != nil)
        .onChange(of: store.account) { _, _ in
            // Choices belong to one account, even if another account has folders
            // with the same numeric IDs. Keep an in-flight acknowledgement alive.
            presentationState.selectedFolderIDs = []
            presentationState.newlyCreatedFolderIDs = []
            presentationState.didInitializeSelection = false
            viewActions.initializeSelectionIfNeeded()
        }
        .onDisappear {
            viewActions.cancelPendingTasks()
        }
    }

    private var sheetActions: FavoriteFolderSelectionSheetActions {
        viewActions.sheetActions
    }

    private var viewActions: FavoriteFolderSelectionViewActions {
        FavoriteFolderSelectionViewActionsBuilder(
            store: store,
            loadFavoriteFolders: loadFavoriteFolders,
            saveFavoriteFolders: saveFavoriteFolders,
            dismiss: dismiss,
            presentationState: $presentationState
        )
        .actions
    }
}
