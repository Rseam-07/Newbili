import Combine
import OSLog
import QuartzCore
import SwiftUI

enum PlaybackDetailPageKind: String, Sendable {
    case video
    case pgc
    case live
}

struct PlaybackDetailPerformanceContext: Equatable, Sendable {
    let kind: PlaybackDetailPageKind
    let pageID: String
    let mediaID: String
    let title: String?

    var key: String {
        "\(kind.rawValue)|\(pageID)"
    }

    static func video(_ video: VideoItem) -> PlaybackDetailPerformanceContext {
        let isPGC = video.isPGCEpisode
        let pageID: String
        if isPGC, let seasonID = video.pgcSeasonID, seasonID > 0 {
            pageID = "season-\(seasonID)"
        } else {
            pageID = video.bvid
        }
        return PlaybackDetailPerformanceContext(
            kind: isPGC ? .pgc : .video,
            pageID: pageID,
            mediaID: video.bvid,
            title: video.title
        )
    }

    static func live(roomID: Int, title: String?) -> PlaybackDetailPerformanceContext {
        PlaybackDetailPerformanceContext(
            kind: .live,
            pageID: String(roomID),
            mediaID: String(roomID),
            title: title
        )
    }

    static func live(_ room: LiveRoom) -> PlaybackDetailPerformanceContext {
        live(roomID: room.roomID, title: room.title)
    }
}

enum PlaybackDetailPerformanceMilestone: String, Hashable, Sendable {
    case pageAppeared
    case initialContentAppeared
    case loadedContentAppeared
    case initialContentRemoved
    case playerAttached
    case firstFramePresented
    case fullscreenTransitionStarted
    case fullscreenLayoutUpdated
    case pageDisappeared

    var recordsOnce: Bool {
        switch self {
        case .fullscreenTransitionStarted, .fullscreenLayoutUpdated:
            return false
        default:
            return true
        }
    }
}

struct PlaybackDetailPerformanceEventRecord: Equatable, Sendable {
    let milestone: PlaybackDetailPerformanceMilestone
    let elapsedMilliseconds: Int
    let deltaMilliseconds: Int
    let detail: String?
}

struct PlaybackDetailPerformanceSnapshot: Equatable, Sendable {
    let context: PlaybackDetailPerformanceContext
    let durationMilliseconds: Int
    let events: [PlaybackDetailPerformanceEventRecord]
}

@MainActor
final class PlaybackDetailPerformanceMonitor {
    static let shared = PlaybackDetailPerformanceMonitor()

    private struct Session {
        var context: PlaybackDetailPerformanceContext
        let startedAt: CFTimeInterval
        var lastEventAt: CFTimeInterval
        var recordedOnce = Set<PlaybackDetailPerformanceMilestone>()
        var events = [PlaybackDetailPerformanceEventRecord]()
    }

    private static let logger = Logger(subsystem: "cc.bili", category: "PlaybackDetailPerformance")
    private var sessions = [String: Session]()
    private var completedSnapshots = [PlaybackDetailPerformanceSnapshot]()

    private init() {}

    func begin(_ context: PlaybackDetailPerformanceContext) {
        guard sessions[context.key] == nil else {
            sessions[context.key]?.context = context
            return
        }
        let now = CACurrentMediaTime()
        sessions[context.key] = Session(
            context: context,
            startedAt: now,
            lastEventAt: now
        )
    }

    func mark(
        _ milestone: PlaybackDetailPerformanceMilestone,
        context: PlaybackDetailPerformanceContext,
        detail: String? = nil
    ) {
        begin(context)
        guard var session = sessions[context.key] else { return }
        session.context = context
        if milestone.recordsOnce, session.recordedOnce.contains(milestone) {
            sessions[context.key] = session
            return
        }

        let now = CACurrentMediaTime()
        let elapsed = Self.milliseconds(from: session.startedAt, to: now)
        let delta = Self.milliseconds(from: session.lastEventAt, to: now)
        let record = PlaybackDetailPerformanceEventRecord(
            milestone: milestone,
            elapsedMilliseconds: elapsed,
            deltaMilliseconds: delta,
            detail: detail
        )
        session.events.append(record)
        if session.events.count > 40 {
            session.events.removeFirst(session.events.count - 40)
        }
        session.lastEventAt = now
        if milestone.recordsOnce {
            session.recordedOnce.insert(milestone)
        }
        sessions[context.key] = session

        PlayerMetricsLog.signpostEvent("PlaybackDetailMilestone")
        Self.logger.info("\(Self.logMessage(context: context, record: record), privacy: .public)")
    }

    func end(_ context: PlaybackDetailPerformanceContext) {
        let latestContext = sessions[context.key]?.context ?? context
        mark(.pageDisappeared, context: latestContext)
        guard let session = sessions.removeValue(forKey: context.key) else { return }
        completedSnapshots.insert(Self.snapshot(from: session), at: 0)
        if completedSnapshots.count > 24 {
            completedSnapshots.removeLast(completedSnapshots.count - 24)
        }
    }

    func snapshot(for context: PlaybackDetailPerformanceContext) -> PlaybackDetailPerformanceSnapshot? {
        if let session = sessions[context.key] {
            return Self.snapshot(from: session)
        }
        return completedSnapshots.first { $0.context.key == context.key }
    }

    func recentSnapshots() -> [PlaybackDetailPerformanceSnapshot] {
        completedSnapshots
    }

    func resetForTesting() {
        sessions.removeAll()
        completedSnapshots.removeAll()
    }

    private static func snapshot(from session: Session) -> PlaybackDetailPerformanceSnapshot {
        PlaybackDetailPerformanceSnapshot(
            context: session.context,
            durationMilliseconds: milliseconds(from: session.startedAt, to: CACurrentMediaTime()),
            events: session.events
        )
    }

    private static func milliseconds(from start: CFTimeInterval, to end: CFTimeInterval) -> Int {
        Int(((end - start) * 1000).rounded())
    }

    private static func logMessage(
        context: PlaybackDetailPerformanceContext,
        record: PlaybackDetailPerformanceEventRecord
    ) -> String {
        [
            "kind=\(context.kind.rawValue)",
            "pageID=\(context.pageID)",
            "mediaID=\(context.mediaID)",
            "event=\(record.milestone.rawValue)",
            "elapsed=\(record.elapsedMilliseconds)ms",
            "delta=\(record.deltaMilliseconds)ms",
            detailText(record.detail),
            context.title.map { "title=\(PlayerMetricsLog.shortTitle($0))" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private static func detailText(_ detail: String?) -> String? {
        guard let detail = detail?.replacingOccurrences(of: "\n", with: " "), !detail.isEmpty else {
            return nil
        }
        return "detail=\(detail)"
    }
}

struct PlaybackDetailPlayerReadinessProbe: View {
    let playerViewModel: PlayerStateViewModel
    let context: PlaybackDetailPerformanceContext

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                PlaybackDetailPerformanceMonitor.shared.mark(.playerAttached, context: context)
                markFirstFrameIfNeeded(playerViewModel.hasPresentedPlayback)
            }
            .onReceive(playerViewModel.$hasPresentedPlayback.removeDuplicates()) { hasPresentedPlayback in
                markFirstFrameIfNeeded(hasPresentedPlayback)
            }
    }

    private func markFirstFrameIfNeeded(_ hasPresentedPlayback: Bool) {
        guard hasPresentedPlayback else { return }
        PlaybackDetailPerformanceMonitor.shared.mark(.firstFramePresented, context: context)
    }
}
