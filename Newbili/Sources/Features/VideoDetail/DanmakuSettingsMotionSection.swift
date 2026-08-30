import SwiftUI

struct DanmakuSettingsMotionSection: View {
    let settings: DanmakuSettings
    @Binding var scrollingDuration: Double
    @Binding var staticDuration: Double
    @Binding var lineHeight: Double
    @Binding var loadFactor: Double

    var body: some View {
        Section("速度与密度") {
            DanmakuSettingsSlider(
                title: "滚动弹幕时长",
                systemImage: "arrow.right",
                value: $scrollingDuration,
                range: 1...50,
                step: 0.5,
                valueText: secondsText(settings.scrollingDuration)
            )

            DanmakuSettingsSlider(
                title: "静态弹幕时长",
                systemImage: "pause.rectangle",
                value: $staticDuration,
                range: 1...50,
                step: 0.5,
                valueText: secondsText(settings.staticDuration)
            )

            DanmakuSettingsSlider(
                title: "弹幕行高",
                systemImage: "arrow.up.and.down.text.horizontal",
                value: $lineHeight,
                range: 1...3,
                step: 0.1,
                valueText: settings.lineHeight.formatted(.number.precision(.fractionLength(1)))
            )

            DanmakuSettingsSlider(
                title: "弹幕密度",
                systemImage: "text.bubble.fill",
                value: $loadFactor,
                range: 0.35...1,
                step: 0.05,
                valueText: "\(Int((settings.loadFactor * 100).rounded()))%"
            )

            Text("播放倍速、低电量和设备温度过高时会在此基础上自动降载，避免弹幕拖慢视频和滑动。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func secondsText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) 秒"
    }
}
