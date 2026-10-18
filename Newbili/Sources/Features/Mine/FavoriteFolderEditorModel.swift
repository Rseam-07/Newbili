import Combine
import Foundation

nonisolated struct FavoriteFolderAccount: Equatable, Sendable {
    let mid: Int
    let version: Int
}

nonisolated struct FavoriteFolderDraft: Equatable, Sendable {
    var title: String
    var intro: String
    var isPublic: Bool
    let cover: String

    var validationMessage: String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "请输入收藏夹名称" }
        if title.count > 20 { return "收藏夹名称最多 20 个字" }
        if intro.count > 500 { return "简介最多 500 个字" }
        return nil
    }
}

nonisolated protocol FavoriteFolderEditing: Sendable {
    func saveFavoriteFolder(id: Int?, draft: FavoriteFolderDraft, account: FavoriteFolderAccount) async throws -> FavoriteFolder
    func deleteFavoriteFolder(id: Int, account: FavoriteFolderAccount) async throws
}

nonisolated enum FavoriteFolderEditError: LocalizedError {
    case staleAccount
    case validation(String)
    var errorDescription: String? {
        switch self {
        case .staleAccount: "账号已切换，请关闭此页面后重新打开"
        case .validation(let message): message
        }
    }
}

extension FavoriteFolder {
    nonisolated var isPublic: Bool { (attr ?? 1) & 1 == 0 }
    nonisolated var isDefault: Bool { attr.map { $0 & 2 == 0 } ?? false }
}

@MainActor
final class FavoriteFolderEditorModel: ObservableObject, Identifiable {
    let id = UUID()
    let folder: FavoriteFolder?
    let account: FavoriteFolderAccount
    @Published var draft: FavoriteFolderDraft
    @Published private(set) var state: LoadingState = .idle
    private let originalDraft: FavoriteFolderDraft
    private let service: any FavoriteFolderEditing
    private let isCurrent: @MainActor () -> Bool

    init(folder: FavoriteFolder?, account: FavoriteFolderAccount, service: any FavoriteFolderEditing,
         isCurrent: @escaping @MainActor () -> Bool) {
        self.folder = folder
        self.account = account
        self.service = service
        self.isCurrent = isCurrent
        let initial = FavoriteFolderDraft(title: folder?.title ?? "", intro: folder?.intro ?? "",
                                          isPublic: folder?.isPublic ?? false, cover: folder?.cover ?? "")
        originalDraft = initial
        draft = initial
    }

    var canApplyResult: Bool { isCurrent() }
    var hasChanges: Bool { draft != originalDraft }
    var canSave: Bool { !state.isLoading && state != .loaded && draft.validationMessage == nil && (folder == nil || hasChanges) }

    func save() async -> FavoriteFolder? {
        guard !state.isLoading, state != .loaded else { return nil }
        guard isCurrent() else { state = .failed(FavoriteFolderEditError.staleAccount.localizedDescription); return nil }
        if let message = draft.validationMessage { state = .failed(message); return nil }
        let submitted = draft
        state = .loading
        do {
            let folder = try await service.saveFavoriteFolder(id: folder?.id, draft: submitted, account: account)
            state = .loaded
            return folder
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }
}
