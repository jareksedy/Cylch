import Foundation

enum LEDEffect: String, CaseIterable, Identifiable {
    case `static` = "Static"
    case rainbow = "Rainbow"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .static:
            "static"
        case .rainbow:
            "rainbow"
        }
    }
}
