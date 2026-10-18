import SwiftUI

struct PlayerLoadingPlaceholder: View {
    @Environment(\.playerStartupArtworkURL) private var artworkURL
    let progress: Double
    let message: String
    let isFinishing: Bool
    var secondaryMessage: String? = nil
    var showsChromeSkeleton = false

    private var accessibilityMessage: String {
        if isFinishing {
            return "即将开始播放"
        }
        if let secondaryMessage {
            return "\(message)，\(secondaryMessage)"
        }
        return message
    }

    var body: some View {
        ZStack {
            if let artworkURL { PlayerStartupArtwork(url: artworkURL) }
            else { Color.black }

            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.regular)
                .tint(.white)
                .accessibilityLabel(accessibilityMessage)

            if showsChromeSkeleton {
                PlayerLoadingChromeSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
