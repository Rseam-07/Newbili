import XCTest
@testable import bili

final class CellularBiliTrafficCompatibilityTests: XCTestCase {
    func testClassifiesOnlyApprovedBiliDomainSuffixes() {
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.classify(host: "upos-sz-mirrorcos.bilivideo.com"),
            .bili
        )
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.classify(host: "xy1.mcdn.bilivideo.cn"),
            .bili
        )
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.classify(host: "bilivideo.com.example.test"),
            .external
        )
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.classify(host: "upos-hz-mirrorakam.akamaized.net"),
            .external
        )
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.classify(host: nil),
            .unknown
        )
    }

    func testPrioritizesBiliDomainsOnlyWhenExperimentIsActiveOnCellular() {
        let external = URL(string: "https://upos-hz-mirrorakam.akamaized.net/video.m4s")!
        let bilivideo = URL(string: "https://upos-sz-mirrorcos.bilivideo.com/video.m4s")!
        let bilivideoCN = URL(string: "https://xy1.mcdn.bilivideo.cn/audio.m4s")!
        let urls = [external, bilivideo, bilivideoCN]

        let prioritized = CellularBiliTrafficCompatibilityExperiment.prioritizedURLs(
            urls,
            isEnabled: true,
            isCellularNetwork: true
        )

        XCTAssertEqual(prioritized, [bilivideo, bilivideoCN, external])
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.prioritizedURLs(
                urls,
                isEnabled: false,
                isCellularNetwork: true
            ),
            urls
        )
        XCTAssertEqual(
            CellularBiliTrafficCompatibilityExperiment.prioritizedURLs(
                urls,
                isEnabled: true,
                isCellularNetwork: false
            ),
            urls
        )
    }

    @MainActor
    func testLibraryStorePersistsCellularBiliTrafficCompatibilityExperiment() {
        let defaults = makeUserDefaults()
        let store = LibraryStore(userDefaults: defaults)

        XCTAssertFalse(store.cellularBiliTrafficCompatibilityExperimentEnabled)
        store.setCellularBiliTrafficCompatibilityExperimentEnabled(true)

        XCTAssertTrue(
            LibraryStore(userDefaults: defaults).cellularBiliTrafficCompatibilityExperimentEnabled
        )
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "cc.bili.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
