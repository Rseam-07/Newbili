import Foundation

nonisolated struct VideoDetailCommentDeepLinkLoadResult: Equatable {
    let rootComment: Comment
    let focusedReplyID: Int?
}

extension VideoDetailViewModel {
    func loadCommentRoot(for anchor: VideoCommentAnchor) async -> VideoDetailCommentDeepLinkLoadResult? {
        guard let target = commentTarget else { return nil }

        do {
            let page = try await commentThreadService.fetchCommentReplies(
                oid: target.oid,
                type: target.type,
                root: anchor.rootID,
                page: 1,
                sort: .time
            )
            guard !Task.isCancelled,
                  isCurrentCommentTarget(target)
            else {
                return nil
            }

            guard let rootComment = page.root
                ?? page.replies?.first(where: { $0.id == anchor.rootID })
            else {
                return nil
            }

            var rawReplies = page.replies ?? []
            var replies = uniqueComments(filteredComments(rawReplies))
            var lastLoadedPage = 1
            var reachedEmptyPage = rawReplies.isEmpty
            let additionalPages = VideoDetailCommentDeepLinkResolution.additionalPageNumbers(
                replyCount: rootComment.replyCount,
                knownReplyIDs: Set(replies.map(\.id)),
                targetReplyID: anchor.secondaryID
            )

            for pageNumber in additionalPages {
                guard VideoDetailCommentDeepLinkResolution.focusedReplyID(
                    requestedReplyID: anchor.secondaryID,
                    rootID: rootComment.id,
                    replies: replies
                ) == nil
                else {
                    break
                }

                do {
                    let nextPage = try await commentThreadService.fetchCommentReplies(
                        oid: target.oid,
                        type: target.type,
                        root: anchor.rootID,
                        page: pageNumber,
                        sort: .time
                    )
                    guard !Task.isCancelled,
                          isCurrentCommentTarget(target)
                    else {
                        return nil
                    }

                    let nextRawReplies = nextPage.replies ?? []
                    guard !nextRawReplies.isEmpty else {
                        reachedEmptyPage = true
                        break
                    }
                    rawReplies += nextRawReplies
                    replies = uniqueComments(filteredComments(rawReplies))
                    lastLoadedPage = pageNumber
                } catch {
                    break
                }
            }

            cacheDeepLinkedReplyThread(
                rootComment: rootComment,
                replies: replies,
                lastLoadedPage: lastLoadedPage,
                reachedEmptyPage: reachedEmptyPage,
                target: target
            )
            return VideoDetailCommentDeepLinkLoadResult(
                rootComment: rootComment,
                focusedReplyID: VideoDetailCommentDeepLinkResolution.focusedReplyID(
                    requestedReplyID: anchor.secondaryID,
                    rootID: rootComment.id,
                    replies: replies
                )
            )
        } catch {
            return nil
        }
    }

    private func cacheDeepLinkedReplyThread(
        rootComment: Comment,
        replies: [Comment],
        lastLoadedPage: Int,
        reachedEmptyPage: Bool,
        target: VideoDetailCommentTarget
    ) {
        commentThreadState.deepLinkAnchor = VideoDetailCommentThreadAnchor(
            contextKey: target.contextKey,
            rootID: rootComment.id
        )
        registerReplyRoot(rootComment)
        commentThreadState.replyThreads[rootComment.id] = replies
        commentThreadState.replyThreadPages[rootComment.id] = lastLoadedPage
        commentThreadState.replyThreadHasMore[rootComment.id] = VideoDetailCommentDeepLinkResolution.hasMoreReplies(
            replyCount: rootComment.replyCount,
            loadedReplyCount: replies.count,
            reachedEmptyPage: reachedEmptyPage
        )
        commentThreadState.replyThreadStates[rootComment.id] = .loaded
        syncCommentThreadRenderStore()
    }

    func replies(for comment: Comment) -> [Comment] {
        replyThreads[comment.id] ?? comment.replies ?? []
    }

    func hasMoreReplies(for comment: Comment) -> Bool {
        if let hasMore = replyThreadHasMore[comment.id] {
            return hasMore
        }
        let loadedCount = replies(for: comment).count
        let totalCount = comment.replyCount ?? comment.replies?.count ?? loadedCount
        return loadedCount < totalCount
    }

    func replyState(for comment: Comment) -> LoadingState {
        replyThreadStates[comment.id] ?? .idle
    }

    func registerReplyRoot(_ comment: Comment) {
        guard comment.id > 0, let target = commentTarget else { return }
        if commentThreadState.replyRootContextKey != target.contextKey {
            commentThreadState.replyRoots.removeAll()
            commentThreadState.replyRootContextKey = target.contextKey
        }
        commentThreadState.replyRoots[comment.id] = comment
    }

    func replyRoot(for rootID: Int) -> Comment? {
        guard rootID > 0, !isPlaybackInvalidatedForNavigation else { return nil }
        if let root = comments.first(where: { $0.id == rootID }) { return root }
        guard commentThreadState.replyRootContextKey == commentTarget?.contextKey else { return nil }
        return commentThreadState.replyRoots[rootID]
    }

    func loadReplies(for rootID: Int) async {
        guard rootID > 0,
              (replyThreadPages[rootID] ?? 0) == 0,
              !(replyThreadStates[rootID]?.isLoading ?? false) else { return }
        await loadReplyPage(for: rootID, reset: true)
    }

    func reloadReplies(for rootID: Int) async {
        guard rootID > 0, !(replyThreadStates[rootID]?.isLoading ?? false) else { return }
        await loadReplyPage(for: rootID, reset: true)
    }

    func loadMoreReplies(for rootID: Int) async {
        guard rootID > 0,
              replyThreadHasMore[rootID] != false || commentThreadState.replyThreadRetryPages[rootID] != nil,
              !(replyThreadStates[rootID]?.isLoading ?? false) else { return }
        let reset = commentThreadState.replyThreadRetryPages[rootID] == 1 || (replyThreadPages[rootID] ?? 0) == 0
        await loadReplyPage(for: rootID, reset: reset)
    }
}
