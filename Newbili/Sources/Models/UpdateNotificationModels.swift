import Foundation

nonisolated enum FollowedUploaderNotificationLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case specialOnly
    case allFollowing

    var id: Self { self }

    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .specialOnly:
            return "仅特别关注"
        case .allFollowing:
            return "全部关注"
        }
    }

    var explanation: String {
        switch self {
        case .off:
            return "不检查关注 UP 的新投稿。"
        case .specialOnly:
            return "只提醒已加入特别关注的 UP 新投稿。"
        case .allFollowing:
            return "提醒动态流中全部已关注 UP 的新投稿。"
        }
    }
}

nonisolated enum SystemNotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case denied
    case enabled

    var title: String {
        switch self {
        case .notDetermined:
            return "尚未请求"
        case .denied:
            return "系统通知已关闭"
        case .enabled:
            return "系统通知已开启"
        }
    }
}

nonisolated struct MarkedAnimePageSnapshot: Codable, Equatable, Hashable, Sendable {
    let cid: Int
    let page: Int?
    let title: String
    let duration: Int?

    init(page: VideoPage) {
        cid = page.cid
        self.page = page.page
        title = page.part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        duration = page.duration
    }

    var videoPage: VideoPage {
        VideoPage(
            cid: cid,
            page: page,
            part: title.isEmpty ? nil : title,
            duration: duration,
            dimension: nil
        )
    }
}

nonisolated struct MarkedAnimeSnapshot: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { bvid }

    let bvid: String
    let aid: Int?
    let title: String
    let coverURL: String?
    let description: String?
    let duration: Int?
    let publishedAt: Int?
    let ownerMID: Int?
    let ownerName: String?
    let ownerFaceURL: String?
    let pages: [MarkedAnimePageSnapshot]
    let markedAt: Date
    let lastCheckedAt: Date?

    init(video: VideoItem, markedAt: Date = Date(), lastCheckedAt: Date? = nil) {
        bvid = video.bvid.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        aid = video.aid
        title = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
        coverURL = video.pic
        description = video.desc
        duration = video.duration
        publishedAt = video.pubdate
        ownerMID = video.owner?.mid
        ownerName = video.owner?.name
        ownerFaceURL = video.owner?.face
        pages = (video.pages ?? []).map(MarkedAnimePageSnapshot.init)
        self.markedAt = markedAt
        self.lastCheckedAt = lastCheckedAt
    }

    init(legacyBVID: String, markedAt: Date = Date()) {
        bvid = legacyBVID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        aid = nil
        title = "待同步的视频"
        coverURL = nil
        description = nil
        duration = nil
        publishedAt = nil
        ownerMID = nil
        ownerName = nil
        ownerFaceURL = nil
        pages = []
        self.markedAt = markedAt
        lastCheckedAt = nil
    }

    func refreshed(with video: VideoItem, checkedAt: Date = Date()) -> MarkedAnimeSnapshot {
        MarkedAnimeSnapshot(video: video, markedAt: markedAt, lastCheckedAt: checkedAt)
    }

    var videoItem: VideoItem {
        let owner: VideoOwner? = if ownerMID != nil || ownerName != nil || ownerFaceURL != nil {
            VideoOwner(mid: ownerMID ?? 0, name: ownerName ?? "", face: ownerFaceURL)
        } else {
            nil
        }
        return VideoItem(
            bvid: bvid,
            aid: aid,
            title: title.isEmpty ? "正在加载" : title,
            pic: coverURL,
            desc: description,
            duration: duration,
            pubdate: publishedAt,
            owner: owner,
            stat: nil,
            cid: pages.first?.cid,
            pages: pages.map(\.videoPage),
            dimension: nil
        )
    }
}

nonisolated struct FollowedUploaderUpdateRecord: Equatable, Hashable, Sendable {
    let dynamicID: String
    let uploaderMID: Int
    let uploaderName: String
    let bvid: String
    let videoTitle: String
}

