import SwiftUI

nonisolated enum HomeFeaturedCarouselStyle: Equatable, Sendable {
    case compact
    case editorial(containerWidth: CGFloat, viewportHeight: CGFloat)
    case cinematic(containerWidth: CGFloat, viewportHeight: CGFloat)

    var height: CGFloat {
        switch self {
        case .compact:
            270
        case .editorial(let containerWidth, let viewportHeight):
            HomeEditorialLayoutPolicy.heroHeight(
                containerWidth: containerWidth,
                viewportHeight: viewportHeight
            )
        case .cinematic(let containerWidth, let viewportHeight):
            HomeCinematicWideLayoutPolicy.heroHeight(
                containerWidth: containerWidth,
                viewportHeight: viewportHeight
            )
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 28
        case .editorial(let containerWidth, _):
            HomeEditorialLayoutPolicy.heroCornerRadius(containerWidth: containerWidth)
        case .cinematic: 0
        }
    }

    var isCinematic: Bool {
        if case .cinematic = self { return true }
        return false
    }

    var isEditorial: Bool {
        if case .editorial = self { return true }
        return false
    }
}

private struct HomeFeaturedAutoplayIdentity: Hashable {
    let itemIDs: [String]
    let isEnabled: Bool
    let interactionRevision: Int
}

