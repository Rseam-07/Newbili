import SwiftUI

struct VideoDescriptionIntelligenceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var sessionStore: SessionStore

    let bvid: String
    let cid: Int?
    let title: String
    let description: String
    let isPresented: Bool

    @State private var summary: VideoIntelligenceSummary?
    @State private var errorMessage: String?
    @State private var generationTask: Task<Void, Never>?

    private var availability: AppleIntelligenceAvailability {
        AppleIntelligenceAvailabilityService.current()
    }

    private var hasSourceContent: Bool {
        VideoTranscriptRequest(bvid: bvid, cid: cid) != nil
            || VideoIntelligenceSummaryInput(
                title: title,
                sourceText: description,
                source: .videoDescription
            ) != nil
    }

    var body: some View {
        Group {
            if isPresented, hasSourceContent, availability.isAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    if let summary {
                        Label(
                            summary.source.isTranscript ? "Apple 智能视频总结" : "Apple 智能观看导读",
                            systemImage: "apple.intelligence"
                        )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)

                        Text(summary.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        Label(summary.source.label, systemImage: summary.source.isTranscript ? "captions.bubble" : "doc.text")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(summary.source.isTranscript ? Color.secondary : Color.orange)
                            .accessibilityLabel("总结依据：\(summary.source.label)")

                        Text("总结由设备端 Apple 智能生成，字幕不会提交给云端模型。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Button("重新总结", action: generateSummary)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            .biliMinimumInteractiveTarget()
                    } else if generationTask != nil {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在读取字幕并在设备端总结…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                    } else {
                        Button(action: generateSummary) {
                            Label("用 Apple 智能总结视频", systemImage: "apple.intelligence")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityHint("优先使用 B站字幕，在设备端生成视频总结；没有字幕时明确降级为简介导读")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .top)))
            }
        }
        .onChange(of: sourceIdentity) { _, _ in
            generationTask?.cancel()
            generationTask = nil
            summary = nil
            errorMessage = nil
        }
        .onDisappear {
            generationTask?.cancel()
            generationTask = nil
        }
    }

    private var sourceIdentity: String {
        bvid + "\u{1F}" + String(cid ?? 0) + "\u{1F}" + title + "\u{1F}" + description
    }

    private func generateSummary() {
        generationTask?.cancel()
        summary = nil
        errorMessage = nil
        Haptics.light()

        let credentials = sessionStore.credentialSnapshot(
            for: .playback,
            multiAccountEnabled: libraryStore.multiAccountExperimentEnabled
        )
        let cookieHeader = credentials.isLoggedIn
            ? credentials.cookieHeader
            : credentials.anonymousCookieHeader

        generationTask = Task {
            do {
                let generated = try await VideoDescriptionIntelligenceService.shared.summarizeVideo(
                    bvid: bvid,
                    cid: cid,
                    title: title,
                    description: description,
                    cookieHeader: cookieHeader
                )
                guard !Task.isCancelled else { return }
                summary = generated
                Haptics.success()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                Haptics.medium()
            }
            generationTask = nil
        }
    }
}
