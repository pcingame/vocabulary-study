import SwiftUI

/// Bảng màu pastel xanh mint, mỗi màu có bản sáng/tối.
/// - Nền nút: màu pastel nhạt + chữ `onPastel` đậm (chữ trắng trên pastel không đọc được).
/// - Chữ/icon nhấn: tông đậm (`…Ink`, AccentColor) để đủ tương phản 4.5:1 trên nền trắng.
extension Color {
    static let accentFill = dynamic(light: 0xBFE8D6, dark: 0x93D3B8)
    static let onPastel = dynamic(light: 0x173D2E, dark: 0x0E2A1F)

    static let forgot = dynamic(light: 0xF5C4C0, dark: 0xE89C96)
    static let hard = dynamic(light: 0xF8DFAE, dark: 0xE6C27E)
    static let easy = dynamic(light: 0xC9E7B4, dark: 0xA6D488)

    static let forgotInk = dynamic(light: 0xB03A35, dark: 0xF2A9A4)
    static let hardInk = dynamic(light: 0x8A6114, dark: 0xF0CF8E)
    static let easyInk = dynamic(light: 0x3F7A26, dark: 0xB5DF98)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

extension View {
    /// Nút chính kiểu pastel: nền pastel, chữ đậm. Nút con có thể đổi nền bằng `.tint(.easy)`…
    func pastelProminent() -> some View {
        buttonStyle(.borderedProminent).tint(.accentFill).foregroundStyle(Color.onPastel)
    }
}

/// Giao diện sáng/tối, chọn trong Cài đặt.
enum Appearance: String, CaseIterable {
    case system, light, dark
    var title: String { ["Hệ thống", "Sáng", "Tối"][Self.allCases.firstIndex(of: self)!] }
    var colorScheme: ColorScheme? { [nil, .light, .dark][Self.allCases.firstIndex(of: self)!] }
}
