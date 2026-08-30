import Combine
import SwiftUI
import UIKit

nonisolated enum DanmakuMotionTiming {
    static func remainingDuration(
        totalDuration: TimeInterval,
        elapsed: TimeInterval
    ) -> TimeInterval {
        max(0.05, totalDuration - min(max(elapsed, 0), totalDuration))
    }

    static func laneEntranceDelay(
        surfaceWidth: CGFloat,
        labelWidth: CGFloat,
        duration: TimeInterval,
        gap: CGFloat
    ) -> TimeInterval {
        let travelDistance = max(surfaceWidth + labelWidth, 1)
        let protectedWidth = min(labelWidth + gap, surfaceWidth * 0.72)
        return duration * TimeInterval(protectedWidth / travelDistance)
    }
}

nonisolated enum DanmakuQuickActionLayout {
    static let minimumHitDimension: CGFloat = 44

    static func frame(
        anchoredTo anchor: CGRect,
        menuSize: CGSize,
        in container: CGRect,
        edgeInset: CGFloat = 8,
        verticalGap: CGFloat = 6
    ) -> CGRect {
        let safeBounds = container.insetBy(dx: max(0, edgeInset), dy: max(0, edgeInset))
        let width = min(max(0, menuSize.width), max(0, safeBounds.width))
        let height = min(max(0, menuSize.height), max(0, safeBounds.height))
        let centeredX = anchor.midX - width / 2
        let x = min(max(centeredX, safeBounds.minX), max(safeBounds.minX, safeBounds.maxX - width))
        let preferredAboveY = anchor.minY - verticalGap - height
        let preferredBelowY = anchor.maxY + verticalGap
        let hasRoomAbove = preferredAboveY >= safeBounds.minY
        let candidateY = hasRoomAbove ? preferredAboveY : preferredBelowY
        let y = min(max(candidateY, safeBounds.minY), max(safeBounds.minY, safeBounds.maxY - height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

nonisolated enum DanmakuQuickActionPolicy {
    static func showsLike(
        allowsRemoteInteraction: Bool,
        dmid: Int64?,
        hasLikeAction: Bool
    ) -> Bool {
        allowsRemoteInteraction
            && (dmid ?? 0) > 0
            && hasLikeAction
    }

    static func showsMore(hasMoreAction: Bool) -> Bool {
        hasMoreAction
    }
}

enum DanmakuQuickActionLikeResult {
    case success(isLiked: Bool)
    case failure(message: String)
}

@MainActor
struct DanmakuQuickActionConfiguration {
    let allowsRemoteInteraction: Bool
    let onCopy: (DanmakuItem) -> Void
    let onToggleLike: ((DanmakuItem, Bool, @escaping (DanmakuQuickActionLikeResult) -> Void) -> Void)?
    let onMore: ((DanmakuItem, Bool) -> Void)?

    static func copyOnly(onCopy: @escaping (DanmakuItem) -> Void) -> Self {
        Self(
            allowsRemoteInteraction: false,
            onCopy: onCopy,
            onToggleLike: nil,
            onMore: nil
        )
    }
}

struct DanmakuOverlayView: UIViewRepresentable {
    fileprivate struct ConfigurationSignature: Equatable {
        let itemsRevision: Int
        let currentTimeBucket: Int?
        let isPlaying: Bool
        let playbackRateTenths: Int
        let isEnabled: Bool
        let hasPresentedPlayback: Bool
        let isLoadShedding: Bool
        let settings: DanmakuSettings
        let topInsetTenths: Int
        let bottomInsetTenths: Int

        init(
            itemsRevision: Int,
            currentTime: TimeInterval,
            usesExternalClock: Bool,
            isPlaying: Bool,
            playbackRate: Double,
            isEnabled: Bool,
            hasPresentedPlayback: Bool,
            isLoadShedding: Bool,
            settings: DanmakuSettings,
            topInset: CGFloat,
            bottomInset: CGFloat
        ) {
            self.itemsRevision = itemsRevision
            // When a PlayerPlaybackClock is bound, UIKit receives time ticks directly.
            // Without one, keep a coarse time bucket so live-style callers can resync.
            currentTimeBucket = usesExternalClock ? nil : Int(max(0, currentTime) * 2)
            self.isPlaying = isPlaying
            playbackRateTenths = Int((max(playbackRate, 0.1) * 10).rounded())
            self.isEnabled = isEnabled
            self.hasPresentedPlayback = hasPresentedPlayback
            self.isLoadShedding = isLoadShedding
            self.settings = settings.normalized
            topInsetTenths = Int((max(0, topInset) * 10).rounded())
            bottomInsetTenths = Int((max(0, bottomInset) * 10).rounded())
        }
    }

    let items: [DanmakuItem]
    let itemsRevision: Int
    let currentTime: TimeInterval
    let isPlaying: Bool
    let playbackRate: Double
    let isEnabled: Bool
    let hasPresentedPlayback: Bool
    let isLoadShedding: Bool
    let settings: DanmakuSettings
    let topInset: CGFloat
    let bottomInset: CGFloat
    let isLayoutTransitioning: Bool
    let playbackClock: PlayerPlaybackClock?
    let onPlaybackTime: ((TimeInterval, Bool) -> Void)?
    let onSelectItem: ((DanmakuItem) -> Void)?
    let quickActions: DanmakuQuickActionConfiguration?

    init(
        items: [DanmakuItem],
        itemsRevision: Int,
        currentTime: TimeInterval = 0,
        isPlaying: Bool,
        playbackRate: Double,
        isEnabled: Bool,
        hasPresentedPlayback: Bool,
        isLoadShedding: Bool = false,
        settings: DanmakuSettings,
        topInset: CGFloat,
        bottomInset: CGFloat,
        isLayoutTransitioning: Bool = false,
        playbackClock: PlayerPlaybackClock? = nil,
        onPlaybackTime: ((TimeInterval, Bool) -> Void)? = nil,
        onSelectItem: ((DanmakuItem) -> Void)? = nil,
        quickActions: DanmakuQuickActionConfiguration? = nil
    ) {
        self.items = items
        self.itemsRevision = itemsRevision
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.playbackRate = playbackRate
        self.isEnabled = isEnabled
        self.hasPresentedPlayback = hasPresentedPlayback
        self.isLoadShedding = isLoadShedding
        self.settings = settings
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.isLayoutTransitioning = isLayoutTransitioning
        self.playbackClock = playbackClock
        self.onPlaybackTime = onPlaybackTime
        self.onSelectItem = onSelectItem
        self.quickActions = quickActions
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> DanmakuAnimationOverlayView {
        let view = DanmakuAnimationOverlayView()
        view.onSelectItem = onSelectItem
        view.quickActions = quickActions
        view.setLayoutTransitioning(isLayoutTransitioning)
        let resolvedCurrentTime = playbackClock?.currentTime ?? currentTime
        let signature = configurationSignature(resolvedCurrentTime: resolvedCurrentTime)
        view.apply(
            items: items,
            itemsRevision: itemsRevision,
            currentTime: resolvedCurrentTime,
            isPlaying: isPlaying,
            playbackRate: playbackRate,
            isEnabled: isEnabled,
            hasPresentedPlayback: hasPresentedPlayback,
            isLoadShedding: isLoadShedding,
            settings: settings,
            topInset: topInset,
            bottomInset: bottomInset
        )
        context.coordinator.markApplied(signature)
        context.coordinator.bind(clock: playbackClock, uiView: view, onPlaybackTime: onPlaybackTime)
        return view
    }

    func updateUIView(_ uiView: DanmakuAnimationOverlayView, context: Context) {
        uiView.onSelectItem = onSelectItem
        uiView.quickActions = quickActions
        if isLayoutTransitioning {
            uiView.setLayoutTransitioning(true)
        }
        let resolvedCurrentTime = playbackClock?.currentTime ?? currentTime
        let signature = configurationSignature(resolvedCurrentTime: resolvedCurrentTime)
        if context.coordinator.shouldApply(signature) {
            uiView.apply(
                items: items,
                itemsRevision: itemsRevision,
                currentTime: resolvedCurrentTime,
                isPlaying: isPlaying,
                playbackRate: playbackRate,
                isEnabled: isEnabled,
                hasPresentedPlayback: hasPresentedPlayback,
                isLoadShedding: isLoadShedding,
                settings: settings,
                topInset: topInset,
                bottomInset: bottomInset
            )
            context.coordinator.markApplied(signature)
        }
        if !isLayoutTransitioning {
            uiView.setLayoutTransitioning(false)
        }
        context.coordinator.bind(clock: playbackClock, uiView: uiView, onPlaybackTime: onPlaybackTime)
    }

    private func configurationSignature(resolvedCurrentTime: TimeInterval) -> ConfigurationSignature {
        ConfigurationSignature(
            itemsRevision: itemsRevision,
            currentTime: resolvedCurrentTime,
            usesExternalClock: playbackClock != nil,
            isPlaying: isPlaying,
            playbackRate: playbackRate,
            isEnabled: isEnabled,
            hasPresentedPlayback: hasPresentedPlayback,
            isLoadShedding: isLoadShedding,
            settings: settings,
            topInset: topInset,
            bottomInset: bottomInset
        )
    }

    static func dismantleUIView(_ uiView: DanmakuAnimationOverlayView, coordinator: Coordinator) {
        coordinator.unbind()
        uiView.onSelectItem = nil
        uiView.quickActions = nil
        uiView.stop()
    }

    @MainActor
    final class Coordinator {
        private weak var boundClock: PlayerPlaybackClock?
        private var clockCancellable: AnyCancellable?
        private var onPlaybackTime: ((TimeInterval, Bool) -> Void)?
        private var lastReportedPlaybackSecond: Int?
        private var isLoadShedding = false
        private var lastAppliedSignature: ConfigurationSignature?

        fileprivate func shouldApply(_ signature: ConfigurationSignature) -> Bool {
            lastAppliedSignature != signature
        }

        fileprivate func markApplied(_ signature: ConfigurationSignature) {
            lastAppliedSignature = signature
        }

        func bind(
            clock: PlayerPlaybackClock?,
            uiView: DanmakuAnimationOverlayView,
            onPlaybackTime: ((TimeInterval, Bool) -> Void)?
        ) {
            self.onPlaybackTime = onPlaybackTime
            self.isLoadShedding = uiView.isLoadShedding
            guard boundClock !== clock else { return }

            clockCancellable?.cancel()
            boundClock = clock

            guard let clock else { return }
            uiView.synchronizePlaybackTime(clock.currentTime, force: true)
            reportPlaybackTime(clock.currentTime, force: true)
            clockCancellable = clock.$currentTime
                .removeDuplicates { abs($0 - $1) < 0.05 }
                .sink { [weak self, weak uiView] time in
                    uiView?.synchronizePlaybackTime(time)
                    self?.reportPlaybackTime(time)
                }
        }

        func unbind() {
            clockCancellable?.cancel()
            clockCancellable = nil
            boundClock = nil
            lastReportedPlaybackSecond = nil
            lastAppliedSignature = nil
            onPlaybackTime = nil
        }

        private func reportPlaybackTime(_ playbackTime: TimeInterval, force: Bool = false) {
            guard let onPlaybackTime else { return }
            let sanitizedTime = max(0, playbackTime)
            let secondBucket = Int(sanitizedTime.rounded(.down))
            guard force || lastReportedPlaybackSecond != secondBucket else { return }
            lastReportedPlaybackSecond = secondBucket
            onPlaybackTime(sanitizedTime, isLoadShedding)
        }
    }
}

final class DanmakuAnimationOverlayView: UIView {
    private struct ActiveEntry {
        let id: String
        let item: DanmakuItem
        let label: UILabel
        let completion: DanmakuAnimationCompletionDelegate?
        let createdAt: CFTimeInterval
        let animationGeneration: Int
        let scrollingTrajectory: ScrollingTrajectory?
    }

    private struct ScrollingTrajectory {
        let labelWidth: CGFloat
        let surfaceWidth: CGFloat
        let startX: CGFloat
        let endX: CGFloat
        let displayDuration: TimeInterval
    }

    private struct LaneState {
        let releaseTime: TimeInterval
        let itemWidth: CGFloat
    }

    private struct TextMeasurementKey: Hashable {
        let text: String
        let fontSizeTenths: Int
        let fontWeight: DanmakuFontWeightOption
    }

    private struct TimeBucket {
        let index: Int
        var items: [DanmakuItem]
    }

    private var items: [DanmakuItem] = []
    private var timeBuckets: [TimeBucket] = []
    private var settings: DanmakuSettings = .default
    private var itemFilter = DanmakuItemFilter(rules: DanmakuSettings.default.filterRules)
    private var currentTime: TimeInterval = 0
    private var isPlaying = false
    private var playbackRate: Double = 1
    private var isEnabled = true
    private var hasPresentedPlayback = false
    private(set) var isLoadShedding = false
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var nextBucketIndex = 0
    private var nextBucketItemIndex = 0
    private var anchorPlaybackTime: TimeInterval = 0
    private var anchorHostTime = CACurrentMediaTime()
    private var displayLink: CADisplayLink?
    private var activeEntries: [String: ActiveEntry] = [:]
    private var retirementCandidateIDs: [String] = []
    private var reusableLabels: [UILabel] = []
    private var scrollingLaneStates: [Int: LaneState] = [:]
    private var textSizeCache: [TextMeasurementKey: CGSize] = [:]
    private var textSizeCacheOrder: [TextMeasurementKey] = []
    private var lastLayoutSize: CGSize = .zero
    private var activeAnimationSpeed: Float = 1
    private var lastItemsRevision = -1
    private var animationGeneration = 0
    private var layoutSettlingGeneration = 0
    private var isLayoutSettling = false
    private var isLayoutTransitioning = false
    private var needsLayoutRebuildAfterTransition = false
    private var renderEnvironment = PlaybackEnvironment.current
    private var lastRenderEnvironmentRefreshTime = CACurrentMediaTime()
    var onSelectItem: ((DanmakuItem) -> Void)?
    var quickActions: DanmakuQuickActionConfiguration? {
        didSet {
            if quickActions == nil {
                dismissQuickActions(animated: false)
            }
        }
    }
    private var quickActionContainer: UIVisualEffectView?
    private var quickActionStack: UIStackView?
    private var quickActionItem: DanmakuItem?
    private var quickActionLiked = false
    private var quickActionLikedStateByDMID: [Int64: Bool] = [:]
    private var quickActionEntryID: String?
    private weak var quickActionLabel: UILabel?
    private var quickActionDismissWorkItem: DispatchWorkItem?
    private weak var quickActionLikeButton: UIButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    deinit {
        displayLink?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return }
        guard abs(size.width - lastLayoutSize.width) > 1 || abs(size.height - lastLayoutSize.height) > 1 else { return }
        if isLayoutTransitioning {
            needsLayoutRebuildAfterTransition = true
            return
        }
        lastLayoutSize = size
        beginLayoutSettling(animated: isPlaying)
        guard shouldRenderDanmaku else {
            clearActiveLabels()
            return
        }
        rebuildVisibleItemsAfterLayoutChange(
            at: effectivePlaybackTime(),
            animated: false
        )
        updateDisplayLinkState()
        updateAnimationPauseState()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayLinkState()
        updateAnimationPauseState()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let quickActionContainer,
           !quickActionContainer.isHidden,
           quickActionContainer.frame.contains(point) {
            return true
        }
        guard (quickActions != nil || onSelectItem != nil), shouldRenderDanmaku else { return false }
        return activeEntry(at: point) != nil
    }

    func setLayoutTransitioning(_ isTransitioning: Bool) {
        guard isLayoutTransitioning != isTransitioning else { return }
        isLayoutTransitioning = isTransitioning
        if isTransitioning {
            dismissQuickActions(animated: false)
            cancelLayoutSettling()
            return
        }
        guard needsLayoutRebuildAfterTransition else { return }
        needsLayoutRebuildAfterTransition = false
        lastLayoutSize = bounds.size
        // Keep active Core Animation instances intact. Rebuilding here restarts fixed
        // danmaku opacity and scrolling trajectories on the rotation completion frame.
        setNextSpawnPosition(after: effectivePlaybackTime())
        updateDisplayLinkState()
        updateAnimationPauseState()
    }

    func apply(
        items newItems: [DanmakuItem],
        itemsRevision newItemsRevision: Int,
        currentTime newCurrentTime: TimeInterval,
        isPlaying newIsPlaying: Bool,
        playbackRate newPlaybackRate: Double,
        isEnabled newIsEnabled: Bool,
        hasPresentedPlayback newHasPresentedPlayback: Bool,
        isLoadShedding newIsLoadShedding: Bool,
        settings newSettings: DanmakuSettings,
        topInset newTopInset: CGFloat,
        bottomInset newBottomInset: CGFloat
    ) {
        let normalizedRate = max(newPlaybackRate, 0.1)
        let sanitizedTime = max(0, newCurrentTime)
        let previousEffectiveTime = effectivePlaybackTime()
        let previousShouldRender = shouldRenderDanmaku
        let previousIsPlaying = isPlaying
        let didChangeItems = newItemsRevision != lastItemsRevision
        let normalizedSettings = newSettings.normalized
        let didChangeFilterRules = normalizedSettings.filterRules != settings.filterRules
        let didChangeOpacity = abs(normalizedSettings.opacity - settings.opacity) > 0.001
        let requiresRenderedItemRebuild = abs(normalizedSettings.fontScale - settings.fontScale) > 0.001
            || normalizedSettings.displayArea != settings.displayArea
            || normalizedSettings.fontWeight != settings.fontWeight
            || abs(normalizedSettings.scrollingDuration - settings.scrollingDuration) > 0.001
            || abs(normalizedSettings.staticDuration - settings.staticDuration) > 0.001
            || abs(normalizedSettings.lineHeight - settings.lineHeight) > 0.001
            || abs(normalizedSettings.strokeWidth - settings.strokeWidth) > 0.001
            || didChangeFilterRules
        let didChangeTextMetrics = abs(normalizedSettings.fontScale - settings.fontScale) > 0.001
            || normalizedSettings.fontWeight != settings.fontWeight
            || abs(normalizedSettings.lineHeight - settings.lineHeight) > 0.001
            || abs(normalizedSettings.strokeWidth - settings.strokeWidth) > 0.001
        let didChangeInsets = abs(newTopInset - topInset) > 0.5 || abs(newBottomInset - bottomInset) > 0.5
        if didChangeFilterRules {
            itemFilter = DanmakuItemFilter(rules: normalizedSettings.filterRules)
        }
        if didChangeItems || didChangeFilterRules {
            items = itemFilter.filtered(newItems)
            rebuildTimeBuckets()
        }
        lastItemsRevision = newItemsRevision
        currentTime = sanitizedTime
        isPlaying = newIsPlaying
        playbackRate = normalizedRate
        isEnabled = newIsEnabled
        hasPresentedPlayback = newHasPresentedPlayback
        isLoadShedding = newIsLoadShedding
        settings = normalizedSettings
        topInset = max(0, newTopInset)
        bottomInset = max(0, newBottomInset)
        if didChangeTextMetrics {
            textSizeCache.removeAll(keepingCapacity: true)
            textSizeCacheOrder.removeAll(keepingCapacity: true)
        }
        if didChangeOpacity {
            refreshActiveLabelColors()
        }

        let currentShouldRender = shouldRenderDanmaku
        if !currentShouldRender {
            cancelLayoutSettling()
            clearActiveLabels()
            setNextSpawnPosition(after: sanitizedTime)
            syncPlaybackAnchor(to: sanitizedTime)
            stopDisplayLink()
            updateAnimationPauseState()
            return
        }

        let jumped = abs(sanitizedTime - previousEffectiveTime) > seekJumpThreshold || sanitizedTime + 0.2 < previousEffectiveTime
        syncPlaybackAnchor(to: sanitizedTime)

        if isLayoutTransitioning, didChangeInsets {
            needsLayoutRebuildAfterTransition = true
            updateDisplayLinkState()
            updateAnimationPauseState()
            return
        }

        if !previousShouldRender || requiresRenderedItemRebuild || jumped {
            rebuildVisibleItems(at: sanitizedTime, animated: newIsPlaying)
            updateDisplayLinkState()
            updateAnimationPauseState()
            return
        }

        if didChangeInsets {
            rebuildVisibleItemsAfterLayoutChange(
                at: sanitizedTime,
                animated: newIsPlaying
            )
            updateDisplayLinkState()
            updateAnimationPauseState()
            return
        }

        if didChangeItems {
            if activeEntries.isEmpty {
                rebuildVisibleItems(at: sanitizedTime, animated: newIsPlaying)
            } else {
                setNextSpawnPosition(after: sanitizedTime)
            }
        }

        if previousIsPlaying != newIsPlaying && newIsPlaying {
            rebuildVisibleItems(at: sanitizedTime, animated: true)
        }

        updateDisplayLinkState()
        updateAnimationPauseState()
    }

    func stop() {
        cancelLayoutSettling()
        stopDisplayLink()
        dismissQuickActions(animated: false)
        clearActiveLabels()
    }

    func synchronizePlaybackTime(_ playbackTime: TimeInterval, force: Bool = false) {
        let sanitizedTime = max(0, playbackTime)
        let previousEffectiveTime = effectivePlaybackTime()
        currentTime = sanitizedTime

        guard shouldRenderDanmaku else {
            setNextSpawnPosition(after: sanitizedTime)
            syncPlaybackAnchor(to: sanitizedTime)
            stopDisplayLink()
            updateAnimationPauseState()
            return
        }

        let drift = abs(sanitizedTime - previousEffectiveTime)
        let jumped = force || drift > seekJumpThreshold || sanitizedTime + 0.2 < previousEffectiveTime
        syncPlaybackAnchor(to: sanitizedTime)

        if jumped {
            rebuildVisibleItems(at: sanitizedTime, animated: isPlaying)
        }

        updateDisplayLinkState()
        updateAnimationPauseState()
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        guard shouldRenderDanmaku, isPlaying else { return }
        refreshRenderEnvironmentIfNeeded(hostTime: displayLink.timestamp)
        let playbackTime = effectivePlaybackTime(hostTime: displayLink.timestamp)
        retireExpiredActiveEntries(at: playbackTime)
        guard !isLayoutSettling, !isLayoutTransitioning else { return }
        spawnDueItems(at: playbackTime)
    }

    private func configureView() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        isUserInteractionEnabled = true
        layer.allowsGroupOpacity = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleItemTap(_:)))
        tapGesture.cancelsTouchesInView = true
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleItemTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              let entry = activeEntry(at: gesture.location(in: self))
        else { return }
        if quickActions != nil {
            showQuickActions(for: entry, anchoredTo: interactiveFrame(for: entry))
        } else {
            onSelectItem?(entry.item)
        }
    }

    private func interactiveFrame(for entry: ActiveEntry) -> CGRect {
        let layer = entry.label.layer.presentation() ?? entry.label.layer
        return layer.frame
    }

    private func activeEntry(at point: CGPoint) -> ActiveEntry? {
        activeEntries.values
            .filter { entry in
                let layer = entry.label.layer.presentation() ?? entry.label.layer
                guard layer.opacity > 0.05 else { return false }
                let frame = layer.frame
                let horizontalExpansion = max(
                    (DanmakuQuickActionLayout.minimumHitDimension - frame.width) / 2,
                    8
                )
                let verticalExpansion = max(
                    (DanmakuQuickActionLayout.minimumHitDimension - frame.height) / 2,
                    6
                )
                return frame.insetBy(
                    dx: -horizontalExpansion,
                    dy: -verticalExpansion
                ).contains(point)
            }
            .max { lhs, rhs in lhs.createdAt < rhs.createdAt }
    }

    private func showQuickActions(for entry: ActiveEntry, anchoredTo anchor: CGRect) {
        guard let quickActions else { return }
        quickActionDismissWorkItem?.cancel()
        dismissQuickActions(animated: false)
        let item = entry.item
        quickActionItem = item
        quickActionLiked = item.dmid.flatMap { quickActionLikedStateByDMID[$0] } ?? false
        quickActionEntryID = entry.id
        quickActionLabel = entry.label
        suspendQuickActionLabel(entry.label)

        let blur = UIBlurEffect(style: .systemChromeMaterialDark)
        let container = UIVisualEffectView(effect: blur)
        container.clipsToBounds = true
        container.layer.cornerCurve = .continuous
        container.layer.cornerRadius = 24
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        container.accessibilityViewIsModal = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.layoutMargins = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        stack.isLayoutMarginsRelativeArrangement = true
        container.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor)
        ])

        let copyButton = makeQuickActionButton(
            systemImage: "doc.on.doc",
            accessibilityLabel: "复制弹幕",
            action: #selector(copyQuickAction)
        )
        stack.addArrangedSubview(copyButton)

        let showsLike = DanmakuQuickActionPolicy.showsLike(
            allowsRemoteInteraction: quickActions.allowsRemoteInteraction,
            dmid: item.dmid,
            hasLikeAction: quickActions.onToggleLike != nil
        )
        if showsLike {
            let likeButton = makeQuickActionButton(
                systemImage: quickActionLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                accessibilityLabel: quickActionLiked ? "取消弹幕点赞" : "点赞弹幕",
                action: #selector(toggleLikeQuickAction)
            )
            stack.addArrangedSubview(likeButton)
            quickActionLikeButton = likeButton
        }
        if DanmakuQuickActionPolicy.showsMore(hasMoreAction: quickActions.onMore != nil) {
            stack.addArrangedSubview(
                makeQuickActionButton(
                    systemImage: "ellipsis.circle",
                    accessibilityLabel: "更多弹幕操作",
                    action: #selector(moreQuickAction)
                )
            )
        }

        addSubview(container)
        quickActionContainer = container
        quickActionStack = stack
        let itemCount = CGFloat(stack.arrangedSubviews.count)
        let menuSize = CGSize(width: itemCount * 48 + 8, height: 48)
        container.frame = DanmakuQuickActionLayout.frame(
            anchoredTo: anchor,
            menuSize: menuSize,
            in: bounds
        )
        presentQuickActionContainer(container)
        UISelectionFeedbackGenerator().selectionChanged()
        scheduleQuickActionDismissal()
    }

    private func makeQuickActionButton(
        systemImage: String,
        accessibilityLabel: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits.insert(.button)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(
                greaterThanOrEqualToConstant: DanmakuQuickActionLayout.minimumHitDimension
            ),
            button.heightAnchor.constraint(
                greaterThanOrEqualToConstant: DanmakuQuickActionLayout.minimumHitDimension
            )
        ])
        return button
    }

    private func presentQuickActionContainer(_ container: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            container.alpha = 1
            container.transform = .identity
            return
        }
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            container.alpha = 1
            container.transform = .identity
        }
    }

    private func scheduleQuickActionDismissal() {
        quickActionDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissQuickActions(animated: true)
        }
        quickActionDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: workItem)
    }

    private func dismissQuickActions(animated: Bool) {
        quickActionDismissWorkItem?.cancel()
        quickActionDismissWorkItem = nil
        resumeQuickActionLabelIfNeeded()
        quickActionEntryID = nil
        quickActionLabel = nil
        quickActionItem = nil
        quickActionLikeButton = nil
        quickActionStack = nil
        guard let container = quickActionContainer else { return }
        quickActionContainer = nil
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            container.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        } completion: { _ in
            container.removeFromSuperview()
        }
    }

    @objc private func copyQuickAction() {
        guard let item = quickActionItem, let quickActions else { return }
        quickActions.onCopy(item)
        if let copyButton = quickActionStack?.arrangedSubviews.first as? UIButton {
            copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "已复制弹幕")
        scheduleQuickActionDismissal()
    }

    @objc private func toggleLikeQuickAction() {
        guard let item = quickActionItem,
              let quickActions,
              let onToggleLike = quickActions.onToggleLike,
              let button = quickActionLikeButton
        else { return }
        quickActionDismissWorkItem?.cancel()
        button.isEnabled = false
        var configuration = button.configuration ?? .plain()
        configuration.showsActivityIndicator = true
        configuration.image = nil
        button.configuration = configuration
        let target = !quickActionLiked
        onToggleLike(item, target) { [weak self, weak button] result in
            guard let self, let button else { return }
            button.isEnabled = true
            var configuration = button.configuration ?? .plain()
            configuration.showsActivityIndicator = false
            switch result {
            case let .success(isLiked):
                self.quickActionLiked = isLiked
                if let dmid = item.dmid {
                    self.quickActionLikedStateByDMID[dmid] = isLiked
                }
                configuration.image = UIImage(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                button.accessibilityLabel = isLiked ? "取消弹幕点赞" : "点赞弹幕"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: isLiked ? "已点赞弹幕" : "已取消弹幕点赞"
                )
            case let .failure(message):
                configuration.image = UIImage(systemName: "exclamationmark.circle")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            button.configuration = configuration
            self.scheduleQuickActionDismissal()
        }
    }

    @objc private func moreQuickAction() {
        guard let item = quickActionItem, let quickActions else { return }
        let isLiked = quickActionLiked
        dismissQuickActions(animated: true)
        quickActions.onMore?(item, isLiked)
    }

    private func suspendQuickActionLabel(_ label: UILabel) {
        let pausedTime = label.layer.convertTime(CACurrentMediaTime(), from: nil)
        label.layer.speed = 0
        label.layer.timeOffset = pausedTime
    }

    private func resumeQuickActionLabelIfNeeded() {
        guard let label = quickActionLabel, label.layer.speed == 0 else { return }
        let pausedTime = label.layer.timeOffset
        label.layer.speed = 1
        label.layer.timeOffset = 0
        label.layer.beginTime = 0
        let currentTime = label.layer.convertTime(CACurrentMediaTime(), from: nil)
        label.layer.beginTime = currentTime - pausedTime
    }

    private var shouldRenderDanmaku: Bool {
        isEnabled && hasPresentedPlayback && !items.isEmpty && bounds.width > 20 && bounds.height > 20
    }

    private var seekJumpThreshold: TimeInterval {
        max(1.25, 0.7 * playbackRate)
    }

    private func effectivePlaybackTime(hostTime: CFTimeInterval = CACurrentMediaTime()) -> TimeInterval {
        guard isPlaying else { return currentTime }
        let elapsed = max(0, hostTime - anchorHostTime)
        return max(0, anchorPlaybackTime + elapsed * playbackRate)
    }

    private func syncPlaybackAnchor(to playbackTime: TimeInterval) {
        anchorPlaybackTime = max(0, playbackTime)
        anchorHostTime = CACurrentMediaTime()
    }

    private func updateDisplayLinkState() {
        guard shouldRenderDanmaku, isPlaying, window != nil else {
            stopDisplayLink()
            return
        }
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        displayLink?.preferredFrameRateRange = preferredFrameRateRange
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateAnimationPauseState() {
        let shouldPause = !isPlaying || !shouldRenderDanmaku || window == nil
        let targetSpeed: Float = shouldPause ? 0 : Float(max(playbackRate, 0.1))
        guard abs(activeAnimationSpeed - targetSpeed) > 0.001 else { return }
        applyLayerAnimationSpeed(targetSpeed)
        activeAnimationSpeed = targetSpeed
    }

    private func applyLayerAnimationSpeed(_ targetSpeed: Float) {
        let now = CACurrentMediaTime()
        let currentLayerTime = layer.convertTime(now, from: nil)
        layer.speed = targetSpeed
        layer.timeOffset = 0
        layer.beginTime = 0
        if targetSpeed == 0 {
            layer.timeOffset = currentLayerTime
        } else {
            let convertedTime = layer.convertTime(now, from: nil)
            layer.beginTime = convertedTime - currentLayerTime
        }
    }

    private func beginLayoutSettling(animated: Bool) {
        layoutSettlingGeneration &+= 1
        let generation = layoutSettlingGeneration
        isLayoutSettling = true

        for (index, delay) in Self.layoutSettlingRebuildDelays.enumerated() {
            let completesSettling = index == Self.layoutSettlingRebuildDelays.indices.last
            if delay == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.performLayoutSettledRebuild(
                        generation: generation,
                        animated: animated,
                        completesSettling: completesSettling
                    )
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(Int(delay))) { [weak self] in
                    self?.performLayoutSettledRebuild(
                        generation: generation,
                        animated: animated,
                        completesSettling: completesSettling
                    )
                }
            }
        }
    }

    private func performLayoutSettledRebuild(
        generation: Int,
        animated: Bool,
        completesSettling: Bool
    ) {
        guard layoutSettlingGeneration == generation else { return }
        defer {
            if completesSettling, layoutSettlingGeneration == generation {
                isLayoutSettling = false
                updateDisplayLinkState()
                updateAnimationPauseState()
            }
        }
        guard shouldRenderDanmaku else {
            clearActiveLabels()
            return
        }
        rebuildVisibleItemsAfterLayoutChange(
            at: effectivePlaybackTime(),
            animated: completesSettling && animated && isPlaying
        )
    }

    private func cancelLayoutSettling() {
        layoutSettlingGeneration &+= 1
        isLayoutSettling = false
    }

    private func rebuildVisibleItems(at playbackTime: TimeInterval, animated: Bool) {
        isLayoutSettling = false
        advanceAnimationGeneration()
        clearActiveLabels()
        guard shouldRenderDanmaku else { return }
        scrollingLaneStates.removeAll(keepingCapacity: true)

        let replayStart = playbackTime - maximumDisplayDuration()
        let startIndex = firstItemIndex(atOrAfter: replayStart)
        let endIndex = firstItemIndex(after: playbackTime)
        guard startIndex < endIndex else {
            setNextSpawnPosition(after: playbackTime)
            return
        }

        var visibleItems: [DanmakuItem] = []
        visibleItems.reserveCapacity(min(maxActiveCount, endIndex - startIndex))
        for item in items[startIndex..<endIndex] {
            let age = playbackTime - item.time
            guard age >= 0, age < displayDuration(for: item) else { continue }
            visibleItems.append(item)
            if visibleItems.count > maxActiveCount {
                visibleItems.removeFirst(visibleItems.count - maxActiveCount)
            }
        }

        for item in visibleItems {
            spawn(item, at: playbackTime, animated: animated)
        }
        setNextSpawnPosition(after: playbackTime)
    }

    private func rebuildVisibleItemsAfterLayoutChange(
        at playbackTime: TimeInterval,
        animated: Bool
    ) {
        guard shouldRenderDanmaku else {
            clearActiveLabels()
            return
        }
        advanceAnimationGeneration()

        let existingEntries = activeEntries.values
        activeEntries.removeAll(keepingCapacity: true)
        scrollingLaneStates.removeAll(keepingCapacity: true)

        for entry in existingEntries {
            entry.completion?.cancel()
            guard entry.item.isSupported else {
                recycle(entry.label)
                continue
            }

            let duration = displayDuration(for: entry.item)
            let age = playbackTime - entry.item.time
            guard age >= 0 else {
                recycle(entry.label)
                continue
            }
            if !entry.item.isScrolling, age >= duration {
                recycle(entry.label)
                continue
            }
            if entry.item.isScrolling,
               shouldRetire(entry: entry, label: entry.label, at: playbackTime) {
                recycle(entry.label)
                continue
            }

            let fontSize = fontSize(for: entry.item)
            let font = UIFont.systemFont(ofSize: fontSize, weight: settings.fontWeight.uiFontWeight)
            let textSize = measuredTextSize(for: entry.item, font: font)
            let labelSize = CGSize(
                width: min(max(textSize.width + 18 + CGFloat(settings.strokeWidth * 2), 44), bounds.width * 1.45),
                height: max(
                    textSize.height + 8 + CGFloat(settings.strokeWidth * 2),
                    fontSize * CGFloat(settings.lineHeight) + 4
                )
            )
            configure(entry.label, for: entry.item, font: font, size: labelSize)

            let band = displayBand()
            let laneHeight = max(labelSize.height, fontSize * CGFloat(settings.lineHeight) + 4)
            let laneCount = max(1, Int(max(1, band.height) / laneHeight))
            let lane = entry.item.isScrolling
                ? stableLane(for: entry.item.id, laneCount: laneCount)
                : stableLane(for: entry.item.id, laneCount: laneCount)
            let y = yPosition(for: entry.item, lane: lane, laneHeight: laneHeight, band: band, labelSize: labelSize)
            entry.label.layer.removeAllAnimations()

            if entry.item.isScrolling {
                let travelDistance = scrollingTravelDistance(labelWidth: labelSize.width)
                let progress = min(max(age / duration, 0), 1)
                let timelineX = scrollingStartX(labelWidth: labelSize.width) - travelDistance * progress
                let startX = min(max(timelineX, -labelSize.width / 2), bounds.width + labelSize.width / 2)
                let endX = scrollingEndX(labelWidth: labelSize.width)
                let trajectory = scrollingTrajectory(
                    labelWidth: labelSize.width,
                    startX: startX,
                    endX: endX,
                    duration: duration
                )
                entry.label.center = CGPoint(x: startX, y: y)
                let animationDuration = animated
                    ? DanmakuMotionTiming.remainingDuration(totalDuration: duration, elapsed: age)
                    : 0
                let entryAnimationGeneration = animationGeneration
                let completion = animated ? DanmakuAnimationCompletionDelegate { [weak self, weak label = entry.label] finished in
                    guard let self, let label else { return }
                    self.completeActiveLabelAnimation(
                        id: entry.id,
                        label: label,
                        animationGeneration: entryAnimationGeneration,
                        didFinishNaturally: finished
                    )
                } : nil
                activeEntries[entry.id] = ActiveEntry(
                    id: entry.id,
                    item: entry.item,
                    label: entry.label,
                    completion: completion,
                    createdAt: entry.createdAt,
                    animationGeneration: entryAnimationGeneration,
                    scrollingTrajectory: trajectory
                )
                if animated {
                    let animation = CABasicAnimation(keyPath: "position.x")
                    animation.fromValue = startX
                    animation.toValue = endX
                    animation.duration = animationDuration
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    animation.isRemovedOnCompletion = false
                    animation.fillMode = .forwards
                    animation.delegate = completion
                    entry.label.layer.add(animation, forKey: "danmaku.scroll")
                }
            } else {
                entry.label.center = CGPoint(x: bounds.midX, y: y)
                activeEntries[entry.id] = ActiveEntry(
                    id: entry.id,
                    item: entry.item,
                    label: entry.label,
                    completion: nil,
                    createdAt: entry.createdAt,
                    animationGeneration: animationGeneration,
                    scrollingTrajectory: nil
                )
            }
        }

        setNextSpawnPosition(after: playbackTime)
    }

    private func spawnDueItems(at playbackTime: TimeInterval) {
        skipExpiredItems(at: playbackTime)
        var spawnedCount = 0
        let spawnLimit = maxSpawnPerTick
        let currentBucket = timeBucketIndex(for: playbackTime)
        while nextBucketIndex < timeBuckets.count,
              timeBuckets[nextBucketIndex].index <= currentBucket,
              spawnedCount < spawnLimit {
            let bucket = timeBuckets[nextBucketIndex]
            if isBucketTooStale(bucket.index, at: playbackTime) {
                advanceToNextBucket()
                continue
            }

            let bucketItems = bucket.items
            while nextBucketItemIndex < bucketItems.count, spawnedCount < spawnLimit {
                let item = bucketItems[nextBucketItemIndex]
                nextBucketItemIndex += 1
                let age = playbackTime - item.time
                guard age >= -Self.timeBucketDuration, age < displayDuration(for: item) else { continue }
                spawn(item, at: playbackTime, animated: true)
                spawnedCount += 1
            }

            if nextBucketItemIndex >= bucketItems.count {
                advanceToNextBucket()
            }
        }
    }

    private func skipExpiredItems(at playbackTime: TimeInterval) {
        let maximumDuration = maximumDisplayDuration()
        while nextBucketIndex < timeBuckets.count {
            let bucket = timeBuckets[nextBucketIndex]
            guard bucketEndTime(for: bucket.index) >= playbackTime - maximumDuration else {
                advanceToNextBucket()
                continue
            }

            while nextBucketItemIndex < bucket.items.count,
                  playbackTime - bucket.items[nextBucketItemIndex].time > maximumDuration {
                nextBucketItemIndex += 1
            }
            if nextBucketItemIndex >= bucket.items.count {
                advanceToNextBucket()
                continue
            }
            return
        }
    }

    private func spawn(_ item: DanmakuItem, at playbackTime: TimeInterval, animated: Bool) {
        guard item.isSupported, bounds.width > 20, bounds.height > 20 else { return }
        guard canSpawnAdditionalItem else { return }

        let fontSize = fontSize(for: item)
        let font = UIFont.systemFont(ofSize: fontSize, weight: settings.fontWeight.uiFontWeight)
        let textSize = measuredTextSize(for: item, font: font)
        let labelSize = CGSize(
            width: min(max(textSize.width + 18 + CGFloat(settings.strokeWidth * 2), 44), bounds.width * 1.45),
            height: max(
                textSize.height + 8 + CGFloat(settings.strokeWidth * 2),
                fontSize * CGFloat(settings.lineHeight) + 4
            )
        )
        let label = dequeueLabel()
        configure(label, for: item, font: font, size: labelSize)

        let duration = displayDuration(for: item)
        let age = min(max(0, playbackTime - item.time), duration)
        let remainingPlaybackDuration = max(0.05, duration - age)
        let animationDuration = animated ? remainingPlaybackDuration : 0
        let band = displayBand()
        let laneHeight = max(labelSize.height, fontSize * CGFloat(settings.lineHeight) + 4)
        let laneCount = max(1, Int(max(1, band.height) / laneHeight))
        let lane: Int
        if item.isScrolling {
            guard let selectedLane = laneIndex(
                for: item,
                laneCount: laneCount,
                labelWidth: labelSize.width,
                at: item.time
            ) else {
                recycle(label)
                return
            }
            lane = selectedLane
        } else {
            lane = stableLane(for: item.id, laneCount: laneCount)
        }
        let y = yPosition(for: item, lane: lane, laneHeight: laneHeight, band: band, labelSize: labelSize)

        addSubview(label)
        let id = item.id
        let entryAnimationGeneration = animationGeneration
        let completion = animated ? DanmakuAnimationCompletionDelegate { [weak self, weak label] finished in
            guard let self, let label else { return }
            self.completeActiveLabelAnimation(
                id: id,
                label: label,
                animationGeneration: entryAnimationGeneration,
                didFinishNaturally: finished
            )
        } : nil
        activeEntries[id] = ActiveEntry(
            id: id,
            item: item,
            label: label,
            completion: completion,
            createdAt: CACurrentMediaTime(),
            animationGeneration: entryAnimationGeneration,
            scrollingTrajectory: item.isScrolling
                ? scrollingTrajectory(
                    labelWidth: labelSize.width,
                    startX: scrollingStartX(labelWidth: labelSize.width)
                        - scrollingTravelDistance(labelWidth: labelSize.width)
                        * min(max(age / duration, 0), 1),
                    endX: scrollingEndX(labelWidth: labelSize.width),
                    duration: duration
                )
                : nil
        )

        if item.isScrolling {
            let travelDistance = scrollingTravelDistance(labelWidth: labelSize.width)
            let progress = min(max(age / duration, 0), 1)
            let startX = scrollingStartX(labelWidth: labelSize.width) - travelDistance * progress
            let endX = scrollingEndX(labelWidth: labelSize.width)
            label.center = CGPoint(x: startX, y: y)
            if animated {
                let animation = CABasicAnimation(keyPath: "position.x")
                animation.fromValue = startX
                animation.toValue = endX
                animation.duration = DanmakuMotionTiming.remainingDuration(
                    totalDuration: duration,
                    elapsed: age
                )
                animation.timingFunction = CAMediaTimingFunction(name: .linear)
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.delegate = completion
                label.layer.add(animation, forKey: "danmaku.scroll")
            }
        } else {
            label.center = CGPoint(x: bounds.midX, y: y)
            if animated {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = [0, 1, 1, 0]
                animation.keyTimes = [0, 0.06, 0.92, 1]
                animation.duration = animationDuration
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.isRemovedOnCompletion = true
                animation.delegate = completion
                label.layer.opacity = 0
                label.layer.add(animation, forKey: "danmaku.opacity")
            }
        }
    }

    private func configure(_ label: UILabel, for item: DanmakuItem, font: UIFont, size: CGSize) {
        label.font = font
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        let foregroundColor = UIColor.danmakuRGB(item.color).withAlphaComponent(settings.opacity)
        if settings.strokeWidth > 0.01 {
            let strokePercentage = -(settings.strokeWidth / Double(max(font.pointSize, 1))) * 100
            label.attributedText = NSAttributedString(
                string: item.text,
                attributes: [
                    .font: font,
                    .foregroundColor: foregroundColor,
                    .strokeColor: foregroundColor,
                    .strokeWidth: strokePercentage
                ]
            )
        } else {
            label.attributedText = nil
            label.text = item.text
            label.textColor = foregroundColor
        }
        label.alpha = 1
        label.layer.opacity = 1
        label.frame = CGRect(origin: .zero, size: size)
        label.layer.shadowOpacity = 0
        label.layer.shouldRasterize = true
        label.layer.rasterizationScale = window?.screen.scale ?? traitCollection.displayScale
        label.layer.allowsEdgeAntialiasing = true
    }

    private func refreshActiveLabelColors() {
        for entry in activeEntries.values {
            let label = entry.label
            let font = label.font ?? UIFont.systemFont(ofSize: fontSize(for: entry.item))
            let foregroundColor = UIColor.danmakuRGB(entry.item.color)
                .withAlphaComponent(settings.opacity)
            if settings.strokeWidth > 0.01 {
                let strokePercentage = -(settings.strokeWidth / Double(max(font.pointSize, 1))) * 100
                label.attributedText = NSAttributedString(
                    string: entry.item.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: foregroundColor,
                        .strokeColor: foregroundColor,
                        .strokeWidth: strokePercentage
                    ]
                )
            } else {
                label.attributedText = nil
                label.text = entry.item.text
                label.textColor = foregroundColor
            }
        }
    }

    private func dequeueLabel() -> UILabel {
        if let label = reusableLabels.popLast() {
            label.layer.removeAllAnimations()
            return label
        }
        let label = UILabel()
        label.backgroundColor = .clear
        label.isOpaque = false
        return label
    }

    private func recycle(_ label: UILabel) {
        label.text = nil
        label.attributedText = nil
        label.layer.removeAllAnimations()
        label.removeFromSuperview()
        guard reusableLabels.count < 72 else { return }
        reusableLabels.append(label)
    }

    private func clearActiveLabels() {
        dismissQuickActions(animated: false)
        let entries = activeEntries.values
        activeEntries.removeAll(keepingCapacity: true)
        for entry in entries {
            entry.completion?.cancel()
            entry.label.layer.removeAllAnimations()
            recycle(entry.label)
        }
    }

    private func removeActiveLabel(id: String, label: UILabel, shouldRecycle: Bool) {
        guard let entry = activeEntries[id], entry.label === label else { return }
        entry.completion?.cancel()
        activeEntries[id] = nil
        label.layer.removeAllAnimations()
        if shouldRecycle {
            recycle(label)
        } else {
            label.removeFromSuperview()
        }
    }

    private func completeActiveLabelAnimation(
        id: String,
        label: UILabel,
        animationGeneration: Int,
        didFinishNaturally: Bool
    ) {
        guard let entry = activeEntries[id], entry.label === label else { return }
        guard entry.animationGeneration == animationGeneration,
              self.animationGeneration == animationGeneration
        else { return }
        if entry.item.isScrolling, isLayoutSettling {
            return
        }
        if entry.item.isScrolling, !didFinishNaturally {
            return
        }
        let playbackTime = effectivePlaybackTime()
        if shouldRetire(
            entry: entry,
            label: label,
            at: playbackTime,
            allowsTimelineFallback: didFinishNaturally
        ) {
            removeActiveLabel(id: id, label: label, shouldRecycle: true)
            return
        }

        guard entry.item.isScrolling, shouldRenderDanmaku else { return }
        rebuildVisibleItemsAfterLayoutChange(at: playbackTime, animated: isPlaying)
    }

    private func advanceAnimationGeneration() {
        animationGeneration &+= 1
    }

    private func retireExpiredActiveEntries(at playbackTime: TimeInterval) {
        guard !activeEntries.isEmpty else { return }
        retirementCandidateIDs.removeAll(keepingCapacity: true)
        for entry in activeEntries.values
        where entry.id != quickActionEntryID
            && shouldRetire(entry: entry, label: entry.label, at: playbackTime) {
            retirementCandidateIDs.append(entry.id)
        }
        for id in retirementCandidateIDs {
            guard let entry = activeEntries[id] else { continue }
            removeActiveLabel(id: entry.id, label: entry.label, shouldRecycle: true)
        }
    }

    private func refreshRenderEnvironmentIfNeeded(hostTime: CFTimeInterval) {
        guard hostTime - lastRenderEnvironmentRefreshTime >= 1 else { return }
        lastRenderEnvironmentRefreshTime = hostTime
        let nextEnvironment = PlaybackEnvironment.current
        let frameRateMayChange = nextEnvironment.isLowPowerModeEnabled != renderEnvironment.isLowPowerModeEnabled
            || nextEnvironment.thermalPressure != renderEnvironment.thermalPressure
        renderEnvironment = nextEnvironment
        if frameRateMayChange {
            displayLink?.preferredFrameRateRange = preferredFrameRateRange
        }
    }

    private func shouldRetire(
        entry: ActiveEntry,
        label: UILabel,
        at playbackTime: TimeInterval,
        allowsTimelineFallback: Bool = false
    ) -> Bool {
        let duration = entry.scrollingTrajectory?.displayDuration ?? displayDuration(for: entry.item)
        let age = playbackTime - entry.item.time
        guard age >= 0 else { return false }
        guard entry.item.isScrolling else { return age >= duration - 0.04 }
        guard !isLayoutSettling else {
            return allowsTimelineFallback && age >= duration + 0.35
        }

        let currentX = label.layer.presentation()?.position.x ?? label.center.x
        let endX = entry.scrollingTrajectory?.endX ?? scrollingEndX(labelWidth: label.bounds.width)
        if currentX <= endX + 1 {
            return true
        }

        return allowsTimelineFallback && age >= duration + 0.18
    }

    private func scrollingStartX(labelWidth: CGFloat) -> CGFloat {
        bounds.width + labelWidth / 2
    }

    private func scrollingEndX(labelWidth: CGFloat) -> CGFloat {
        -labelWidth / 2 - scrollingRetirementOverscan
    }

    private func scrollingTravelDistance(labelWidth: CGFloat) -> CGFloat {
        max(scrollingStartX(labelWidth: labelWidth) - scrollingEndX(labelWidth: labelWidth), 1)
    }

    private func scrollingTrajectory(
        labelWidth: CGFloat,
        startX: CGFloat,
        endX: CGFloat,
        duration: TimeInterval
    ) -> ScrollingTrajectory {
        ScrollingTrajectory(
            labelWidth: labelWidth,
            surfaceWidth: bounds.width,
            startX: startX,
            endX: endX,
            displayDuration: duration
        )
    }

    private var scrollingRetirementOverscan: CGFloat {
        min(max(bounds.width * 0.035, 8), 28)
    }

    private var canSpawnAdditionalItem: Bool {
        activeEntries.count < maxActiveCount
    }

    private func measuredTextSize(for item: DanmakuItem, font: UIFont) -> CGSize {
        let key = TextMeasurementKey(
            text: item.text,
            fontSizeTenths: Int((font.pointSize * 10).rounded()),
            fontWeight: settings.fontWeight
        )
        if let cached = textSizeCache[key] {
            return cached
        }

        let size = (item.text as NSString).size(withAttributes: [.font: font])
        let measured = CGSize(width: ceil(size.width), height: ceil(max(size.height, font.lineHeight)))
        textSizeCache[key] = measured
        textSizeCacheOrder.append(key)
        trimTextSizeCacheIfNeeded()
        return measured
    }

    private func trimTextSizeCacheIfNeeded() {
        guard textSizeCacheOrder.count > 520 else { return }
        let overflow = textSizeCacheOrder.count - 420
        let removedKeys = textSizeCacheOrder.prefix(overflow)
        removedKeys.forEach { textSizeCache[$0] = nil }
        textSizeCacheOrder.removeFirst(overflow)
    }

    private func displayBand() -> CGRect {
        let usableMinY = max(0, topInset)
        let usableMaxY = max(usableMinY + 1, bounds.height - max(0, bottomInset))
        let usableHeight = max(1, usableMaxY - usableMinY)
        let fraction: CGFloat
        switch settings.displayArea {
        case .topQuarter:
            fraction = 0.25
        case .topHalf:
            fraction = 0.5
        case .topThreeQuarters:
            fraction = 0.75
        case .center:
            fraction = 0.5
        case .full:
            fraction = 1
        }
        let targetHeight = bounds.height * fraction
        let minimumHeight = minimumDisplayBandHeight(for: fraction, usableHeight: usableHeight)
        let height = min(usableHeight, max(targetHeight, minimumHeight))
        return CGRect(x: 0, y: usableMinY, width: bounds.width, height: height)
    }

    private func minimumDisplayBandHeight(for fraction: CGFloat, usableHeight: CGFloat) -> CGFloat {
        guard fraction < 1 else { return usableHeight }
        let compactScale = bounds.width > 640 ? 0.86 : 0.70
        let representativeFontSize = min(
            max(25 * compactScale * CGFloat(settings.fontScale), bounds.width > 640 ? 13.5 : 11.7),
            (bounds.width > 640 ? 24 : 18) * 1.35
        )
        let laneHeight = representativeFontSize * CGFloat(settings.lineHeight) + 4
        let preferredLaneCount: CGFloat
        if bounds.height < 220 {
            preferredLaneCount = fraction <= 0.25 ? 3 : 4
        } else {
            preferredLaneCount = fraction <= 0.25 ? 4 : 5
        }
        return min(usableHeight, laneHeight * preferredLaneCount)
    }

    private func yPosition(
        for item: DanmakuItem,
        lane: Int,
        laneHeight: CGFloat,
        band: CGRect,
        labelSize: CGSize
    ) -> CGFloat {
        if item.isBottomAnchored {
            let anchoredLaneCount = min(3, max(1, Int(max(1, band.height) / laneHeight)))
            let anchoredLane = stableLane(for: item.id, laneCount: anchoredLaneCount)
            let y = band.maxY - laneHeight * (CGFloat(anchoredLane) + 0.5)
            return min(max(y, labelSize.height / 2), bounds.height - labelSize.height / 2)
        }
        if item.isTopAnchored {
            let anchoredLaneCount = min(3, max(1, Int(max(1, band.height) / laneHeight)))
            let anchoredLane = stableLane(for: item.id, laneCount: anchoredLaneCount)
            let y = band.minY + laneHeight * (CGFloat(anchoredLane) + 0.5)
            return min(max(y, labelSize.height / 2), bounds.height - labelSize.height / 2)
        }
        let y = band.minY + laneHeight * (CGFloat(lane) + 0.5)
        return min(max(y, labelSize.height / 2), bounds.height - labelSize.height / 2)
    }

    private func laneIndex(
        for item: DanmakuItem,
        laneCount: Int,
        labelWidth: CGFloat,
        at itemTime: TimeInterval
    ) -> Int? {
        guard laneCount > 1, item.isScrolling else { return 0 }
        let startLane = stableLane(for: item.id, laneCount: laneCount)
        for offset in 0..<laneCount {
            let lane = (startLane + offset) % laneCount
            if (scrollingLaneStates[lane]?.releaseTime ?? 0) <= itemTime {
                scrollingLaneStates[lane] = LaneState(
                    releaseTime: itemTime + laneEntranceDelay(for: labelWidth),
                    itemWidth: labelWidth
                )
                return lane
            }
        }

        guard let earliest = scrollingLaneStates.min(by: { lhs, rhs in
            lhs.value.releaseTime < rhs.value.releaseTime
        }) else {
            return startLane
        }
        guard earliest.value.releaseTime - itemTime <= maxLaneOverlapTolerance else {
            return nil
        }
        scrollingLaneStates[earliest.key] = LaneState(
            releaseTime: itemTime + laneEntranceDelay(for: labelWidth),
            itemWidth: labelWidth
        )
        return earliest.key
    }

    private func laneEntranceDelay(for labelWidth: CGFloat) -> TimeInterval {
        let gap = bounds.width > 640 ? 40.0 : 30.0
        return DanmakuMotionTiming.laneEntranceDelay(
            surfaceWidth: bounds.width,
            labelWidth: labelWidth,
            duration: scrollDuration,
            gap: gap
        )
    }

    private var maxLaneOverlapTolerance: TimeInterval {
        bounds.width > 640 ? 0.16 : 0.10
    }

    private func displayDuration(for item: DanmakuItem) -> TimeInterval {
        item.isScrolling ? scrollDuration : settings.staticDuration
    }

    private func maximumDisplayDuration() -> TimeInterval {
        max(scrollDuration, settings.staticDuration)
    }

    private var scrollDuration: TimeInterval {
        settings.scrollingDuration
    }

    private var maxActiveCount: Int {
        let baseCount = bounds.width > 640 ? 44 : 24
        return max(isLoadShedding ? 5 : 8, Int(Double(baseCount) * adaptiveDanmakuLoadFactor))
    }

    private var maxSpawnPerTick: Int {
        let baseCount = bounds.width > 640 ? 6 : 4
        return max(1, Int(Double(baseCount) * adaptiveDanmakuLoadFactor))
    }

    private var adaptiveDanmakuLoadFactor: Double {
        let environment = renderEnvironment
        let loadSheddingFactor = isLoadShedding ? 0.46 : 1.0
        let rateFactor: Double
        if playbackRate >= 1.75 {
            rateFactor = 0.86
        } else if playbackRate > 1.15 {
            rateFactor = 0.92
        } else {
            rateFactor = 1.0
        }
        if environment.isThermallyConstrained || environment.isLowPowerModeEnabled {
            return min(settings.loadFactor, 0.50) * loadSheddingFactor * rateFactor
        }
        if environment.isThermallyElevated {
            return min(settings.loadFactor, 0.66) * loadSheddingFactor * rateFactor
        }
        if environment.shouldPreferConservativePlayback {
            return min(settings.loadFactor, 0.72) * loadSheddingFactor * rateFactor
        }
        return settings.loadFactor * loadSheddingFactor * rateFactor
    }

    private var preferredFrameRateRange: CAFrameRateRange {
        let environment = renderEnvironment
        if isLoadShedding || environment.isThermallyConstrained {
            return CAFrameRateRange(minimum: 10, maximum: 18, preferred: 14)
        }
        if environment.isThermallyElevated || environment.isLowPowerModeEnabled {
            return CAFrameRateRange(minimum: 10, maximum: 20, preferred: 16)
        }
        if playbackRate >= 1.75 {
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        }
        if playbackRate > 1.15 {
            return CAFrameRateRange(minimum: 24, maximum: 60, preferred: 48)
        }
        return CAFrameRateRange(minimum: 12, maximum: 24, preferred: 20)
    }

    private static let layoutSettlingRebuildDelays: [UInt64] = [
        0,
        120_000_000,
        280_000_000
    ]

    private static let timeBucketDuration: TimeInterval = 0.1

    private func fontSize(for item: DanmakuItem) -> CGFloat {
        let compactScale = bounds.width > 640 ? 0.86 : 0.70
        let maximumSize: CGFloat = bounds.width > 640 ? 24 : 18
        let minimumSize: CGFloat = bounds.width > 640 ? 15 : 13
        let scaledSize = CGFloat(item.fontSize) * compactScale * CGFloat(settings.fontScale)
        return min(max(scaledSize, minimumSize * 0.9), maximumSize * 1.35)
    }

    private func rebuildTimeBuckets() {
        timeBuckets.removeAll(keepingCapacity: true)
        timeBuckets.reserveCapacity(min(items.count, 600))
        for item in items {
            let bucketIndex = timeBucketIndex(for: item.time)
            if let lastIndex = timeBuckets.indices.last,
               timeBuckets[lastIndex].index == bucketIndex {
                timeBuckets[lastIndex].items.append(item)
            } else {
                timeBuckets.append(TimeBucket(index: bucketIndex, items: [item]))
            }
        }
        nextBucketIndex = 0
        nextBucketItemIndex = 0
    }

    private func setNextSpawnPosition(after playbackTime: TimeInterval) {
        guard !timeBuckets.isEmpty else {
            nextBucketIndex = 0
            nextBucketItemIndex = 0
            return
        }

        let nextItemIndex = firstItemIndex(after: playbackTime)
        guard nextItemIndex < items.count else {
            nextBucketIndex = timeBuckets.count
            nextBucketItemIndex = 0
            return
        }

        let bucketIndex = timeBucketIndex(for: items[nextItemIndex].time)
        nextBucketIndex = firstTimeBucketIndex(atOrAfter: bucketIndex)
        guard nextBucketIndex < timeBuckets.count else {
            nextBucketItemIndex = 0
            return
        }

        let bucketItems = timeBuckets[nextBucketIndex].items
        nextBucketItemIndex = bucketItems.firstIndex { $0.time > playbackTime } ?? bucketItems.count
        if nextBucketItemIndex >= bucketItems.count {
            advanceToNextBucket()
        }
    }

    private func advanceToNextBucket() {
        nextBucketIndex += 1
        nextBucketItemIndex = 0
    }

    private func isBucketTooStale(_ bucketIndex: Int, at playbackTime: TimeInterval) -> Bool {
        playbackTime - bucketEndTime(for: bucketIndex) > maximumBucketSpawnDelay
    }

    private var maximumBucketSpawnDelay: TimeInterval {
        if isLoadShedding {
            return 0.22
        }
        if renderEnvironment.isThermallyElevated {
            return 0.32
        }
        if playbackRate > 1.15 {
            return 0.50
        }
        return 0.48
    }

    private func timeBucketIndex(for time: TimeInterval) -> Int {
        Int((max(0, time) / Self.timeBucketDuration).rounded(.down))
    }

    private func bucketEndTime(for bucketIndex: Int) -> TimeInterval {
        TimeInterval(bucketIndex + 1) * Self.timeBucketDuration
    }

    private func firstTimeBucketIndex(atOrAfter bucketIndex: Int) -> Int {
        var lower = 0
        var upper = timeBuckets.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if timeBuckets[middle].index < bucketIndex {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func firstItemIndex(atOrAfter time: TimeInterval) -> Int {
        var lower = 0
        var upper = items.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if items[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func firstItemIndex(after time: TimeInterval) -> Int {
        var lower = 0
        var upper = items.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if items[middle].time <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func stableLane(for id: String, laneCount: Int) -> Int {
        guard laneCount > 1 else { return 0 }
        var hash: UInt64 = 5_381
        for scalar in id.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(laneCount))
    }

}

private final class DanmakuAnimationCompletionDelegate: NSObject, CAAnimationDelegate {
    private let completion: (Bool) -> Void
    private var isCancelled = false

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard !isCancelled else { return }
        completion(flag)
    }

    func cancel() {
        isCancelled = true
    }
}

private extension UIColor {
    static func danmakuRGB(_ rgb: UInt32) -> UIColor {
        let red = CGFloat((rgb >> 16) & 0xFF) / 255
        let green = CGFloat((rgb >> 8) & 0xFF) / 255
        let blue = CGFloat(rgb & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension DanmakuFontWeightOption {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }
}
