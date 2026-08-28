import Combine
import Foundation

struct AudioMiniPlayerSnapshot: Equatable {
    let video: VideoItem
    let isPlaying: Bool
    let canPlayNext: Bool
    let artworkURLString: String?
    let ownerName: String
}

enum AudioMiniPlayerSnapshotPublicationPolicy {
    static func shouldPublish(
        _ nextSnapshot: AudioMiniPlayerSnapshot?,
        replacing currentSnapshot: AudioMiniPlayerSnapshot?
    ) -> Bool {
        nextSnapshot != currentSnapshot
    }
}

@MainActor
final class AudioMiniPlayerCoordinator: ObservableObject {
    static let shared = AudioMiniPlayerCoordinator()

    @Published private(set) var snapshot: AudioMiniPlayerSnapshot?

    private var retainedViewModel: VideoDetailViewModel?
    private weak var observedPlayer: PlayerStateViewModel?
    private var viewModelCancellable: AnyCancellable?
    private var playerCancellable: AnyCancellable?
    private var pendingDetailOpenKey: String?
    private var refreshTask: Task<Void, Never>?

    init() {}

    func adopt(_ viewModel: VideoDetailViewModel) {
        guard viewModel.isVideoListenModeEnabled else { return }
        if retainedViewModel === viewModel {
            refreshBindingsAndSnapshot()
            return
        }

        let previous = retainedViewModel
        clearRetention()
        previous?.stopPlaybackForNavigation()
        retainedViewModel = viewModel
        bindViewModel(viewModel)
        refreshBindingsAndSnapshot()
    }

    func release(_ viewModel: VideoDetailViewModel, stopsPlayback: Bool) {
        guard retainedViewModel === viewModel else { return }
        clearRetention()
        if stopsPlayback {
            viewModel.stopPlaybackForNavigation()
        }
    }

    func shouldKeepAlive(_ viewModel: VideoDetailViewModel) -> Bool {
        retainedViewModel === viewModel && viewModel.isVideoListenModeEnabled
    }

    func togglePlayback() {
        retainedViewModel?.stablePlayerViewModel?.togglePlayback()
    }

    func playNext() {
        retainedViewModel?.stablePlayerViewModel?.requestNextTrack()
    }

    func prepareForDetailOpen() -> VideoItem? {
        guard let viewModel = retainedViewModel else { return nil }
        viewModel.persistVideoListenPlaybackSession()
        pendingDetailOpenKey = VideoListenPlaybackSessionStore.contentKey(for: viewModel.detail)
        return viewModel.detail
    }

    func stopUnlessPreparedForDetailOpen(_ video: VideoItem) {
        let key = VideoListenPlaybackSessionStore.contentKey(for: video)
        if key != nil, key == pendingDetailOpenKey {
            return
        }
        pendingDetailOpenKey = nil
        close()
    }

    /// Hands the already-playing listen-mode detail back to the page that opened
    /// from the mini player. The exact dependency and playback-option checks keep
    /// a stale session from crossing account or test-runtime boundaries.
    func takePreparedDetailViewModel(
        for video: VideoItem,
        api: BiliAPIClient,
        libraryStore: LibraryStore,
        sessionStore: SessionStore,
        sponsorBlockService: SponsorBlockService,
        playbackOptions: VideoDetailPlaybackOptions
    ) -> VideoDetailViewModel? {
        let key = VideoListenPlaybackSessionStore.contentKey(for: video)
        guard key != nil, key == pendingDetailOpenKey else {
            pendingDetailOpenKey = nil
            return nil
        }
        guard let viewModel = retainedViewModel,
              VideoListenPlaybackSessionStore.contentKey(for: viewModel.detail) == key,
              viewModel.api === api,
              viewModel.libraryStore === libraryStore,
              viewModel.sessionStore === sessionStore,
              viewModel.sponsorBlockService === sponsorBlockService,
              viewModel.playbackOptions == playbackOptions,
              viewModel.hasReusablePlaybackSessionForCurrentContext
        else {
            pendingDetailOpenKey = nil
            close()
            return nil
        }
        pendingDetailOpenKey = nil
        return viewModel
    }

    func close() {
        guard let viewModel = retainedViewModel else { return }
        clearRetention()
        viewModel.stopPlaybackForNavigation()
    }

    private func bindViewModel(_ viewModel: VideoDetailViewModel) {
        viewModelCancellable = Publishers.CombineLatest3(
            viewModel.$detail,
            viewModel.$stablePlayerViewModel,
            viewModel.$playbackContentMode
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.scheduleRefresh()
        }
    }

    private func bindPlayerIfNeeded(_ player: PlayerStateViewModel?) {
        guard observedPlayer !== player else { return }
        playerCancellable?.cancel()
        playerCancellable = nil
        observedPlayer = player
        guard let player else { return }
        playerCancellable = Publishers.CombineLatest(
            player.$isPlaying.removeDuplicates(),
            player.$canRequestNextTrack.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.refreshBindingsAndSnapshot()
            self.refreshTask = nil
        }
    }

    private func refreshBindingsAndSnapshot() {
        guard let viewModel = retainedViewModel,
              viewModel.isVideoListenModeEnabled
        else {
            if snapshot != nil {
                snapshot = nil
            }
            return
        }
        let player = viewModel.stablePlayerViewModel
        bindPlayerIfNeeded(player)
        let ownerName = viewModel.detail.owner?.name
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextSnapshot = AudioMiniPlayerSnapshot(
            video: viewModel.detail,
            isPlaying: player?.isPlaying == true,
            canPlayNext: player?.canRequestNextTrack == true,
            artworkURLString: viewModel.detail.pic?.normalizedBiliURL(),
            ownerName: ownerName.isEmpty ? "未知 UP 主" : ownerName
        )
        guard AudioMiniPlayerSnapshotPublicationPolicy.shouldPublish(
            nextSnapshot,
            replacing: snapshot
        ) else { return }
        snapshot = nextSnapshot
    }

    private func clearRetention() {
        refreshTask?.cancel()
        refreshTask = nil
        viewModelCancellable?.cancel()
        viewModelCancellable = nil
        playerCancellable?.cancel()
        playerCancellable = nil
        observedPlayer = nil
        retainedViewModel = nil
        if snapshot != nil {
            snapshot = nil
        }
    }
}
