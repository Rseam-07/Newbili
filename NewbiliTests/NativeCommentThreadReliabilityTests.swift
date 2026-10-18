import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct NativeCommentThreadReliabilityTests {
    @Test func directRepliesWithoutDialogIDsDoNotShareADialogCacheEntry() throws {
        let root = try comment(100)
        let replies = try JSONDecoder().decode([bili.Comment].self, from: Data(#"[{"rpid":101,"root":100,"parent":100},{"rpid":102,"root":100,"parent":100}]"#.utf8))
        #expect(VideoDetailCommentThreadResolver.dialogKey(root: root, reply: replies[0]) != VideoDetailCommentThreadResolver.dialogKey(root: root, reply: replies[1]))
    }

    @Test func localConversationAlwaysIncludesItsSelectedReplyEvenWhenNotInThePreview() throws {
        let replies = try JSONDecoder().decode([bili.Comment].self, from: Data(#"[{"rpid":101,"root":100,"parent":100,"dialog":7},{"rpid":102,"root":100,"parent":101,"dialog":7}]"#.utf8))
        let result = VideoDetailCommentThreadResolver.localDialogReplies(replies[1], siblings: [replies[0]], rootID: 100)
        #expect(Set(result.map(\.id)) == [101, 102])
    }

    @Test func localConversationDoesNotMixOtherDialogsThatShareTheRootParent() throws {
        let values = try JSONDecoder().decode([bili.Comment].self, from: Data(#"[{"rpid":101,"root":100,"parent":100,"dialog":7},{"rpid":102,"root":100,"parent":100,"dialog":8},{"rpid":103,"root":100,"parent":101,"dialog":7}]"#.utf8))
        #expect(VideoDetailCommentThreadResolver.localDialogReplies(values[0], siblings: values, rootID: 100).map(\.id) == [101, 103])
    }

    @Test func invalidatingLoadsClearsTheSpinnerAndRejectsTheirLateResponses() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.suspends = true
        let model = makeModel(service, root: root)
        let task = Task { await model.loadReplies(for: root.id) }
        await service.started()
        model.clearCommentThreadLoads()
        #expect(model.replyState(for: root) == .idle)
        service.finish(try page([101, 102], total: 2))
        await task.value
        #expect(model.replyThreads.isEmpty)
    }

    @Test func firstPageUsesServerOrderRatherThanHotPreviewOrder() async throws {
        let root = try comment(100, preview: [303, 202], total: 4)
        let service = ControlledCommentThreads()
        service.responses = [.success(try page([101, 202, 202, 100], total: 4))]
        let model = makeModel(service, root: root)
        await model.loadReplies(for: root.id)
        #expect(model.replies(for: root).map(\.id) == [101, 202])
        #expect(model.replyState(for: root) == .loaded)
        #expect(model.hasMoreReplies(for: root))
    }

    @Test func failedNextPageKeepsDataAndRetriesTheSamePage() async throws {
        let root = try comment(100, total: 4)
        let service = ControlledCommentThreads()
        service.responses = [.success(try page([101, 102], total: 4)), .failure(BiliAPIError.emptyData),
                             .success(try page([102, 103, 104], total: 4, number: 2))]
        let model = makeModel(service, root: root)
        await model.loadReplies(for: root.id)
        await model.loadMoreReplies(for: root.id)
        #expect(model.replies(for: root).map(\.id) == [101, 102])
        #expect(isFailed(model.replyState(for: root)))
        #expect(model.replyThreadPages[root.id] == 1)
        await model.loadMoreReplies(for: root.id)
        #expect(service.requestedPages == [1, 2, 2])
        #expect(model.replies(for: root).map(\.id) == [101, 102, 103, 104])
        #expect(!model.hasMoreReplies(for: root))
    }

    @Test func previewFallbackRemainsAnErrorUntilFirstPageActuallySucceeds() async throws {
        let root = try comment(100, preview: [202], total: 2)
        let service = ControlledCommentThreads()
        service.responses = [.failure(BiliAPIError.emptyData), .success(try page([101, 202], total: 2))]
        let model = makeModel(service, root: root)
        await model.loadReplies(for: root.id)
        #expect(model.replies(for: root).map(\.id) == [202])
        #expect(isFailed(model.replyState(for: root)))
        #expect((model.replyThreadPages[root.id] ?? 0) == 0)
        await model.loadMoreReplies(for: root.id)
        #expect(service.requestedPages == [1, 1])
        #expect(model.replies(for: root).map(\.id) == [101, 202])
    }

    @Test func failedRefreshOfExhaustedThreadCanStillRetryPageOne() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.responses = [.success(try page([101, 102], total: 2)), .failure(BiliAPIError.emptyData),
                             .success(try page([103, 104], total: 2))]
        let model = makeModel(service, root: root)
        await model.loadReplies(for: root.id)
        #expect(!model.hasMoreReplies(for: root))
        await model.reloadReplies(for: root.id)
        #expect(model.replies(for: root).map(\.id) == [101, 102])
        await model.loadMoreReplies(for: root.id)
        #expect(service.requestedPages == [1, 1, 1])
        #expect(model.replies(for: root).map(\.id) == [103, 104])
    }

    @Test func concurrentSheetCallbacksMakeOnlyOneRequest() async throws {
        let root = try comment(100, total: 4)
        let service = ControlledCommentThreads()
        service.suspends = true
        let model = makeModel(service, root: root)
        let first = Task { await model.loadReplies(for: root.id) }
        await service.started()
        await model.loadMoreReplies(for: root.id)
        await model.reloadReplies(for: root.id)
        #expect(service.requestedPages == [1])
        service.finish(try page([101, 102], total: 4))
        await first.value
        #expect(model.replyState(for: root) == .loaded)
    }

    @Test func cancelledSheetLoadReleasesLoadingStateAndCanRetry() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.suspends = true
        let model = makeModel(service, root: root)
        let task = Task { await model.loadReplies(for: root.id) }
        await service.started()
        task.cancel()
        service.finish(try page([101, 102], total: 2))
        await task.value
        #expect(model.replyState(for: root) == .idle)
        #expect(model.replyThreadPages[root.id] == nil)
        service.suspends = false
        service.responses = [.success(try page([101, 102], total: 2))]
        await model.loadReplies(for: root.id)
        #expect(service.requestedPages == [1, 1])
        #expect(model.replyState(for: root) == .loaded)
    }

    @Test func responseForPreviousVideoCannotPopulateCurrentThread() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.suspends = true
        let model = makeModel(service, root: root)
        let task = Task { await model.loadReplies(for: root.id) }
        await service.started()
        model.detail = video(aid: 9002)
        model.comments = []
        model.resetCommentThreadStateForNewComments()
        service.finish(try page([101, 102], total: 2))
        await task.value
        #expect(model.replyThreads.isEmpty)
        #expect(model.replyRoot(for: root.id) == nil)
    }

    @Test func registeredDeepLinkRootDoesNotNeedToAppearInMainCommentPage() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.responses = [.success(try page([101, 102], total: 2))]
        let model = makeModel(service, root: root)
        model.comments = []
        await model.loadReplies(for: root.id)
        #expect(model.replies(for: root).map(\.id) == [101, 102])
    }

    @Test func footerActionPassesStableRootIDThroughAsyncCallback() async throws {
        let root = try comment(100, total: 2)
        let service = ControlledCommentThreads()
        service.suspends = true
        let model = makeModel(service, root: root)
        let actions = CommentRepliesFooterActions(rootComment: root, loadMoreReplies: { @MainActor [model] rootID in
            await model.loadMoreReplies(for: rootID)
        })
        actions.performLoadMoreReplies()
        await service.started()
        #expect(service.requestedRootIDs == [100])
        service.finish(try page([101, 102], total: 2))
        // Await the actual published completion rather than assuming Task scheduling.
        for _ in 0..<50 where model.replyState(for: root).isLoading { await Task.yield() }
        #expect(model.replyState(for: root) == .loaded)
    }

    @Test func dialogErrorKeepsFallbackAndCanReload() async throws {
        let root = try comment(100, preview: [202], total: 2)
        let service = ControlledCommentThreads()
        service.dialogResponses = [.failure(BiliAPIError.emptyData), .success(try page([202, 303], total: 2))]
        let model = makeModel(service, root: root)
        let reply = try #require(root.replies?.first)
        await model.loadDialog(for: root.id, replyID: reply.id)
        #expect(isFailed(model.dialogState(for: root, reply: reply)))
        #expect(model.dialogReplies(for: root, reply: reply).map(\.id) == [202])
        await model.reloadDialog(for: root.id, replyID: reply.id)
        #expect(model.dialogState(for: root, reply: reply) == .loaded)
        #expect(model.dialogReplies(for: root, reply: reply).map(\.id) == [202, 303])
    }

    @Test func invalidRootDoesNotStartNetworkWork() async throws {
        let service = ControlledCommentThreads()
        let model = makeModel(service, root: try comment(100))
        await model.loadMoreReplies(for: 0)
        await model.loadMoreReplies(for: 999)
        #expect(service.requestedPages.isEmpty)
    }

    @Test func serverPaginationUsesRawPageSizeAndHandlesExtremeCounts() throws {
        let filteredPage = try page([101, 102], total: 4)
        #expect(filteredPage.hasMoreThreadReplies(requestedPage: 1, rawReplyCount: 2, fallbackTotal: 1))
        #expect(!filteredPage.hasMoreThreadReplies(requestedPage: 2, rawReplyCount: 2, fallbackTotal: 999))
        #expect(!filteredPage.hasMoreThreadReplies(requestedPage: 1, rawReplyCount: 0, fallbackTotal: 999))
        let noMetadata = CommentPage(replies: [], topReplies: nil, cursor: nil)
        #expect(!noMetadata.hasMoreThreadReplies(requestedPage: Int.max, rawReplyCount: 20, fallbackTotal: Int.max))
    }

    private func makeModel(_ service: ControlledCommentThreads, root: bili.Comment) -> VideoDetailViewModel {
        let defaults = UserDefaults(suiteName: "cc.bili.tests.replies.\(UUID().uuidString)")!
        let library = LibraryStore(userDefaults: defaults)
        let session = SessionStore(keychain: KeychainStore(service: "cc.bili.tests.replies.\(UUID().uuidString)"))
        let api = BiliAPIClient(sessionStore: session, libraryStore: library, homeRecommendDiagnosticsStore: .shared)
        let model = VideoDetailViewModel(seedVideo: video(), api: api, libraryStore: library, sessionStore: session,
                                        sponsorBlockService: SponsorBlockService(),
                                        videoListenPlaybackSessionStore: VideoListenPlaybackSessionStore(),
                                        commentThreadService: service)
        model.comments = [root]
        model.registerReplyRoot(root)
        return model
    }

    private func video(aid: Int = 9001) -> VideoItem {
        VideoItem(bvid: "BV1xx411c7mD", aid: aid, title: "评论测试", pic: nil, desc: nil, duration: nil,
                  pubdate: nil, owner: nil, stat: nil, cid: 9001, pages: nil, dimension: nil)
    }

    private func comment(_ id: Int, preview: [Int] = [], total: Int = 0) throws -> bili.Comment {
        let replies = preview.map { #"{"rpid":\#($0),"root":100,"parent":100,"dialog":7,"content":{"message":"预览"}}"# }.joined(separator: ",")
        return try JSONDecoder().decode(bili.Comment.self, from: Data(#"{"rpid":\#(id),"rcount":\#(total),"replies":[\#(replies)]}"#.utf8))
    }

    private func page(_ ids: [Int], total: Int, number: Int = 1) throws -> CommentPage {
        let replies = ids.map { #"{"rpid":\#($0),"root":100,"parent":100,"dialog":7,"content":{"message":"回复"}}"# }.joined(separator: ",")
        return try JSONDecoder().decode(CommentPage.self, from: Data(#"{"replies":[\#(replies)],"page":{"num":\#(number),"size":2,"count":"\#(total)"}}"#.utf8))
    }

    private func isFailed(_ state: LoadingState) -> Bool {
        if case .failed = state { return true }
        return false
    }
}

@MainActor
private final class ControlledCommentThreads: CommentThreadServing {
    var responses: [Result<CommentPage, Error>] = []
    var dialogResponses: [Result<CommentPage, Error>] = []
    var requestedPages: [Int] = []
    var requestedRootIDs: [Int] = []
    var suspends = false
    private var pending: CheckedContinuation<CommentPage, Error>?
    private var waiter: CheckedContinuation<Void, Never>?

    func started() async {
        if pending != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func finish(_ page: CommentPage) { pending?.resume(returning: page); pending = nil }
    func fetchCommentReplies(oid: String, type: Int, root: Int, page: Int, sort: CommentSort?) async throws -> CommentPage {
        requestedPages.append(page)
        requestedRootIDs.append(root)
        if suspends {
            return try await withCheckedThrowingContinuation {
                pending = $0
                waiter?.resume()
                waiter = nil
            }
        }
        guard !responses.isEmpty else { throw BiliAPIError.emptyData }
        return try responses.removeFirst().get()
    }
    func fetchCommentDialog(oid: String, type: Int, root: Int, dialog: Int, size: Int) async throws -> CommentPage {
        guard !dialogResponses.isEmpty else { throw BiliAPIError.emptyData }
        return try dialogResponses.removeFirst().get()
    }
}
