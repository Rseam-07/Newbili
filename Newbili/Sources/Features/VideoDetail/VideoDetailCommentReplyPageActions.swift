import Foundation

extension VideoDetailViewModel {
    func loadReplyPage(for rootID: Int, reset: Bool) async {
        guard !Task.isCancelled, let comment = replyRoot(for: rootID) else { return }
        guard let target = commentTarget else {
            replyThreadStates[rootID] = .failed("没有找到评论对象，无法加载回复")
            return
        }
        let token = beginReplyThreadLoad(for: rootID)
        defer {
            clearReplyThreadLoadIfCurrent(commentID: rootID, token: token)
        }
        replyThreadStates[rootID] = .loading
        do {
            let nextPage = reset ? 1 : (replyThreadPages[rootID] ?? 0) + 1
            commentThreadState.replyThreadRetryPages[rootID] = nextPage
            let page = try await commentThreadService.fetchCommentReplies(
                oid: target.oid,
                type: target.type,
                root: rootID,
                page: nextPage,
                sort: .time
            )
            try Task.checkCancellation()
            guard isCurrentReplyThreadLoad(commentID: rootID, token: token, target: target) else {
                return
            }
            let rawReplies = (page.replies ?? []).filter { $0.id > 0 && $0.id != rootID }
            let fetchedReplies = filteredComments(rawReplies)
            let existingReplies = reset
                ? []
                : filteredComments(replyThreads[rootID] ?? [])
            let replies = uniqueComments(existingReplies + fetchedReplies)
            if let updatedRoot = page.root, updatedRoot.id == rootID { registerReplyRoot(updatedRoot) }
            commentThreadState.replyThreads[rootID] = replies
            commentThreadState.replyThreadPages[rootID] = nextPage
            commentThreadState.replyThreadHasMore[rootID] = page.hasMoreThreadReplies(
                requestedPage: nextPage,
                rawReplyCount: rawReplies.count,
                fallbackTotal: page.root?.replyCount ?? comment.replyCount
            )
            commentThreadState.replyThreadStates[rootID] = .loaded
            commentThreadState.replyThreadRetryPages[rootID] = nil
            syncCommentThreadRenderStore()
        } catch {
            guard isCurrentReplyThreadLoad(commentID: rootID, token: token, target: target) else {
                return
            }
            if commentThreadState.replyThreads[rootID] == nil {
                commentThreadState.replyThreads[rootID] = uniqueComments(filteredComments(comment.replies ?? []))
            }
            let wasCancelled = Task.isCancelled || error is CancellationError
                || (error as? URLError)?.code == .cancelled
            commentThreadState.replyThreadStates[rootID] = wasCancelled
                ? ((replyThreadPages[rootID] ?? 0) > 0 ? .loaded : .idle)
                : .failed(error.localizedDescription)
            // Keep the last successful page and its availability so Retry requests
            // the same page. Preview replies are not a successfully loaded page.
            syncCommentThreadRenderStore()
        }
    }
}
