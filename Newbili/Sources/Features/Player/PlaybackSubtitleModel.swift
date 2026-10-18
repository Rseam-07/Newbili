import Combine
import Foundation

nonisolated protocol VideoSubtitleServing: Sendable {
    func fetchPlaybackSubtitleTracks(request: VideoTranscriptRequest) async throws -> [VideoSubtitleTrack]
    func fetchPlaybackSubtitleCues(request: VideoTranscriptRequest, track: VideoSubtitleTrack) async throws -> [VideoSubtitleCue]
}

extension VideoSubtitleTrack {
    nonisolated var selectionKey: String { "\(id)|\(languageCode)|\(urlString)" }
    nonisolated var displayTitle: String { language.isEmpty ? languageCode : language }
}

/// Binary search remains correct for backwards seeks and overlapping bilingual cues.
/// No timer or full-document scan is needed for each playback update.
nonisolated struct PlaybackSubtitleTimeline: Equatable, Sendable {
    static let empty = Self(cues: [])
    let cues: [VideoSubtitleCue]
    private let maximumEndBeforeIndex: [Double]

    init(cues: [VideoSubtitleCue]) {
        self.cues = cues.filter {
            $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start
                && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        var maximumEnd = 0.0
        self.maximumEndBeforeIndex = self.cues.map {
            maximumEnd = max(maximumEnd, $0.end)
            return maximumEnd
        }
    }

    func text(at time: TimeInterval) -> String {
        guard time.isFinite, time >= 0, !cues.isEmpty else { return "" }
        var lower = 0
        var upper = cues.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if cues[middle].start <= time { lower = middle + 1 } else { upper = middle }
        }
        var index = lower - 1
        var active: [String] = []
        while index >= 0, maximumEndBeforeIndex[index] > time {
            let cue = cues[index]
            if cue.end > time {
                let text = cue.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !active.contains(text) { active.append(text) }
                if active.count == 3 { break }
            }
            index -= 1
        }
        return active.reversed().joined(separator: "\n")
    }
}

@MainActor
final class PlaybackSubtitleModel: ObservableObject {
    @Published private(set) var tracks: [VideoSubtitleTrack] = []
    @Published private(set) var selectedTrack: VideoSubtitleTrack?
    @Published private(set) var tracksState: LoadingState = .idle
    @Published private(set) var cuesState: LoadingState = .idle
    @Published private(set) var timeline: PlaybackSubtitleTimeline = .empty
    @Published private(set) var isEnabled: Bool
    @Published private(set) var fontScale: Double
    @Published private(set) var delay: TimeInterval = 0

    private let service: any VideoSubtitleServing
    private let defaults: UserDefaults
    private var request: VideoTranscriptRequest?
    private var credentialVersion = ""
    private var revision: UInt64 = 0
    private var selectionRevision: UInt64 = 0
    private var tracksTask: Task<Void, Never>?
    private var cuesTask: Task<Void, Never>?
    private var cueCache: [String: PlaybackSubtitleTimeline] = [:]
    private var preferredLanguage: String?
    private static let enabledKey = "cc.bili.subtitles.enabled.v1"
    private static let languageKey = "cc.bili.subtitles.language.v1"
    private static let scaleKey = "cc.bili.subtitles.scale.v1"

    init(service: any VideoSubtitleServing, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        preferredLanguage = defaults.string(forKey: Self.languageKey)
        let storedScale = defaults.object(forKey: Self.scaleKey) as? Double ?? 1
        fontScale = storedScale.isFinite ? min(max(storedScale, 0.8), 1.5) : 1
    }

    deinit {
        tracksTask?.cancel()
        cuesTask?.cancel()
    }

    var selectionTitle: String {
        guard isEnabled else { return "关闭" }
        if let selectedTrack { return selectedTrack.displayTitle }
        if tracksState.isLoading { return "正在获取" }
        return tracks.isEmpty && tracksState == .loaded ? "暂无字幕" : "自动选择"
    }

    func setContext(request: VideoTranscriptRequest?, credentialVersion: String) {
        guard self.request != request || self.credentialVersion != credentialVersion else { return }
        revision &+= 1
        selectionRevision &+= 1
        tracksTask?.cancel()
        cuesTask?.cancel()
        tracksTask = nil
        cuesTask = nil
        self.request = request
        self.credentialVersion = credentialVersion
        tracks = []
        selectedTrack = nil
        timeline = .empty
        cueCache.removeAll()
        tracksState = .idle
        cuesState = .idle
        delay = 0
        if isEnabled { loadTracksIfNeeded() }
    }

