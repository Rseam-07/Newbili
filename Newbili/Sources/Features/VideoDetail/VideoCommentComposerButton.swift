import SwiftUI

struct VideoCommentComposerButton: View {
    @Environment(\.videoCommentComposerContext) private var context
    var root: Comment? = nil
    var parent: Comment? = nil
    var iconOnly = false
    @State private var submission: VideoCommentSubmissionModel?

    var body: some View {
        if let context {
            Button {
                submission = context.makeSubmission(root: root, parent: parent)
            } label: {
                if iconOnly {
                    Image(systemName: "square.and.pencil")
                } else {
                    Label(root == nil && parent == nil ? "写评论" : "回复", systemImage: "arrowshape.turn.up.left")
                }
            }
            .buttonStyle(.plain)
            .biliMinimumInteractiveTarget(alignment: .leading)
            .accessibilityLabel(root == nil && parent == nil ? "写评论" : "回复 \((parent ?? root)?.member?.uname ?? "这条评论")")
            .sheet(item: $submission) { model in VideoCommentComposerSheet(model: model) }
        }
    }
}

private struct VideoCommentComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: VideoCommentSubmissionModel
    @FocusState private var isFocused: Bool
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let name = model.recipientName, !name.isEmpty {
                    Label("回复 @\(name)", systemImage: "arrowshape.turn.up.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                TextEditor(text: $model.draft)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppSurfaceColors.groupedCard, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel(model.rootID == nil ? "评论内容" : "回复内容")
                    .disabled(model.state.isLoading)
                HStack {
                    if case .failed(let message) = model.state {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer(minLength: 12)
                    Text("\(model.normalizedDraft.count)/1000")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(model.normalizedDraft.count > 1_000 ? Color.red : Color.secondary)
                }
            }
            .padding(16)
            .background(AppSurfaceColors.groupedPage)
            .navigationTitle(model.rootID == nil ? "发表评论" : "回复评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if model.draft.isEmpty { dismiss() } else { confirmsDiscard = true }
                    }
                    .disabled(model.state.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if await model.submit() { dismiss() } }
                    } label: {
                        if model.state.isLoading { ProgressView() } else { Text("发送").fontWeight(.semibold) }
                    }
                    .disabled(!model.canSubmit)
                    .accessibilityLabel(model.state.isLoading ? "正在发送" : "发送评论")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(model.state.isLoading || !model.draft.isEmpty)
        .confirmationDialog("放弃这份评论草稿？", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("放弃草稿", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        }
        .task { isFocused = true }
    }
}
