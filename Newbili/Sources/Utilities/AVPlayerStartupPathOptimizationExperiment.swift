import Foundation

nonisolated enum AVPlayerStartupPathOptimizationExperiment {
    static let storageKey = "cc.bili.playback.avPlayerStartupPathOptimizationExperimentEnabled.v1"
    static let defaultIsEnabled = true
    static let startupPacketGateMaximumWait: TimeInterval = 0.04

    static func stored(in _: UserDefaults = .standard) -> Bool {
        true
    }

    static func playerCreationWarmupWait(
        normalBudget: TimeInterval,
        userDefaults: UserDefaults = .standard
    ) -> TimeInterval {
        guard stored(in: userDefaults) else { return normalBudget }
        return min(max(normalBudget, 0), startupPacketGateMaximumWait)
    }

    static func diagnosticStateTitle(for isEnabled: Bool?) -> String {
        guard let isEnabled else { return "unknown" }
        return isEnabled ? "on" : "off"
    }

    static func sampleGroupStateTitle(for isEnabled: Bool?) -> String {
        guard let isEnabled else { return "启动链路：旧样本未知" }
        return isEnabled ? "启动链路：已启用" : "启动链路：未启用"
    }
}

nonisolated enum PiliPlusStylePlayURLSelectionExperiment {
    static let storageKey = "cc.bili.playback.piliPlusStylePlayURLSelectionExperimentEnabled.v1"
    static let defaultIsEnabled = true
    static let currentStrategyKey = "piliPlusTargetFirstCompatibilityRescueV18"
    static let webpageHedgeDelayNanoseconds: UInt64 = 0

    static func stored(in _: UserDefaults = .standard) -> Bool {
        true
    }

    static func diagnosticStateTitle(for isEnabled: Bool?) -> String {
        guard let isEnabled else { return "unknown" }
        return isEnabled ? "on" : "off"
    }

    static func sampleGroupStateTitle(for isEnabled: Bool?) -> String {
        guard let isEnabled else { return "PiliPlus AV1 取流：旧样本未知" }
        return isEnabled ? "PiliPlus AV1 取流：已启用" : "PiliPlus AV1 取流：未启用"
    }

    static func sampleGroupStrategy(
        startupSchedulerMessage: String?,
        isEnabled: Bool?
    ) -> (key: String, title: String) {
        guard isEnabled == true else {
            return isEnabled == false
                ? ("disabled", "取流策略：非 PiliPlus")
                : ("unknown", "取流策略：旧样本未知")
        }
        let message = startupSchedulerMessage ?? ""
        if message.contains("strategy=\(currentStrategyKey)") {
            return (currentStrategyKey, "取流策略：V18")
        }
        if message.contains("strategy=piliPlusConditionalWBIRescueV17") {
            return ("piliPlusConditionalWBIRescueV17", "取流策略：V17")
        }
        if message.contains("strategy=piliPlusPromptWinnerCancellationV16") {
            return ("piliPlusPromptWinnerCancellationV16", "取流策略：V16")
        }
        if message.contains("strategy=piliPlusBaseQualitySelectionV15") {
            return ("piliPlusBaseQualitySelectionV15", "取流策略：V15")
        }
        if message.contains("strategy=piliPlusWBIKeyRefreshRecoveryV14") {
            return ("piliPlusWBIKeyRefreshRecoveryV14", "取流策略：V14")
        }
        if message.contains("strategy=piliPlusWBIResponseDiagnosticsV13") {
            return ("piliPlusWBIResponseDiagnosticsV13", "取流策略：V13")
        }
        if message.contains("strategy=piliPlusImmediateStreamingWebpageHedgeV12") {
            return ("piliPlusImmediateStreamingWebpageHedgeV12", "取流策略：V12")
        }
        if message.contains("strategy=piliPlusStreamingWebpagePlayInfoV11") {
            return ("piliPlusStreamingWebpagePlayInfoV11", "取流策略：V11")
        }
        if message.contains("strategy=piliPlusScopedWBIHealthV10") {
            return ("piliPlusScopedWBIHealthV10", "取流策略：V10")
        }
        if message.contains("strategy=piliPlusCancellableWebpageHedgeV9") {
            return ("piliPlusCancellableWebpageHedgeV9", "取流策略：V9")
        }
        if message.contains("strategy=piliPlusBaseQualityWBIWebpageRaceV8") {
            return ("piliPlusBaseQualityWBIWebpageRaceV8", "取流策略：V8")
        }
        if message.contains("strategy=piliPlusStandardWBIWebpageRaceV7") {
            return ("piliPlusStandardWBIWebpageRaceV7", "取流策略：V7")
        }
        if message.contains("strategy=piliPlusStandardWBIRaceV6") {
            return ("piliPlusStandardWBIRaceV6", "取流策略：V6")
        }
        if message.contains("strategy=piliPlusLegacyFirstFallbackV5") {
            return ("piliPlusLegacyFirstFallbackV5", "取流策略：V5")
        }
        if message.contains("strategy=piliPlusStaggeredRescueV4") {
            return ("piliPlusStaggeredRescueV4", "取流策略：V4")
        }
        if message.contains("strategy=piliPlusTargetRescueV3") {
            return ("piliPlusTargetRescueV3", "取流策略：V3")
        }
        if message.contains("route=singleWBITargetQ") {
            return ("piliPlusTargetRaceV2", "取流策略：V2")
        }
        if message.contains("route=singleWBIBaseQ80") {
            return ("piliPlusSingleResponseV1", "取流策略：V1")
        }
        return ("piliPlusUnknown", "取流策略：旧样本未知")
    }
}

nonisolated struct HLSStartupPacketWarmupResult: Equatable, Sendable {
    let videoReady: Bool
    let audioReady: Bool

    var isReady: Bool {
        videoReady && audioReady
    }

    var diagnosticState: String {
        "video=\(videoReady ? "ready" : "skip") audio=\(audioReady ? "ready" : "skip")"
    }
}

nonisolated enum PendingTaskDeadline {
    static func finishes<Value: Sendable>(
        _ task: Task<Value, Never>,
        within nanoseconds: UInt64
    ) async -> Bool {
        guard nanoseconds > 0 else { return false }

        let (stream, continuation) = AsyncStream.makeStream(
            of: Bool.self,
            bufferingPolicy: .bufferingOldest(1)
        )
        let completionWaiter = Task {
            _ = await task.value
            guard !Task.isCancelled else { return }
            continuation.yield(true)
            continuation.finish()
        }
        let timeoutWaiter = Task {
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            continuation.yield(false)
            continuation.finish()
        }

        var iterator = stream.makeAsyncIterator()
        let didFinish = await iterator.next() ?? false
        completionWaiter.cancel()
        timeoutWaiter.cancel()
        continuation.finish()
        return didFinish
    }
}
