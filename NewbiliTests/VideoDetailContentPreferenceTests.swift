import Foundation
import Testing
@testable import bili

@MainActor
struct VideoDetailContentPreferenceTests {
    @Test
    func `video detail content preferences default to PiliPlus compatible behavior and persist`() throws {
        let suiteName = "cc.bili.tests.video-detail-content.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        #expect(store.showsRelatedVideosInVideoDetail)
        #expect(store.showsVideoCommentsInVideoDetail)
        #expect(!store.expandsVideoDescriptionByDefault)
        #expect(!store.videoIntelligenceSummaryEnabled)

        store.setShowsRelatedVideosInVideoDetail(false)
        store.setShowsVideoCommentsInVideoDetail(false)
        store.setExpandsVideoDescriptionByDefault(true)
        store.setVideoIntelligenceSummaryEnabled(true)

        #expect(!store.showsRelatedVideosInVideoDetail)
        #expect(!store.showsVideoCommentsInVideoDetail)
        #expect(store.expandsVideoDescriptionByDefault)
        #expect(store.videoIntelligenceSummaryEnabled)

        let restored = LibraryStore(userDefaults: defaults)
        #expect(!restored.showsRelatedVideosInVideoDetail)
        #expect(!restored.showsVideoCommentsInVideoDetail)
        #expect(restored.expandsVideoDescriptionByDefault)
        #expect(restored.videoIntelligenceSummaryEnabled)
    }

    @Test
    func `content visibility policy removes hidden tabs and background side loads`() {
        #expect(
            VideoDetailContentVisibilityPolicy.resolvedSelection(
                .comments,
                showsComments: false
            ) == .detail
        )
        #expect(
            VideoDetailContentVisibilityPolicy.resolvedSelection(
                .comments,
                showsComments: true
            ) == .comments
        )
        #expect(
            !VideoDetailContentVisibilityPolicy.showsRelatedVideos(
                isPGCEpisode: false,
                preferenceEnabled: false
            )
        )
        #expect(
            !VideoDetailContentVisibilityPolicy.showsRelatedVideos(
                isPGCEpisode: true,
                preferenceEnabled: true
            )
        )
        #expect(
            VideoDetailContentVisibilityPolicy.showsRelatedVideos(
                isPGCEpisode: false,
                preferenceEnabled: true
            )
        )
        #expect(
            !VideoDetailContentVisibilityPolicy.automaticallyLoadsComments(
                hasCommentTarget: true,
                preferenceEnabled: false
            )
        )
        #expect(
            VideoDetailContentVisibilityPolicy.automaticallyLoadsComments(
                hasCommentTarget: true,
                preferenceEnabled: true
            )
        )
    }
}
