import Foundation

enum AppLiquidGlassStylePreference: String, CaseIterable, Identifiable {
    case current
    case fluent

    static let storageKey = "cc.bili.display.liquidGlassStylePreference.v1"
    static let defaultValue: AppLiquidGlassStylePreference = .current

    var id: String { rawValue }

    init(storedRawValue: String?) {
        self = Self(rawValue: storedRawValue ?? "") ?? Self.defaultValue
    }

    static func stored(in userDefaults: UserDefaults = .standard) -> Self {
        Self(storedRawValue: userDefaults.string(forKey: storageKey))
    }

    var isFluent: Bool {
        self == .fluent
    }

    var title: String {
        switch self {
        case .current:
            return "当前完整风格"
        case .fluent:
            return "Fluent UI"
        }
    }

    var detail: String {
        switch self {
        case .current:
            return "保留现有的液态玻璃、沉浸首页与播放器视觉。"
        case .fluent:
            return "使用 Fluent 的语义色、层级、亚克力表面与紧凑动效。"
        }
    }
}
