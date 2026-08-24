import Foundation

nonisolated enum SponsorBlockBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
    case alwaysSkip
    case skipOnce
    case skipManually
    case showOnly
    case disable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alwaysSkip: return "始终自动跳过"
        case .skipOnce: return "每次播放跳过一次"
        case .skipManually: return "手动决定"
        case .showOnly: return "仅提示"
        case .disable: return "不处理"
        }
    }

    var shortTitle: String {
        switch self {
        case .alwaysSkip: return "始终跳过"
        case .skipOnce: return "跳过一次"
        case .skipManually: return "手动"
        case .showOnly: return "仅提示"
        case .disable: return "关闭"
        }
    }
}

nonisolated enum SponsorBlockCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case sponsor
    case selfpromo
    case exclusiveAccess = "exclusive_access"
    case interaction
    case poiHighlight = "poi_highlight"
    case intro
    case outro
    case preview
    case padding
    case filler
    case musicOfftopic = "music_offtopic"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sponsor: return "赞助／恰饭"
        case .selfpromo: return "无偿／自我推广"
        case .exclusiveAccess: return "独家访问／抢先体验"
        case .interaction: return "三连／互动提醒"
        case .poiHighlight: return "精彩时刻／重点"
        case .intro: return "过场／开场动画"
        case .outro: return "鸣谢／结束画面"
        case .preview: return "回顾／概要"
        case .padding: return "填充内容／前黑／后黑"
        case .filler: return "离题闲聊／玩笑"
        case .musicOfftopic: return "音乐：非音乐部分"
        }
    }

    var shortTitle: String {
        switch self {
        case .sponsor: return "赞助"
        case .selfpromo: return "推广"
        case .exclusiveAccess: return "品牌合作"
        case .interaction: return "互动提醒"
        case .poiHighlight: return "精彩时刻"
        case .intro: return "开场"
        case .outro: return "片尾"
        case .preview: return "预览"
        case .padding: return "填充"
        case .filler: return "离题"
        case .musicOfftopic: return "非音乐"
        }
    }

    var systemImage: String {
        switch self {
        case .sponsor: return "megaphone"
        case .selfpromo: return "person.crop.circle.badge.plus"
        case .exclusiveAccess: return "lock.open"
        case .interaction: return "hand.tap"
        case .poiHighlight: return "sparkles"
        case .intro: return "play.square.stack"
        case .outro: return "flag.checkered"
        case .preview: return "eye"
        case .padding: return "rectangle.compress.vertical"
        case .filler: return "ellipsis.bubble"
        case .musicOfftopic: return "music.note.slash"
        }
    }
}

nonisolated struct SponsorBlockPreferences: Codable, Equatable, Sendable {
    var categoryBehaviors: [String: SponsorBlockBehavior]
    var minimumSegmentDuration: TimeInterval
    var showsSkipNotice: Bool
    var trackingEnabled: Bool
    var customServerURL: String

    init(
        categoryBehaviors: [String: SponsorBlockBehavior] = [:],
        minimumSegmentDuration: TimeInterval = 0,
        showsSkipNotice: Bool = true,
        trackingEnabled: Bool = true,
        customServerURL: String = ""
    ) {
        self.categoryBehaviors = categoryBehaviors
        self.minimumSegmentDuration = minimumSegmentDuration
        self.showsSkipNotice = showsSkipNotice
        self.trackingEnabled = trackingEnabled
        self.customServerURL = customServerURL
    }

    static let `default` = SponsorBlockPreferences()

    func behavior(for category: String, duration: TimeInterval? = nil) -> SponsorBlockBehavior {
        let threshold = min(max(minimumSegmentDuration, 0), 120)
        if let duration, duration < threshold {
            return .showOnly
        }
        return categoryBehaviors[category.lowercased()] ?? .skipOnce
    }

    var normalized: SponsorBlockPreferences {
        var result = self
        result.minimumSegmentDuration = min(max(minimumSegmentDuration, 0), 120)
        result.customServerURL = customServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    var serverURL: URL? {
        let value = normalized.customServerURL
        guard !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return url
    }
}

nonisolated struct SponsorBlockSegment: Identifiable, Codable, Equatable, Sendable {
    var id: String { uuid }

    let uuid: String
    let category: String
    let actionType: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let videoDuration: TimeInterval?
    let votes: Int?

    var isSkippable: Bool {
        actionType.lowercased() == "skip" && endTime > startTime
    }

    var title: String {
        SponsorBlockCategory(rawValue: category.lowercased())?.shortTitle ?? "空降片段"
    }

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}

nonisolated struct SponsorBlockSkipEvent: Equatable, Sendable {
    let segment: SponsorBlockSegment
    let fromTime: TimeInterval
    let skippedAt: Date
}

final class SponsorBlockService: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://www.bsbsb.top")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchSkipSegments(
        bvid: String,
        cid: Int,
        serverURL: URL? = nil
    ) async throws -> [SponsorBlockSegment] {
        guard var components = URLComponents(
            url: (serverURL ?? baseURL).appendingPathComponent("/api/skipSegments"),
            resolvingAgainstBaseURL: false
        ) else {
            throw BiliAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "videoID", value: bvid),
            URLQueryItem(name: "cid", value: String(cid))
        ]
        guard let url = components.url else { throw BiliAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        applyClientHeaders(to: &request)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return []
        }
        if httpResponse.statusCode == 404 {
            return []
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw BiliAPIError.api(code: httpResponse.statusCode, message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }

        return try Self.decodeSegments(from: data)
    }

    static func decodeSegments(from data: Data) throws -> [SponsorBlockSegment] {
        try JSONDecoder().decode([SponsorBlockSegmentResponse].self, from: data)
            .compactMap(SponsorBlockSegment.init(response:))
            .filter(\.isSkippable)
            .sorted { $0.startTime < $1.startTime }
    }

    func reportViewed(uuid: String, serverURL: URL? = nil) async {
        guard let components = URLComponents(
            url: (serverURL ?? baseURL).appendingPathComponent("/api/viewedVideoSponsorTime"),
            resolvingAgainstBaseURL: false
        ) else {
            return
        }
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        applyClientHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONEncoder().encode(["UUID": uuid])

        _ = try? await session.data(for: request)
    }

    private func applyClientHeaders(to request: inout URLRequest) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        request.setValue("Newbili", forHTTPHeaderField: "Origin")
        request.setValue(version ?? "1.0.1", forHTTPHeaderField: "X-Ext-Version")
    }
}

private nonisolated struct SponsorBlockSegmentResponse: Decodable {
    let cid: String?
    let category: String
    let actionType: String?
    let segment: [Double]
    let uuid: String
    let videoDuration: Double?
    let votes: Int?

    enum CodingKeys: String, CodingKey {
        case cid
        case category
        case actionType
        case segment
        case uuid = "UUID"
        case videoDuration
        case votes
    }
}

private extension SponsorBlockSegment {
    nonisolated init?(response: SponsorBlockSegmentResponse) {
        guard response.segment.count >= 2 else { return nil }
        let startTime = response.segment[0]
        let endTime = response.segment[1]
        guard startTime.isFinite, endTime.isFinite, startTime >= 0, endTime > startTime else { return nil }

        self.init(
            uuid: response.uuid,
            category: response.category,
            actionType: response.actionType ?? "skip",
            startTime: startTime,
            endTime: endTime,
            videoDuration: response.videoDuration,
            votes: response.votes
        )
    }
}
