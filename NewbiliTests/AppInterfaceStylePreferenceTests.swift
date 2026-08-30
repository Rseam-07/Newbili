import Foundation
import XCTest
@testable import bili

@MainActor
final class AppInterfaceStylePreferenceTests: XCTestCase {
    func testInterfaceStyleDefaultsToCurrent() throws {
        let defaults = try makeUserDefaults()

        XCTAssertEqual(AppLiquidGlassStylePreference.stored(in: defaults), .current)
        XCTAssertEqual(LibraryStore(userDefaults: defaults).liquidGlassStylePreference, .current)
    }

    func testFluentPreferencePersistsForNextLaunch() throws {
        let defaults = try makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        let activeStyleForCurrentLaunch = AppLiquidGlassStylePreference.stored(in: defaults)
        store.setLiquidGlassStylePreference(.fluent)

        XCTAssertEqual(activeStyleForCurrentLaunch, .current)
        XCTAssertEqual(store.liquidGlassStylePreference, .fluent)
        XCTAssertEqual(AppLiquidGlassStylePreference.stored(in: defaults), .fluent)
        XCTAssertEqual(LibraryStore(userDefaults: defaults).liquidGlassStylePreference, .fluent)
    }

    func testUnknownStoredStyleFallsBackSafely() throws {
        let defaults = try makeUserDefaults()
        defaults.set("retired-style", forKey: AppLiquidGlassStylePreference.storageKey)

        XCTAssertEqual(AppLiquidGlassStylePreference.stored(in: defaults), .current)
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "AppInterfaceStylePreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
