import Foundation

nonisolated enum HomePresentationStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case immersive
    case simple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immersive: "新版首页"
        case .simple: "简约模式"
        }
    }

    var subtitle: String {
        switch self {
        case .immersive: "大幅精选内容、柔光背景与更鲜明的内容层级"
        case .simple: "保留原来的直接信息流，减少装饰与首屏占用"
        }
    }

    var systemImage: String {
        switch self {
        case .immersive: "sparkles.rectangle.stack"
        case .simple: "rectangle.grid.1x2"
        }
    }
}
