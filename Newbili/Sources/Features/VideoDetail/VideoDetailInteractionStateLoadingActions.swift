import Foundation

extension VideoDetailViewModel {
    func loadInteractionState(
        aid capturedAID: Int? = nil,
        bvid capturedBVID: String? = nil,
        preserving confirmation: VideoDetailInteractionMutationConfirmation? = nil
    ) async {
        let bvid = capturedBVID ?? detail.bvid
        guard let aid = capturedAID ?? detail.aid else { return }
        let capturedMutationRevision = interactionMutationRevision
        let account = currentInteractionAccount
        do {
            var state = try await api.fetchVideoInteractionState(aid: aid, bvid: bvid)
            guard !Task.isCancelled,
                  currentInteractionAccount == account,
                  capturedMutationRevision == interactionMutationRevision,
                  isCurrentVideoContext(aid: aid, bvid: bvid)
            else { return }
            if let followConfirmation, followConfirmation.matches(ownerMID: detail.owner?.mid, account: account) {
                state.isFollowing = followConfirmation.isFollowing
            } else if let isFollowing = uploaderProfile?.following {
                state.isFollowing = isFollowing
            }
            if let confirmation {
                state = confirmation.reconciling(state)
            }
            interactionState = state
            if state.isFavorited {
                let favoriteFolderTask = Task { @MainActor [weak self, aid, bvid = detail.bvid] in
                    guard let self,
                          !self.isPlaybackInvalidatedForNavigation,
                          self.isCurrentVideoContext(aid: aid, bvid: bvid)
                    else { return }
                    await self.loadFavoriteFoldersForCurrentVideo()
                }
                trackBackgroundTask(favoriteFolderTask)
            }
            interactionMessage = nil
        } catch BiliAPIError.missingSESSDATA {
            guard !Task.isCancelled,
                  currentInteractionAccount == account,
                  capturedMutationRevision == interactionMutationRevision,
                  isCurrentVideoContext(aid: aid, bvid: bvid)
            else { return }
            interactionState.isFollowing = uploaderProfile?.following == true
        } catch {
            guard !Task.isCancelled,
                  currentInteractionAccount == account,
                  capturedMutationRevision == interactionMutationRevision,
                  isCurrentVideoContext(aid: aid, bvid: bvid)
            else { return }
            interactionMessage = "互动状态同步失败：\(error.localizedDescription)"
        }
    }
}
