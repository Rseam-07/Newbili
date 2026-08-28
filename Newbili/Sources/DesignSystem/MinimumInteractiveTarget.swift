import SwiftUI

extension View {
    func biliMinimumInteractiveTarget(
        _ side: CGFloat = 44,
        alignment: Alignment = .center
    ) -> some View {
        frame(minWidth: side, minHeight: side, alignment: alignment)
            .contentShape(Rectangle())
    }
}
