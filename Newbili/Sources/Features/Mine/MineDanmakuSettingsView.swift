import SwiftUI

struct MineDanmakuSettingsView: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Form {
            Section("交互") {
                MineDanmakuTapInteractionToggle(libraryStore: libraryStore)
            }

            Section {
                Text("这里保存的是视频和直播共用的默认弹幕参数；播放器内仍可即时调整，修改会同步回此处。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            DanmakuSettingsEditorSections(settings: settingsBinding)
        }
        .tint(libraryStore.appTintColor)
        .formStyle(.grouped)
        .navigationTitle("弹幕设置")
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
    }

    private var settingsBinding: Binding<DanmakuSettings> {
        Binding(
            get: { libraryStore.danmakuSettings },
            set: { libraryStore.setDanmakuSettings($0) }
        )
    }
}
