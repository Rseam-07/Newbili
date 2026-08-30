import Foundation

nonisolated enum HomeRealtimeBlurSettings {
    static let storageKey = "cc.bili.home.realtimeAmbientBlurEnabled.v1"
    static let defaultIsEnabled = true
}

nonisolated enum HomePresentationStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case immersive
    case editorial
    case simple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immersive: "新版首页"
        case .editorial: "影像杂志"
        case .simple: "简约模式"
        }
    }

    var subtitle: String {
        switch self {
        case .immersive: "大幅精选内容、柔光背景与更鲜明的内容层级"
        case .editorial: "OLED 深色舞台、内容主导的影像编排与克制玻璃控件"
        case .simple: "保留原来的直接信息流，减少装饰与首屏占用"
        }
    }

    var systemImage: String {
        switch self {
        case .immersive: "sparkles.rectangle.stack"
        case .editorial: "newspaper.fill"
        case .simple: "rectangle.grid.1x2"
        }
    }

    var usesFeaturedStage: Bool {
        self != .simple
    }
}
