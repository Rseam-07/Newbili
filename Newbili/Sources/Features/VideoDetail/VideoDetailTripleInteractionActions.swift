import Foundation

extension VideoDetailViewModel {
    @discardableResult
    func triple() async -> Bool {
        guard let aid = detail.aid, aid > 0 else {
            interactionMessage = "没有找到视频 AV 号，无法一键三连"
            return false
        }
        if interactionState.isLiked,
           interactionState.isCoined,
           interactionState.isFavorited {
            interactionMessage = "已经完成三连"
            return true
        }

        let bvid = detail.bvid
        let pgcEpisodeID = detail.pgcEpisodeID
        let pgcSeasonID = detail.pgcSeasonID
        let succeeded = await performInteractionMutation(
            .triple,
            isCurrent: { isCurrentVideoContext(aid: aid, bvid: bvid) }
        ) {
            do {
                let result = try await api.tripleVideo(
                    aid: aid,
                    bvid: bvid,
                    pgcEpisodeID: pgcEpisodeID,
                    pgcSeasonID: pgcSeasonID
                )
                guard isCurrentVideoContext(aid: aid, bvid: bvid) else {
                    throw CancellationError()
                }
                if result.isLiked == true {
                    interactionState.isLiked = true
                }
                if result.isCoined == true || (result.coinCount ?? 0) > 0 {
                    interactionState.coinCount = max(
                        interactionState.coinCount,
                        max(result.coinCount ?? 1, 1)
                    )
                }
                if result.isFavorited == true {
                    interactionState.isFavorited = true
                }
            } catch {
                guard isCurrentVideoContext(aid: aid, bvid: bvid) else {
                    throw CancellationError()
                }
                guard await recoverAmbiguousTripleMutationIfNeeded(
                    error,
                    aid: aid,
                    bvid: bvid
                ) else {
                    throw error
                }
            }
        }

        if succeeded {
            interactionMessage = interactionState.isLiked
                && interactionState.isCoined
                && interactionState.isFavorited
                ? "三连成功"
                : "互动已同步，硬币或收藏未能完成"
        }
        return succeeded
    }
}
