import SwiftUI

struct CommentComposerBar: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let placeholder: String
    let submissionState: LoadingState
    let submit: (String) async -> Bool

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var normalizedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !normalizedDraft.isEmpty
            && normalizedDraft.count <= 1_000
            && !submissionState.isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if case .failed(let message) = submissionState {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .accessibilityLabel("发送失败：\(message)")
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: send) {
                    Group {
                        if submissionState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.white)
                    .background(appTintColor, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit || submissionState.isLoading ? 1 : 0.45)
                .accessibilityLabel(submissionState.isLoading ? "正在发送评论" : "发送评论")
            }

            if normalizedDraft.count > 900 {
                Text("\(normalizedDraft.count)/1000")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(normalizedDraft.count > 1_000 ? Color.red : Color.gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let message = normalizedDraft
        guard canSubmit else { return }
        Task {
            if await submit(message) {
                draft = ""
                isFocused = false
            }
        }
    }
}