struct HomeFeaturedCarousel: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [HomeFeaturedItem]
    let mode: HomeFeedMode
    let style: HomeFeaturedCarouselStyle
    let actions: HomeFeedContentActions

    @State private var selectedID = ""
    @State private var isUserInteracting = false
    @State private var isAutoplayPaused = false
    @State private var interactionRevision = 0
    @State private var isPresented = false
    @State private var activeExposure: HomeFeaturedItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedID) {
                ForEach(items) { item in
                    HomeFeaturedSlide(
                        item: item,
                        position: position(of: item.id),
                        totalCount: items.count,
                        isSelected: item.id == selectedID,
                        mode: mode,
                        style: style,
                        actions: actions
                    )
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if items.count > 1 {
                if style.isEditorial {
                    HomeEditorialCarouselControls(
                        selectedIndex: position(of: selectedID),
                        itemCount: items.count,
                        isPaused: isAutoplayPaused,
                        onPrevious: selectPrevious,
                        onTogglePlayback: { isAutoplayPaused.toggle() },
                        onNext: selectNext
                    )
                    .padding(.trailing, 14)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } else {
                    HomeFeaturedPageControl(
                        items: items,
                        selectedID: selectedID,
                        onSelect: selectManually
                    )
                    .padding(.trailing, style.isCinematic ? 38 : 13)
                    .padding(.bottom, style.isCinematic ? 38 : 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: carouselHeight)
        .clipShape(HomeFeaturedCarouselShape(style: style))
        .overlay {
            if !style.isCinematic {
                HomeFeaturedCarouselShape(style: style)
                    .stroke(
                        style.isEditorial
                            ? AnyShapeStyle(HomeEditorialPalette.divider)
                            : AnyShapeStyle(.white.opacity(0.16)),
                        lineWidth: 1
                    )
            }
        }
        .shadow(
            color: style.isCinematic
                ? .clear
                : style.isEditorial
                ? .clear
                : .black.opacity(0.22),
            radius: 20,
            x: style.isEditorial ? -8 : 0,
            y: style.isEditorial ? 16 : 10
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in
                    guard !isUserInteracting else { return }
                    isUserInteracting = true
                }
                .onEnded { _ in
                    isUserInteracting = false
                    interactionRevision &+= 1
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("首页焦点推荐")
        .accessibilityValue(accessibilityPageValue)
        .accessibilityAdjustableAction(adjustSelection)
        .onAppear {
            isPresented = true
            normalizeSelection()
            synchronizeExposure()
        }
        .onDisappear {
            isPresented = false
            endExposure()
        }
        .onChange(of: itemIDs) { _, _ in
            normalizeSelection()
            synchronizeExposure()
        }
        .onChange(of: selectedID) { _, _ in
            synchronizeExposure()
        }
        .task(id: autoplayIdentity) {
            guard autoplayIdentity.isEnabled else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(6))
                } catch {
                    return
                }
                guard !Task.isCancelled, autoplayIdentity.isEnabled else { return }
                advanceAutomatically()
            }
        }
    }

    private var itemIDs: [String] {
        items.map(\.id)
    }

    private var carouselHeight: CGFloat {
        guard style.isEditorial, dynamicTypeSize.isAccessibilitySize else { return style.height }
        return max(style.height, 420)
    }

    private var autoplayIdentity: HomeFeaturedAutoplayIdentity {
        HomeFeaturedAutoplayIdentity(
            itemIDs: itemIDs,
            isEnabled: HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: items.count,
                isSceneActive: scenePhase == .active,
                isUserInteracting: isUserInteracting,
                isPausedByUser: isAutoplayPaused,
                reduceMotion: reduceMotion,
                voiceOverEnabled: voiceOverEnabled
            ),
            interactionRevision: interactionRevision
        )
    }

    private var accessibilityPageValue: String {
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return "" }
        return "第 \(index + 1) 项，共 \(items.count) 项"
    }

    private func position(of id: String) -> Int {
        items.firstIndex(where: { $0.id == id }) ?? 0
    }

    private func normalizeSelection() {
        guard let firstID = items.first?.id else {
            selectedID = ""
            return
        }
        guard items.contains(where: { $0.id == selectedID }) else {
            selectedID = firstID
            return
        }
    }

    private func advanceAutomatically() {
        guard let nextID = HomeFeaturedMixPolicy.nextID(in: itemIDs, after: selectedID) else { return }
        withAnimation(.smooth(duration: 0.48)) {
            selectedID = nextID
        }
    }

    private func selectManually(_ id: String) {
        guard id != selectedID else { return }
        interactionRevision &+= 1
        if reduceMotion {
            selectedID = id
        } else {
            withAnimation(.smooth(duration: 0.32)) {
                selectedID = id
            }
        }
    }

    private func selectNext() {
        guard let destination = HomeFeaturedMixPolicy.nextID(in: itemIDs, after: selectedID) else { return }
        selectManually(destination)
    }

    private func selectPrevious() {
        guard let destination = HomeFeaturedMixPolicy.previousID(in: itemIDs, before: selectedID) else { return }
        selectManually(destination)
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let destination: String?
        switch direction {
        case .increment:
            destination = HomeFeaturedMixPolicy.nextID(in: itemIDs, after: selectedID)
        case .decrement:
            destination = HomeFeaturedMixPolicy.previousID(in: itemIDs, before: selectedID)
        @unknown default:
            destination = nil
        }
        guard let destination else { return }
        selectManually(destination)
    }

    private func synchronizeExposure() {
        guard isPresented,
              let selected = items.first(where: { $0.id == selectedID }),
              activeExposure?.id != selected.id
        else { return }
        endExposure()
        activeExposure = selected
        actions.onFeaturedCardAppear(selected)
    }

    private func endExposure() {
        guard let activeExposure else { return }
        actions.onFeaturedCardDisappear(activeExposure)
        self.activeExposure = nil
    }
}

