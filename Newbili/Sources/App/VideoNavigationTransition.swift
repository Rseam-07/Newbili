import SwiftUI

/// Identifies a particular card instance, not just a video: the same video can
/// occur in multiple tabs, shelves, and related lists at the same time.
struct VideoSourceRoute: Hashable {
    let video: VideoItem
    let sourceID: UUID
}

struct VideoNavigationContext {
    let namespace: Namespace.ID
    let open: (VideoItem, UUID) -> Void
    let prewarm: (VideoItem) -> Void
}

private struct VideoNavigationContextKey: EnvironmentKey {
    static let defaultValue: VideoNavigationContext? = nil
}

extension EnvironmentValues {
    var videoNavigationContext: VideoNavigationContext? {
        get { self[VideoNavigationContextKey.self] }
        set { self[VideoNavigationContextKey.self] = newValue }
    }
}

struct VideoCardTransitionSource: ViewModifier {
    @Environment(\.videoNavigationContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sourceID: UUID

    @ViewBuilder func body(content: Content) -> some View {
        if let context, !reduceMotion {
            content.matchedTransitionSource(id: sourceID, in: context.namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        } else {
            content
        }
    }
}

struct VideoCardDestinationTransition: ViewModifier {
    @Environment(\.videoNavigationContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sourceID: UUID

    @ViewBuilder func body(content: Content) -> some View {
        if let context, !reduceMotion {
            content.navigationTransition(.zoom(sourceID: sourceID, in: context.namespace))
        } else {
            content
        }
    }
}
