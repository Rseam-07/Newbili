import SwiftUI

private struct PlayerStartupArtworkURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

extension EnvironmentValues {
    var playerStartupArtworkURL: URL? {
        get { self[PlayerStartupArtworkURLKey.self] }
        set { self[PlayerStartupArtworkURLKey.self] = newValue }
    }
}

extension VideoItem {
    var playbackArtworkURL: URL? {
        pic.flatMap { URL(string: $0.normalizedBiliURL().biliCoverThumbnailURL(width: 960, height: 540)) }
    }
}

struct PlayerStartupArtwork: View {
    let url: URL
    var body: some View {
        GeometryReader { geometry in
            CachedRemoteImage(url: url, targetPixelSize: 960, animatesAppearance: false) { image in
                image.resizable().scaledToFill()
            } placeholder: { Color.black }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay {
                LinearGradient(colors: [.black.opacity(0.22), .black.opacity(0.08), .black.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
