import CryptoKit
import Foundation

nonisolated struct VideoTranscriptRequest: Hashable, Sendable {
    let bvid: String
    let cid: Int

    init?(bvid: String, cid: Int?) {
        let normalizedBVID = bvid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cid,
              cid > 0,
              normalizedBVID.hasPrefix("BV"),
              normalizedBVID.count <= 24,
              normalizedBVID.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        else { return nil }
        self.bvid = normalizedBVID
        self.cid = cid
    }

    func cacheKey(cookieHeader: String) -> VideoTranscriptCacheKey {
        VideoTranscriptCacheKey(
            bvid: bvid,
            cid: cid,
            authenticationIdentity: VideoTranscriptAuthenticationIdentity(
                cookieHeader: cookieHeader
            )
        )
    }
}

nonisolated struct VideoTranscriptCacheKey: Hashable, Sendable {
    let bvid: String
    let cid: Int
    let authenticationIdentity: VideoTranscriptAuthenticationIdentity
}

nonisolated enum VideoTranscriptAuthenticationIdentity: Hashable, Sendable {
    case anonymous
    case authenticated(sha256: String)

    private static let canonicalAuthenticationCookieNames = [
        "sessdata": "SESSDATA",
        "dedeuserid": "DedeUserID",
        "bili_jct": "bili_jct"
    ]

    init(cookieHeader: String) {
        let authenticationCookies = cookieHeader
            .split(separator: ";", omittingEmptySubsequences: true)
            .compactMap(Self.authenticationCookie(from:))
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.value < $1.value
            }

        guard !authenticationCookies.isEmpty else {
            self = .anonymous
            return
        }

        var canonicalData = Data()
        for cookie in authenticationCookies {
            Self.appendLengthPrefixed(cookie.name, to: &canonicalData)
            Self.appendLengthPrefixed(cookie.value, to: &canonicalData)
        }
        let digest = SHA256.hash(data: canonicalData)
            .map { String(format: "%02x", $0) }
            .joined()
        self = .authenticated(sha256: digest)
    }

    private static func authenticationCookie(
        from segment: Substring
    ) -> (name: String, value: String)? {
        guard let separatorIndex = segment.firstIndex(of: "=") else { return nil }
        let rawName = segment[..<separatorIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let canonicalName = canonicalAuthenticationCookieNames[rawName.lowercased()] else {
            return nil
        }
        let valueStart = segment.index(after: separatorIndex)
        let value = segment[valueStart...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return (canonicalName, value)
    }

    private static func appendLengthPrefixed(_ value: String, to data: inout Data) {
        let valueData = Data(value.utf8)
        var length = UInt64(valueData.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(valueData)
    }
}

nonisolated struct VideoTranscript: Equatable, Sendable {
    let language: String
    let languageCode: String
    let isAIGenerated: Bool
    let summaryText: String
}

nonisolated struct VideoSubtitleTrack: Decodable, Equatable, Sendable {
    let id: String
    let languageCode: String
    let language: String
    let urlString: String
    let isAIGenerated: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case idString = "id_str"
        case languageCode = "lan"
        case language = "lan_doc"
        case urlString = "subtitle_url"
        case type
        case aiType = "ai_type"
    }

    init(
        id: String,
        languageCode: String,
        language: String,
        urlString: String,
        isAIGenerated: Bool
    ) {
        self.id = id
        self.languageCode = languageCode
        self.language = language
        self.urlString = urlString
        self.isAIGenerated = isAIGenerated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .idString))
            ?? (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(Int.self, forKey: .id)).map(String.init)
            ?? ""
        languageCode = (try? container.decode(String.self, forKey: .languageCode)) ?? ""
        language = (try? container.decode(String.self, forKey: .language)) ?? languageCode
        urlString = (try? container.decode(String.self, forKey: .urlString)) ?? ""
        let type = try? container.decode(Int.self, forKey: .type)
        let aiType = try? container.decode(Int.self, forKey: .aiType)
        isAIGenerated = type == 1 || aiType == 1 || languageCode.lowercased().hasPrefix("ai")
    }

    var selectionPriority: Int {
        let normalizedLanguage = languageCode.lowercased()
        let isChinese = normalizedLanguage.contains("zh")
            || normalizedLanguage.contains("cn")
            || language.contains("中")
        switch (isChinese, isAIGenerated) {
        case (true, false): return 0
        case (true, true): return 1
        case (false, false): return 2
        case (false, true): return 3
        }
    }
}

