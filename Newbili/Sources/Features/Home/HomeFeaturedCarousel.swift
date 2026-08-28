import SwiftUI

enum HomeFeaturedCarouselStyle: Equatable {
    case compact
    case cinematic(containerWidth: CGFloat, viewportHeight: CGFloat)

    var height: CGFloat {
        switch self {
        case .compact:
            270
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
        case .cinematic: 0
        }
    }

    var isCinematic: Bool {
        if case .cinematic = self { return true }
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
    let items: [HomeFeaturedItem]
    let mode: HomeFeedMode
    let style: HomeFeaturedCarouselStyle
    let actions: HomeFeedContentActions

    @State private var selectedID = ""
    @State private var isUserInteracting = false
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
                        mode: mode,
                        style: style,
                        actions: actions
                    )
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if items.count > 1 {
                HomeFeaturedPageControl(
                    items: items,
                    selectedID: selectedID,
                    onSelect: selectManually
                )
                .padding(.trailing, style.isCinematic ? 38 : 13)
                .padding(.bottom, style.isCinematic ? 38 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: style.height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: style.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            if !style.isCinematic {
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
        }
        .shadow(color: style.isCinematic ? .clear : .black.opacity(0.22), radius: 20, y: 10)
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

    private var autoplayIdentity: HomeFeaturedAutoplayIdentity {
        HomeFeaturedAutoplayIdentity(
            itemIDs: itemIDs,
            isEnabled: HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: items.count,
                isSceneActive: scenePhase == .active,
                isUserInteracting: isUserInteracting,
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
    let item: HomeFeaturedItem
    let position: Int
    let totalCount: Int
    let mode: HomeFeedMode
    let style: HomeFeaturedCarouselStyle
    let actions: HomeFeedContentActions

    var body: some View {
        Button {
            actions.onFeaturedVideoTap(item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    CachedRemoteImage(
                        url: item.cell.display.largeThumbnailURL(
                            fitting: geometry.size,
                            scale: displayScale,
                            maximumPixelLength: style.isCinematic ? 1_920 : 1_280
                        ),
                        targetPixelSize: item.cell.display.coverTargetPixelSize(
                            fitting: geometry.size,
                            scale: displayScale,
                            maximumPixelLength: style.isCinematic ? 1_920 : 1_280
                        ),
                        animatesAppearance: false
                    ) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [.pink.opacity(0.66), .indigo.opacity(0.52), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
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

                VStack(alignment: .leading, spacing: style.isCinematic ? 11 : 7) {
                    Text(sourceTitle)
                        .font(.caption.weight(.bold))
                        .tracking(style.isCinematic ? 1.25 : 0.5)
                        .foregroundStyle(.white.opacity(0.82))

                    Text(item.cell.display.title)
                        .font(titleFont)
                        .foregroundStyle(.white)
                        .lineLimit(style.isCinematic ? 2 : 2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: textMaximumWidth, alignment: .leading)

                    Text(metadata)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                        .frame(maxWidth: textMaximumWidth, alignment: .leading)

                    Label("立即观看", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, style.isCinematic ? 20 : 15)
                        .frame(height: style.isCinematic ? 45 : 38)
                        .background(.white, in: Capsule())
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
                pressedScale: style.isCinematic ? 0.992 : 0.985,
                pressedOpacity: 0.96,
                pressAnimation: .spring(duration: 0.28, bounce: 0.18)
            ) {
                actions.onVideoPress(item.cell.video)
            }
        )
        .accessibilityLabel(
            "\(sourceTitle)，\(item.cell.display.title)，\(item.cell.display.metadataSummaryText)，第 \(position + 1) 项，共 \(totalCount) 项"
        )
        .accessibilityHint("轻点打开视频；左右轻扫可切换推荐")
    }

    private var sourceTitle: String {
        if item.source == .popular { return "B站热门" }
        if mode == .popular { return "全站焦点" }
        return position == 0 ? "每日精选" : "为你推荐"
    }

    private var metadata: String {
        [
            item.cell.display.authorName,
            item.cell.display.viewText.isEmpty ? nil : item.cell.display.viewText + "次观看",
            item.cell.display.publishTimeText
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")
    }

    private var titleFont: Font {
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
        guard case .cinematic(let containerWidth, let viewportHeight) = style else { return 18 }
        if HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(viewportHeight: viewportHeight) {
            return min(max(containerWidth * 0.045, 28), 44)
        }
        return min(max(containerWidth * 0.050, 38), 72)
    }

    private var bottomPadding: CGFloat {
        guard case .cinematic(_, let viewportHeight) = style else { return 18 }
        if HomeCinematicWideLayoutPolicy.usesCompactCinemaHeight(viewportHeight: viewportHeight) {
            return 38
        }
        return min(max(style.height * 0.14, 62), 94)
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
                        .frame(width: item.id == selectedID ? 18 : 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if reduceTransparency {
                Capsule().fill(.black.opacity(0.76))
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    .white.opacity(colorSchemeContrast == .increased ? 0.62 : 0.12),
                    lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.5
                )
        }
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