private struct HomeFeaturedSlide: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: HomeFeaturedItem
    let position: Int
    let totalCount: Int
    let isSelected: Bool
    let mode: HomeFeedMode
    let style: HomeFeaturedCarouselStyle
    let actions: HomeFeedContentActions

    var body: some View {
        Button {
            actions.onFeaturedItemTap(item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    CachedRemoteImage(
                        url: item.cell.display.largeThumbnailURL(
                            fitting: geometry.size,
                            scale: displayScale,
                            maximumPixelLength: style.isCinematic ? 1_920 : style.isEditorial ? 1_440 : 1_280
                        ),
                        targetPixelSize: item.cell.display.coverTargetPixelSize(
                            fitting: geometry.size,
                            scale: displayScale,
                            maximumPixelLength: style.isCinematic ? 1_920 : style.isEditorial ? 1_440 : 1_280
                        ),
                        animatesAppearance: false
                    ) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        if style.isEditorial {
                            HomeEditorialPalette.elevatedSurface
                        } else {
                            LinearGradient(
                                colors: [.pink.opacity(0.66), .indigo.opacity(0.52), .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(editorialImageScale)
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.86),
                        value: isSelected
                    )
                    .clipped()
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: style.isCinematic ? 0.28 : 0.20),
                        .init(color: .black.opacity(0.20), location: 0.54),
                        .init(color: .black.opacity(0.90), location: 0.94),
                        .init(color: .black.opacity(0.96), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if style.isCinematic {
                    LinearGradient(
                        colors: [.black.opacity(0.78), .black.opacity(0.24), .clear],
                        startPoint: .leading,
                        endPoint: UnitPoint(x: 0.76, y: 0.5)
                    )
                }

                if style.isEditorial, !dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(HomeEditorialPalette.accent)
                                .frame(width: 2, height: 18)

                            Text(sourceTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)

                            Spacer(minLength: 0)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(18)
                }

                VStack(alignment: .leading, spacing: style.isCinematic ? 11 : style.isEditorial ? 9 : 7) {
                    if !style.isEditorial {
                        Text(sourceTitle)
                            .font(.caption.weight(.bold))
                            .tracking(style.isCinematic ? 1.25 : 0.5)
                            .foregroundStyle(.white.opacity(0.82))
                    }

                    Text(item.cell.display.title)
                        .font(titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(style.isEditorial && dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .frame(maxWidth: textMaximumWidth, alignment: .leading)

                    Text(metadata)
                        .font(style.isEditorial ? .caption.weight(.semibold) : .subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(style.isEditorial && dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .frame(maxWidth: textMaximumWidth, alignment: .leading)

                    HStack(spacing: 8) {
                        Image(systemName: item.source == .activity ? "sparkles" : "play.fill")
                        Text(item.source == .activity ? "查看活动" : "立即观看")
                    }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, style.isCinematic ? 20 : 15)
                        .padding(.vertical, style.isEditorial ? 10 : 0)
                        .frame(minHeight: style.isCinematic ? 45 : style.isEditorial ? 44 : 38)
                        .background {
                            if style.isEditorial {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(HomeEditorialPalette.selectedFill)
                            } else {
                                Capsule().fill(.white)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, style.isCinematic ? 3 : 1)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonStyle(
            PressPreloadButtonStyle(
                pressedScale: style.isCinematic ? 0.992 : style.isEditorial ? 0.988 : 0.985,
                pressedOpacity: 0.96,
                pressAnimation: .spring(duration: 0.28, bounce: 0.18)
            ) {
                if let video = item.preloadVideo {
                    actions.onVideoPress(video)
                }
            }
        )
        .accessibilityLabel(
            "\(sourceTitle)，\(item.cell.display.title)，\(item.cell.display.metadataSummaryText)，第 \(position + 1) 项，共 \(totalCount) 项"
        )
        .accessibilityHint(item.source == .activity ? "轻点打开活动；左右轻扫可切换推荐" : "轻点打开视频；左右轻扫可切换推荐")
    }

    private var sourceTitle: String {
        if item.source == .activity { return "B站活动" }
        if item.source == .popular { return "B站热门" }
        if mode == .popular { return "全站焦点" }
        if style.isEditorial { return "为你推荐" }
        return position == 0 ? "每日精选" : "为你推荐"
    }

    private var editorialImageScale: CGFloat {
        guard style.isEditorial, !reduceMotion else { return 1 }
        return isSelected ? 1.012 : 1
    }

    private var metadata: String {
        if item.source == .activity {
            return "哔哩哔哩  ·  官方专题"
        }
        return [
            item.cell.display.authorName,
            item.cell.display.viewText.isEmpty ? nil : item.cell.display.viewText + "次观看",
            item.cell.display.publishTimeText
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")
    }

    private var titleFont: Font {
        if style.isEditorial {
            return .system(.title2, design: .default, weight: .bold)
        }
        guard case .cinematic(let containerWidth, let viewportHeight) = style else {
            return .title2.bold()
        }
        let isCompactHeight = HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(
            viewportHeight: viewportHeight
        )
        let size = isCompactHeight
            ? min(max(containerWidth * 0.031, 26), 34)
            : min(max(containerWidth * 0.038, 31), 52)
        return .system(size: size, weight: .bold)
    }

    private var textMaximumWidth: CGFloat? {
        guard case .cinematic(let containerWidth, _) = style else { return nil }
        return min(containerWidth * 0.58, 680)
    }

    private var horizontalPadding: CGFloat {
        if style.isEditorial { return 22 }
        guard case .cinematic(let containerWidth, let viewportHeight) = style else { return 18 }
        if HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(viewportHeight: viewportHeight) {
            return min(max(containerWidth * 0.045, 28), 44)
        }
        return min(max(containerWidth * 0.050, 38), 72)
    }

    private var bottomPadding: CGFloat {
        if style.isEditorial { return 22 }
        guard case .cinematic(_, let viewportHeight) = style else { return 18 }
        if HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(viewportHeight: viewportHeight) {
            return 38
        }
        return min(max(style.height * 0.14, 62), 94)
    }
}

nonisolated private struct HomeFeaturedCarouselShape: Shape {
    let style: HomeFeaturedCarouselStyle

    nonisolated func path(in rect: CGRect) -> Path {
        if style.isEditorial {
            return RoundedRectangle(
                cornerRadius: style.cornerRadius,
                style: .continuous
            )
            .path(in: rect)
        }
        return RoundedRectangle(
            cornerRadius: style.cornerRadius,
            style: .continuous
        )
        .path(in: rect)
    }
}

private struct HomeEditorialCarouselControls: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let selectedIndex: Int
    let itemCount: Int
    let isPaused: Bool
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(pageText)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.leading, 12)
                .padding(.trailing, 8)

            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(width: 1, height: 16)

            controlButton(
                systemImage: "chevron.left",
                accessibilityLabel: "上一项",
                action: onPrevious
            )
            controlButton(
                systemImage: isPaused ? "play.fill" : "pause.fill",
                accessibilityLabel: isPaused ? "继续自动切换" : "暂停自动切换",
                action: onTogglePlayback
            )
            controlButton(
                systemImage: "chevron.right",
                accessibilityLabel: "下一项",
                action: onNext
            )
        }
        .background(
            .black.opacity(reduceTransparency ? 0.88 : 0.58),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
    }

    private var pageText: String {
        String(format: "%02d / %02d", selectedIndex + 1, itemCount)
    }

    private func controlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HomeFeaturedPageControl: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let items: [HomeFeaturedItem]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        Button(action: selectNext) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    Capsule()
                        .fill(.white.opacity(item.id == selectedID ? 0.96 : 0.38))
                        .frame(
                            width: item.id == selectedID ? 16 : 5,
                            height: 5
                        )
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background {
                if reduceTransparency {
                    Capsule().fill(.black.opacity(0.76))
                } else {
                    Capsule().fill(.black.opacity(0.30))
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        .white.opacity(colorSchemeContrast == .increased ? 0.62 : 0.14),
                        lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.5
                    )
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("轮播页码")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("轻点切换到下一项，或上下轻扫调整")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selectNext()
            case .decrement:
                selectPrevious()
            @unknown default:
                break
            }
        }
    }

    private var selectedIndex: Int {
        items.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    private var accessibilityValue: String {
        "第 \(selectedIndex + 1) 项，共 \(items.count) 项"
    }

    private func selectNext() {
        guard let nextID = HomeFeaturedMixPolicy.nextID(
            in: items.map(\.id),
            after: selectedID
        ) else { return }
        onSelect(nextID)
    }

    private func selectPrevious() {
        guard let previousID = HomeFeaturedMixPolicy.previousID(
            in: items.map(\.id),
            before: selectedID
        ) else { return }
        onSelect(previousID)
    }
}
