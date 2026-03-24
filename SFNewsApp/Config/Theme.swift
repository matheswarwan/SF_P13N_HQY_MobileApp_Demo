import SwiftUI

/// HealthEquity brand colors and theming constants.
enum HETheme {
    static let primaryGreen = Color(hex: "00A651")
    static let lightGreen = Color(hex: "00A651").opacity(0.15)
}

extension Color {
    /// Initialize a Color from a hex string (e.g., "00A651" or "#00A651").
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r, g, b: Double
        switch sanitized.count {
        case 6:
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        case 8:
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: r, green: g, blue: b)
    }
}
