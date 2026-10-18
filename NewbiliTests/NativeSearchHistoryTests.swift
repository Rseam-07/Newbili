import XCTest
@testable import bili

@MainActor
final class NativeSearchHistoryTests: XCTestCase {
    func testHistoryNormalizesDeduplicatesAndSurvivesRestart() throws {
        let name = "NativeSearchHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryStore(userDefaults: defaults)
        store.recordSearchKeyword(" Swift ")
        store.recordSearchKeyword("动画")
        store.recordSearchKeyword("swift")
        store.recordSearchKeyword(" \n ")
        XCTAssertEqual(store.searchHistory, ["swift", "动画"])
        XCTAssertEqual(LibraryStore(userDefaults: defaults).searchHistory, store.searchHistory)
        store.removeSearchKeyword("swift")
        XCTAssertEqual(LibraryStore(userDefaults: defaults).searchHistory, ["动画"])
        store.clearSearchHistory()
        XCTAssertTrue(LibraryStore(userDefaults: defaults).searchHistory.isEmpty)
    }

    func testIncognitoAndRecordingPreferencePreventHistoryWrites() throws {
        let name = "NativeSearchHistoryTests.Privacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryStore(userDefaults: defaults)
        store.setIncognitoModeEnabled(true)
        store.recordSearchKeyword("private")
        store.setIncognitoModeEnabled(false)
        store.setRecordsSearchHistory(false)
        store.recordSearchKeyword("disabled")
        XCTAssertTrue(store.searchHistory.isEmpty)
        XCTAssertTrue(LibraryStore(userDefaults: defaults).searchHistory.isEmpty)
        store.setShowsSearchSuggestions(false)
        XCTAssertFalse(LibraryStore(userDefaults: defaults).showsSearchSuggestions)
        XCTAssertFalse(LibraryStore(userDefaults: defaults).recordsSearchHistory)
    }

    func testHistoryIsBoundedAndRejectsOversizedKeywords() throws {
        let name = "NativeSearchHistoryTests.Bound.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryStore(userDefaults: defaults)
        for i in 0..<40 { store.recordSearchKeyword("query-\(i)") }
        store.recordSearchKeyword(String(repeating: "字", count: 201))
        XCTAssertEqual(store.searchHistory.count, 30)
        XCTAssertEqual(store.searchHistory.first, "query-39")
        XCTAssertEqual(store.searchHistory.last, "query-10")
    }
}
