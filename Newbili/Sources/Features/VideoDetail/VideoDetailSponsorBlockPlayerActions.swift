import Foundation

extension VideoDetailViewModel {
    func resetSponsorBlockSegments() {
        cancelSponsorBlockTask()
        sponsorBlockSegments = []
        sponsorBlockIdentity = nil
        stablePlayerViewModel?.setSponsorBlockSegments([], isEnabled: false)
    }

    func applySponsorBlockSegmentsToPlayer() {
        guard !isPlaybackInvalidatedForNavigation else { return }
        let preferences = libraryStore.sponsorBlockPreferences
        stablePlayerViewModel?.setSponsorBlockSegments(
            sponsorBlockSegments,
            isEnabled: libraryStore.sponsorBlockEnabled,
            preferences: preferences
        ) { [sponsorBlockService] event in
            guard preferences.trackingEnabled else { return }
            await sponsorBlockService.reportViewed(
                uuid: event.segment.uuid,
                serverURL: preferences.serverURL
            )
        }
    }
}
