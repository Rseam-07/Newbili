import AVFoundation
import Foundation
import OSLog

/// AVAudioSession activation can block in the audio server. All session mutations
/// run on one serial queue; leases prevent an outgoing player from silencing its successor.
nonisolated final class PlaybackAudioSessionCoordinator: @unchecked Sendable {
    static let shared = PlaybackAudioSessionCoordinator()
    typealias Operation = @Sendable (_ active: Bool, _ configureCategory: Bool) throws -> Void

    private let queue = DispatchQueue(label: "cc.bili.audio-session", qos: .userInitiated)
    private let operation: Operation
    private let releaseDelay: TimeInterval
    private let logger = Logger(subsystem: "cc.bili", category: "AudioSession")
    // Accessed exclusively on queue.
    private var owners = Set<UUID>()
    private var revision: UInt64 = 0
    private var isActive = false
    private var isConfigured = false

    init(releaseDelay: TimeInterval = 0.18,
         operation: @escaping Operation = PlaybackAudioSessionCoordinator.systemOperation) {
        self.releaseDelay = releaseDelay
        self.operation = operation
    }

    /// Enqueues synchronously so a subsequent release always follows this request.
    func acquire(
        _ owner: UUID,
        force: Bool = false,
        completion: @escaping @MainActor @Sendable (Bool) -> Void = { _ in }
    ) {
        queue.async { [self] in
            owners.insert(owner)
            revision &+= 1
            var succeeded = true
            if force || !isActive {
                do {
                    try operation(true, force || !isConfigured)
                    isConfigured = true
                    isActive = true
                } catch {
                    isActive = false
                    isConfigured = false
                    succeeded = false
                    logger.error("Audio session activation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            let result = succeeded
            Task { @MainActor in completion(result) }
        }
    }

    func release(_ owner: UUID) {
        queue.async { [self] in
            guard owners.remove(owner) != nil else { return }
            revision &+= 1
            guard owners.isEmpty else { return }
            let scheduledRevision = revision
            queue.asyncAfter(deadline: .now() + releaseDelay) { [self] in
                guard owners.isEmpty, revision == scheduledRevision, isActive else { return }
                do {
                    try operation(false, false)
                } catch {
                    logger.error("Audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
                }
                // Even a failed deactivation must be revalidated on the next play.
                isActive = false
            }
        }
    }

    private static func systemOperation(active: Bool, configureCategory: Bool) throws {
        dispatchPrecondition(condition: .notOnQueue(.main))
        let session = AVAudioSession.sharedInstance()
        if configureCategory {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
        }
        try session.setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
    }
}
