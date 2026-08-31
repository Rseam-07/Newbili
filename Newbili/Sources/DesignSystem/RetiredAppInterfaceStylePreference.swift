import Foundation

/// Removes the retired alternate-interface preference once. Keeping this
/// migration isolated prevents a saved pre-release value from silently
/// reactivating an interface branch that no longer exists.
nonisolated enum RetiredAppInterfaceStylePreference {
    static let storageKey = "cc.bili.display.liquidGlassStylePreference.v1"

    static func migrate(in userDefaults: UserDefaults = .standard) {
        guard userDefaults.object(forKey: storageKey) != nil else { return }
        userDefaults.removeObject(forKey: storageKey)
    }
}
