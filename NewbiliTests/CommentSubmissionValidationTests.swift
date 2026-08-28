import Testing
@testable import bili

struct CommentSubmissionValidationTests {
    @Test
    func `comment and dynamic interaction account policies stay explicit`() {
        #expect(BiliCommentAccountPolicy.submission == .main)
        #expect(BiliCommentAccountPolicy.reaction == .interaction)
        #expect(BiliDynamicLikeAccountPolicy.statusRead == .interaction)
        #expect(BiliDynamicLikeAccountPolicy.mutation == .interaction)
    }

    @Test
    func `dynamic feed snapshot invalidation requires matching identities`() {
        #expect(BiliDynamicLikeAccountPolicy.shouldInvalidateDynamicFeedSnapshot(
            dynamicFeedAccountMID: 1,
            interactionAccountMID: 1
        ))
        #expect(!BiliDynamicLikeAccountPolicy.shouldInvalidateDynamicFeedSnapshot(
            dynamicFeedAccountMID: 1,
            interactionAccountMID: 2
        ))
        #expect(!BiliDynamicLikeAccountPolicy.shouldInvalidateDynamicFeedSnapshot(
            dynamicFeedAccountMID: nil,
            interactionAccountMID: 1
        ))
        #expect(!BiliDynamicLikeAccountPolicy.shouldInvalidateDynamicFeedSnapshot(
            dynamicFeedAccountMID: 1,
            interactionAccountMID: nil
        ))
    }

    @Test
    func `comment validation trims outer whitespace`() throws {
        let message = try BiliAPIClient.validatedCommentMessage("  真正可发送的评论  \n")
        #expect(message == "真正可发送的评论")
    }

    @Test
    func `comment validation rejects empty content`() {
        #expect(throws: BiliAPIError.self) {
            try BiliAPIClient.validatedCommentMessage("  \n ")
        }
    }

    @Test
    func `comment validation rejects content beyond one thousand characters`() {
        #expect(throws: BiliAPIError.self) {
            try BiliAPIClient.validatedCommentMessage(String(repeating: "评", count: 1_001))
        }
    }
}
