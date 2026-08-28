import Foundation

extension VideoDetailViewModel {
    func playerIdentity(for variant: PlayVariant) -> String {
        let audioIdentity = playbackContentMode == .audioOnly
            ? (resolvedVideoListenAudioVariant?.id ?? "audio-missing")
            : "video-audio"
        let credentialIdentity = sessionStore.accountCacheIdentityKey(
            for: .playback,
            multiAccountEnabled: libraryStore.multiAccountExperimentEnabled
        )
        return [
            detail.bvid.lowercased(),
            String(selectedCID ?? 0),
            variant.id,
            playbackContentMode.rawValue,
            audioIdentity,
            credentialIdentity
        ].joined(separator: "|")
    }

    var hasReusablePlaybackSessionForCurrentContext: Bool {
        guard let player = stablePlayerViewModel,
              !player.isTerminated,
              hasStablePlaybackIdentityForCurrentContext
        else { return false }
        return true
    }

    var hasStablePlaybackIdentityForCurrentContext: Bool {
        guard let variant = selectedPlayVariant,
              variant.isPlayable
        else { return false }
        return stablePlayerIdentity == playerIdentity(for: variant)
    }

    var selectedPageNumber: Int? {
        guard let selectedCID else { return nil }
        guard let page = detail.pages?.first(where: { $0.cid == selectedCID })?.page,
              page > 1
        else { return nil }
        return page
    }

    var selectedPage: VideoPage? {
        guard let selectedCID else { return detail.pages?.first }
        return detail.pages?.first(where: { $0.cid == selectedCID }) ?? detail.pages?.first
    }

    var playbackAdaptationProfile: PlayerPlaybackAdaptationProfile {
        PlayerPerformanceStore.shared.playbackAdaptationProfile(
            for: detail.bvid,
            isEnabled: libraryStore.isPlaybackAutoOptimizationEnabled
        )
    }

    var targetPlaybackPreferredQuality: Int? {
        libraryStore.effectivePreferredVideoQuality ?? LibraryStore.defaultPreferredVideoQuality
    }

    var adaptiveStartupPreferredQuality: Int? {
        targetPlaybackPreferredQuality
    }

    var adaptiveStartupQualityCeiling: Int? {
        nil
    }

    func playVariants(from data: PlayURLData) -> [PlayVariant] {
        data.playVariants(
            cdnPreference: libraryStore.effectivePlaybackCDNPreference,
            codecPreference: libraryStore.videoCodecPreference,
            requiresHardwareDecode: libraryStore.forceHardwareDecodeEnabled,
            prefersBackupAudioURL: libraryStore.prefersBackupAudioURL
        )
    }
}
