import SwiftUI

extension RootTabView {
    var shouldAutoOpenDetail: Bool {
        !didConsumeStartupVideo && shouldStartDetail && startBVID == nil
    }

    func openStartupVideoIfNeeded() {
        guard !didConsumeStartupVideo,
              let startBVID
        else { return }

        openVideo(Self.seedVideo(bvid: startBVID))
    }

    func openStartupLiveRoomIfNeeded() {
        guard !didConsumeStartupLiveRoom,
              let startLiveRoomID
        else { return }

        didConsumeStartupLiveRoom = true
        selectedTab = .live
        DispatchQueue.main.async {
            openLiveRoom(Self.seedLiveRoom(roomID: startLiveRoomID))
        }
    }

    func openStartupUploaderIfNeeded() {
        guard !didConsumeStartupUploader,
              let startUploaderMID,
              startUploaderMID > 0
        else { return }

        didConsumeStartupUploader = true
        selectedTab = .home
        DispatchQueue.main.async {
            openVideoOwnerRoute(Self.seedUploader(mid: startUploaderMID))
        }
    }

    func openStartupMineRouteIfNeeded() {
        guard !didConsumeStartupMineRoute,
              let startMineRoute,
              let route = Self.mineOverlayRoute(argumentValue: startMineRoute)
        else { return }

        didConsumeStartupMineRoute = true
        selectedTab = .mine
        mineViewModelHolder.configure(
            api: dependencies.api,
            sessionStore: dependencies.sessionStore,
            accountMessageService: dependencies.accountMessageService
        )
        DispatchQueue.main.async {
            openMineOverlayRoute(route)
        }
    }

    func openAppURL(_ url: URL) {
        guard AppLinkRouter.canHandle(url) else { return }

        Task { @MainActor in
            let destination = await AppLinkRouter.destination(for: url, api: dependencies.api)
            routeAppLinkDestination(destination)
        }
    }

    func routeAppLinkDestination(_ destination: AppLinkDestination) {
        switch destination {
        case .video(let video):
            openVideo(video)
        case .videoComment(let route):
            openVideoComment(route)
        case .liveRoom(let room):
            openLiveRoomFromLink(room)
        case .user(let owner):
            openUserFromLink(owner)
        case .browser(let url):
            inAppBrowserItem = InAppBrowserItem(
                url: url,
                cookieHeader: AppLinkRouter.isAuthenticatedBiliWebDestination(url)
                    ? dependencies.sessionStore.cookieHeader()
                    : nil
            )
        }
    }

    func openPgcSeasonRoute(_ route: PgcSeasonRoute) {
        pushRootRoute(route)
    }

    func openVideoOwnerRoute(_ owner: VideoOwner) {
        guard owner.mid > 0 else { return }
        AppOrientationLock.restorePortrait()
        pushRootRoute(owner)
    }

    private func pushRootRoute<Route: Hashable>(_ route: Route) {
        AppOrientationLock.restorePortrait()
        if bottomMode == .video {
            withAnimation(.smooth(duration: 0.28)) {
                videoNavigationPath.append(route)
            }
            return
        }

        withAnimation(.smooth(duration: 0.30)) {
            rootNavigationPath.append(route)
        }
    }

    func openLiveRoomFromLink(_ room: LiveRoom) {
        selectedTab = .live
        openLiveRoom(room)
    }

    func openLiveRoom(_ room: LiveRoom) {
        AppOrientationLock.restorePortrait()
        if bottomMode == .video {
            ActivePlaybackCoordinator.shared.stopActivePlayback()
            withAnimation(.smooth(duration: 0.28)) {
                videoNavigationPath.append(room)
            }
            return
        }

        if !rootNavigationPath.isEmpty {
            ActivePlaybackCoordinator.shared.stopActivePlayback()
        }
        withAnimation(.smooth(duration: 0.30)) {
            rootNavigationPath.append(room)
        }
    }

