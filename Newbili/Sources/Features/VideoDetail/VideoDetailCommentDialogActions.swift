import Foundation

extension VideoDetailViewModel {
    func dialogReplies(for root: Comment, reply: Comment) -> [Comment] {
        let key = dialogKey(root: root, reply: reply)
        return dialogThreads[key] ?? localDialogReplies(root: root, reply: reply)
    }

    func dialogState(for root: Comment, reply: Comment) -> LoadingState {
        dialogThreadStates[dialogKey(root: root, reply: reply)] ?? .idle
    }

    func dialogReply(root: Comment, replyID: Int) -> Comment? {
        if let reply = (replyThreads[root.id] ?? []).first(where: { $0.id == replyID })
            ?? root.replies?.first(where: { $0.id == replyID }) { return reply }
        for replies in dialogThreads.values {
            if let reply = replies.first(where: { $0.id == replyID }) { return reply }
        }
        return nil
    }

    func loadDialog(for rootID: Int, replyID: Int) async {
        guard let root = replyRoot(for: rootID),
              let reply = dialogReply(root: root, replyID: replyID) else { return }
        let key = dialogKey(root: root, reply: reply)
        guard dialogThreads[key] == nil, dialogThreadStates[key]?.isLoading != true else { return }
        await loadDialogPage(for: rootID, replyID: replyID)
    }

    func reloadDialog(for rootID: Int, replyID: Int) async {
        guard let root = replyRoot(for: rootID),
              let reply = dialogReply(root: root, replyID: replyID) else { return }
        let key = dialogKey(root: root, reply: reply)
        guard dialogThreadStates[key]?.isLoading != true else { return }
        await loadDialogPage(for: rootID, replyID: replyID)
    }

    func loadDialogPage(for rootID: Int, replyID: Int) async {
        guard !Task.isCancelled, let root = replyRoot(for: rootID),
              let reply = dialogReply(root: root, replyID: replyID) else { return }
        guard let target = commentTarget else {
            dialogThreadStates[dialogKey(root: root, reply: reply)] = .failed("没有找到评论对象，无法加载对话")
            return
        }

        let key = dialogKey(root: root, reply: reply)
        let token = beginDialogThreadLoad(for: key)
        defer {
            clearDialogThreadLoadIfCurrent(key: key, token: token)
        }
        let fallbackReplies = filteredComments(localDialogReplies(root: root, reply: reply))

        guard let dialogID = reply.dialogID, dialogID > 0 else {
            guard isCurrentDialogThreadLoad(key: key, rootID: root.id, token: token, target: target) else {
                return
            }
            dialogThreads[key] = fallbackReplies
            dialogThreadStates[key] = .loaded
            return
        }

        dialogThreadStates[key] = .loading
        do {
            let page = try await commentThreadService.fetchCommentDialog(
                oid: target.oid,
                type: target.type,
                root: root.rpid,
                dialog: dialogID,
                size: 20
            )
            try Task.checkCancellation()
            guard isCurrentDialogThreadLoad(key: key, rootID: root.id, token: token, target: target) else {
                return
            }
            let replies = uniqueComments(filteredComments(page.replies ?? []) + fallbackReplies)
            commentThreadState.dialogThreads[key] = replies.isEmpty ? fallbackReplies : replies
            commentThreadState.dialogThreadStates[key] = .loaded
            syncCommentThreadRenderStore()
        } catch {
            guard isCurrentDialogThreadLoad(key: key, rootID: root.id, token: token, target: target) else {
                return
            }
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                commentThreadState.dialogThreadStates[key] = dialogThreads[key] == nil ? .idle : .loaded
            } else {
                if dialogThreads[key] == nil { commentThreadState.dialogThreads[key] = fallbackReplies }
                commentThreadState.dialogThreadStates[key] = .failed(error.localizedDescription)
            }
            syncCommentThreadRenderStore()
        }
    }
}
