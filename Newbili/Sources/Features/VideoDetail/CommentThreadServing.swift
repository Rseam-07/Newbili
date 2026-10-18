import Foundation

@MainActor
protocol CommentThreadServing {
    func fetchCommentReplies(oid: String, type: Int, root: Int, page: Int, sort: CommentSort?) async throws -> CommentPage
    func fetchCommentDialog(oid: String, type: Int, root: Int, dialog: Int, size: Int) async throws -> CommentPage
}

extension BiliAPIClient: CommentThreadServing {}
