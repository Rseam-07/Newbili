import Combine
import Foundation

@MainActor
final class VideoDetailCommentThreadRenderStore: ObservableObject {
    @Published var snapshot = VideoDetailCommentThreadRenderSnapshot()
    var replyDisplayCache: [Int: VideoDetailCommentReplyDisplayCacheEntry] = [:]
    var dialogDisplayCache: [String: VideoDetailCommentDialogDisplayCacheEntry] = [:]

    func update(
        replyThreads: [Int: [Comment]],
        replyThreadStates: [Int: LoadingState],
        replyThreadHasMore: [Int: Bool],
        dialogThreads: [String: [Comment]],
        dialogThreadStates: [String: LoadingState]
    ) {
        setSnapshot(
            VideoDetailCommentThreadRenderSnapshot(
                replyThreads: replyThreads,
                replyThreadStates: replyThreadStates,
                replyThreadHasMore: replyThreadHasMore,
                dialogThreads: dialogThreads,
                dialogThreadStates: dialogThreadStates
            )
        )
    }

    private func setSnapshot(_ next: VideoDetailCommentThreadRenderSnapshot) {
        guard next.changeSignature != snapshot.changeSignature else { return }
        let activeRoots = Set(next.replyThreads.keys).union(next.replyThreadStates.keys)
        let activeDialogs = Set(next.dialogThreads.keys).union(next.dialogThreadStates.keys)
        replyDisplayCache = replyDisplayCache.filter { activeRoots.contains($0.key) }
        dialogDisplayCache = dialogDisplayCache.filter { activeDialogs.contains($0.key) }
        snapshot = next
    }
}
