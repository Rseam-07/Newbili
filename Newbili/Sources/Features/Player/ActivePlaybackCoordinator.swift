import Foundation

@MainActor
final class ActivePlaybackCoordinator {
    static let shared = ActivePlaybackCoordinator()

    private weak var activePlayer: PlayerStateViewModel?
    private var registeredPlayers: [ObjectIdentifier: WeakPlayerReference] = [:]
    private var visualPlaybackActivationOrder: [ObjectIdentifier] = []
    private var activeGeneration = UUID()
    private let maximumRetainedVisualPlayers = 2

    private init() {}

    func register(_ player: PlayerStateViewModel) {
        cleanupRegisteredPlayers()
        registeredPlayers[ObjectIdentifier(player)] = WeakPlayerReference(player)
    }

    func unregister(_ player: PlayerStateViewModel) {
        let playerID = ObjectIdentifier(player)
        registeredPlayers[playerID] = nil
        visualPlaybackActivationOrder.removeAll { $0 == playerID }
        if activePlayer === player {
            activePlayer = nil
            activeGeneration = UUID()
        }
        cleanupRegisteredPlayers()
    }

    @discardableResult
    func activate(_ player: PlayerStateViewModel) -> UUID {
        register(player)
        if let activePlayer, activePlayer !== player {
            activePlayer.pauseForNavigation()
        }
        activePlayer = player
        activeGeneration = UUID()
        recordVisualPlaybackActivation(player)
        enforceVisualPlaybackRetentionBudget()
        return activeGeneration
    }

    func deactivate(_ player: PlayerStateViewModel) {
        guard activePlayer === player else { return }
        activePlayer = nil
        activeGeneration = UUID()
    }

    func stopActivePlayback() {
        let players = registeredPlayersIncludingActive()
        activePlayer = nil
        activeGeneration = UUID()
        players.forEach { $0.stop(reason: .navigation) }
        cleanupRegisteredPlayers()
    }

    func pauseActivePlaybackForNavigation() {
        for player in registeredPlayersIncludingActive() where !player.isPictureInPictureActive {
            player.pauseForNavigation()
        }
    }

    @discardableResult
    func pauseActivePlaybackForAppBackground() -> Bool {
        cleanupRegisteredPlayers()
        return activePlayer?.pauseForAppBackground() ?? false
    }

    @discardableResult
    func resumeActivePlaybackAfterCancelledNavigation() -> Bool {
        activePlayer?.restoreAudioAfterCancelledNavigation() ?? false
    }

    func isActive(_ player: PlayerStateViewModel) -> Bool {
        activePlayer === player
    }

    func currentActivePlayer() -> PlayerStateViewModel? {
        activePlayer
    }

    func applyBackgroundPlaybackMode(_ mode: BackgroundPlaybackMode) {
        for player in registeredPlayersIncludingActive() {
            player.applyBackgroundPlaybackMode(mode)
        }
    }

    /// Clears visual detail players while preserving listen-mode and active PiP
    /// sessions that intentionally outlive the navigation stack.
    func stopVisualPlaybackForNavigation() {
        let players = registeredPlayersIncludingActive()
        for player in players
        where !player.isAudioOnlyPlayback && !player.isPictureInPictureActive {
            player.stop(reason: .navigation)
        }
        cleanupRegisteredPlayers()
    }

    private func registeredPlayersIncludingActive() -> [PlayerStateViewModel] {
        cleanupRegisteredPlayers()
        var players = registeredPlayers.values.compactMap(\.player)
        if let activePlayer, !players.contains(where: { $0 === activePlayer }) {
            players.append(activePlayer)
        }
        return players
    }

    private func cleanupRegisteredPlayers() {
        registeredPlayers = registeredPlayers.filter { $0.value.player != nil }
        let registeredPlayerIDs = Set(registeredPlayers.keys)
        visualPlaybackActivationOrder.removeAll { playerID in
            guard registeredPlayerIDs.contains(playerID),
                  let player = registeredPlayers[playerID]?.player
            else { return true }
            return player.isTerminated
        }
    }

    private func recordVisualPlaybackActivation(_ player: PlayerStateViewModel) {
        guard player.participatesInVisualPlaybackRetentionBudget else { return }
        let playerID = ObjectIdentifier(player)
        visualPlaybackActivationOrder.removeAll { $0 == playerID }
        visualPlaybackActivationOrder.append(playerID)
    }

    private func enforceVisualPlaybackRetentionBudget() {
        cleanupRegisteredPlayers()
        let retainedPlayers = visualPlaybackActivationOrder.compactMap { playerID in
            registeredPlayers[playerID]?.player
        }
        .filter(\.participatesInVisualPlaybackRetentionBudget)
        let overflowCount = retainedPlayers.count - maximumRetainedVisualPlayers
        guard overflowCount > 0 else { return }

        // The activation order is oldest-first. Terminating the overflow leaves
        // the current detail and the immediately covered detail warm, while the
        // owning view models keep their navigation resume state for rebuilding.
        for player in retainedPlayers.prefix(overflowCount) where player !== activePlayer {
            player.stop(reason: .navigationRetentionBudgetExceeded)
        }
    }
}

private struct WeakPlayerReference {
    weak var player: PlayerStateViewModel?

    init(_ player: PlayerStateViewModel) {
        self.player = player
    }
}

enum PlayerStopReason {
    case navigation
    case navigationRetentionBudgetExceeded
    case replacedByAnotherPlayer
    case deallocated
}
