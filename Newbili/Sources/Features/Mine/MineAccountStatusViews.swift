import SwiftUI

struct MineLoggedInHeaderView: View {
    let display: MineAccountProfileDisplayModel
    let isRefreshing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarRemoteImage(urlString: display.avatarURLString, pixelSize: 128) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(display.username)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let level = display.level {
                        Text("LV\(level)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(levelColor(level))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(levelColor(level).opacity(0.13), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(levelColor(level).opacity(0.32), lineWidth: 0.7)
                            }
                            .accessibilityLabel("账号等级 \(level) 级")
                    }

                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityLabel("正在更新账号资料")
                    }
                }

                metadata

                if let progress = display.experienceProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 240)
                        .accessibilityLabel("等级经验进度")
                        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var metadata: some View {
        if let experienceText = display.experienceText {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metadataText(display.uidText)
                    metadataText(experienceText)
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 2) {
                    metadataText(display.uidText)
                    metadataText(experienceText)
                }
            }
        } else {
            metadataText(display.uidText)
        }
    }

    private func metadataText(_ value: String) -> some View {
        Text(value)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 6:
            return .pink
        case 5:
            return .orange
        case 4:
            return .yellow
        case 3:
            return .green
        case 2:
            return .blue
        default:
            return .secondary
        }
    }
}

struct MineLoginPanelView: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let message: String
    let onQRCodeLogin: () -> Void
    let onSMSLogin: () -> Void
    let onWebLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(appTintColor)

            Text(message.isEmpty ? "想让 App 端首页推荐更接近官方，优先用短信验证码；想稳定登录可用扫码。" : message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                LoginOptionButton(
                    title: "App 短信验证码登录",
                    subtitle: "更适合 App 端推荐，可能触发风控",
                    badge: "推荐",
                    systemImage: "message.badge",
                    tint: appTintColor,
                    isProminent: true,
                    action: onSMSLogin
                )

                LoginOptionButton(
                    title: "App 扫码登录",
                    subtitle: "更稳定；当前更适合配合网页端推荐",
                    badge: "稳定",
                    systemImage: "qrcode",
                    tint: .blue,
                    isProminent: false,
                    action: onQRCodeLogin
                )

                LoginOptionButton(
                    title: "网页登录",
                    subtitle: "备用登录方式，首页推荐个性化较弱",
                    badge: "备用",
                    systemImage: "globe",
                    tint: .secondary,
                    isProminent: false,
                    action: onWebLogin
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

private struct LoginOptionButton: View {
    let title: String
    let subtitle: String
    let badge: String
    let systemImage: String
    let tint: Color
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isProminent ? .white : tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isProminent ? tint : tint.opacity(0.12))
                            )
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isProminent ? tint.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isProminent ? tint.opacity(0.45) : Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
