import SwiftUI

nonisolated enum HoldProgressMovementPolicy {
    static let defaultMaximumMovement: CGFloat = 10

    static func shouldCancel(
        translation: CGSize,
        location: CGPoint,
        interactiveSize: CGSize,
        maximumMovement: CGFloat = defaultMaximumMovement
    ) -> Bool {
        let distance = hypot(translation.width, translation.height)
        guard distance <= maximumMovement else { return true }
        guard interactiveSize.width > 0, interactiveSize.height > 0 else { return false }
        return location.x < 0
            || location.y < 0
            || location.x > interactiveSize.width
            || location.y > interactiveSize.height
    }
}

nonisolated enum HoldProgressReleasePolicy {
    static func shouldSuppressTap(
        didCommit: Bool,
        hasPendingSuppression: Bool,
        ignoredCurrentTouch: Bool
    ) -> Bool {
        didCommit || hasPendingSuppression || ignoredCurrentTouch
    }
}

nonisolated struct HoldProgressTracker: Equatable, Sendable {
    nonisolated enum Event: Equatable, Sendable {
        case milestone(Int)
        case committed
    }

    private(set) var progress = 0.0
    private(set) var deliveredMilestone = 0
    private(set) var isCommitted = false

    var suppressesTapOnRelease: Bool { isCommitted }

    mutating func reset() {
        self = HoldProgressTracker()
    }

    mutating func advance(to proposedProgress: Double) -> [Event] {
        guard !isCommitted else { return [] }
        progress = min(max(proposedProgress, progress), 1)
        var events = [Event]()
        let targetMilestone = min(2, Int((progress * 3).rounded(.down)))
        if targetMilestone > deliveredMilestone {
            for milestone in (deliveredMilestone + 1)...targetMilestone {
                events.append(.milestone(milestone))
            }
            deliveredMilestone = targetMilestone
        }
        if progress >= 1 {
            isCommitted = true
            events.append(.committed)
        }
        return events
    }
}

struct HoldProgressButton<Label: View, ProgressIndicator: View>: View {
    let holdDuration: TimeInterval
    let maximumMovement: CGFloat
    let isDisabled: Bool
    let tapAction: () -> Void
    let holdAction: () -> Void
    let milestoneFeedback: (Int) -> Void
    let commitFeedback: () -> Void
    let label: () -> Label
    let progressIndicator: (Double) -> ProgressIndicator

    @State private var tracker = HoldProgressTracker()
    @State private var isTracking = false
    @State private var ignoresCurrentTouch = false
    @State private var suppressesNextTap = false
    @State private var progressTask: Task<Void, Never>?
    @State private var tapSuppressionTask: Task<Void, Never>?
    @State private var interactiveSize = CGSize.zero

    init(
        holdDuration: TimeInterval = 1.15,
        maximumMovement: CGFloat = HoldProgressMovementPolicy.defaultMaximumMovement,
        isDisabled: Bool,
        tapAction: @escaping () -> Void,
        holdAction: @escaping () -> Void,
        milestoneFeedback: @escaping (Int) -> Void = { _ in },
        commitFeedback: @escaping () -> Void = {},
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder progressIndicator: @escaping (Double) -> ProgressIndicator
    ) {
        self.holdDuration = holdDuration
        self.maximumMovement = maximumMovement
        self.isDisabled = isDisabled
        self.tapAction = tapAction
        self.holdAction = holdAction
        self.milestoneFeedback = milestoneFeedback
        self.commitFeedback = commitFeedback
        self.label = label
        self.progressIndicator = progressIndicator
    }

    var body: some View {
        Button {
            guard !suppressesNextTap else {
                suppressesNextTap = false
                tapSuppressionTask?.cancel()
                tapSuppressionTask = nil
                return
            }
            tapAction()
        } label: {
            label()
        }
        .biliMinimumInteractiveTarget()
        .overlay {
            if isTracking {
                progressIndicator(tracker.progress)
                    .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(pressGesture)
        .disabled(isDisabled)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            interactiveSize = newSize
        }
        .onChange(of: isDisabled) { _, disabled in
            if disabled, isTracking {
                ignoresCurrentTouch = true
                finishTracking(suppressingTap: tracker.isCommitted)
            }
        }
        .onDisappear {
            progressTask?.cancel()
            progressTask = nil
            tapSuppressionTask?.cancel()
            tapSuppressionTask = nil
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isDisabled, !ignoresCurrentTouch else { return }
                if !isTracking {
                    beginTracking()
                }
                if HoldProgressMovementPolicy.shouldCancel(
                    translation: value.translation,
                    location: value.location,
                    interactiveSize: interactiveSize,
                    maximumMovement: maximumMovement
                ) {
                    ignoresCurrentTouch = true
                    finishTracking(suppressingTap: true, untilRelease: true)
                }
            }
            .onEnded { _ in
                finishTracking(
                    suppressingTap: HoldProgressReleasePolicy.shouldSuppressTap(
                        didCommit: tracker.suppressesTapOnRelease,
                        hasPendingSuppression: suppressesNextTap,
                        ignoredCurrentTouch: ignoresCurrentTouch
                    )
                )
                ignoresCurrentTouch = false
            }
    }

    private func beginTracking() {
        tracker.reset()
        isTracking = true
        suppressesNextTap = false
        tapSuppressionTask?.cancel()
        tapSuppressionTask = nil
        progressTask?.cancel()
        let stepCount = 36
        let interval = max(holdDuration / Double(stepCount), 0.01)
        progressTask = Task { @MainActor in
            for step in 1...stepCount {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled, isTracking else { return }
                let events = tracker.advance(to: Double(step) / Double(stepCount))
                for event in events {
                    switch event {
                    case .milestone(let milestone):
                        milestoneFeedback(milestone)
                    case .committed:
                        suppressesNextTap = true
                        commitFeedback()
                        holdAction()
                    }
                }
            }
        }
    }

    private func finishTracking(suppressingTap: Bool, untilRelease: Bool = false) {
        progressTask?.cancel()
        progressTask = nil
        isTracking = false
        tracker.reset()
        if suppressingTap {
            suppressesNextTap = true
            tapSuppressionTask?.cancel()
            guard !untilRelease else { return }
            tapSuppressionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                suppressesNextTap = false
                tapSuppressionTask = nil
            }
        }
    }
}
