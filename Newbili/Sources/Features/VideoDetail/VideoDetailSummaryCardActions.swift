import Foundation

nonisolated enum VideoDetailSummaryCardLikeOutcome: Equatable {
    case liked
    case unliked
    case failed
}

nonisolated enum VideoDetailSummaryCardTripleOutcome: Equatable {
    case completed
    case alreadyCompleted
    case partial
    case failed
}

nonisolated enum VideoDetailSummaryCardFeedbackPolicy {
    static func likeOutcome(
        targetState: Bool,
        succeeded: Bool
    ) -> VideoDetailSummaryCardLikeOutcome {
        guard succeeded else { return .failed }
        return targetState ? .liked : .unliked
    }

    static func tripleOutcome(
        wasAlreadyCompleted: Bool,
        succeeded: Bool,
        isNowCompleted: Bool
    ) -> VideoDetailSummaryCardTripleOutcome {
        guard succeeded else { return .failed }
        guard !wasAlreadyCompleted else { return .alreadyCompleted }
        return isNowCompleted ? .completed : .partial
    }
}

@MainActor
private final class VideoDetailSummaryCardViewModelBox {
    weak var viewModel: VideoDetailViewModel?

    init(_ viewModel: VideoDetailViewModel) {
        self.viewModel = viewModel
    }
}

@MainActor
struct VideoDetailSummaryCardActions {
    private let viewModelBox: VideoDetailSummaryCardViewModelBox
    let showFavoriteFolders: () -> Void

    init(
        viewModel: VideoDetailViewModel,
        showFavoriteFolders: @escaping () -> Void
    ) {
        viewModelBox = VideoDetailSummaryCardViewModelBox(viewModel)
        self.showFavoriteFolders = showFavoriteFolders
    }

    func follow() {
        Haptics.light()
        Task { [weak viewModel = viewModelBox.viewModel] in
            guard let viewModel else { return }
            if await viewModel.toggleFollow() {
                Haptics.success()
            }
        }
    }

    func like(completion: @escaping (VideoDetailSummaryCardLikeOutcome) -> Void) {
        guard viewModelBox.viewModel != nil else {
            completion(.failed)
            return
        }
        Haptics.light()
        Task { [weak viewModel = viewModelBox.viewModel] in
            guard let viewModel else {
                completion(.failed)
                return
            }
            let outcome = await viewModel.toggleLike()
            completion(outcome)
        }
    }

    func triple(completion: @escaping (VideoDetailSummaryCardTripleOutcome) -> Void) {
        guard viewModelBox.viewModel != nil else {
            completion(.failed)
            return
        }
        Task { [weak viewModel = viewModelBox.viewModel] in
            guard let viewModel else {
                completion(.failed)
                return
            }
            let outcome = await viewModel.triple()
            if outcome == .completed {
                Haptics.success()
            }
            completion(outcome)
        }
    }

    func favorite() {
        Haptics.light()
        showFavoriteFolders()
    }

    func watchLater() {
        Haptics.light()
        Task { [weak viewModel = viewModelBox.viewModel] in
            guard let viewModel else { return }
            if await viewModel.addToWatchLater() {
                Haptics.success()
            }
        }
    }

    func share() {
        Haptics.light()
    }

    func retryPlayURL() {
        Task { [weak viewModel = viewModelBox.viewModel] in
            guard let viewModel else { return }
            await viewModel.retryPlayURL()
        }
    }
}
