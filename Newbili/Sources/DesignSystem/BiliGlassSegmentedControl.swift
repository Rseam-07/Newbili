import SwiftUI

struct BiliGlassSegmentedControl<Option: Identifiable & Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    let select: (Option) -> Void
    var showsContainer = true
    var animation: Animation = .smooth(duration: 0.28)

    private var selectedIndex: Int {
        options.firstIndex(of: selected) ?? 0
    }

    private var activeAnimation: Animation? {
        reduceMotion ? nil : animation
    }

    @ViewBuilder
    var body: some View {
        if showsContainer {
            controlContent
                .biliBottomTabGlassEffect(interactive: false, in: Capsule())
        } else {
            controlContent
        }
    }

    private var controlContent: some View {
        GeometryReader { proxy in
            let segmentWidth = segmentWidth(in: proxy.size.width)

            ZStack(alignment: .leading) {
                if !options.isEmpty {
                    selectedCapsule(width: segmentWidth)
                        .offset(x: 3 + CGFloat(selectedIndex) * segmentWidth)
                }

                if options.count > 1 {
                    ForEach(1..<options.count, id: \.self) { boundary in
                        segmentDivider
                            .opacity(showsDivider(at: boundary) ? 1 : 0)
                            .offset(x: 3 + CGFloat(boundary) * segmentWidth)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(options) { option in
                        segmentButton(for: option)
                    }
                }
                .padding(3)
            }
        }
        .frame(height: 36)
        .animation(activeAnimation, value: selectedIndex)
        .accessibilityElement(children: .contain)
    }

    private func segmentWidth(in containerWidth: CGFloat) -> CGFloat {
        let contentWidth = max(containerWidth - 6, 0)
        return options.isEmpty ? 0 : contentWidth / CGFloat(options.count)
    }

    private func selectedCapsule(width: CGFloat) -> some View {
        Capsule()
            .fill(selectedFill)
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08),
                radius: 3,
                x: 0,
                y: 1
            )
            .frame(width: width, height: 30)
    }

    private var selectedFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color(.systemBackground).opacity(0.96)
    }

    private var segmentDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.12))
            .frame(width: 0.5, height: 18)
    }

    private func showsDivider(at boundary: Int) -> Bool {
        boundary != selectedIndex && boundary != selectedIndex + 1
    }

    private func segmentButton(for option: Option) -> some View {
        let isSelected = option == selected

        return Button {
            guard !isSelected else { return }
            withAnimation(activeAnimation) {
                select(option)
            }
        } label: {
            Text(title(option))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(Color.primary.opacity(isSelected ? 1 : 0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(option))
        .accessibilityValue(isSelected ? "已选中" : "")
    }
}
