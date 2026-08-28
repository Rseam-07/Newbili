import Foundation

enum HLSRemoteRangeResponseValidator {
    nonisolated static func validate(
        _ response: URLResponse,
        requestedRange: HTTPByteRange,
        url: URL? = nil
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HLSBridgeRemoteFailure.httpStatus(httpResponse.statusCode, url: url, range: requestedRange)
        }
        switch httpResponse.statusCode {
        case 200:
            guard requestedRange.start == 0,
                  contentLength(from: httpResponse) == requestedRange.length
            else {
                throw HLSBridgeRemoteFailure.invalidRangeResponse(
                    statusCode: httpResponse.statusCode,
                    url: url,
                    range: requestedRange
                )
            }
        case 206:
            guard contentRange(from: httpResponse) == requestedRange,
                  contentLength(from: httpResponse).map({ $0 == requestedRange.length }) ?? true
            else {
                throw HLSBridgeRemoteFailure.invalidRangeResponse(
                    statusCode: httpResponse.statusCode,
                    url: url,
                    range: requestedRange
                )
            }
        default:
            throw HLSBridgeRemoteFailure.invalidRangeResponse(statusCode: httpResponse.statusCode, url: url, range: requestedRange)
        }
    }

    private nonisolated static func contentLength(from response: HTTPURLResponse) -> Int64? {
        guard let value = response.value(forHTTPHeaderField: "Content-Length")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let length = Int64(value),
              length >= 0
        else { return nil }
        return length
    }

    private nonisolated static func contentRange(from response: HTTPURLResponse) -> HTTPByteRange? {
        guard let value = response.value(forHTTPHeaderField: "Content-Range")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              value.hasPrefix("bytes ")
        else { return nil }
        let payload = value.dropFirst("bytes ".count)
        let parts = payload.split(separator: "/", maxSplits: 1).map(String.init)
        return HTTPByteRange(rawValue: parts.first)
    }
}
