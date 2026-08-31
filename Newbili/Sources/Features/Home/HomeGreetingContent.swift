import Foundation

nonisolated struct HomeGreetingContent: Equatable, Sendable {
    let title: String
    let subtitle: String

    static func make(
        date: Date,
        calendar: Calendar = .current,
        displayName: String?
    ) -> HomeGreetingContent {
        make(
            hour: calendar.component(.hour, from: date),
            displayName: displayName
        )
    }

    static func make(hour: Int, displayName: String?) -> HomeGreetingContent {
        let normalizedHour = min(max(hour, 0), 23)
        let trimmedName = displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let name = trimmedName.isEmpty ? nil : trimmedName
        let salutation: String
        let subtitle: String

        switch normalizedHour {
        case 5..<10:
            salutation = "早上好"
            subtitle = "新一天，从喜欢的内容开始"
        case 10..<13:
            salutation = "中午好"
            subtitle = "歇一会儿，看看为你挑的内容"
        case 13..<18:
            salutation = "下午好"
            subtitle = "为你准备了一些新鲜内容"
        case 18..<23:
            salutation = "晚上好"
            subtitle = "今晚想看点什么？"
        default:
            salutation = "夜深了"
            subtitle = "慢慢看，也别忘了休息"
        }

        return HomeGreetingContent(
            title: name.map { "\(salutation)，\($0)" } ?? salutation,
            subtitle: subtitle
        )
    }
}

nonisolated enum HomeNavigationHeaderLayoutPolicy {
    static let singleRowMinimumWidth: CGFloat = 820
    static let centerControlWidth: CGFloat = 330
    static let horizontalInset: CGFloat = 18
    static let centerGap: CGFloat = 16

    static func usesStackedLayout(
        containerWidth: CGFloat,
        usesAccessibilitySize: Bool
    ) -> Bool {
        usesAccessibilitySize || containerWidth < singleRowMinimumWidth
    }

    static func sideSlotWidth(containerWidth: CGFloat) -> CGFloat {
        max(
            (
                containerWidth
                    - horizontalInset * 2
                    - centerControlWidth
                    - centerGap * 2
            ) / 2,
            0
        )
    }
}