    func openUserFromLink(_ owner: VideoOwner) {
        openVideoOwnerRoute(owner)
    }

    func videoNavigationHost() -> some View {
        RootVideoNavigationHost(
            path: $videoNavigationPath,
            isClosingVideo: isClosingVideo,
            onRequestClose: closeVideo,
            onPopOne: popOneVideoLevel,
            onCancelledClose: cancelCloseVideoIfNeeded,
            onCompletedClose: completeCloseVideoIfNeeded
        ) {
            guard bottomMode == .video else { return }
            scheduleCloseVideo()
        }
    }

    func openMineOverlayRoute(_ route: MineOverlayRoute) {
        withAnimation(.smooth(duration: 0.30)) {
            rootNavigationPath.append(route)
        }
    }

    /// 详情页返回按钮：只 pop 一层（回到上一个详情页或来源页），
    /// 而非 closeVideo 的清空整栈。count==1 时 removeLast 会清空到 0，
    /// 触发 onPathEmptied → scheduleCloseVideo，正好回到来源页。
    func popOneVideoLevel() {
        guard bottomMode == .video, !videoNavigationPath.isEmpty else { return }
        withAnimation(.smooth(duration: 0.28)) {
            videoNavigationPath.removeLast()
        }
    }

    func openVideo(_ video: VideoItem) {
        audioMiniPlayerCoordinator.stopUnlessPreparedForDetailOpen(video)
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: video.bvid, title: video.title)
        if bottomMode == .video {
            pushVideo(video)
            return
        }

        beginPlaybackPreload(for: video)
        if !rootNavigationPath.isEmpty {
            ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        }

