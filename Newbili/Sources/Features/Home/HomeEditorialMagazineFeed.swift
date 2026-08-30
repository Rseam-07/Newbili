import SwiftUI

nonisolated enum HomeEditorialMagazinePlan {
    static let itemsPerGroup = 3

    static func ranges(totalCount: Int, startIndex: Int) -> [Range<Int>] {
        guard totalCount > startIndex, startIndex >= 0 else { return [] }
        return stride(from: startIndex, to: totalCount, by: itemsPerGroup).map { lowerBound in
            lowerBound..<min(lowerBound + itemsPerGroup, totalCount)
        }
    }
}

nonisolated enum HomeEditorialImagePolicy {
    static func maximumPixelLength(containerWidth: CGFloat) -> Int {
        containerWidth >= HomeEditorialLayoutPolicy.wideLayoutMinimumWidth ? 1_280 : 960
    }
}

struct HomeEditorialMagazineFeed: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let cells: [HomeVideoCellModel]
    let startIndex: Int
    let mode: HomeFeedMode
    let layout: HomeFeedLayout
    let containerWidth: CGFloat
    let imagePixelLength: Int
    let lastSeenMarkerCellIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    private var visibleRanges: [Range<Int>] {
        HomeEditorialMagazinePlan.ranges(
            totalCount: cells.count,
            startIndex: startIndex
        )
    }

    private var loadMoreTriggerCellID: String? {
        cells.last?.id
    }

    private var usesWideFeatureLayout: Bool {
        HomeEditorialLayoutPolicy.usesWideFeatureCard(containerWidth: containerWidth)
            && !dynamicTypeSize.isAccessibilitySize
    }

    private var usesBorder: Bool {
        switch layout {
        case .borderedDoubleColumn, .borderedSingleColumn:
            return true
        case .doubleColumn, .singleColumn:
            return false
        }
    }

    var body: some View {
        LazyVStack(spacing: containerWidth >= 700 ? 48 : 42) {
            ForEach(Array(visibleRanges.enumerated()), id: \.offset) { groupIndex, range in
                editorialGroup(groupIndex: groupIndex, range: range)
            }

            if isLoadingMore {
                ProgressView()
                    .tint(HomeEditorialPalette.primaryText)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .accessibilityLabel("正在加载更多推荐")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HomeEditorialLayoutPolicy.horizontalInset(containerWidth: containerWidth))
    }

    @ViewBuilder
    private func editorialGroup(groupIndex: Int, range: Range<Int>) -> some View {
        let groupCells = range.compactMap { index in
            cells.indices.contains(index) ? cells[index] : nil
        }

        VStack(alignment: .leading, spacing: 18) {
            HomeEditorialIssueHeader(
                ordinal: groupIndex + 1,
                mode: mode
            )

            if let feature = groupCells.first {
                markerIfNeeded(before: feature)

                card(
                    feature,
                    variant: .feature(ordinal: groupIndex + 1)
                )
            }

            let supporting = Array(groupCells.dropFirst())
            if !supporting.isEmpty {
                if dynamicTypeSize.isAccessibilitySize || !layout.isDoubleColumn || supporting.count == 1 {
                    VStack(spacing: 18) {
                        ForEach(supporting) { cell in
                            markerIfNeeded(before: cell)
                            card(cell, variant: .supporting)
                        }
                    }
                } else {
                    HomeEditorialSupportingPairLayout(
                        leadingFraction: supportingLeadingFraction(groupIndex: groupIndex),
                        spacing: 12
                    ) {
                        ForEach(supporting) { cell in
                            VStack(spacing: 12) {
                                markerIfNeeded(before: cell)
                                card(cell, variant: .supporting)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func markerIfNeeded(before cell: HomeVideoCellModel) -> some View {
        if lastSeenMarkerCellIndex == cell.index {
            HomeEditorialLastSeenMarker(action: actions.onRefreshFromLastSeenMarker)
        }
    }

    private func card(
        _ cell: HomeVideoCellModel,
        variant: HomeEditorialVideoCard.Variant
    ) -> some View {
        HomeEditorialVideoCard(
            cell: cell,
            mode: mode,
            variant: variant,
            imagePixelLength: imagePixelLength,
            usesEmphasizedBorder: usesBorder,
            usesWideFeatureLayout: usesWideFeatureLayout,
            wideFeatureHeight: HomeEditorialLayoutPolicy.wideFeatureCardHeight(containerWidth: containerWidth),
            actions: actions
        )
        .homeFeedCardLifecycle(
            cell: cell,
            loadMoreTriggerCellID: loadMoreTriggerCellID,
            actions: actions
        )
    }

    private func supportingLeadingFraction(groupIndex: Int) -> CGFloat {
        guard containerWidth >= HomeEditorialLayoutPolicy.wideLayoutMinimumWidth else { return 0.5 }
        return groupIndex.isMultiple(of: 2) ? 0.56 : 0.44
    }
}

private struct HomeEditorialIssueHeader: View {
    let ordinal: Int
    let mode: HomeFeedMode

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "%02d", ordinal))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(HomeEditorialPalette.accent)

            Text(mode == .popular ? "本期热榜" : "为你选片")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HomeEditorialPalette.secondaryText)

            Rectangle()
                .fill(HomeEditorialPalette.divider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeEditorialSupportingPairLayout: Layout {
    let leadingFraction: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        guard subviews.count > 1 else {
            return subviews[0].sizeThatFits(proposal)
        }
        let totalWidth = max(proposal.width ?? 0, spacing)
        let widths = itemWidths(totalWidth: totalWidth)
        let firstSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: widths.0, height: proposal.height)
        )
        let secondSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: widths.1, height: proposal.height)
        )
        return CGSize(width: totalWidth, height: max(firstSize.height, secondSize.height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }
        guard subviews.count > 1 else {
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
            return
        }
        let widths = itemWidths(totalWidth: bounds.width)
        subviews[0].place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: widths.0, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + widths.0 + spacing, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: widths.1, height: bounds.height)
        )
    }

    private func itemWidths(totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        let availableWidth = max(totalWidth - spacing, 0)
        let first = availableWidth * min(max(leadingFraction, 0.35), 0.65)
        return (first, max(availableWidth - first, 0))
    }
}

