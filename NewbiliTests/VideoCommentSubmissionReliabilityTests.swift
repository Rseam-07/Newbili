import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct VideoCommentSubmissionReliabilityTests {
    @Test func replyUsesRootAndSelectedParentAndClearsDraftOnlyAfterAcknowledgement() async throws {
        let service = ControlledVideoCommentSubmission()
        var refreshes = 0
        let model = VideoCommentSubmissionModel(target: try target(), rootID: 100, parentID: 202, recipientName: "UP",
                                                service: service, isCurrent: { true }, didSubmit: { refreshes += 1 })
        model.draft = "  正式回复  "
        #expect(await model.submit())
        #expect(service.messages == ["正式回复"])
        #expect(service.roots == [100])
        #expect(service.parents == [202])
        #expect(refreshes == 1)
        #expect(model.draft.isEmpty)
        #expect(model.state == .loaded)
    }

    @Test func failedSendKeepsTheOriginalDraftAndDoesNotAutoRetry() async throws {
        let service = ControlledVideoCommentSubmission()
        service.fails = true
        let model = VideoCommentSubmissionModel(target: try target(), service: service, isCurrent: { true }, didSubmit: {})
        model.draft = "  保留草稿和空格  "
        #expect(!(await model.submit()))
        #expect(model.draft == "  保留草稿和空格  ")
        #expect(service.messages.count == 1)
        service.fails = false
        #expect(await model.submit())
        #expect(service.messages.count == 2)
    }

    @Test func rapidRepeatedTapDoesNotCreateASecondSubmission() async throws {
        let service = ControlledVideoCommentSubmission()
        service.suspends = true
        let model = VideoCommentSubmissionModel(target: try target(), service: service, isCurrent: { true }, didSubmit: {})
        model.draft = "仅发送一次"
        let first = Task { await model.submit() }
        await service.started()
        #expect(!(await model.submit()))
        #expect(service.messages.count == 1)
        #expect(!model.canSubmit)
        service.finish()
        #expect(await first.value)
    }

    @Test func changedAccountOrVideoRejectsAnOldEditorBeforeSending() async throws {
        let service = ControlledVideoCommentSubmission()
        let model = VideoCommentSubmissionModel(target: try target(), service: service, isCurrent: { false }, didSubmit: {})
        model.draft = "仍是草稿"
        #expect(!(await model.submit()))
        #expect(service.messages.isEmpty)
        #expect(model.draft == "仍是草稿")
    }

    @Test func contextChangeDuringSendDoesNotTurnServerSuccessIntoARetry() async throws {
        let service = ControlledVideoCommentSubmission()
        service.suspends = true
        var refreshes = 0
        let model = VideoCommentSubmissionModel(target: try target(), service: service, isCurrent: { service.contextIsCurrent },
                                                didSubmit: { refreshes += 1 })
        model.draft = "已发送的内容"
        let pending = Task { await model.submit() }
        await service.started()
        service.contextIsCurrent = false
        service.finish()
        #expect(await pending.value)
        #expect(model.draft.isEmpty)
        #expect(refreshes == 0)
    }

    @Test func emptyOrOversizedMessageCannotReachTheService() async throws {
        let service = ControlledVideoCommentSubmission()
        let model = VideoCommentSubmissionModel(target: try target(), service: service, isCurrent: { true }, didSubmit: {})
        model.draft = " \n "
        #expect(!(await model.submit()))
        model.draft = String(repeating: "字", count: 1_001)
        #expect(!(await model.submit()))
        #expect(service.messages.isEmpty)
        #expect(model.draft.count == 1_001)
    }

    @Test func parentWithoutRootCannotAccidentallyBecomeATopLevelComment() async throws {
        let service = ControlledVideoCommentSubmission()
        let model = VideoCommentSubmissionModel(target: try target(), parentID: 202,
                                                service: service, isCurrent: { true }, didSubmit: {})
        model.draft = "需要正确回复目标"
        #expect(!(await model.submit()))
        #expect(service.messages.isEmpty)
    }

    private func target() throws -> VideoDetailCommentTarget {
        let video = VideoItem(bvid: "BV1xx411c7mD", aid: 9001, title: "测试", pic: nil, desc: nil, duration: nil,
                              pubdate: nil, owner: nil, stat: nil, cid: 9001, pages: nil, dimension: nil)
        return try #require(VideoDetailCommentTarget(detail: video))
    }
}

@MainActor
private final class ControlledVideoCommentSubmission: VideoCommentSubmitting {
    var messages: [String] = []
    var roots: [Int?] = []
    var parents: [Int?] = []
    var fails = false
    var suspends = false
    var contextIsCurrent = true
    private var pending: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func started() async {
        if pending != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func finish() { pending?.resume(); pending = nil }
    func submitComment(oid: String, type: Int, message: String, root: Int?, parent: Int?) async throws {
        messages.append(message)
        roots.append(root)
        parents.append(parent)
        if suspends {
            await withCheckedContinuation {
                pending = $0
                waiter?.resume()
                waiter = nil
            }
        }
        if fails { throw BiliAPIError.emptyData }
    }
}
