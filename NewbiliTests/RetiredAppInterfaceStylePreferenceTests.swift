import Foundation
import XCTest
@testable import bili

@MainActor
final class RetiredAppInterfaceStylePreferenceTests: XCTestCase {
    func testRetiredFluentPreferenceIsRemovedWhenStoreStarts() throws {
        let defaults = try makeUserDefaults()
        defaults.set("fluent", forKey: RetiredAppInterfaceStylePreference.storageKey)

        _ = LibraryStore(userDefaults: defaults)

        XCTAssertNil(defaults.object(forKey: RetiredAppInterfaceStylePreference.storageKey))
    }

    func testMigrationLeavesUnrelatedDisplayPreferencesUntouched() throws {
        let defaults = try makeUserDefaults()
        defaults.set("fluent", forKey: RetiredAppInterfaceStylePreference.storageKey)
        defaults.set(true, forKey: "cc.bili.display.minimizesTabBarOnScroll.v1")

        RetiredAppInterfaceStylePreference.migrate(in: defaults)

        XCTAssertNil(defaults.object(forKey: RetiredAppInterfaceStylePreference.storageKey))
        XCTAssertEqual(defaults.object(forKey: "cc.bili.display.minimizesTabBarOnScroll.v1") as? Bool, true)
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "RetiredAppInterfaceStylePreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
