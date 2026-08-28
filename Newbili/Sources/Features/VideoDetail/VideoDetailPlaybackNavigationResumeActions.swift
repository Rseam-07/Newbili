import Foundation

extension VideoDetailViewModel {
    func markRelatedVideoNavigation() {
        isAwaitingRelatedVideoReturnPlayback = true
    }

    func resumePlaybackAfterCoveredNavigationIfNeeded() async {
        let wasInvalidated = isPlaybackInvalidatedForNavigation || isPlaybackTerminatedForNavigation
        if wasInvalidated {
            navigationState.playbackStopTask?.cancel()
            navigationState.playbackStopTask = nil
            isPlaybackInvalidatedForNavigation = false
            isPlaybackTerminatedForNavigation = false
        }

        if stablePlayerViewModel?.isTerminated == true {
            // A deeper related-video route may have evicted this page's engine
            // from the two-player warm budget. Validate the saved identity
            // before releasing it so a session/account change cannot reuse an
            // old playurl under new credentials.
            guard hasStablePlaybackIdentityForCurrentContext else {
                await reloadPlaybackForCurrentVariantContext()
                return
            }
            guard discardTerminatedStablePlayerIfNeeded() else { return }
            if selectedPlayVariant?.isPlayable == true {
                restoreStablePlayerForLoadedDetail()
            } else {
                await load()
            }
            return
        }

        if stablePlayerViewModel != nil,
           !hasReusablePlaybackSessionForCurrentContext {
            await reloadPlaybackForCurrentVariantContext()
            return
        }

        if let player = stablePlayerViewModel {
            let hasSuspendedPlayer = player.pendingNavigationResumeState() != nil
            guard wasInvalidated || hasSuspendedPlayer || hasPendingNavigationInterruption else { return }
            let didRestorePlayer = player.restoreAudioAfterCancelledNavigation()
            if isAwaitingRelatedVideoReturnPlayback {
                if didRestorePlayer {
                    player.pause()
                }
                player.setPlaybackIntent(false)
                player.setRelatedVideoReturnPlaybackPrompt(true)
                clearPendingNavigationResumeState()
                return
            }
            clearPendingNavigationResumeState()
            return
        }

        guard wasInvalidated else { return }
        await load()
    }

    private func reloadPlaybackForCurrentVariantContext() async {
        resetPlaybackStateForSelectedPage()
        await loadPlayURL(mode: .playbackRecovery)
    }

    private func clearPendingNavigationResumeState() {
        shouldResumePlaybackAfterCancelledNavigation = false
        pendingNavigationResumeTime = nil
        hasPendingNavigationInterruption = false
    }
}
