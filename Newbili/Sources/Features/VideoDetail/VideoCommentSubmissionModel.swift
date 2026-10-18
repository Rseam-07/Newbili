import Combine
import Foundation

@MainActor
protocol VideoCommentSubmitting {
    func submitComment(oid: String, type: Int, message: String, root: Int?, parent: Int?) async throws
}

extension BiliAPIClient: VideoCommentSubmitting {}

@MainActor
final class VideoCommentSubmissionModel: ObservableObject, Identifiable {
    let id = UUID()
    let target: VideoDetailCommentTarget
    let rootID: Int?
    let parentID: Int?
    let recipientName: String?
    @Published var draft = ""
    @Published private(set) var state: LoadingState = .idle
    private let service: any VideoCommentSubmitting
    private let isCurrent: @MainActor () -> Bool
    private let didSubmit: @MainActor () -> Void

    init(target: VideoDetailCommentTarget, rootID: Int? = nil, parentID: Int? = nil, recipientName: String? = nil,
         service: any VideoCommentSubmitting, isCurrent: @escaping @MainActor () -> Bool,
         didSubmit: @escaping @MainActor () -> Void) {
        self.target = target
        self.rootID = rootID
        self.parentID = parentID
        self.recipientName = recipientName
        self.service = service
        self.isCurrent = isCurrent
        self.didSubmit = didSubmit
    }

    var normalizedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSubmit: Bool { !state.isLoading && !normalizedDraft.isEmpty && normalizedDraft.count <= 1_000 }

    func submit() async -> Bool {
        guard !state.isLoading else { return false }
        do {
            let message = try BiliAPIClient.validatedCommentMessage(draft)
            guard isCurrent(), !Task.isCancelled else {
                state = .failed("视频或登录账号已切换，请返回当前评论重新打开编辑器")
                return false
            }
            guard rootID == nil && parentID == nil
                    || (rootID ?? 0) > 0 && (parentID ?? 0) > 0 else {
                state = .failed("回复目标无效，请重新选择要回复的评论")
                return false
            }
            state = .loading
            try await service.submitComment(oid: target.oid, type: target.type, message: message, root: rootID, parent: parentID)
            // A successful server acknowledgement remains a success even if the
            // user changes context while the non-idempotent request is in flight.
            state = .loaded
            draft = ""
            if isCurrent() { didSubmit() }
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
}
