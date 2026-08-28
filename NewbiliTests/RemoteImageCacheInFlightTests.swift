import UIKit
import XCTest
@testable import bili

final class RemoteImageCacheInFlightTests: XCTestCase {
    func testConcurrentWaitersReuseOneTaskAndOnlyOwnerFinishes() async throws {
        let diagnosticsWereEnabled = RemoteImageDiagnosticsSettings.isRecordingEnabled
        RemoteImageDiagnosticsRuntime.shared.setEnabled(true)
        defer {
            RemoteImageDiagnosticsRuntime.shared.setEnabled(diagnosticsWereEnabled)
            DelayedRemoteImageURLProtocol.releaseResponses()
        }

        let imageData = try XCTUnwrap(makeImage().pngData())
        DelayedRemoteImageURLProtocol.configure(imageData: imageData)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedRemoteImageURLProtocol.self]
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let cache = RemoteImageCache(session: session)
        await cache.resetDiagnostics()
        let url = try XCTUnwrap(URL(string: "https://remote-image-cache.test/\(UUID().uuidString).png"))
        let loadCount = 12

        let (successfulLoadCount, statisticsBeforeResponse) = await withTaskGroup(
            of: Bool.self,
            returning: (Int, RemoteImageCacheStatistics).self
        ) { group in
            for _ in 0..<loadCount {
                group.addTask {
                    await cache.load(
                        url: url,
                        scale: 1,
                        cachePolicy: .standard,
                        priority: .visible
                    ) != nil
                }
            }

            var statistics = await cache.statistics()
            for _ in 0..<200 where statistics.inFlightReuseCount < loadCount - 1 {
                try? await Task.sleep(nanoseconds: 5_000_000)
                statistics = await cache.statistics()
            }
            DelayedRemoteImageURLProtocol.releaseResponses()

            var successfulLoads = 0
            for await succeeded in group where succeeded {
                successfulLoads += 1
            }
            return (successfulLoads, statistics)
        }

        let finalStatistics = await cache.statistics()
        XCTAssertEqual(statisticsBeforeResponse.inFlightCount, 1)
        XCTAssertEqual(statisticsBeforeResponse.loadTaskCount, 1)
        XCTAssertEqual(statisticsBeforeResponse.inFlightReuseCount, loadCount - 1)
        XCTAssertEqual(successfulLoadCount, loadCount)
        XCTAssertEqual(DelayedRemoteImageURLProtocol.requestCount, 1)
        XCTAssertEqual(finalStatistics.loadTaskCount, 1)
        XCTAssertEqual(finalStatistics.stores, 1)
        XCTAssertEqual(finalStatistics.memoryEntryCount, 1)
        XCTAssertEqual(finalStatistics.inFlightCount, 0)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }
}

private nonisolated final class DelayedRemoteImageURLProtocol: URLProtocol, @unchecked Sendable {
    private static let state = DelayedRemoteImageURLProtocolState()

    static var requestCount: Int {
        state.requestCount
    }

    static func configure(imageData: Data) {
        state.configure(imageData: imageData)
    }

    static func releaseResponses() {
        state.releaseResponses()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "remote-image-cache.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = Self.state.beginRequest()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            response.gate.wait()
            guard let self else { return }
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "image/png",
                    "Content-Length": "\(response.imageData.count)"
                ]
            )!
            self.client?.urlProtocol(
                self,
                didReceive: httpResponse,
                cacheStoragePolicy: .notAllowed
            )
            self.client?.urlProtocol(self, didLoad: response.imageData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private nonisolated final class DelayedRemoteImageURLProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var imageData = Data()
    private var responseGate = DispatchSemaphore(value: 0)
    private var recordedRequestCount = 0

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequestCount
    }

    func configure(imageData: Data) {
        lock.lock()
        self.imageData = imageData
        responseGate = DispatchSemaphore(value: 0)
        recordedRequestCount = 0
        lock.unlock()
    }

    func beginRequest() -> (imageData: Data, gate: DispatchSemaphore) {
        lock.lock()
        defer { lock.unlock() }
        recordedRequestCount += 1
        return (imageData, responseGate)
    }

    func releaseResponses() {
        lock.lock()
        let gate = responseGate
        lock.unlock()
        for _ in 0..<32 {
            gate.signal()
        }
    }
}
