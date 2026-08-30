import SwiftUI

struct BiliContentStateSurface<Actions: View>: View {
    @Environment(\.appInterfaceStyle) private var interfaceStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    let actions: Actions

    init(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.actions = actions()
    }

    var body: some View {
        let palette = AppFluentPalette.resolve(colorScheme: colorScheme, contrast: contrast)
        let cornerRadius = interfaceStyle.isFluent ? AppFluentShape.surfaceRadius : 18
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(
                    interfaceStyle.isFluent
                        ? palette.raisedSurface
                        : Color(.tertiarySystemFill),
                    in: Circle()
                )

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            interfaceStyle.isFluent
                ? palette.surface.opacity(0.94)
                : Color(.secondarySystemGroupedBackground).opacity(0.78)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    interfaceStyle.isFluent ? palette.subtleStroke : Color(.separator).opacity(0.10),
                    lineWidth: interfaceStyle.isFluent ? 1 : 0.6
                )
        }
        .shadow(
            color: .black.opacity(interfaceStyle.isFluent ? (colorScheme == .dark ? 0.18 : 0.08) : 0),
            radius: 8,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 18)
        .accessibilityElement(children: .combine)
    }
}
