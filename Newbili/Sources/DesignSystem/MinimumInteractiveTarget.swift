import SwiftUI

nonisolated enum BiliInteractiveTarget {
    static let minimumSide: CGFloat = 44
}

extension View {
    func biliMinimumInteractiveTarget(
        _ side: CGFloat = BiliInteractiveTarget.minimumSide,
        alignment: Alignment = .center
    ) -> some View {
        frame(minWidth: side, minHeight: side, alignment: alignment)
            .contentShape(Rectangle())
    }
}
