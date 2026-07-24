import SwiftUI

struct LEDColor: Identifiable, Equatable, Sendable {
    let name: String
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var id: String { name }
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    var contrastingColor: Color {
        let luminance = (0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)) / 255
        return luminance > 0.55 ? .black : .white
    }

    static let palette: [LEDColor] = [
        LEDColor(name: "Red", red: 255, green: 0, blue: 0),
        LEDColor(name: "Orange", red: 255, green: 75, blue: 0),
        LEDColor(name: "Yellow", red: 255, green: 180, blue: 0),
        LEDColor(name: "Green", red: 0, green: 255, blue: 0),
        LEDColor(name: "Cyan", red: 0, green: 255, blue: 255),
        LEDColor(name: "Blue", red: 0, green: 0, blue: 255),
        LEDColor(name: "Purple", red: 255, green: 0, blue: 255),
        LEDColor(name: "White", red: 255, green: 255, blue: 255)
    ]
}

