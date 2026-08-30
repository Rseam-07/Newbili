import Foundation

enum VideoDetailContentTab: String, CaseIterable, Identifiable {
    case detail
    case comments

    var id: Self { self }

    var title: String {
        switch self {
        case .detail:
            return "详情"
        case .comments:
            return "评论"
        }
    }

    var systemImage: String {
        switch self {
        case .detail:
            return "text.alignleft"
        case .comments:
            return "bubble.left.and.bubble.right"
        }
    }
}

enum VideoDetailContentVisibilityPolicy {
    static func resolvedSelection(
        _ selection: VideoDetailContentTab,
        showsComments: Bool
    ) -> VideoDetailContentTab {
        selection == .comments && !showsComments ? .detail : selection
    }

    static func showsRelatedVideos(
        isPGCEpisode: Bool,
        preferenceEnabled: Bool
    ) -> Bool {
        preferenceEnabled && !isPGCEpisode
    }

    static func automaticallyLoadsComments(
        hasCommentTarget: Bool,
        preferenceEnabled: Bool
    ) -> Bool {
        preferenceEnabled && hasCommentTarget
    }
}
