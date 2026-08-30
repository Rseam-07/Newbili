import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated enum AppleIntelligenceAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case notEnabled
    case modelNotReady
    case frameworkUnavailable

    var isAvailable: Bool {
        self == .available
    }

    var title: String {
        switch self {
        case .available:
            return "Apple 智能可用"
        case .deviceNotEligible:
            return "此设备不支持 Apple 智能"
        case .notEnabled:
            return "Apple 智能尚未开启"
        case .modelNotReady:
            return "Apple 智能模型尚未就绪"
        case .frameworkUnavailable:
            return "当前系统不提供 Apple 智能模型"
        }
    }
}

nonisolated enum AppleIntelligenceAvailabilityService {
    static func current() -> AppleIntelligenceAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .notEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(_):
            return .frameworkUnavailable
        }
        #else
        return .frameworkUnavailable
        #endif
    }
}
