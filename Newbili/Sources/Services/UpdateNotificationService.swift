import BackgroundTasks
import Combine
import Foundation
import os
import UIKit
import UserNotifications

enum UpdateNotificationRefreshReason: Sendable {
    case appActivation
    case manual
    case background
}

@MainActor
final class UpdateNotificationService: ObservableObject {
    @Published private(set) var permissionState: SystemNotificationPermissionState = .notDetermined
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var statusMessage = "尚未检查更新"

    private let api: BiliAPIClient
    private let libraryStore: LibraryStore
    private let sessionStore: SessionStore
    private let notificationCenter: UNUserNotificationCenter
    private let checkState: UpdateNotificationCheckStateStore
    private static let logger = Logger(subsystem: "com.rseam07.newbili", category: "UpdateNotifications")

    init(
        api: BiliAPIClient,
        libraryStore: LibraryStore,
        sessionStore: SessionStore,
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.api = api
        self.libraryStore = libraryStore
        self.sessionStore = sessionStore
        self.notificationCenter = notificationCenter
        checkState = UpdateNotificationCheckStateStore(userDefaults: userDefaults)
    }

    var hasAnyTrackingTarget: Bool {
        libraryStore.followedUploaderNotificationLevel != .off
            || !libraryStore.markedAnimeSnapshots.isEmpty
    }

    func refreshPermissionState() async {
        let settings = await notificationCenter.notificationSettings()
        permissionState = Self.permissionState(for: settings.authorizationStatus)
        synchronizeBackgroundRefreshSchedule()
    }

    func followedUploaderNotificationLevelDidChange(_ level: FollowedUploaderNotificationLevel) {
        if level == .off {
            checkState.requireFreshDynamicBaseline()
        }
        synchronizeBackgroundRefreshSchedule()
    }

    func synchronizeBackgroundRefreshSchedule() {
        UpdateNotificationBackgroundRefreshCoordinator.scheduleIfNeeded(
            hasTrackingTarget: hasAnyTrackingTarget,
            permissionState: permissionState
        )
    }

