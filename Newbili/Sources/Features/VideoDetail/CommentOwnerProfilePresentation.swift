import SwiftUI

private struct CommentOwnerProfileRoute: Identifiable, Hashable {
    let owner: VideoOwner

    var id: Int { owner.mid }
}

struct CommentOwnerProfileNavigationContainer<Content: View>: View {
    @State private var profileRoute: CommentOwnerProfileRoute?
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            content()
                .environment(\.openVideoOwnerRouteAction, openProfile)
                .navigationDestination(item: $profileRoute) { route in
                    UploaderView(
                        owner: route.owner,
                        hidesRootTabBar: false,
                        allowsPullToRefresh: false
                    )
                        .videoDestinations(hidesRootTabBar: false)
                }
        }
    }

    private func openProfile(_ owner: VideoOwner) {
        guard owner.mid > 0 else { return }

        profileRoute = CommentOwnerProfileRoute(owner: owner)
    }
}
