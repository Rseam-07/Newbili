import Combine
import SwiftUI
import UIKit

struct PlaybackSubtitleSettingsView: View {
    @ObservedObject var model: PlaybackSubtitleModel

    var body: some View {
        Form {
            Section {
                Toggle("显示字幕", isOn: Binding(get: { model.isEnabled }, set: model.setEnabled))
                if model.tracksState.isLoading {
                    HStack { ProgressView(); Text("正在获取字幕").foregroundStyle(.secondary) }
                } else if case .failed(let message) = model.tracksState {
                    retryRow(message)
                } else if model.tracksState == .loaded, model.tracks.isEmpty {
                    Label("这个视频暂时没有可用字幕", systemImage: "captions.bubble")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.tracks, id: \.selectionKey) { track in
                    Button { model.select(track) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.displayTitle).foregroundStyle(.primary)
                                if track.isAIGenerated {
                                    Text("自动生成").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if model.isEnabled, model.selectedTrack == track {
                                if model.cuesState.isLoading { ProgressView() }
                                else { Image(systemName: "checkmark").fontWeight(.semibold) }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
                if case .failed(let message) = model.cuesState { retryRow(message) }
            } header: { Text("字幕语言") }

            if model.isEnabled {
                Section("显示") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("字号"); Spacer(); Text("\(Int(model.fontScale * 100))%").foregroundStyle(.secondary).monospacedDigit() }
                        Slider(value: Binding(get: { model.fontScale }, set: model.setFontScale), in: 0.8...1.5, step: 0.05)
                            .accessibilityLabel("字幕字号")
                        Text("字幕预览 · Newbili")
                            .font(.system(size: 16 * model.fontScale, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(AppSurfaceColors.groupedPage, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Stepper(value: Binding(get: { model.delay }, set: model.setDelay), in: -10...10, step: 0.1) {
                        HStack {
                            Text("时间校准")
                            Spacer()
                            Text(model.delay, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))
                                .monospacedDigit().foregroundStyle(.secondary)
                            Text("秒").foregroundStyle(.secondary)
                        }
                    }
                    if abs(model.delay) > 0.01 {
                        Button("重置时间校准") { model.setDelay(0) }
                    }
                }
                Section {
                    Text("正值让字幕晚一点出现，负值让字幕提前。切换分 P 后自动恢复原始时间；语言和字号会保留。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("字幕")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppSurfaceColors.groupedPage)
        .task { model.loadTracksIfNeeded() }
    }

    private func retryRow(_ message: String) -> some View {
        HStack {
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("重试", action: model.retry)
        }
    }
}

/// Clock updates stay inside this leaf UIKit view. They never invalidate the
/// SwiftUI player chrome, comment list, or enclosing navigation hierarchy.
struct PlaybackSubtitleOverlay: UIViewRepresentable {
    let model: PlaybackSubtitleModel
    let clock: PlayerPlaybackClock
    let bottomInset: CGFloat

    func makeUIView(context: Context) -> SubtitleCanvas {
        let canvas = SubtitleCanvas()
        canvas.bind(model: model, clock: clock)
        return canvas
    }

    func updateUIView(_ canvas: SubtitleCanvas, context: Context) {
        canvas.bind(model: model, clock: clock)
        canvas.bottomInset = bottomInset
    }

    static func dismantleUIView(_ canvas: SubtitleCanvas, coordinator: ()) {
        canvas.unbind()
    }

    final class SubtitleCanvas: UIView {
        private let label = InsetSubtitleLabel()
        private weak var model: PlaybackSubtitleModel?
        private weak var clock: PlayerPlaybackClock?
        private var subscriptions = Set<AnyCancellable>()
        private var time: TimeInterval = 0
        var bottomInset: CGFloat = 12 { didSet { if oldValue != bottomInset { setNeedsLayout() } } }

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            label.textAlignment = .center
            label.textColor = .white
            label.backgroundColor = UIColor.black.withAlphaComponent(0.56)
            label.layer.cornerRadius = 7
            label.layer.masksToBounds = true
            label.numberOfLines = 4
            label.isHidden = true
            label.isAccessibilityElement = true
            addSubview(label)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func bind(model: PlaybackSubtitleModel, clock: PlayerPlaybackClock) {
            guard self.model !== model || self.clock !== clock else { return }
            subscriptions.removeAll()
            self.model = model
            self.clock = clock
            time = clock.currentTime
            clock.$currentTime.sink { [weak self] time in
                self?.time = time
                self?.refreshText()
            }.store(in: &subscriptions)
            model.objectWillChange.sink { [weak self] in
                DispatchQueue.main.async { [weak self] in self?.refreshText() }
            }.store(in: &subscriptions)
            refreshText()
        }

        func unbind() { subscriptions.removeAll(); model = nil; clock = nil }

        private func refreshText() {
            guard let model else { return }
            let text = model.isEnabled ? model.timeline.text(at: time - model.delay) : ""
            let size = CGFloat(16 * model.fontScale)
            guard text != label.text || label.font.pointSize != size else { return }
            label.text = text
            label.font = .systemFont(ofSize: size, weight: .medium)
            label.isHidden = text.isEmpty
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let availableWidth = max(1, bounds.width - 32)
            let size = label.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
            let width = min(availableWidth, size.width)
            let height = min(size.height, max(0, bounds.height - bottomInset - 8))
            label.frame = CGRect(x: (bounds.width - width) / 2,
                                 y: max(8, bounds.height - bottomInset - height), width: width, height: height)
        }
    }
}

private final class InsetSubtitleLabel: UILabel {
    private let padding = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: padding)) }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let measured = super.sizeThatFits(CGSize(width: max(1, size.width - padding.left - padding.right), height: size.height))
        return CGSize(width: measured.width + padding.left + padding.right, height: measured.height + padding.top + padding.bottom)
    }
}
