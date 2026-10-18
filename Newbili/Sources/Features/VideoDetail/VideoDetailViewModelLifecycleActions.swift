import Combine
import Foundation

extension VideoDetailViewModel {
    func syncSubtitleContext() {
        subtitleModel.setContext(
            request: VideoTranscriptRequest(bvid: detail.bvid, cid: selectedCID),
            credentialVersion: "\(sessionStore.playbackCredentialVersion)|\(sessionStore.playbackAccountCredentialVersion)|\(sessionStore.accountConfigurationVersion)|\(libraryStore.multiAccountExperimentEnabled)"
        )
    }

    func configureLifecycleBindings() {
        lifecycleSubscriptionState.favoriteFolderCancellable = Publishers.CombineLatest4(
            sessionStore.$playbackCredentialVersion,
            sessionStore.$interactionAccountCredentialVersion,
            sessionStore.$accountConfigurationVersion,
            libraryStore.$multiAccountExperimentEnabled
        )
        .dropFirst()
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.invalidateFavoriteFoldersIfAccountChanged() }
        }
        lifecycleSubscriptionState.subtitleCancellable = Publishers.CombineLatest4(
            sessionStore.$playbackCredentialVersion,
            sessionStore.$playbackAccountCredentialVersion,
            sessionStore.$accountConfigurationVersion,
            libraryStore.$multiAccountExperimentEnabled
        )
        .dropFirst()
        .sink { [weak self] _ in
            // @Published emits before storage changes; read after this actor turn.
            Task { @MainActor [weak self] in self?.syncSubtitleContext() }
        }
        lastDanmakuAdaptationProfile = playbackAdaptationProfile
        filterCancellable = libraryStore.$blocksGoodsComments
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard self?.isPlaybackInvalidatedForNavigation != true else { return }
                self?.refilterLoadedComments()
            }
        sponsorBlockCancellable = Publishers.CombineLatest(
            libraryStore.$sponsorBlockEnabled,
            libraryStore.$sponsorBlockPreferences
        )
            .removeDuplicates { lhs, rhs in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
            .sink { [weak self] values in
                let (isEnabled, _) = values
                guard self?.isPlaybackInvalidatedForNavigation != true else { return }
                self?.stablePlayerViewModel?.setSponsorBlockEnabled(isEnabled)
                if isEnabled {
                    self?.scheduleSponsorBlockSegmentsAfterFirstFrame()
                } else {
                    self?.resetSponsorBlockSegments()
                }
            }
        playbackAutoOptimizationCancellable = libraryStore.$playbackAutoOptimizationMode
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard self?.isPlaybackInvalidatedForNavigation != true else { return }
                self?.refreshDanmakuRenderStoreForPlaybackPerformance(force: true)
            }
        playbackPerformanceCancellable = PlayerPerformanceStore.shared.updates
            .sink { [weak self] _ in
                guard let self,
                      !self.isPlaybackInvalidatedForNavigation
                else { return }
                self.refreshDanmakuRenderStoreForPlaybackPerformance(
                    force: !self.libraryStore.diagnosticsBackgroundProcessingExperimentEnabled
                )
            }
    }

    private func refreshDanmakuRenderStoreForPlaybackPerformance(force: Bool) {
        let nextProfile = playbackAdaptationProfile
        defer { lastDanmakuAdaptationProfile = nextProfile }
        guard force || lastDanmakuAdaptationProfile != nextProfile else { return }
        scheduleRenderStoreSync(.danmaku)
    }

}
