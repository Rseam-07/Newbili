import Foundation

nonisolated struct VideoDetailStartupPlayURLRequestIdentity: Equatable, Sendable {
    let bvid: String
    let cid: Int
    let page: Int?
    let preferredQuality: Int?
    let streamSourcePlatform: String
    let playbackCredentialIdentity: String

    var key: String {
        [
            bvid.lowercased(),
            String(cid),
            page.map(String.init) ?? "-",
            "q\(preferredQuality ?? 0)",
            streamSourcePlatform,
            playbackCredentialIdentity
        ].joined(separator: "|")
    }
}

extension VideoDetailViewModel {
    func cancelStartupPlayURLTask() {
        startupPlayURLRequestLease?.invalidate()
        startupPlayURLTask?.cancel()
        startupPlayURLTask = nil
        startupPlayURLTaskKey = nil
        startupPlayURLRequestLease = nil
        advanceStartupPlayURLGeneration()
    }

    func startupPlayURL(
        bvid: String,
        cid: Int,
        page: Int?
    ) async throws -> PlayURLData {
        let adaptiveQuality = adaptiveStartupPreferredQuality
        let streamSource = libraryStore.playbackStreamSourcePreference
        let requestIdentity = VideoDetailStartupPlayURLRequestIdentity(
            bvid: bvid,
            cid: cid,
            page: page,
            preferredQuality: adaptiveQuality,
            streamSourcePlatform: streamSource.cachePlatform,
            playbackCredentialIdentity: sessionStore.accountCacheIdentityKey(
                for: .playback,
                multiAccountEnabled: libraryStore.multiAccountExperimentEnabled
            )
        )
        let key = requestIdentity.key
        if startupPlayURLTaskKey == key, let startupPlayURLTask {
            let data = try await waitForStartupPlayURLTask(
                startupPlayURLTask,
                requestLease: startupPlayURLRequestLease
            )
            guard isCurrentPlaybackContext(bvid: bvid, cid: cid, page: page),
                  StartupPlayURLFeedbackEligibility.allows(startupPlayURLRequestLease)
            else { throw CancellationError() }
            return data
        }

        startupPlayURLRequestLease?.invalidate()
        startupPlayURLTask?.cancel()
        let startupGeneration = advanceStartupPlayURLGeneration()
        let requestLease = StartupPlayURLRequestLease()
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self else { throw CancellationError() }
            guard self.isCurrentPlaybackContext(bvid: bvid, cid: cid, page: page),
                  self.startupPlayURLGeneration == startupGeneration,
                  requestLease.isActive
            else { throw CancellationError() }
            let data = try await self.fetchStartupPlayURL(
                bvid: bvid,
                cid: cid,
                page: page,
                requestLease: requestLease
            )
            try Task.checkCancellation()
            guard self.isCurrentPlaybackContext(bvid: bvid, cid: cid, page: page),
                  self.startupPlayURLGeneration == startupGeneration,
                  requestLease.isActive
            else { throw CancellationError() }
            return data
        }
        startupPlayURLTask = task
        startupPlayURLTaskKey = key
        startupPlayURLRequestLease = requestLease
        Task { @MainActor [weak self, task] in
            _ = await task.result
            self?.clearStartupPlayURLTaskIfCurrent(key: key, generation: startupGeneration)
        }

        let data = try await waitForStartupPlayURLTask(task, requestLease: requestLease)
        guard isCurrentPlaybackContext(bvid: bvid, cid: cid, page: page),
              startupPlayURLGeneration == startupGeneration,
              requestLease.isActive
        else { throw CancellationError() }
        return data
    }

    private func waitForStartupPlayURLTask(
        _ task: Task<PlayURLData, Error>,
        requestLease: StartupPlayURLRequestLease?
    ) async throws -> PlayURLData {
        let data = try await BiliAPIClient.awaitSharedTask(task)
        guard StartupPlayURLFeedbackEligibility.allows(requestLease) else {
            throw CancellationError()
        }
        return data
    }
}
