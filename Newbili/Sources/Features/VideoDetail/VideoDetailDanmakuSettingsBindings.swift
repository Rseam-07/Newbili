import SwiftUI

extension DanmakuSettingsSheet {
    var settingsSummary: String {
        if store.isDanmakuEnabled {
            return "当前使用 \(store.danmakuSettings.displayArea.title)，字号 \(Int((store.danmakuSettings.fontScale * 100).rounded()))%，不透明度 \(Int((store.danmakuSettings.opacity * 100).rounded()))%。"
        }
        return "弹幕已关闭，播放时不会显示滚动评论。"
    }

    var settingsBinding: Binding<DanmakuSettings> {
        Binding(
            get: { store.danmakuSettings },
            set: updateDanmakuSettings
        )
    }
}
