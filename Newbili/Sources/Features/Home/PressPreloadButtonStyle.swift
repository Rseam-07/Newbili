import SwiftUI

struct PressPreloadButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let actions: PressPreloadButtonActions
    let pressedScale: CGFloat
    let pressedOpacity: Double
    let pressAnimation: Animation

    init(
        pressedScale: CGFloat = 0.985,
        pressedOpacity: Double = 0.94,
        pressAnimation: Animation = .spring(response: 0.24, dampingFraction: 0.84),
        onPress: @escaping () -> Void
    ) {
        actions = PressPreloadButtonActions(onPress: onPress)
        self.pressedScale = pressedScale
        self.pressedOpacity = pressedOpacity
        self.pressAnimation = pressAnimation
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.08)
                    : configuration.isPressed ? .easeOut(duration: 0.07) : pressAnimation,
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                actions.handlePressedChange(isPressed)
            }
    }
}