nonisolated struct VideoSubtitleCue: Decodable, Equatable, Sendable {
    let start: Double
    let end: Double
    let content: String

    private enum CodingKeys: String, CodingKey {
        case start = "from"
        case end = "to"
        case content
    }
}

private nonisolated struct VideoPlayerSubtitlePayload: Decodable {
    let subtitle: VideoPlayerSubtitleContainer?
}

private nonisolated struct VideoPlayerSubtitleContainer: Decodable {
    let subtitles: [VideoSubtitleTrack]?
}

private nonisolated struct VideoSubtitleDocument: Decodable {
    let body: [VideoSubtitleCue]?
}

nonisolated enum VideoTranscriptServiceError: Error, Sendable {
    case invalidResponse
    case responseTooLarge
    case api(code: Int)
}

actor VideoTranscriptService {
    static let shared = VideoTranscriptService()

    private struct CacheEntry {
        let transcript: VideoTranscript?
        let storedAt: Date
    }

    private static let maximumCacheEntries = 24
    private static let cacheTTL: TimeInterval = 10 * 60
    private static let maximumResponseBytes = 2 * 1_024 * 1_024
    private let session: URLSession
    private var cache = [VideoTranscriptCacheKey: CacheEntry]()
    private var cacheOrder = [VideoTranscriptCacheKey]()
    private var tasksInFlight = [VideoTranscriptCacheKey: Task<VideoTranscript?, Error>]()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcript(
        for request: VideoTranscriptRequest,
        cookieHeader: String
    ) async throws -> VideoTranscript? {
        let cacheKey = request.cacheKey(cookieHeader: cookieHeader)
        if let entry = cache[cacheKey],
           Date().timeIntervalSince(entry.storedAt) < Self.cacheTTL {
            touch(cacheKey)
            return entry.transcript
        }
        cache[cacheKey] = nil

        if let task = tasksInFlight[cacheKey] {
            return try await task.value
        }

        let session = session
        let task = Task<VideoTranscript?, Error> {
            try await Self.fetchTranscript(
                request: request,
                cookieHeader: cookieHeader,
                session: session
            )
        }
        tasksInFlight[cacheKey] = task

        do {
            let transcript = try await task.value
            tasksInFlight[cacheKey] = nil
            insert(transcript, for: cacheKey)
            return transcript
        } catch {
            tasksInFlight[cacheKey] = nil
            throw error
        }
    }

    nonisolated static func preferredTrack(
        from tracks: [VideoSubtitleTrack]
    ) -> VideoSubtitleTrack? {
        tracks
            .filter { !$0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .min { lhs, rhs in
                if lhs.element.selectionPriority != rhs.element.selectionPriority {
                    return lhs.element.selectionPriority < rhs.element.selectionPriority
                }
                return lhs.offset < rhs.offset
            }?
            .element
    }

    nonisolated static func subtitleTracks(from playerData: Data) throws -> [VideoSubtitleTrack] {
        let response = try JSONDecoder().decode(
            BiliResponse<VideoPlayerSubtitlePayload>.self,
            from: playerData
        )
        guard response.code == 0 else {
            throw VideoTranscriptServiceError.api(code: response.code)
        }
        return response.payload?.subtitle?.subtitles ?? []
    }

    nonisolated static func transcript(
        from data: Data,
        track: VideoSubtitleTrack
    ) throws -> VideoTranscript? {
        let document = try JSONDecoder().decode(VideoSubtitleDocument.self, from: data)
        let cues = (document.body ?? []).filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let summaryText = sampledTranscriptText(
            from: cues,
            limit: VideoIntelligenceSummaryInput.maximumTranscriptLength
        )
        guard !summaryText.isEmpty else { return nil }
        return VideoTranscript(
            language: track.language,
            languageCode: track.languageCode,
            isAIGenerated: track.isAIGenerated,
            summaryText: summaryText
        )
    }

    nonisolated static func sampledTranscriptText(
        from cues: [VideoSubtitleCue],
        limit: Int
    ) -> String {
        guard limit > 0 else { return "" }
        var rendered = [String]()
        rendered.reserveCapacity(cues.count)
        var previousContent: String?

        for cue in cues {
            let content = cue.content
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty, content != previousContent else { continue }
            previousContent = content
            rendered.append("[\(timestamp(cue.start))] \(String(content.prefix(500)))")
        }

        let complete = rendered.joined(separator: "\n")
        guard complete.count > limit else { return complete }

        let bucketCount = min(12, rendered.count)
        let budgetPerBucket = max(80, limit / max(1, bucketCount))
        var samples = [String]()
        samples.reserveCapacity(bucketCount)

        for bucket in 0..<bucketCount {
            let lowerBound = bucket * rendered.count / bucketCount
            let upperBound = max(lowerBound + 1, (bucket + 1) * rendered.count / bucketCount)
            var sample = ""
            for line in rendered[lowerBound..<min(upperBound, rendered.count)] {
                let separator = sample.isEmpty ? "" : "\n"
                let remaining = budgetPerBucket - sample.count - separator.count
                guard remaining > 0 else { break }
                sample += separator + String(line.prefix(remaining))
            }
            if !sample.isEmpty {
                samples.append(sample)
            }
        }

        return String(samples.joined(separator: "\n…\n").prefix(limit))
    }

    private nonisolated static func fetchTranscript(
        request: VideoTranscriptRequest,
        cookieHeader: String,
        session: URLSession
    ) async throws -> VideoTranscript? {
        try Task.checkCancellation()
        guard var components = URLComponents(
            string: "https://api.bilibili.com/x/player/wbi/v2"
        ) else {
            throw VideoTranscriptServiceError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "bvid", value: request.bvid),
            URLQueryItem(name: "cid", value: String(request.cid))
        ]
        guard let playerURL = components.url else {
            throw VideoTranscriptServiceError.invalidResponse
        }

        var playerRequest = URLRequest(url: playerURL)
        configure(
            &playerRequest,
            referer: "https://www.bilibili.com/video/\(request.bvid)",
            cookieHeader: cookieHeader
        )
        let playerData = try await responseData(for: playerRequest, session: session)
        let tracks = try subtitleTracks(from: playerData)
        guard let track = preferredTrack(from: tracks),
              let subtitleURL = trustedSubtitleURL(from: track.urlString)
        else { return nil }

        let cacheKey = SubtitleCueCacheKey(
            bvid: request.bvid,
            cid: request.cid,
            subtitleId: track.id,
            language: track.languageCode,
            urlHash: sha256(subtitleURL.absoluteString)
        )
        let subtitleData: Data
        if let cached = await SubtitleDanmakuResourceCache.shared.subtitleData(for: cacheKey) {
            subtitleData = cached
        } else {
            var subtitleRequest = URLRequest(url: subtitleURL)
            configure(
                &subtitleRequest,
                referer: "https://www.bilibili.com/video/\(request.bvid)",
                cookieHeader: ""
            )
            subtitleData = try await responseData(for: subtitleRequest, session: session)
            await SubtitleDanmakuResourceCache.shared.storeSubtitleData(subtitleData, for: cacheKey)
        }
        try Task.checkCancellation()
        return try transcript(from: subtitleData, track: track)
    }

    private nonisolated static func configure(
        _ request: inout URLRequest,
        referer: String,
        cookieHeader: String
    ) {
        request.timeoutInterval = 10
        request.cachePolicy = .useProtocolCachePolicy
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
    }

    private nonisolated static func responseData(
        for request: URLRequest,
        session: URLSession
    ) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode)
        else {
            throw VideoTranscriptServiceError.invalidResponse
        }
        guard data.count <= maximumResponseBytes else {
            throw VideoTranscriptServiceError.responseTooLarge
        }
        return data
    }

    nonisolated static func trustedSubtitleURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let absolute = trimmed.hasPrefix("//") ? "https:\(trimmed)" : trimmed
        guard var components = URLComponents(string: absolute),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              let host = components.host?.lowercased(),
              host == "hdslb.com" || host.hasSuffix(".hdslb.com")
        else { return nil }
        components.scheme = "https"
        components.fragment = nil
        return components.url
    }

    private nonisolated static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private nonisolated static func timestamp(_ seconds: Double) -> String {
        let safeSeconds = max(0, Int(seconds.isFinite ? seconds : 0))
        let hours = safeSeconds / 3_600
        let minutes = safeSeconds % 3_600 / 60
        let remainder = safeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private func touch(_ key: VideoTranscriptCacheKey) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func insert(_ transcript: VideoTranscript?, for key: VideoTranscriptCacheKey) {
        cache[key] = CacheEntry(transcript: transcript, storedAt: Date())
        touch(key)
        while cacheOrder.count > Self.maximumCacheEntries {
            let evicted = cacheOrder.removeFirst()
            cache[evicted] = nil
        }
    }
}
