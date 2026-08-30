import Foundation

nonisolated struct DanmakuFilterRules: Equatable, Sendable {
    let showsScrollingDanmaku: Bool
    let showsTopDanmaku: Bool
    let showsBottomDanmaku: Bool
    let blockedKeywords: [String]
    let blockedRegularExpressions: [String]
    let blockedUserIDs: [String]

    var isInactive: Bool {
        showsScrollingDanmaku
            && showsTopDanmaku
            && showsBottomDanmaku
            && blockedKeywords.isEmpty
            && blockedRegularExpressions.isEmpty
            && blockedUserIDs.isEmpty
    }
}

/// Compiles the user rules once when settings change. Rendering then performs only
/// set lookups, substring checks and precompiled-regex matches when an item batch changes.
nonisolated final class DanmakuItemFilter {
    private let rules: DanmakuFilterRules
    private let blockedSenderIdentifiers: Set<String>
    private let regularExpressions: [NSRegularExpression]

    init(rules: DanmakuFilterRules) {
        self.rules = rules

        var senderIdentifiers = Set<String>()
        senderIdentifiers.reserveCapacity(rules.blockedUserIDs.count * 2)
        for userID in rules.blockedUserIDs {
            let normalizedID = userID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedID.isEmpty else { continue }
            senderIdentifiers.insert(normalizedID)
            senderIdentifiers.insert(Self.crc32MIDHash(for: normalizedID))
        }
        blockedSenderIdentifiers = senderIdentifiers

        regularExpressions = rules.blockedRegularExpressions.compactMap { pattern in
            try? NSRegularExpression(
                pattern: Self.normalizedRegularExpression(pattern),
                options: [.caseInsensitive]
            )
        }
    }

    func allows(_ item: DanmakuItem) -> Bool {
        guard typeIsVisible(item) else { return false }

        if let senderIdentifier = item.senderIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           blockedSenderIdentifiers.contains(senderIdentifier) {
            return false
        }

        if rules.blockedKeywords.contains(where: item.text.contains) {
            return false
        }

        guard !regularExpressions.isEmpty else { return true }
        let range = NSRange(item.text.startIndex..<item.text.endIndex, in: item.text)
        return !regularExpressions.contains { expression in
            expression.firstMatch(in: item.text, options: [], range: range) != nil
        }
    }

    func filtered(_ items: [DanmakuItem]) -> [DanmakuItem] {
        guard !rules.isInactive else { return items }
        return items.filter(allows)
    }

    static func isValidRegularExpression(_ pattern: String) -> Bool {
        let normalized = normalizedRegularExpression(pattern)
        guard !normalized.isEmpty else { return false }
        return (try? NSRegularExpression(pattern: normalized)) != nil
    }

    static func crc32MIDHash(for userID: String) -> String {
        var crc = UInt32.max
        for byte in userID.utf8 {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let leastSignificantBit = crc & 1
                crc = (crc >> 1) ^ (leastSignificantBit == 1 ? 0xEDB8_8320 : 0)
            }
        }
        return String(crc ^ UInt32.max, radix: 16)
    }

    private func typeIsVisible(_ item: DanmakuItem) -> Bool {
        if item.isScrolling { return rules.showsScrollingDanmaku }
        if item.isTopAnchored { return rules.showsTopDanmaku }
        if item.isBottomAnchored { return rules.showsBottomDanmaku }
        return false
    }

    private static func normalizedRegularExpression(_ pattern: String) -> String {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.first == "/", trimmed.last == "/" else {
            return trimmed
        }
        return String(trimmed.dropFirst().dropLast())
    }
}
