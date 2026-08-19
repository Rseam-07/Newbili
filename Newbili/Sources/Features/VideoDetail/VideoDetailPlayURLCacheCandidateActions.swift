import Foundation

extension VideoDetailViewModel {
    func resolveStartupCachedPlayURLCandidate(
        _ data: PlayURLData,
        cid: Int,
        page: Int?,
        mode: VideoDetailPlayURLLoadMode,
        cacheKind: String,
        fallbackSource: String,
        loadedSource: String,
        loadedSignpost: String,
        deferredFallback: inout VideoDetailPlayURLFallback?
    ) async -> VideoDetailPlayURLCacheResolution? {
        guard !isPlaybackInvalidatedForNavigation else {
            return .loaded(signpostMessage: "bvid=\(detail.bvid) invalidated")
        }

        if shouldRefetchForStartupQuality(data) {
            rememberDeferredPlayableFallback(
                data,
                source: fallbackSource,
                mode: mode,
                deferredFallback: &deferredFallback
            )
            logPlayURLCacheBypass(kind: cacheKind, data: data)
            return nil
        }

        if !hasRequestedPlayableVariant(in: playVariants(from: data)) {
            rememberDeferredPlayableFallback(
                data,
                source: fallbackSource,
                mode: mode,
                deferredFallback: &deferredFallback
            )
            logPlayURLCacheBypass(kind: "\(cacheKind)TargetMiss", data: data)
            return nil
        }

        await applyCachedPlayURLData(
            data,
            cid: cid,
            page: page,
            source: loadedSource
        )
        return .loaded(signpostMessage: loadedSignpost)
    }
}
