import Foundation

extension VideoDetailViewModel {
    @discardableResult
    func toggleFollow() async -> Bool {
        guard let mid = detail.owner?.mid, mid > 0 else {
            interactionMessage = "没有找到 UP 主 UID，无法关注"
            return false
        }
        let bvid = detail.bvid
        let account = currentInteractionAccount
        let targetState = !interactionState.isFollowing
        return await performInteractionMutation(
            .follow,
            isCurrent: { isCurrentVideoContext(bvid: bvid, ownerMID: mid) && currentInteractionAccount == account }
        ) {
            try await api.setUploaderFollowing(mid: mid, following: targetState)
            guard isCurrentVideoContext(bvid: bvid, ownerMID: mid), currentInteractionAccount == account
            else { throw CancellationError() }
            if let account {
                followConfirmation = VideoDetailFollowConfirmation(ownerMID: mid, account: account, isFollowing: targetState)
            }
            if let profile = uploaderProfile { uploaderProfile = profile.withFollowing(targetState) }
            interactionState.isFollowing = targetState
        }
    }
}
