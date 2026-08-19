import XCTest
@testable import bili

final class DashStreamDispatcherTests: XCTestCase {
    func testAutoPrefersHEVCOverH264AndAV1() {
        let h264 = stream(codecs: "avc1.64002a", bandwidth: 8_000)
        let hevc = stream(codecs: "hev1.1.6.L120.90", bandwidth: 12_000)
        let av1 = stream(codecs: "av01.0.08M.08", bandwidth: 6_000)

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [h264, hevc, av1],
            preference: .auto
        )

        XCTAssertEqual(selected?.codecs, hevc.codecs)
    }

    func testAV1SelectionFollowsHardwareCapability() {
        let h264 = stream(codecs: "avc1.64002a")
        let av1 = stream(codecs: "av01.0.08M.08")

        let unsupportedSelection = CoreVideoPlayerManager.selectBestStream(
            from: [av1],
            preference: .preferAV1,
            supportsAV1HardwareDecode: false
        )
        XCTAssertNil(unsupportedSelection)

        let supportedSelection = CoreVideoPlayerManager.selectBestStream(
            from: [h264, av1],
            preference: .preferAV1,
            supportsAV1HardwareDecode: true
        )
        XCTAssertEqual(supportedSelection?.codecs, av1.codecs)
    }

    func testPreferAV1FallsBackToHEVCOnlyWhenAV1IsMissing() {
        let hevc = stream(codecs: "hev1.1.6.L120.90", bandwidth: 12_000)
        let h264 = stream(codecs: "avc1.64002a", bandwidth: 8_000)

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [h264, hevc],
            preference: .preferAV1,
            supportsAV1HardwareDecode: true
        )

        XCTAssertEqual(selected?.codecs, hevc.codecs)
    }

    func testForceHEVCRejectsOtherCodecs() {
        let h264 = stream(codecs: "avc1.64002a")
        let av1 = stream(codecs: "av01.0.08M.08")

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [av1, h264],
            preference: .forceHEVC
        )

        XCTAssertNil(selected)
    }

    func testDolbyVisionCodecIsTreatedAsHEVCFamily() {
        let h264 = stream(codecs: "avc1.64002a", bandwidth: 10_000)
        let dolby = stream(codecs: "dvh1.08.06", bandwidth: 8_000)

        XCTAssertEqual(dolby.videoCodecFamily, .hevc)
        XCTAssertTrue(dolby.isHEVCVideoCodec)
        XCTAssertTrue(dolby.isDolbyVisionVideoCodec)
        XCTAssertEqual(dolby.codecLabel, "Dolby Vision")
        XCTAssertEqual(
            CoreVideoPlayerManager.selectBestStream(from: [h264, dolby], preference: .forceHEVC)?.codecs,
            dolby.codecs
        )
    }

    func testAutoPrefersPlainHEVCOverDolbyVisionWithinSameQuality() {
        let hevc = stream(codecs: "hvc1.2.4.L150.B0", bandwidth: 14_000)
        let dolby = stream(codecs: "dvh1.08.06", bandwidth: 8_000)

        XCTAssertEqual(
            CoreVideoPlayerManager.selectBestStream(from: [hevc, dolby], preference: .auto)?.codecs,
            hevc.codecs
        )
    }

    func testForceH264RejectsOtherCodecs() {
        let hevc = stream(codecs: "hev1.1.6.L120.90")
        let av1 = stream(codecs: "av01.0.08M.08")

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [av1, hevc],
            preference: .forceH264
        )

        XCTAssertNil(selected)
    }

    func testSameCodecChoosesHigherBandwidth() {
        let lower = stream(codecs: "hev1.1.6.L120.90", bandwidth: 4_000)
        let higher = stream(codecs: "hev1.1.6.L120.90", bandwidth: 8_000)

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [lower, higher],
            preference: .auto
        )

        XCTAssertEqual(selected?.bandwidth, higher.bandwidth)
    }

    func testCustomOrderExcludesDisabledCodecAndUsesConfiguredPriority() {
        let h264 = stream(codecs: "avc1.64002a", bandwidth: 4_000)
        let hevc = stream(codecs: "hev1.1.6.L120.90", bandwidth: 12_000)
        let av1 = stream(codecs: "av01.0.08M.08", bandwidth: 8_000)
        let preference = VideoCodecPreference(codecOrder: [.h264, .av1])

        let selected = CoreVideoPlayerManager.selectBestStream(
            from: [hevc, av1, h264],
            preference: preference,
            supportsAV1HardwareDecode: true
        )

        XCTAssertEqual(selected?.codecs, h264.codecs)
    }

    private func stream(
        codecs: String,
        bandwidth: Int = 1_000
    ) -> DashStream {
        DashStream(
            id: 80,
            url: URL(string: "https://upos.example.test/\(UUID().uuidString).m4s")!,
            bandwidth: bandwidth,
            codecs: codecs,
            width: 1920,
            height: 1080,
            mimeType: "video/mp4"
        )
    }
}
