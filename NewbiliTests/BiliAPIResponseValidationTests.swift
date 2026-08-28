import Foundation
import XCTest
@testable import bili

final class BiliAPIResponseValidationTests: XCTestCase {
    func testValidatedHTTPDataReturnsSuccessfulBody() throws {
        let data = Data("ok".utf8)

        XCTAssertEqual(
            try BiliAPIClient.validatedHTTPData(data, response: response(statusCode: 200)),
            data
        )
    }

    func testValidatedHTTPDataRejectsEmptySuccessfulBody() throws {
        XCTAssertThrowsError(
            try BiliAPIClient.validatedHTTPData(Data(), response: response(statusCode: 204))
        ) { error in
            guard case BiliAPIError.emptyData = error else {
                return XCTFail("Expected emptyData, got \(error)")
            }
        }
    }

    func testValidatedHTTPDataPreservesFinalHTTPFailure() throws {
        XCTAssertThrowsError(
            try BiliAPIClient.validatedHTTPData(
                Data("busy".utf8),
                response: response(statusCode: 503)
            )
        ) { error in
            guard case BiliAPIError.api(let code, _) = error else {
                return XCTFail("Expected API error, got \(error)")
            }
            XCTAssertEqual(code, 503)
        }
    }

    func testValidatedHTTPDataRejectsNonHTTPResponse() throws {
        let url = URL(string: "https://api.bilibili.com/test")!
        let response = URLResponse(
            url: url,
            mimeType: "application/json",
            expectedContentLength: 2,
            textEncodingName: nil
        )

        XCTAssertThrowsError(try BiliAPIClient.validatedHTTPData(Data("{}".utf8), response: response)) {
            error in
            guard case BiliAPIError.emptyData = error else {
                return XCTFail("Expected emptyData, got \(error)")
            }
        }
    }

    private func response(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.bilibili.com/test")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }
}
