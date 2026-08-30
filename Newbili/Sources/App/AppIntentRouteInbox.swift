import Combine
import Foundation

nonisolated enum AppIntentRoute: Codable, Equatable, Sendable {
    case home
    case history
    case watchLater
    case favorites
    case video(bvid: String)
}

nonisolated struct AppIntentRouteRequest: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let route: AppIntentRoute
    let createdAt: Date

    init(
        id: UUID = UUID(),
        route: AppIntentRoute,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.route = route
        self.createdAt = createdAt
    }
}

/// A small durable queue shared by App Intents and the root SwiftUI scene.
///
/// Persisting the requests is intentional: an intent may run while the app is
/// launching, before `RootTabView` has installed its observers. The root view
/// acknowledges a request only after it has routed it, so a cold-start request
/// cannot be lost between the two lifecycles.
@MainActor
final class AppIntentRouteInbox: ObservableObject {
    static let shared = AppIntentRouteInbox()

    @Published private(set) var requests: [AppIntentRouteRequest]

    var pendingRequest: AppIntentRouteRequest? {
        requests.first
    }

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let requestLifetime: TimeInterval
    private let now: () -> Date

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "app-intent-route-inbox-v1",
        requestLifetime: TimeInterval = 10 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.requestLifetime = max(30, requestLifetime)
        self.now = now
        requests = Self.loadRequests(
            from: userDefaults,
            storageKey: storageKey,
            createdAfter: now().addingTimeInterval(-max(30, requestLifetime))
        )
        if requests.isEmpty, userDefaults.data(forKey: storageKey) != nil {
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    func enqueue(
        _ route: AppIntentRoute,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        guard createdAt >= now().addingTimeInterval(-requestLifetime) else { return }
        // Every supported intent selects a destination. Only the newest pending
        // destination is actionable; replaying an older route first creates
        // navigation flashes and duplicate API loads after a cold start.
        replaceRequests([
            AppIntentRouteRequest(id: id, route: route, createdAt: createdAt)
        ])
    }

    func acknowledge(_ requestID: UUID) {
        guard requests.contains(where: { $0.id == requestID }) else { return }
        replaceRequests(requests.filter { $0.id != requestID })
    }

    /// Re-reads the durable queue when the app becomes active. This covers the
    /// process boundary used by future App Intent extensions as well as the
    /// current in-app execution path.
    func refreshFromDisk() {
        let storedRequests = Self.loadRequests(
            from: userDefaults,
            storageKey: storageKey,
            createdAfter: now().addingTimeInterval(-requestLifetime)
        )
        guard storedRequests != requests else { return }
        replaceRequests(storedRequests)
    }

    private func replaceRequests(_ requests: [AppIntentRouteRequest]) {
        self.requests = requests
        if requests.isEmpty {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(requests) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadRequests(
        from userDefaults: UserDefaults,
        storageKey: String,
        createdAfter expirationDate: Date
    ) -> [AppIntentRouteRequest] {
        guard let data = userDefaults.data(forKey: storageKey),
              let requests = try? JSONDecoder().decode([AppIntentRouteRequest].self, from: data)
        else {
            return []
        }
        return Array(
            requests
                .filter { $0.createdAt >= expirationDate }
                .suffix(1)
        )
    }
}

nonisolated enum AppIntentVideoIdentifier {
    static func normalizedBVID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = #"(?i)(?:^|[/\s])(BV[0-9A-Za-z]{8,})(?=$|[/?#\s])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let searchRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: searchRange),
              let bvidRange = Range(match.range(at: 1), in: trimmed)
        else {
            return nil
        }

        let rawBVID = String(trimmed[bvidRange])
        return "BV\(rawBVID.dropFirst(2))"
    }
}
