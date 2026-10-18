import Foundation

nonisolated enum VideoDetailCommentThreadResolver {
    static func dialogKey(root: Comment, reply: Comment) -> String {
        if let dialogID = reply.dialogID, dialogID > 0 {
            return "dialog-\(root.id)-\(dialogID)"
        }
        if let parentID = reply.parentID, parentID > 0, parentID != root.id {
            return "parent-\(root.id)-\(parentID)"
        }
        return "reply-\(root.id)-\(reply.id)"
    }

    static func localDialogReplies(_ reply: Comment, siblings: [Comment], rootID: Int? = nil) -> [Comment] {
        let dialogID = reply.dialogID
        let parentID = reply.parentID
        let knownRootID = rootID ?? reply.rootID
        let relatedReplies = siblings.filter { sibling in
            if sibling.id == reply.id { return true }
            if let dialogID, dialogID > 0 {
                return sibling.dialogID == dialogID
                    || (parentID != knownRootID && sibling.id == parentID)
            }
            if sibling.parentID == reply.id { return true }
            if let parentID, parentID > 0, let knownRootID, parentID != knownRootID {
                return sibling.id == parentID || sibling.parentID == parentID
            }
            return false
        }
        return uniqueComments(relatedReplies + [reply])
    }

    static func uniqueComments(_ comments: [Comment]) -> [Comment] {
        var seen = Set<Int>()
        return comments.filter { comment in
            comment.id > 0 && seen.insert(comment.id).inserted
        }
    }
}

nonisolated struct VideoDetailCommentSignature: Equatable {
    let id: Int
    let like: Int?
    let likeState: Int?
    let replyCount: Int?
    let message: String?
    let replyIDs: [Int]
    let pictureURLs: [String]

    init(_ comment: Comment) {
        id = comment.id
        like = comment.like
        likeState = comment.likeState
        replyCount = comment.replyCount
        message = comment.content?.message
        replyIDs = (comment.replies ?? []).map(\.id)
        pictureURLs = (comment.content?.pictures ?? []).compactMap(\.url)
    }
}
