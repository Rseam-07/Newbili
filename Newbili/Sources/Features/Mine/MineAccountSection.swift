import SwiftUI

struct MineAccountSection: View {
    let display: MineAccountProfileDisplayModel
    let profileState: LoadingState
    let loginMessage: String
    let isLoggedIn: Bool
    let multiAccountExperimentEnabled: Bool
    let onQRCodeLogin: () -> Void
    let onSMSLogin: () -> Void
    let onWebLogin: () -> Void
    let onOpenRoute: (MineOverlayRoute) -> Void
    let onRefreshProfile: () -> Void
    let onLogout: () -> Void

    var body: some View {
        Section {
            if isLoggedIn {
                MineLoggedInHeaderView(
                    display: display,
                    isRefreshing: profileState.isLoading
                )

                if case .failed(let message) = profileState {
                    LibraryErrorRow(
                        title: "账号资料暂未更新",
                        message: "已保留上次成功资料。\(message)",
                        retry: onRefreshProfile
                    )
                }

                if multiAccountExperimentEnabled {
                    MineOverlayNavigationButton {
                        onOpenRoute(.multiAccountSettings)
                    } label: {
                        Label("多账号与用途", systemImage: "person.2.badge.gearshape")
                    }
                }

                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Label(
                        multiAccountExperimentEnabled ? "退出所有账号" : "退出登录",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
            } else {
                MineLoginPanelView(
                    message: loginMessage,
                    onQRCodeLogin: onQRCodeLogin,
                    onSMSLogin: onSMSLogin,
                    onWebLogin: onWebLogin
                )
            }
        }
    }
}
