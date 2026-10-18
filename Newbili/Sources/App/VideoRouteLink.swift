import SwiftUI

private struct OpenVideoActionKey: EnvironmentKey {
    static let defaultValue: ((VideoItem) -> Void)? = nil
}

private struct OpenLiveRoomActionKey: EnvironmentKey {
    static let defaultValue: ((LiveRoom) -> Void)? = nil
}

private struct PrewarmVideoRouteActionKey: EnvironmentKey {
    static let defaultValue: ((VideoItem) -> Void)? = nil
}

private struct OpenPgcSeasonRouteActionKey: EnvironmentKey {
    static let defaultValue: ((PgcSeasonRoute) -> Void)? = nil
}

private struct OpenVideoOwnerRouteActionKey: EnvironmentKey {
    static let defaultValue: ((VideoOwner) -> Void)? = nil
}

extension EnvironmentValues {
    var openVideoAction: ((VideoItem) -> Void)? {
        get { self[OpenVideoActionKey.self] }
        set { self[OpenVideoActionKey.self] = newValue }
    }

    var openLiveRoomAction: ((LiveRoom) -> Void)? {
        get { self[OpenLiveRoomActionKey.self] }
        set { self[OpenLiveRoomActionKey.self] = newValue }
    }

    var prewarmVideoRouteAction: ((VideoItem) -> Void)? {
        get { self[PrewarmVideoRouteActionKey.self] }
        set { self[PrewarmVideoRouteActionKey.self] = newValue }
    }

    var openPgcSeasonRouteAction: ((PgcSeasonRoute) -> Void)? {
        get { self[OpenPgcSeasonRouteActionKey.self] }
        set { self[OpenPgcSeasonRouteActionKey.self] = newValue }
    }

    var openVideoOwnerRouteAction: ((VideoOwner) -> Void)? {
        get { self[OpenVideoOwnerRouteActionKey.self] }
        set { self[OpenVideoOwnerRouteActionKey.self] = newValue }
    }
}

struct VideoOwnerRouteLink<Label: View>: View {
    let owner: VideoOwner
    @ViewBuilder let label: () -> Label
    @Environment(\.openVideoOwnerRouteAction) private var openVideoOwnerRoute

    var body: some View {
        if let openVideoOwnerRoute {
            Button {
                openVideoOwnerRoute(owner)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: owner) {
                label()
            }
            .buttonStyle(.plain)
        }
    }
}

struct VideoRouteLink<Label: View>: View {
    let video: VideoItem
    let onOpen: (() -> Void)?
    let showsPressFeedback: Bool
    @ViewBuilder let label: () -> Label
    @Environment(\.openVideoAction) private var openVideo
    @Environment(\.prewarmVideoRouteAction) private var prewarmVideoRoute
    @Environment(\.videoNavigationContext) private var navigationContext
    @State private var transitionSourceID = UUID()

    init(
        _ video: VideoItem,
        onOpen: (() -> Void)? = nil,
        showsPressFeedback: Bool = true,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.video = video
        self.onOpen = onOpen
        self.showsPressFeedback = showsPressFeedback
        self.label = label
    }

    var body: some View {
        if let navigationContext {
            VideoRouteTapLink(
                video: video,
                openVideo: { navigationContext.open($0, transitionSourceID) },
                prewarmVideoRoute: prewarmVideoRoute ?? navigationContext.prewarm,
                onOpen: onOpen,
                showsPressFeedback: showsPressFeedback,
                label: label
            )
            .modifier(VideoCardTransitionSource(sourceID: transitionSourceID))
        } else if let openVideo {
            VideoRouteTapLink(
                video: video,
                openVideo: openVideo,
                prewarmVideoRoute: prewarmVideoRoute,
                onOpen: onOpen,
                showsPressFeedback: showsPressFeedback,
                label: label
            )
        } else {
            NavigationLink(value: video) {
                label()
            }
            .buttonStyle(VideoRoutePrewarmButtonStyle {
                onOpen?()
                prewarmVideoRoute?(video)
            })
        }
    }
}

private struct VideoRouteTapLink<Label: View>: View {
    let video: VideoItem
    let openVideo: (VideoItem) -> Void
    let prewarmVideoRoute: ((VideoItem) -> Void)?
    let onOpen: (() -> Void)?
    let showsPressFeedback: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: open) {
            label()
        }
        .buttonStyle(
            VideoRouteTapPrewarmButtonStyle(showsPressFeedback: showsPressFeedback) {
                prewarmVideoRoute?(video)
            }
        )
    }

    private func open() {
        onOpen?()
        prewarmVideoRoute?(video)
        openVideo(video)
    }
}

private struct VideoRouteTapPrewarmButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let showsPressFeedback: Bool
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(showsPressFeedback && configuration.isPressed ? 0.92 : 1)
            .scaleEffect(showsPressFeedback && configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                showsPressFeedback
                    ? (reduceMotion ? .easeOut(duration: 0.08)
                        : configuration.isPressed ? .easeOut(duration: 0.07)
                        : .spring(response: 0.24, dampingFraction: 0.84))
                    : nil,
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                onPress()
            }
    }
}

private struct VideoRoutePrewarmButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.94 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : configuration.isPressed ? .easeOut(duration: 0.07) : .spring(response: 0.24, dampingFraction: 0.84), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                onPress()
            }
    }
}