    func loadTracksIfNeeded(force: Bool = false) {
        guard let request, !tracksState.isLoading, force || tracksState != .loaded else { return }
        tracksState = .loading
        let revision = revision
        tracksTask = Task { [weak self, service] in
            do {
                let fetched = try await service.fetchPlaybackSubtitleTracks(request: request)
                try Task.checkCancellation()
                guard let self, self.revision == revision else { return }
                var seen = Set<String>()
                self.tracks = fetched.filter {
                    VideoTranscriptService.trustedSubtitleURL(from: $0.urlString) != nil
                        && seen.insert($0.selectionKey).inserted
                }
                self.tracksState = .loaded
                self.tracksTask = nil
                if self.isEnabled { self.selectPreferredTrack() }
            } catch {
                guard let self, self.revision == revision else { return }
                self.tracksTask = nil
                self.tracksState = Task.isCancelled || error is CancellationError
                    ? .idle : .failed("字幕列表加载失败，请重试")
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        if enabled {
            if tracksState == .loaded { selectPreferredTrack() } else { loadTracksIfNeeded() }
        } else {
            selectionRevision &+= 1
            cuesTask?.cancel()
            cuesTask = nil
            selectedTrack = nil
            timeline = .empty
            cuesState = .idle
        }
    }

    func select(_ track: VideoSubtitleTrack) {
        select(track, remembersLanguage: true)
    }

    private func select(_ track: VideoSubtitleTrack, remembersLanguage: Bool) {
        guard tracks.contains(track), let request else { return }
        isEnabled = true
        defaults.set(true, forKey: Self.enabledKey)
        if remembersLanguage {
            preferredLanguage = track.languageCode
            defaults.set(track.languageCode, forKey: Self.languageKey)
        }
        selectionRevision &+= 1
        let selectionRevision = selectionRevision
        let revision = revision
        cuesTask?.cancel()
        cuesTask = nil
        selectedTrack = track
        timeline = .empty
        if let cached = cueCache[track.selectionKey] {
            timeline = cached
            cuesState = .loaded
            return
        }
        cuesState = .loading
        cuesTask = Task { [weak self, service] in
            do {
                let cues = try await service.fetchPlaybackSubtitleCues(request: request, track: track)
                try Task.checkCancellation()
                // Build the index off the UI executor, including large subtitle files.
                let timeline = await Task.detached(priority: .userInitiated) {
                    PlaybackSubtitleTimeline(cues: cues)
                }.value
                guard let self, !Task.isCancelled, self.revision == revision,
                      self.selectionRevision == selectionRevision else { return }
                if self.cueCache.count >= 3 { self.cueCache.removeAll(keepingCapacity: true) }
                self.cueCache[track.selectionKey] = timeline
                self.timeline = timeline
                self.cuesState = .loaded
                self.cuesTask = nil
            } catch {
                guard let self, self.revision == revision,
                      self.selectionRevision == selectionRevision else { return }
                self.cuesTask = nil
                self.cuesState = Task.isCancelled || error is CancellationError
                    ? .idle : .failed("字幕内容加载失败，请重试")
            }
        }
    }

    func retry() {
        if let selectedTrack, case .failed = cuesState { select(selectedTrack, remembersLanguage: false) }
        else { loadTracksIfNeeded(force: true) }
    }

    func setFontScale(_ value: Double) {
        guard value.isFinite else { return }
        fontScale = min(max(value, 0.8), 1.5)
        defaults.set(fontScale, forKey: Self.scaleKey)
    }

    func setDelay(_ value: TimeInterval) {
        guard value.isFinite else { return }
        delay = min(max(value, -10), 10)
    }

    private func selectPreferredTrack() {
        guard let track = tracks.first(where: { $0.languageCode == preferredLanguage })
                ?? VideoTranscriptService.preferredTrack(from: tracks) else {
            selectedTrack = nil
            timeline = .empty
            cuesState = .loaded
            return
        }
        select(track, remembersLanguage: false)
    }
}
