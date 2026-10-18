import SwiftUI

private struct FavoriteFolderPresentationActions {
    var edit: (FavoriteFolder?, @escaping (FavoriteFolder) -> Void) -> Void
    var delete: (FavoriteFolder, @escaping () -> Void) -> Void
}

private struct FavoriteFolderPresentationActionsKey: EnvironmentKey {
    static let defaultValue: FavoriteFolderPresentationActions? = nil
}

private extension EnvironmentValues {
    var favoriteFolderPresentation: FavoriteFolderPresentationActions? {
        get { self[FavoriteFolderPresentationActionsKey.self] }
        set { self[FavoriteFolderPresentationActionsKey.self] = newValue }
    }
}

struct FavoriteFolderEditButton: View {
    var folder: FavoriteFolder? = nil
    let onSaved: (FavoriteFolder) -> Void
    @Environment(\.favoriteFolderPresentation) private var presentation

    var body: some View {
        Button { presentation?.edit(folder, onSaved) } label: {
            Label(folder == nil ? "新建收藏夹" : "编辑收藏夹", systemImage: folder == nil ? "folder.badge.plus" : "pencil")
        }
        .disabled(presentation == nil)
    }
}

struct FavoriteFolderDeleteButton: View {
    let folder: FavoriteFolder
    let onDeleted: () -> Void
    @Environment(\.favoriteFolderPresentation) private var presentation

    var body: some View {
        if !folder.isDefault {
            Button(role: .destructive) { presentation?.delete(folder, onDeleted) } label: {
                Label("删除收藏夹", systemImage: "trash")
            }
            .disabled(presentation == nil)
        }
    }
}

private struct FavoriteFolderDeletion {
    let folder: FavoriteFolder
    let account: FavoriteFolderAccount
    let completed: () -> Void
}

/// Keep presentation on the persistent page, not on a transient Menu or context-menu row.
private struct FavoriteFolderManagementModifier: ViewModifier {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var editor: FavoriteFolderEditorModel?
    @State private var didSave: ((FavoriteFolder) -> Void)?
    @State private var pendingDeletion: FavoriteFolderDeletion?
    @State private var isDeleting = false
    @State private var message: String?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .environment(\.favoriteFolderPresentation, FavoriteFolderPresentationActions(edit: openEditor, delete: requestDeletion))
            .sheet(item: $editor) { model in
                FavoriteFolderEditorView(model: model) { saved in didSave?(saved) }
            }
            .confirmationDialog("删除“\(pendingDeletion?.folder.displayTitle ?? "收藏夹")”？",
                                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                                titleVisibility: .visible) {
                if let pendingDeletion {
                    Button("删除收藏夹", role: .destructive) { delete(pendingDeletion) }
                }
            } message: {
                Text("这个收藏夹及其中的收藏记录会被移除，视频本身不会被删除。")
            }
            .alert("收藏夹操作失败", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
            .overlay(alignment: .bottom) {
                if isDeleting {
                    HStack(spacing: 8) { ProgressView(); Text("正在删除收藏夹").font(.subheadline) }
                        .padding(16).background(.regularMaterial, in: Capsule()).padding(.bottom, 24)
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    private func currentAccount() -> FavoriteFolderAccount? {
        let snapshot = dependencies.sessionStore.credentialSnapshot(
            for: .interaction, multiAccountEnabled: dependencies.libraryStore.multiAccountExperimentEnabled)
        guard snapshot.isLoggedIn, let mid = snapshot.accountMID else { return nil }
        return FavoriteFolderAccount(mid: mid, version: snapshot.version)
    }

    private func openEditor(_ folder: FavoriteFolder?, onSaved: @escaping (FavoriteFolder) -> Void) {
        guard !isDeleting, editor == nil else { return }
        guard let account = currentAccount() else { message = "请先登录收藏操作使用的账号"; return }
        let multiAccount = dependencies.libraryStore.multiAccountExperimentEnabled
        let sessionStore = dependencies.sessionStore
        let libraryStore = dependencies.libraryStore
        didSave = onSaved
        editor = FavoriteFolderEditorModel(folder: folder, account: account, service: dependencies.api) {
            let snapshot = sessionStore.credentialSnapshot(for: .interaction, multiAccountEnabled: multiAccount)
            return snapshot.isLoggedIn && snapshot.accountMID == account.mid && snapshot.version == account.version
                && libraryStore.multiAccountExperimentEnabled == multiAccount
        }
    }

    private func requestDeletion(_ folder: FavoriteFolder, onDeleted: @escaping () -> Void) {
        guard !isDeleting, !folder.isDefault else { return }
        guard let account = currentAccount() else { message = "请先登录"; return }
        pendingDeletion = FavoriteFolderDeletion(folder: folder, account: account, completed: onDeleted)
    }

    private func delete(_ deletion: FavoriteFolderDeletion) {
        guard !isDeleting else { return }
        pendingDeletion = nil
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await dependencies.api.deleteFavoriteFolder(id: deletion.folder.id, account: deletion.account)
                if isVisible, currentAccount() == deletion.account { deletion.completed() }
            } catch { message = error.localizedDescription }
        }
    }
}

extension View {
    func favoriteFolderManagement() -> some View { modifier(FavoriteFolderManagementModifier()) }
}

private struct FavoriteFolderEditorView: View {
    @ObservedObject var model: FavoriteFolderEditorModel
    let onSaved: (FavoriteFolder) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false
    @FocusState private var focusesTitle: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("收藏夹名称", text: $model.draft.title)
                        .focused($focusesTitle)
                        .disabled(model.folder?.isDefault == true)
                        .submitLabel(.done)
                    TextField("简介（可选）", text: $model.draft.intro, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text(model.folder?.isDefault == true ? "默认收藏夹的名称由哔哩哔哩管理。" : "名称最多 20 个字，简介最多 500 个字。")
                }
                Section {
                    Toggle("公开收藏夹", isOn: $model.draft.isPublic)
                } footer: {
                    Text(model.draft.isPublic ? "其他人可以在你的空间查看此收藏夹。" : "仅你自己可见。")
                }
                if case .failed(let message) = model.state {
                    Section { Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .disabled(model.state.isLoading)
            .scrollContentBackground(.hidden)
            .background(AppSurfaceColors.groupedPage)
            .navigationTitle(model.folder == nil ? "新建收藏夹" : "编辑收藏夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if model.hasChanges { confirmsDiscard = true } else { dismiss() } }
                        .disabled(model.state.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if let saved = await model.save() {
                                if model.canApplyResult { onSaved(saved) }
                                dismiss()
                            }
                        }
                    } label: {
                        if model.state.isLoading { ProgressView() } else { Text("保存").bold() }
                    }
                    .disabled(!model.canSave)
                }
            }
        }
        .interactiveDismissDisabled(model.hasChanges || model.state.isLoading)
        .confirmationDialog("放弃未保存的修改？", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) { dismiss() }
        }
        .presentationDetents([.large])
        .task { focusesTitle = model.folder == nil }
    }
}

