import XCTest
@testable import bili

@MainActor
final class PlaybackControlsPreferenceTests: XCTestCase {
    func testCustomPlaybackControlsAreTheDefaultAndPreferencePersists() throws {
        let suiteName = "PlaybackControlsPreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialStore = LibraryStore(userDefaults: defaults)
        XCTAssertFalse(initialStore.usesNativePlaybackControls)

        initialStore.setUsesNativePlaybackControls(true)
        XCTAssertTrue(initialStore.usesNativePlaybackControls)
        XCTAssertTrue(LibraryStore(userDefaults: defaults).usesNativePlaybackControls)

        initialStore.setUsesNativePlaybackControls(false)
        XCTAssertFalse(LibraryStore(userDefaults: defaults).usesNativePlaybackControls)
    }
}
