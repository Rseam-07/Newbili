import Foundation

/// Stable, precomputed values for the Mine account header. Profile fallback,
/// level boundaries and experience formatting stay outside SwiftUI layout code.
nonisolated struct MineAccountProfileDisplayModel: Equatable, Sendable {
    let avatarURLString: String?
    let username: String
    let uidText: String
    let level: Int?
    let experienceText: String?
    let experienceProgress: Double?

    init(user: NavUserInfo?, fallbackAccount: BiliAccountSummary?) {
        avatarURLString = Self.nonEmpty(user?.face) ?? Self.nonEmpty(fallbackAccount?.face)
        username = Self.nonEmpty(user?.uname)
            ?? Self.nonEmpty(fallbackAccount?.name)
            ?? fallbackAccount.map { "UID \($0.mid)" }
            ?? "已登录"

        let mid = user?.mid.flatMap { $0 > 0 ? $0 : nil } ?? fallbackAccount?.mid
        uidText = mid.map { "UID \($0)" } ?? "UID --"

        let levelInfo = user?.levelInfo ?? fallbackAccount?.levelInfo
        if let currentLevel = levelInfo?.currentLevel, (0...6).contains(currentLevel) {
            level = currentLevel
        } else {
            level = nil
        }

        if let currentExperience = levelInfo?.currentExperience {
            if let nextExperience = levelInfo?.effectiveNextLevelExperience {
                experienceText = "经验 \(currentExperience)/\(nextExperience)"
            } else {
                experienceText = "经验 \(currentExperience)"
            }
        } else {
            experienceText = nil
        }
        experienceProgress = levelInfo?.progress
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
