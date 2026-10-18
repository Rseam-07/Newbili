import Foundation

extension VideoDetailViewModel {
    func loadUploaderProfile(mid capturedMID: Int? = nil, bvid capturedBVID: String? = nil, aid capturedAID: Int? = nil) async {
        let mid = capturedMID ?? detail.owner?.mid
        let bvid = capturedBVID ?? detail.bvid
        let aid = capturedAID ?? detail.aid
        let account = currentInteractionAccount
        guard let mid, mid > 0 else {
            guard isCurrentVideoContext(aid: aid, bvid: bvid) else { return }
            uploaderProfile = nil
            interactionState.isFollowing = false
            return
        }

        do {
            var profile = try await api.fetchUploaderProfile(mid: mid)
            guard !Task.isCancelled,
                  currentInteractionAccount == account,
                  isCurrentVideoContext(aid: aid, bvid: bvid, ownerMID: mid)
            else { return }
            if let confirmation = followConfirmation, confirmation.matches(ownerMID: mid, account: account) {
                profile = profile.withFollowing(confirmation.isFollowing)
            }
            uploaderProfile = profile
            interactionState.isFollowing = profile.following == true
        } catch {
            guard !Task.isCancelled,
                  currentInteractionAccount == account,
                  isCurrentVideoContext(aid: aid, bvid: bvid, ownerMID: mid)
            else { return }
            if let confirmation = followConfirmation, confirmation.matches(ownerMID: mid, account: account) {
                interactionState.isFollowing = confirmation.isFollowing
            } else if uploaderProfile == nil {
                interactionState.isFollowing = false
            }
        }
    }
}

extension UploaderProfile {
    nonisolated func withFollowing(_ value: Bool) -> Self {
        Self(card: card, follower: follower, following: value, likeNum: likeNum, archiveCount: archiveCount)
    }
}
