import SwiftUI

struct DanmakuSettingsTextSection: View {
    let settings: DanmakuSettings
    @Binding var fontScale: Double
    @Binding var fontWeight: DanmakuFontWeightOption
    @Binding var strokeWidth: Double

    var body: some View {
        Section("文字") {
            DanmakuSettingsSlider(
                title: "字体大小",
                systemImage: "textformat.size",
                value: $fontScale,
                range: 0.5...2.5,
                step: 0.05,
                valueText: "\(Int((settings.fontScale * 100).rounded()))%"
            )

            Picker(selection: $fontWeight) {
                ForEach(DanmakuFontWeightOption.allCases) { weight in
                    Text(weight.title).tag(weight)
                }
            } label: {
                Label("字体粗细", systemImage: "bold")
            }
            .pickerStyle(.navigationLink)

            DanmakuSettingsSlider(
                title: "描边粗细",
                systemImage: "textformat",
                value: $strokeWidth,
                range: 0...5,
                step: 0.5,
                valueText: settings.strokeWidth.formatted(.number.precision(.fractionLength(1)))
            )
        }
    }
}