nonisolated enum UpdateNotificationDiff {
    static func addedPages(
        previous: [MarkedAnimePageSnapshot],
        current: [MarkedAnimePageSnapshot]
    ) -> [MarkedAnimePageSnapshot] {
        guard !previous.isEmpty else { return [] }
        let existingCIDs = Set(previous.map(\.cid))
        return current.filter { !existingCIDs.contains($0.cid) }
    }

    static func newFollowedUploaderVideos(
        current: [FollowedUploaderUpdateRecord],
        previouslySeenDynamicIDs: Set<String>,
        hasEstablishedBaseline: Bool,
        requiresRebaseline: Bool = false,
        allowedUploaderMIDs: Set<Int>? = nil
    ) -> [FollowedUploaderUpdateRecord] {
        guard hasEstablishedBaseline, !requiresRebaseline else { return [] }
        var emittedIDs = Set<String>()
        return current.filter { record in
            guard !previouslySeenDynamicIDs.contains(record.dynamicID),
                  emittedIDs.insert(record.dynamicID).inserted
            else { return false }
            if let allowedUploaderMIDs {
                return allowedUploaderMIDs.contains(record.uploaderMID)
            }
            return true
        }
    }
}

nonisolated enum UpdateNotificationStatusText {
    static func refreshResult(
        notificationCount: Int,
        completedChecks: Int,
        failures: Int,
        skippedFollowedUploadersBecauseLoggedOut: Bool
    ) -> String {
        let baseMessage: String
        switch (notificationCount, completedChecks, failures) {
        case let (count, _, _) where count > 0:
            baseMessage = "发现 \(count) 条更新，已发送通知"
        case (_, 0, let failureCount) where failureCount > 0:
            baseMessage = "本次检查失败，将在下次启动或后台刷新时重试"
        case (_, _, let failureCount) where failureCount > 0:
            baseMessage = "已完成部分检查，失败项目会自动重试"
        case (_, let checkCount, _) where checkCount > 0:
            baseMessage = "已检查，目前没有新内容"
        default:
            baseMessage = "没有可执行的更新检查"
        }
        guard skippedFollowedUploadersBecauseLoggedOut else { return baseMessage }
        if completedChecks > 0 || failures > 0 || notificationCount > 0 {
            return "\(baseMessage)；关注 UP 未登录，本次未检查"
        }
        return "关注 UP 未登录，本次未检查"
    }
}

nonisolated enum UpdateNotificationBackgroundRefreshPolicy {
    static func shouldSchedule(
        hasTrackingTarget: Bool,
        permissionState: SystemNotificationPermissionState
    ) -> Bool {
        hasTrackingTarget && permissionState == .enabled
    }
}

nonisolated enum UpdateNotificationAccessibilityText {
    static func markedAnimeCount(_ count: Int) -> String {
        "\(max(0, count)) 个追更项目"
    }
}

nonisolated enum UpdateNotificationText {
    static func animePageUpdateTitle(for snapshot: MarkedAnimeSnapshot) -> String {
        "追更提醒 · \(snapshot.title.isEmpty ? snapshot.bvid : snapshot.title)"
    }

    static func animePageUpdateBody(addedPages: [MarkedAnimePageSnapshot]) -> String {
        guard addedPages.count == 1, let page = addedPages.first else {
            return "新增 \(addedPages.count) 个分 P，点此继续观看。"
        }
        let fallback = page.page.map { "P\($0)" } ?? "新分 P"
        return "\(page.title.isEmpty ? fallback : page.title) 已更新，点此继续观看。"
    }

    static func uploaderUpdateTitle(uploaderName: String) -> String {
        "\(uploaderName.isEmpty ? "关注的 UP" : uploaderName) 更新了"
    }
}

nonisolated enum UpdateNotificationCopy {
    static let backgroundDeliveryNotice = "Newbili 会在启动、回到前台以及系统允许的后台刷新时检查。iOS 会根据电量、网络和使用习惯决定后台时机，因此无法保证实时送达。"
}
