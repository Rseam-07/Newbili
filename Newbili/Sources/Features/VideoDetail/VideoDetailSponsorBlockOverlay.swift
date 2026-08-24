import SwiftUI

struct VideoDetailSponsorBlockOverlay: View {
    @ObservedObject var playerViewModel: PlayerStateViewModel
    @ObservedObject var libraryStore: LibraryStore
    let isLandscape: Bool

    var body: some View {
        Group {
            if let notice = playerViewModel.sponsorBlockSkipNotice {
                noticePill(notice)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let segment = playerViewModel.activeSponsorBlockSegment,
                      let presentation = presentation(for: segment) {
                activeSegmentPill(segment, presentation: presentation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, isLandscape ? 84 : 18)
        .padding(.bottom, isLandscape ? 92 : 62)
        .animation(.snappy(duration: 0.24), value: playerViewModel.activeSponsorBlockSegment?.id)
        .animation(.snappy(duration: 0.24), value: playerViewModel.sponsorBlockSkipNotice?.skippedAt)
    }

    private func activeSegmentPill(
        _ segment: SponsorBlockSegment,
        presentation: SponsorBlockBehavior
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: presentation == .skipManually ? "forward.end.fill" : "info.circle.fill")

            VStack(alignment: .leading, spacing: 1) {
                Text(segment.title)
                    .font(.subheadline.weight(.semibold))
                Text("片段 \(durationText(segment.duration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if presentation == .skipManually {
                Button("跳过") {
                    playerViewModel.skipActiveSponsorBlockSegment()
                }
                .font(.subheadline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, presentation == .skipManually ? 6 : 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private func noticePill(_ event: SponsorBlockSkipEvent) -> some View {
        Label {
            Text("已跳过\(event.segment.title) · \(durationText(event.segment.duration))")
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: "forward.end.fill")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        .allowsHitTesting(false)
    }

    private func presentation(for segment: SponsorBlockSegment) -> SponsorBlockBehavior? {
        let behavior = libraryStore.sponsorBlockPreferences.behavior(
            for: segment.category,
            duration: segment.duration
        )
        switch behavior {
        case .skipManually, .showOnly:
            return behavior
        case .alwaysSkip, .skipOnce, .disable:
            return nil
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        if duration < 10 {
            return String(format: "%.1f 秒", duration)
        }
        return "\(Int(duration.rounded())) 秒"
    }
}
