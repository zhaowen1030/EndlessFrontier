import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum AppTheme {
    static let accent = Color(hex: "6FA8FF")
    static let accentDeep = Color(hex: "3B6DE8")
    static let gold = Color(hex: "F4B860")
    static let cyan = Color(hex: "67D8E8")
    static let ink = Color(hex: "0B1526")
    static let positive = Color(hex: "56C596")
    static let warning = Color(hex: "E9A24A")
    static let danger = Color(hex: "E46B6B")

    static let paperBackground = Color(nsColor: .windowBackgroundColor)
    static let cardStroke = Color.primary.opacity(0.075)
    static let quietText = Color.primary.opacity(0.56)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "0D1D3A"), Color(hex: "112E4C"), Color(hex: "0B1A2C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aurora = LinearGradient(
        colors: [accent.opacity(0.26), cyan.opacity(0.12), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGlow = RadialGradient(
        colors: [gold.opacity(0.22), .clear],
        center: .topTrailing,
        startRadius: 4,
        endRadius: 460
    )

    static func groupColor(_ id: String) -> Color {
        switch id {
        case "cs": return Color(hex: "6C9BFF")
        case "math": return Color(hex: "B58CFF")
        case "physics": return Color(hex: "F2A25C")
        case "q-bio": return Color(hex: "5BCB9A")
        case "q-fin": return Color(hex: "E4C35B")
        case "stat": return Color(hex: "59C9C9")
        case "eess": return Color(hex: "EA7E9B")
        case "econ": return Color(hex: "D2A46D")
        default: return accent
        }
    }

    static func groupTint(_ id: String) -> LinearGradient {
        let c = groupColor(id)
        return LinearGradient(colors: [c.opacity(0.30), c.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum AppFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func chinese(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 16
    var tint: Color = Color.primary.opacity(0.025)
    var stroke: Color = AppTheme.cardStroke

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.background.opacity(0.62))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func cardSurface(radius: CGFloat = 16, tint: Color = Color.primary.opacity(0.02), stroke: Color = AppTheme.cardStroke) -> some View {
        modifier(CardBackground(radius: radius, tint: tint, stroke: stroke))
    }

    func sectionPadding(_ value: CGFloat = 22) -> some View {
        padding(.horizontal, value).padding(.vertical, value)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}

struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func fieldSurface() -> some View { modifier(FieldBackground()) }
}

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuietIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }
}

extension Date {
    var shortEnglish: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }

    var shortChinese: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: self)
    }

    var relativeQuiet: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: self, relativeTo: Date())
    }
}