    /// Called only from the notification settings button. Merely selecting a
    /// tracking tier or marking a series must never trigger the system prompt.
    func requestPermissionFromUserAction() async {
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Self.logger.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshPermissionState()
        if permissionState == .enabled {
            _ = await refresh(reason: .manual)
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func refreshIfNeededOnAppActivation() async {
        if let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 5 * 60 {
            await refreshPermissionState()
            return
        }
        _ = await refresh(reason: .appActivation)
    }

    @discardableResult
    func refresh(reason: UpdateNotificationRefreshReason) async -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        await refreshPermissionState()
        guard hasAnyTrackingTarget else {
            statusMessage = "没有需要检查的关注或追更项目"
            synchronizeBackgroundRefreshSchedule()
            return true
        }
        guard permissionState == .enabled else {
            statusMessage = permissionState == .denied
                ? "系统通知已关闭，请在系统设置中开启"
                : "请先点按“允许系统通知”"
            return false
        }

        var notificationCount = 0
        var completedChecks = 0
        var failures = 0
        let skippedFollowedUploadersBecauseLoggedOut =
            libraryStore.followedUploaderNotificationLevel != .off && !sessionStore.isLoggedIn

        if !libraryStore.markedAnimeSnapshots.isEmpty {
            let result = await refreshMarkedAnimeUpdates()
            notificationCount += result.notifications
            completedChecks += result.checks
            failures += result.failures
        }

        if libraryStore.followedUploaderNotificationLevel != .off, sessionStore.isLoggedIn {
            do {
                notificationCount += try await refreshFollowedUploaderUpdates()
                completedChecks += 1
            } catch {
                failures += 1
                Self.logger.error("Followed uploader refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        lastRefreshAt = Date()
        statusMessage = UpdateNotificationStatusText.refreshResult(
            notificationCount: notificationCount,
            completedChecks: completedChecks,
            failures: failures,
            skippedFollowedUploadersBecauseLoggedOut: skippedFollowedUploadersBecauseLoggedOut
        )
        return failures == 0
    }

    private func refreshMarkedAnimeUpdates() async -> (notifications: Int, checks: Int, failures: Int) {
        let snapshots = libraryStore.markedAnimeSnapshots
        var notifications = 0
        var checks = 0
        var failures = 0

        for snapshot in snapshots {
            guard !Task.isCancelled else { break }
            do {
                let detail = try await api.fetchVideoDetail(bvid: snapshot.bvid, bypassesCache: true)
                let refreshed = snapshot.refreshed(with: detail)
                let addedPages = UpdateNotificationDiff.addedPages(
                    previous: snapshot.pages,
                    current: refreshed.pages
                )
                if !addedPages.isEmpty {
                    try await addAnimeUpdateNotification(snapshot: refreshed, addedPages: addedPages)
                    notifications += 1
                }
                libraryStore.updateMarkedAnimeSnapshot(refreshed)
                checks += 1
            } catch {
                failures += 1
                Self.logger.error("Marked series refresh failed for \(snapshot.bvid, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .public)")
            }
        }
        return (notifications, checks, failures)
    }

    private func refreshFollowedUploaderUpdates() async throws -> Int {
        let page = try await api.fetchDynamicFeed(fetchPolicy: .networkOnly)
        let records = (page.items ?? []).compactMap(Self.followedUploaderRecord)
        let allowedMIDs: Set<Int>?
        switch libraryStore.followedUploaderNotificationLevel {
        case .off:
            return 0
        case .specialOnly:
            allowedMIDs = try await api.fetchSpecialFollowedUploaderMIDs()
        case .allFollowing:
            allowedMIDs = nil
        }

        let newRecords = UpdateNotificationDiff.newFollowedUploaderVideos(
            current: records,
            previouslySeenDynamicIDs: checkState.seenDynamicIDs,
            hasEstablishedBaseline: checkState.hasDynamicBaseline,
            requiresRebaseline: checkState.requiresFreshDynamicBaseline,
            allowedUploaderMIDs: allowedMIDs
        )
        for record in newRecords.prefix(20) {
            try await addUploaderUpdateNotification(record)
        }
        checkState.recordDynamicBaseline(currentIDs: records.map(\.dynamicID))
        return min(newRecords.count, 20)
    }

    private func addAnimeUpdateNotification(
        snapshot: MarkedAnimeSnapshot,
        addedPages: [MarkedAnimePageSnapshot]
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = UpdateNotificationText.animePageUpdateTitle(for: snapshot)
        content.body = UpdateNotificationText.animePageUpdateBody(addedPages: addedPages)
        content.sound = .default
        content.threadIdentifier = "newbili.marked-series"
        content.userInfo = ["bvid": snapshot.bvid]
        let request = UNNotificationRequest(
            identifier: "newbili.marked-series.\(snapshot.bvid).\(addedPages.map(\.cid).map(String.init).joined(separator: "-"))",
            content: content,
            trigger: nil
        )
        try await notificationCenter.add(request)
    }

    private func addUploaderUpdateNotification(_ record: FollowedUploaderUpdateRecord) async throws {
        let content = UNMutableNotificationContent()
        content.title = UpdateNotificationText.uploaderUpdateTitle(uploaderName: record.uploaderName)
        content.body = record.videoTitle
        content.sound = .default
        content.threadIdentifier = "newbili.followed-uploaders"
        content.userInfo = ["bvid": record.bvid]
        let request = UNNotificationRequest(
            identifier: "newbili.followed-uploader.\(record.dynamicID)",
            content: content,
            trigger: nil
        )
        try await notificationCenter.add(request)
    }

    private static func followedUploaderRecord(_ item: DynamicFeedItem) -> FollowedUploaderUpdateRecord? {
        guard let archive = item.archive,
              let bvid = archive.bvid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bvid.isEmpty,
              let author = item.author,
              let mid = author.mid,
              mid > 0
        else { return nil }
        return FollowedUploaderUpdateRecord(
            dynamicID: item.idStr,
            uploaderMID: mid,
            uploaderName: author.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            bvid: bvid,
            videoTitle: archive.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "新投稿"
        )
    }

    private static func permissionState(for status: UNAuthorizationStatus) -> SystemNotificationPermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .enabled
        @unknown default:
            return .notDetermined
        }
    }
}

@MainActor
private final class UpdateNotificationCheckStateStore {
    private let userDefaults: UserDefaults
    private let seenDynamicIDsKey = "cc.newbili.notifications.seenDynamicIDs.v1"
    private let dynamicBaselineKey = "cc.newbili.notifications.hasDynamicBaseline.v1"
    private let requiresFreshDynamicBaselineKey = "cc.newbili.notifications.requiresFreshDynamicBaseline.v1"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var seenDynamicIDs: Set<String> {
        Set(userDefaults.stringArray(forKey: seenDynamicIDsKey) ?? [])
    }

    var hasDynamicBaseline: Bool {
        userDefaults.bool(forKey: dynamicBaselineKey)
    }

    var requiresFreshDynamicBaseline: Bool {
        userDefaults.bool(forKey: requiresFreshDynamicBaselineKey)
    }

    func requireFreshDynamicBaseline() {
        userDefaults.set(true, forKey: requiresFreshDynamicBaselineKey)
    }

    func recordDynamicBaseline(currentIDs: [String]) {
        var orderedIDs = [String]()
        var seen = Set<String>()
        for id in currentIDs + Array(seenDynamicIDs) where seen.insert(id).inserted {
            orderedIDs.append(id)
            if orderedIDs.count == 512 { break }
        }
        userDefaults.set(orderedIDs, forKey: seenDynamicIDsKey)
        userDefaults.set(true, forKey: dynamicBaselineKey)
        userDefaults.set(false, forKey: requiresFreshDynamicBaselineKey)
    }
}

@MainActor
enum UpdateNotificationBackgroundRefreshCoordinator {
    static let taskIdentifier = "com.rseam07.newbili.update-notifications"
    private static let logger = Logger(subsystem: "com.rseam07.newbili", category: "BackgroundRefresh")
    private static var refreshHandler: (() async -> Bool)?

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let operation = Task { @MainActor in
                let succeeded = await refreshHandler?() ?? false
                appRefreshTask.setTaskCompleted(success: succeeded)
            }
            appRefreshTask.expirationHandler = {
                operation.cancel()
            }
        }
    }

    static func install(service: UpdateNotificationService) {
        refreshHandler = { [weak service] in
            guard let service else { return false }
            return await service.refresh(reason: .background)
        }
        service.synchronizeBackgroundRefreshSchedule()
    }

    static func scheduleIfNeeded(
        hasTrackingTarget: Bool,
        permissionState: SystemNotificationPermissionState
    ) {
        guard UpdateNotificationBackgroundRefreshPolicy.shouldSchedule(
            hasTrackingTarget: hasTrackingTarget,
            permissionState: permissionState
        ) else {
            cancelPendingRefresh()
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.debug("Background refresh scheduling unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func cancelPendingRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }
}
