import Foundation

extension VideoDetailViewModel {
    func cancelCommentsLoadingTask(advancesGeneration: Bool = true) {
        commentsLoadingTask?.cancel()
        commentsLoadingTask = nil
        commentsLoadingToken = nil
        if advancesGeneration {
            advanceCommentPageLoadGeneration()
        }
    }

    func clearCommentThreadLoads() {
        replyThreadLoadTokens.removeAll()
        dialogThreadLoadTokens.removeAll()
        for (rootID, state) in commentThreadState.replyThreadStates where state.isLoading {
            commentThreadState.replyThreadStates[rootID] = (replyThreadPages[rootID] ?? 0) > 0 ? .loaded : .idle
        }
        for (key, state) in commentThreadState.dialogThreadStates where state.isLoading {
            commentThreadState.dialogThreadStates[key] = dialogThreads[key] == nil ? .idle : .loaded
        }
        syncCommentThreadRenderStore()
    }

    func clearCommentThreadCaches(preservingRootID: Int? = nil) {
        let previous = commentThreadState
        var next = VideoDetailCommentThreadState()
        if let rootID = preservingRootID {
            next.replyRoots[rootID] = previous.replyRoots[rootID]
            next.replyRootContextKey = previous.replyRootContextKey
            next.replyThreads[rootID] = previous.replyThreads[rootID]
            next.replyThreadStates[rootID] = previous.replyThreadStates[rootID]
            next.replyThreadPages[rootID] = previous.replyThreadPages[rootID]
            next.replyThreadHasMore[rootID] = previous.replyThreadHasMore[rootID]
            next.replyThreadRetryPages[rootID] = previous.replyThreadRetryPages[rootID]
            next.deepLinkAnchor = previous.deepLinkAnchor
        }
        commentThreadState = next
        syncCommentThreadRenderStore()
    }

    func resetCommentThreadStateForNewComments() {
        clearCommentThreadLoads()
        guard let anchor = commentThreadState.deepLinkAnchor,
              anchor.contextKey == commentTarget?.contextKey
        else {
            clearCommentThreadCaches()
            return
        }
        clearCommentThreadCaches(preservingRootID: anchor.rootID)
    }

    func clearDeepLinkCommentThreadAnchor() {
        commentThreadState.deepLinkAnchor = nil
    }

    @discardableResult
    func beginReplyThreadLoad(for commentID: Int) -> UUID {
        let token = UUID()
        replyThreadLoadTokens[commentID] = token
        return token
    }

    func isCurrentReplyThreadLoad(
        commentID: Int,
        token: UUID,
        target: VideoDetailCommentTarget
    ) -> Bool {
        replyThreadLoadTokens[commentID] == token
            && (comments.contains { $0.id == commentID }
                || replyThreadStates[commentID] != nil)
            && commentTarget == target
            && !isPlaybackInvalidatedForNavigation
    }

    func clearReplyThreadLoadIfCurrent(commentID: Int, token: UUID) {
        guard replyThreadLoadTokens[commentID] == token else { return }
        replyThreadLoadTokens[commentID] = nil
    }

    @discardableResult
    func beginDialogThreadLoad(for key: String) -> UUID {
        let token = UUID()
        dialogThreadLoadTokens[key] = token
        return token
    }

    func isCurrentDialogThreadLoad(
        key: String,
        rootID: Int,
        token: UUID,
        target: VideoDetailCommentTarget
    ) -> Bool {
        dialogThreadLoadTokens[key] == token
            && (comments.contains { $0.id == rootID }
                || replyThreadStates[rootID] != nil)
            && commentTarget == target
            && !isPlaybackInvalidatedForNavigation
    }

    func clearDialogThreadLoadIfCurrent(key: String, token: UUID) {
        guard dialogThreadLoadTokens[key] == token else { return }
        dialogThreadLoadTokens[key] = nil
    }
}