private struct HomeEditorialVideoCard: View {
    enum Variant {
        case feature(ordinal: Int)
        case supporting
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let cell: HomeVideoCellModel
    let mode: HomeFeedMode
    let variant: Variant
    let imagePixelLength: Int
    let usesEmphasizedBorder: Bool
    let usesWideFeatureLayout: Bool
    let wideFeatureHeight: CGFloat
    let actions: HomeFeedContentActions

    var body: some View {
        Button(action: open) {
            switch variant {
            case .feature(let ordinal):
                if usesWideFeatureLayout {
                    wideFeatureCard(ordinal: ordinal)
                } else {
                    compactFeatureCard(ordinal: ordinal)
                }
            case .supporting:
                supportingCard
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(
            PressPreloadButtonStyle(
                pressedScale: 0.988,
                pressedOpacity: 0.90,
                pressAnimation: .spring(duration: 0.24, bounce: 0.12)
            ) {
                actions.onVideoPress(cell.video)
            }
        )
        .hoverEffect(.highlight)
        .accessibilityLabel("\(cell.display.title)，\(cell.display.metadataSummaryText)")
        .accessibilityHint("轻点播放视频")
    }

    private func compactFeatureCard(ordinal: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cover(cornerRadius: 22)

            VStack(alignment: .leading, spacing: 7) {
                Text(featureKicker(ordinal: ordinal))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(HomeEditorialPalette.accent)

                Text(cell.display.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HomeEditorialPalette.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)

                Text(primaryMetadata)
                    .font(.subheadline)
                    .foregroundStyle(HomeEditorialPalette.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(usesEmphasizedBorder ? 12 : 0)
        .background(usesEmphasizedBorder ? HomeEditorialPalette.surface : .clear)
        .clipShape(RoundedRectangle(cornerRadius: usesEmphasizedBorder ? 26 : 0, style: .continuous))
        .overlay {
            if usesEmphasizedBorder {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(HomeEditorialPalette.divider, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    private func wideFeatureCard(ordinal: Int) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                cover(cornerRadius: 0, aspectRatio: nil)
                    .frame(width: geometry.size.width * 0.62, height: geometry.size.height)

                VStack(alignment: .leading, spacing: 12) {
                    Text(featureKicker(ordinal: ordinal))
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(HomeEditorialPalette.accent)

                    Text(cell.display.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HomeEditorialPalette.primaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(cell.display.authorName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HomeEditorialPalette.secondaryText)
                        .lineLimit(1)

                    Text("\(cell.display.viewText)次观看 · \(cell.display.publishTimeText)")
                        .font(.caption)
                        .foregroundStyle(HomeEditorialPalette.tertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Label("立即播放", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HomeEditorialPalette.selectedForeground)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(HomeEditorialPalette.selectedFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(HomeEditorialPalette.surface)
            }
        }
        .frame(height: wideFeatureHeight)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(usesEmphasizedBorder ? HomeEditorialPalette.strongDivider : HomeEditorialPalette.divider, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var supportingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            cover(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 5) {
                Text(cell.display.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeEditorialPalette.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)

                Text("\(cell.display.authorName) · \(cell.display.viewText)次观看")
                    .font(.caption)
                    .foregroundStyle(HomeEditorialPalette.tertiaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, usesEmphasizedBorder ? 10 : 0)
            .padding(.bottom, usesEmphasizedBorder ? 10 : 0)
        }
        .padding(usesEmphasizedBorder ? 4 : 0)
        .background(usesEmphasizedBorder ? HomeEditorialPalette.surface : .clear)
        .clipShape(RoundedRectangle(cornerRadius: usesEmphasizedBorder ? 18 : 0, style: .continuous))
        .overlay {
            if usesEmphasizedBorder {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HomeEditorialPalette.divider, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    private func cover(cornerRadius: CGFloat, aspectRatio: CGFloat? = 16.0 / 9.0) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                CachedRemoteImage(
                    url: editorialImageURL,
                    fallbackURL: cell.display.coverURL,
                    targetPixelSize: imagePixelLength,
                    animatesAppearance: false
                ) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    HomeEditorialPalette.elevatedSurface
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()

                Text(cell.display.durationText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 25)
                    .background(.black.opacity(0.84))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .padding(8)
            }
        }
        .modifier(HomeEditorialCoverRatioModifier(aspectRatio: aspectRatio))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(HomeEditorialPalette.divider, lineWidth: 0.75)
        }
    }

    private func featureKicker(ordinal: Int) -> String {
        let label = mode == .popular ? "热门" : "为你推荐"
        return "\(label) / \(String(format: "%02d", ordinal))"
    }

    private var primaryMetadata: String {
        "\(cell.display.authorName) · \(cell.display.viewText)次观看 · \(cell.display.publishTimeText)"
    }

    private var editorialImageURL: URL? {
        guard let source = cell.display.sourceCoverURL?.absoluteString else {
            return cell.display.largeCoverURL ?? cell.display.coverURL
        }
        return URL(string: source.biliImageThumbnailURL(maxSide: imagePixelLength))
            ?? cell.display.largeCoverURL
            ?? cell.display.coverURL
    }

    private func open() {
        if let onVideoSelect = actions.onVideoSelect {
            onVideoSelect(cell.video)
        } else {
            actions.onVideoTap(cell.video)
        }
    }
}

private struct HomeEditorialCoverRatioModifier: ViewModifier {
    let aspectRatio: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let aspectRatio {
            content.aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            content
        }
    }
}

private struct HomeEditorialLastSeenMarker: View {
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HomeEditorialPalette.accent)
                    .frame(width: 44, height: 44)
                    .background(HomeEditorialPalette.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("上次看到这里")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HomeEditorialPalette.primaryText)
                    Text("轻点刷新后续推荐")
                        .font(.caption)
                        .foregroundStyle(HomeEditorialPalette.secondaryText)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HomeEditorialPalette.tertiaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomeEditorialPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HomeEditorialPalette.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("上次看到这里，刷新推荐")
    }
}
