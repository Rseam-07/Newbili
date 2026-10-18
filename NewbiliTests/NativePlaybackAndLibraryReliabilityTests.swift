import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct NativePlaybackAndLibraryReliabilityTests {
    @Test func subtitleIndexHandlesBackwardSeekGapsAndExclusiveEnd() {
        let timeline = PlaybackSubtitleTimeline(cues: [cue(8, 9, "后"), cue(1, 3, "前")])
        #expect(timeline.text(at: 8.5) == "后")
        #expect(timeline.text(at: 1) == "前")
        #expect(timeline.text(at: 3).isEmpty)
        #expect(timeline.text(at: 7).isEmpty)
    }

    @Test func subtitleIndexKeepsOverlappingLinesAndRejectsInvalidIntervals() {
        let timeline = PlaybackSubtitleTimeline(cues: [cue(0, 8, "第一行"), cue(2, 4, "第二行"),
            cue(2, 4, "第二行"), cue(.nan, 9, "无效"), cue(3, 3, "无效"), cue(-1, 9, "无效")])
        #expect(timeline.text(at: 3) == "第一行\n第二行")
        #expect(timeline.text(at: 4) == "第一行")
        #expect(timeline.text(at: .infinity).isEmpty)
        #expect(timeline.text(at: -1).isEmpty)
    }

    @Test func oldSubtitleDownloadCannotReplaceTheNextPart() async throws {
        let service = ControlledPlaybackSubtitles()
        let old = track("old", language: "zh-CN")
        let next = track("next", language: "zh-CN")
        service.tracksByCID = [1: [old], 2: [next]]
        service.suspendedIDs = [old.id]
        let defaults = isolatedDefaults()
        defer { defaults.clear() }
        let model = PlaybackSubtitleModel(service: service, defaults: defaults.value)
        model.setContext(request: .init(bvid: "BVparts", cid: 1), credentialVersion: "one")
        model.setEnabled(true)
        try await eventually { service.pending[old.id] != nil }
        model.setContext(request: .init(bvid: "BVparts", cid: 2), credentialVersion: "one")
        try await eventually { model.timeline.text(at: 1) == "next" }
        service.finish(old.id)
        await Task.yield()
        await Task.yield()
        #expect(model.selectedTrack == next)
        #expect(model.timeline.text(at: 1) == "next")
    }

    @Test func disablingSubtitlesWhileDownloadingNeverResurrectsTheOverlay() async throws {
        let service = ControlledPlaybackSubtitles()
        let subtitle = track("slow", language: "zh-CN")
        service.tracksByCID = [1: [subtitle]]
        service.suspendedIDs = [subtitle.id]
        let defaults = isolatedDefaults()
        defer { defaults.clear() }
        let model = PlaybackSubtitleModel(service: service, defaults: defaults.value)
        model.setContext(request: .init(bvid: "BVoff", cid: 1), credentialVersion: "one")
        model.setEnabled(true)
        try await eventually { service.pending[subtitle.id] != nil }
        model.setEnabled(false)
        service.finish(subtitle.id)
        await Task.yield()
        await Task.yield()
        #expect(!model.isEnabled)
        #expect(model.timeline == .empty)
        #expect(model.selectedTrack == nil)
    }

    @Test func automaticFallbackDoesNotReplaceTheUsersPreferredLanguage() async throws {
        let service = ControlledPlaybackSubtitles()
        let english = track("english", language: "en")
        let chinese = track("chinese", language: "zh-CN")
        service.tracksByCID = [1: [english], 2: [chinese], 3: [chinese, english]]
        let defaults = isolatedDefaults()
        defer { defaults.clear() }
        let model = PlaybackSubtitleModel(service: service, defaults: defaults.value)
        model.setContext(request: .init(bvid: "BVlanguage", cid: 1), credentialVersion: "one")
        model.loadTracksIfNeeded()
        try await eventually { model.tracksState == .loaded }
        model.select(english)
        try await eventually { model.cuesState == .loaded }
        model.setContext(request: .init(bvid: "BVlanguage", cid: 2), credentialVersion: "one")
        try await eventually { model.selectedTrack == chinese }
        model.setContext(request: .init(bvid: "BVlanguage", cid: 3), credentialVersion: "one")
        try await eventually { model.cuesState == .loaded }
        #expect(model.selectedTrack == english)
    }

    @Test func credentialChangeClearsSubtitleDataAndResetsPartTiming() async throws {
        let service = ControlledPlaybackSubtitles()
        service.tracksByCID = [1: [track("account", language: "zh-CN")]]
        let defaults = isolatedDefaults()
        defer { defaults.clear() }
        let model = PlaybackSubtitleModel(service: service, defaults: defaults.value)
        let request = VideoTranscriptRequest(bvid: "BVaccount", cid: 1)
        model.setContext(request: request, credentialVersion: "one")
        model.setEnabled(true)
        try await eventually { model.cuesState == .loaded }
        model.setDelay(1.5)
        model.setContext(request: request, credentialVersion: "two")
        #expect(model.timeline == .empty)
        #expect(model.delay == 0)
        try await eventually { model.cuesState == .loaded }
        #expect(service.cueRequests == ["account", "account"])
    }

    @Test func folderFailureRetainsDraftAndSuccessCannotBeSubmittedTwice() async throws {
        let service = ControlledFavoriteFolderEditing()
        service.fails = true
        let model = folderModel(service)
        model.draft.title = "  收藏集  "
        model.draft.intro = "我的简介"
        #expect(await model.save() == nil)
        #expect(model.draft.title == "  收藏集  ")
        #expect(model.draft.intro == "我的简介")
        service.fails = false
        #expect(await model.save() != nil)
        #expect(await model.save() == nil)
        #expect(service.saveCount == 2)
        #expect(!model.canSave)
    }

    @Test func folderSaveIsSingleFlightAndOldAccountCannotSubmit() async throws {
        let service = ControlledFavoriteFolderEditing()
        service.suspends = true
        let model = folderModel(service)
        model.draft.title = "收藏集"
        let pending = Task { await model.save() }
        try await eventually { service.pending != nil }
        #expect(await model.save() == nil)
        service.finish()
        #expect(await pending.value != nil)
        #expect(service.saveCount == 1)
        let stale = folderModel(service, isCurrent: { false })
        stale.draft.title = "旧账号草稿"
        #expect(await stale.save() == nil)
        #expect(service.saveCount == 1)
        #expect(stale.draft.title == "旧账号草稿")
    }

    @Test func folderCreatedOnOldAccountIsAcknowledgedButNotAppliedToNewAccount() async throws {
        let service = ControlledFavoriteFolderEditing()
        service.suspends = true
        let model = folderModel(service, isCurrent: { service.isCurrentAccount })
        model.draft.title = "收藏集"
        let pending = Task { await model.save() }
        try await eventually { service.pending != nil }
        service.isCurrentAccount = false
        service.finish()
        #expect(await pending.value != nil)
        #expect(model.state == .loaded)
        #expect(!model.canApplyResult)
        #expect(!model.canSave)
    }

    @Test func invalidFolderDraftNeverReachesServer() async {
        let service = ControlledFavoriteFolderEditing()
        let model = folderModel(service)
        model.draft.title = " \n "
        #expect(await model.save() == nil)
        model.draft.title = String(repeating: "字", count: 21)
        #expect(await model.save() == nil)
        model.draft.title = "有效名称"
        model.draft.intro = String(repeating: "字", count: 501)
        #expect(await model.save() == nil)
        #expect(service.saveCount == 0)
    }

    @Test func audioSessionOperationsRunOffMainAndSuccessorKeepsTheLease() async throws {
        let log = AudioSessionOperationLog()
        let session = PlaybackAudioSessionCoordinator(releaseDelay: 0.01, operation: log.record)
        let outgoing = UUID()
        let incoming = UUID()
        #expect(await activate(session, owner: outgoing))
        session.release(outgoing)
        #expect(await activate(session, owner: incoming))
        session.release(incoming)
        try await eventually { log.entries.contains { !$0.active } }
        #expect(log.entries.map(\.active) == [true, false])
        #expect(log.entries.allSatisfy { !$0.onMainThread })
    }

    @Test func failedAudioActivationIsRetriedByNextPlayAndForceReconfigures() async {
        let log = AudioSessionOperationLog(failFirst: true)
        let session = PlaybackAudioSessionCoordinator(releaseDelay: 0, operation: log.record)
        let owner = UUID()
        #expect(!(await activate(session, owner: owner)))
        #expect(await activate(session, owner: owner))
        #expect(await activate(session, owner: owner, force: true))
        #expect(log.entries.map(\.configuresCategory) == [true, true, true])
        session.release(owner)
    }

    private func cue(_ start: Double, _ end: Double, _ text: String) -> VideoSubtitleCue {
        VideoSubtitleCue(start: start, end: end, content: text)
    }

    private func track(_ id: String, language: String) -> VideoSubtitleTrack {
        VideoSubtitleTrack(id: id, languageCode: language, language: language,
                           urlString: "https://aisubtitle.hdslb.com/\(id).json", isAIGenerated: false)
    }

    private func folderModel(_ service: ControlledFavoriteFolderEditing,
                             isCurrent: @escaping @MainActor () -> Bool = { true }) -> FavoriteFolderEditorModel {
        FavoriteFolderEditorModel(folder: nil, account: .init(mid: 1, version: 1), service: service, isCurrent: isCurrent)
    }

    private func activate(_ session: PlaybackAudioSessionCoordinator, owner: UUID, force: Bool = false) async -> Bool {
        await withCheckedContinuation { continuation in
            session.acquire(owner, force: force) { continuation.resume(returning: $0) }
        }
    }

    private func eventually(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw NativeReliabilityTestError.timeout }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private func isolatedDefaults() -> (value: UserDefaults, clear: () -> Void) {
        let name = "cc.bili.tests.subtitle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }
}

@MainActor
private final class ControlledPlaybackSubtitles: VideoSubtitleServing {
    var tracksByCID: [Int: [VideoSubtitleTrack]] = [:]
    var suspendedIDs = Set<String>()
    var pending: [String: CheckedContinuation<Void, Never>] = [:]
    var cueRequests: [String] = []
    @MainActor func fetchPlaybackSubtitleTracks(request: VideoTranscriptRequest) async throws -> [VideoSubtitleTrack] {
        tracksByCID[request.cid] ?? []
    }
    @MainActor func fetchPlaybackSubtitleCues(request: VideoTranscriptRequest, track: VideoSubtitleTrack) async throws -> [VideoSubtitleCue] {
        cueRequests.append(track.id)
        if suspendedIDs.contains(track.id) { await withCheckedContinuation { pending[track.id] = $0 } }
        return [VideoSubtitleCue(start: 0, end: 5, content: track.id)]
    }
    func finish(_ id: String) { pending.removeValue(forKey: id)?.resume() }
}

@MainActor
private final class ControlledFavoriteFolderEditing: FavoriteFolderEditing {
    var saveCount = 0
    var fails = false
    var suspends = false
    var isCurrentAccount = true
    var pending: CheckedContinuation<Void, Never>?
    @MainActor func saveFavoriteFolder(id: Int?, draft: FavoriteFolderDraft, account: FavoriteFolderAccount) async throws -> FavoriteFolder {
        saveCount += 1
        if suspends { await withCheckedContinuation { pending = $0 } }
        if fails { throw NativeReliabilityTestError.offline }
        return try JSONDecoder().decode(FavoriteFolder.self, from: Data(#"{"id":101,"title":"收藏集","attr":3}"#.utf8))
    }
    @MainActor func deleteFavoriteFolder(id: Int, account: FavoriteFolderAccount) async throws {}
    func finish() { pending?.resume(); pending = nil }
}

private nonisolated enum NativeReliabilityTestError: Error { case timeout, offline }

private nonisolated final class AudioSessionOperationLog: @unchecked Sendable {
    struct Entry: Sendable { let active: Bool; let configuresCategory: Bool; let onMainThread: Bool }
    private let lock = NSLock()
    private var recorded: [Entry] = []
    private let failFirst: Bool
    init(failFirst: Bool = false) { self.failFirst = failFirst }
    var entries: [Entry] { lock.withLock { recorded } }
    func record(active: Bool, configureCategory: Bool) throws {
        let shouldFail = lock.withLock {
            recorded.append(Entry(active: active, configuresCategory: configureCategory, onMainThread: Thread.isMainThread))
            return failFirst && recorded.count == 1
        }
        if shouldFail { throw NativeReliabilityTestError.offline }
    }
}