        let opensFromStartup = shouldStartDetail && !didConsumeStartupVideo
        didConsumeStartupVideo = true
        let push = {
            rootNavigationPath.append(video)
        }
        if opensFromStartup {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, push)
        } else {
            withAnimation(.smooth(duration: 0.30), push)
        }
    }

    func openVideoComment(_ route: VideoCommentRoute) {
        audioMiniPlayerCoordinator.stopUnlessPreparedForDetailOpen(route.video)
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: route.video.bvid, title: route.video.title)
        if bottomMode == .video {
            pushVideoComment(route)
            return
        }

        beginPlaybackPreload(for: route.video)
        if !rootNavigationPath.isEmpty {
            ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        }

        let opensFromStartup = shouldStartDetail && !didConsumeStartupVideo
        didConsumeStartupVideo = true
        let push = {
            rootNavigationPath.append(route)
        }
        if opensFromStartup {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, push)
        } else {
            withAnimation(.smooth(duration: 0.30), push)
        }
    }

    func openAudioMiniPlayerDetail() {
        guard let video = audioMiniPlayerCoordinator.prepareForDetailOpen() else { return }
        openVideo(video)
    }

    func pushVideo(_ video: VideoItem) {
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: video.bvid, title: video.title)
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        beginPlaybackPreload(for: video)
        withAnimation(.smooth(duration: 0.28)) {
            didConsumeStartupVideo = true
            isClosingVideo = false
            videoNavigationPath.append(video)
        }
    }

    func pushVideoComment(_ route: VideoCommentRoute) {
        AppOrientationLock.restorePortrait()
        PlayerMetricsLog.record(.routeOpen, metricsID: route.video.bvid, title: route.video.title)
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        beginPlaybackPreload(for: route.video)
        withAnimation(.smooth(duration: 0.28)) {
            didConsumeStartupVideo = true
            isClosingVideo = false
            videoNavigationPath.append(route)
        }
    }

    func beginPlaybackPreload(for video: VideoItem) {
        guard !video.bvid.isEmpty, !video.bvid.hasPrefix("av") else { return }
        guard !video.isPGCEpisode else { return }
        let now = Date()
        if let lastPreload = recentPlaybackPreloadTimes[video.bvid],
           now.timeIntervalSince(lastPreload) < 1.2 {
            return
        }
        recentPlaybackPreloadTimes[video.bvid] = now
        trimRecentPlaybackPreloads(now: now)

        Task {
            let playbackAdaptationProfile = PlayerPerformanceStore.shared.playbackAdaptationProfile(
                for: video.bvid,
                isEnabled: dependencies.libraryStore.isPlaybackAutoOptimizationEnabled
            )
            let preferredQuality = dependencies.libraryStore.effectivePreferredVideoQuality
            let cdnPreference = dependencies.libraryStore.effectivePlaybackCDNPreference
            let api = dependencies.api
            await VideoPreloadCenter.shared.updatePlaybackPreferences(
                preferredQuality: preferredQuality,
                cdnPreference: cdnPreference,
                playbackAdaptationProfile: playbackAdaptationProfile
            )
            await VideoPreloadCenter.shared.prioritizePlayback(for: video)
            await VideoPreloadCenter.shared.preloadPlayInfo(
                video,
                api: api,
                preferredQuality: preferredQuality,
                cdnPreference: cdnPreference,
                priority: .userInitiated,
                warmsMedia: true,
                mediaWarmupDelay: 0,
                playbackAdaptationProfile: playbackAdaptationProfile
            )
        }
    }

    func trimRecentPlaybackPreloads(now: Date) {
        recentPlaybackPreloadTimes = recentPlaybackPreloadTimes.filter { _, date in
            now.timeIntervalSince(date) < 8
        }
        guard recentPlaybackPreloadTimes.count > 16 else { return }
        let keptKeys = Set(
            recentPlaybackPreloadTimes
                .sorted { $0.value > $1.value }
                .prefix(16)
                .map(\.key)
        )
        recentPlaybackPreloadTimes = recentPlaybackPreloadTimes.filter { keptKeys.contains($0.key) }
    }

    func restoreVideoPlaybackUIForPictureInPicture(_ video: VideoItem) async -> Bool {
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        AppOrientationLock.restorePortrait()

        beginPlaybackPreload(for: video)
        didConsumeStartupVideo = true
        isClosingVideo = false

        var restoredPath = NavigationPath()
        restoredPath.append(video)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            rootNavigationPath = restoredPath
            bottomMode = .root
        }

        await Task.yield()
        return bottomMode == .root
            && rootNavigationPath.count == 1
            && videoNavigationPath.isEmpty
    }

    func closeVideo() {
        guard bottomMode == .video else { return }
        beginDefinitiveVideoClose()
    }

    func scheduleCloseVideo() {
        guard bottomMode == .video, !isClosingVideo else {
            return
        }
        isClosingVideo = true
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForNavigation()
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled, bottomMode == .video, isClosingVideo else { return }
            completeCloseVideoIfNeeded()
        }
    }

    func beginDefinitiveVideoClose() {
        isClosingVideo = true
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        ActivePlaybackCoordinator.shared.stopActivePlayback()
        AppOrientationLock.restoreRootOrientations()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            bottomMode = .root
            isClosingVideo = false
        }
        rootTabBarRestoreRequestID &+= 1
    }

    func cancelCloseVideoIfNeeded() {
        guard bottomMode == .video, isClosingVideo else { return }
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        isClosingVideo = false
        ActivePlaybackCoordinator.shared.resumeActivePlaybackAfterCancelledNavigation()
    }

    func completeCloseVideoIfNeeded() {
        guard bottomMode == .video, isClosingVideo else { return }
        closeVideoFallbackTask?.cancel()
        closeVideoFallbackTask = nil
        ActivePlaybackCoordinator.shared.stopActivePlayback()
        AppOrientationLock.restoreRootOrientations()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeVideo = nil
            videoNavigationPath = NavigationPath()
            bottomMode = .root
            isClosingVideo = false
        }
        rootTabBarRestoreRequestID &+= 1
    }
}
