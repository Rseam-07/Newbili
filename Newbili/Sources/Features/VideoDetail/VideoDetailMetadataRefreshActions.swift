import Foundation

extension VideoDetailViewModel {
    func scheduleAcknowledgedInteractionMetadataRefresh() {
        interactionMetadataRefreshTask?.cancel()
        let revision = interactionMutationRevision
        let bvid = detail.bvid
        let aid = detail.aid
        let account = currentInteractionAccount
        let task = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled,
                  self.interactionMutationRevision == revision,
                  self.currentInteractionAccount == account,
                  !self.isPlaybackInvalidatedForNavigation,
                  self.isCurrentVideoContext(aid: aid, bvid: bvid) else { return }
            defer {
                if self.interactionMutationRevision == revision { self.interactionMetadataRefreshTask = nil }
            }
            do {
                let updated = try await self.fetchCurrentFullDetail()
                guard !Task.isCancelled, self.interactionMutationRevision == revision,
                      self.currentInteractionAccount == account, !self.isPlaybackInvalidatedForNavigation,
                      self.isCurrentVideoContext(aid: aid, bvid: bvid) else { return }
                self.detail = updated
                self.syncCommentsRenderStore()
                if self.selectedCID == nil {
                    self.selectedCID = updated.pages?.first?.cid ?? updated.cid
                }
            } catch {
                // The write already succeeded. A failed counter refresh must
                // not delay feedback, roll back state, or invite a second write.
            }
        }
        interactionMetadataRefreshTask = task
        trackBackgroundTask(task)
    }
}
