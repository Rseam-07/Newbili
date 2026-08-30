import SwiftUI

struct DanmakuSettingsSheetContent: View {
    @ObservedObject var store: VideoDetailDanmakuSettingsRenderStore
    let summary: String
    @Binding var settings: DanmakuSettings
    let toggleDanmaku: () -> Void

    var body: some View {
        Form {
            DanmakuSettingsHeaderFormSection(
                store: store,
                summary: summary,
                toggleDanmaku: toggleDanmaku
            )

            DanmakuSettingsEditorSections(settings: $settings)
        }
    }
}

struct DanmakuSettingsEditorSections: View {
    @Binding var settings: DanmakuSettings

    var body: some View {
        DanmakuSettingsTypeFilterSection(settings: $settings)

        DanmakuSettingsFilterRulesSection(settings: $settings)

        DanmakuSettingsDisplayAreaSection(displayArea: $settings.displayArea)

        DanmakuSettingsPortraitVisibilitySection(
            hidesDanmakuInPortrait: $settings.hidesInPortrait
        )

        DanmakuSettingsTextSection(
            settings: settings,
            fontScale: $settings.fontScale,
            fontWeight: $settings.fontWeight,
            strokeWidth: $settings.strokeWidth
        )

        DanmakuSettingsOpacitySection(
            settings: settings,
            opacity: $settings.opacity
        )

        DanmakuSettingsMotionSection(
            settings: settings,
            scrollingDuration: $settings.scrollingDuration,
            staticDuration: $settings.staticDuration,
            lineHeight: $settings.lineHeight,
            loadFactor: $settings.loadFactor
        )
    }
}
