import SwiftUI

struct SurfaceOnlyDanmakuComposerPage: View {
    @ObservedObject var detailViewModel: VideoDetailViewModel
    let close: () -> Void

    @State private var text = ""
    @State private var mode = DanmakuPostMode.scrolling
    @State private var fontSize = 25
    @State private var color: UInt32 = 0xFFFFFF
    @State private var isSending = false
    @State private var errorMessage: String?

    private let colors: [UInt32] = [
        0xFFFFFF, 0xFE0302, 0xFF7204, 0xFFAA02,
        0xFFD302, 0xA0EE00, 0x00CD00, 0x019899,
        0x4266BE, 0x89D5FF, 0xCC0273, 0x222222
    ]

    var body: some View {
        Form {
            Section("内容") {
                TextField("发个友善的弹幕", text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > 100 {
                            text = String(newValue.prefix(100))
                        }
                    }

                HStack {
                    Text("将在当前播放位置发送")
                    Spacer()
                    Text("\(text.count)/100")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("样式") {
                Picker("位置", selection: $mode) {
                    ForEach(DanmakuPostMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Picker("字号", selection: $fontSize) {
                    Text("小").tag(18)
                    Text("标准").tag(25)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(colors, id: \.self) { value in
                        Button {
                            color = value
                        } label: {
                            Circle()
                                .fill(swiftUIColor(value))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle()
                                        .stroke(.primary.opacity(value == color ? 0.85 : 0.18), lineWidth: value == color ? 3 : 1)
                                }
                                .overlay {
                                    if value == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(value == 0xFFFFFF ? .black : .white)
                                    }
                                }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityLabel("弹幕颜色 \(String(format: "%06X", value))")
                    }
                }
                .padding(.vertical, 4)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    send()
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("发送弹幕", systemImage: "paperplane.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(!canSend)
            } footer: {
                if !detailViewModel.sessionStore.isLoggedIn {
                    Text("发送弹幕需要先登录。")
                }
            }
        }
        .navigationTitle("发送弹幕")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSend: Bool {
        detailViewModel.sessionStore.isLoggedIn
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
    }

    private func send() {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await detailViewModel.sendDanmaku(
                    text: text,
                    mode: mode,
                    fontSize: fontSize,
                    color: color
                )
                close()
            } catch {
                errorMessage = error.localizedDescription
                isSending = false
            }
        }
    }

    private func swiftUIColor(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
