import Foundation

extension VideoDetailViewModel {
    func toggleCommentLike(_ requestedComment: Comment) {
        let commentID = requestedComment.id
        guard commentID > 0,
              commentLikeMutationIDs.insert(commentID).inserted,
              let target = commentTarget
        else { return }

        let current = currentComment(withID: commentID) ?? requestedComment
        let originalCount = max(0, current.like ?? 0)
        let originalState = current.likeState ?? 0
        let shouldLike = originalState != 1
        let optimisticCount = max(0, originalCount + (shouldLike ? 1 : -1))
        applyCommentLike(id: commentID, count: optimisticCount, state: shouldLike ? 1 : 0)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.commentLikeMutationIDs.remove(commentID) }
            do {
                try await self.api.setCommentLike(
                    oid: target.oid,
                    type: target.type,
                    rpid: commentID,
                    liked: shouldLike
                )
            } catch {
                self.applyCommentLike(id: commentID, count: originalCount, state: originalState)
                self.interactionMessage = "评论点赞失败：\(error.localizedDescription)"
            }
        }
    }

    private func currentComment(withID id: Int) -> Comment? {
        for comment in comments {
            if let match = findComment(id: id, in: comment) { return match }
        }
        for thread in replyThreads.values {
            for comment in thread {
                if let match = findComment(id: id, in: comment) { return match }
            }
        }
        for thread in dialogThreads.values {
            for comment in thread where comment.id == id { return comment }
        }
        return nil
    }

    private func findComment(id: Int, in comment: Comment) -> Comment? {
        if comment.id == id { return comment }
        for reply in comment.replies ?? [] {
            if let match = findComment(id: id, in: reply) { return match }
        }
        return nil
    }

    private func applyCommentLike(id: Int, count: Int, state: Int) {
        comments = comments.map {
            $0.replacingCommentLike(id: id, count: count, state: state)
        }

        var updatedReplyThreads = replyThreads
        for key in Array(updatedReplyThreads.keys) {
            updatedReplyThreads[key] = updatedReplyThreads[key]?.map {
                $0.replacingCommentLike(id: id, count: count, state: state)
            }
        }
        replyThreads = updatedReplyThreads

        var updatedDialogThreads = dialogThreads
        for key in Array(updatedDialogThreads.keys) {
            updatedDialogThreads[key] = updatedDialogThreads[key]?.map {
                $0.replacingCommentLike(id: id, count: count, state: state)
            }
        }
        dialogThreads = updatedDialogThreads
    }
}
