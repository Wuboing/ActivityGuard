import SwiftUI

enum MonitorColorScheme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var displayNameZH: String {
        switch self {
        case .dark: return "暗色"
        case .light: return "亮色"
        }
    }

    func localizedName(_ language: AppLanguage) -> String {
        language == .chinese ? displayNameZH : displayName
    }
}

struct MonitorTheme {
    let scheme: MonitorColorScheme

    // Brand — Apple system color flavored
    let primary = Color(hex: 0x0A84FF)
    let success = Color(hex: 0x32D74B)
    let warning = Color(hex: 0xFF9F0A)
    let danger = Color(hex: 0xFF453A)
    let cyan = Color(hex: 0x64D2FF)

    // MARK: Sizing tokens
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 10
    static let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    static let buttonShape = RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)

    // MARK: Surfaces

    var background: Color {
        scheme == .dark ? Color(hex: 0x161618) : Color(hex: 0xF5F7FA)
    }

    var windowMaterial: Material {
        scheme == .dark ? .regularMaterial : .regularMaterial
    }

    var cardMaterial: Material {
        scheme == .dark ? .thinMaterial : .regularMaterial
    }

    var cardTint: Color {
        scheme == .dark
            ? Color(hex: 0x2A2A2E).opacity(0.72)
            : Color.white.opacity(0.55)
    }

    var cardBackground: Color {
        scheme == .dark
            ? Color(hex: 0x232326)
            : Color.white.opacity(0.85)
    }

    var cardBorder: Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.05)
    }

    var textPrimary: Color {
        scheme == .dark ? Color(hex: 0xF2F2F7) : Color(hex: 0x1E293B).opacity(0.92)
    }

    var textSecondary: Color {
        scheme == .dark ? Color(hex: 0xAEAEB2) : Color(hex: 0x1E293B).opacity(0.65)
    }

    var textTertiary: Color {
        scheme == .dark ? Color(hex: 0x8E8E93) : Color(hex: 0x1E293B).opacity(0.42)
    }

    var rowHover: Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var rowAlternate: Color {
        scheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
    }

    var headerBackground: Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
    }

    var progressTrack: Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    func cpuColor(for percent: Double) -> Color {
        if percent > 80 { return danger }
        if percent > 50 { return warning }
        return success
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Card Modifier

struct MonitorCardModifier: ViewModifier {
    let theme: MonitorTheme
    var highlight: Bool = false
    var stretch: Bool = false
    @State private var hovered = false

    func body(content: Content) -> some View {
        let shape = MonitorTheme.cardShape

        content
            .padding(16)
            .frame(
                minWidth: 260,
                maxWidth: stretch ? .infinity : nil,
                minHeight: stretch ? 200 : 120,
                maxHeight: stretch ? .infinity : nil,
                alignment: .topLeading
            )
            .background(theme.cardTint, in: shape)
            .background(theme.cardMaterial, in: shape)
            .overlay(shape.stroke(borderColor, lineWidth: 1))
            .shadow(
                color: .black.opacity(theme.scheme == .dark ? 0.22 : 0.06),
                radius: 6,
                y: 2
            )
            .onHover { hovered = $0 }
    }

    private var borderColor: Color {
        if highlight { return theme.warning.opacity(0.45) }
        if hovered { return theme.primary.opacity(0.28) }
        return theme.cardBorder
    }
}

extension View {
    func monitorCard(_ theme: MonitorTheme, highlight: Bool = false, stretch: Bool = false) -> some View {
        modifier(MonitorCardModifier(theme: theme, highlight: highlight, stretch: stretch))
    }
}

// MARK: - Buttons

struct MonitorPrimaryButton: ButtonStyle {
    let theme: MonitorTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                theme.primary.opacity(configuration.isPressed ? 0.78 : 1),
                in: MonitorTheme.buttonShape
            )
    }
}

struct MonitorGhostButton: ButtonStyle {
    let theme: MonitorTheme
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: MonitorTheme.buttonShape)
            .background(
                (hovered ? theme.rowHover : Color.clear)
                    .opacity(configuration.isPressed ? 1.4 : 1),
                in: MonitorTheme.buttonShape
            )
            .overlay(MonitorTheme.buttonShape.stroke(theme.cardBorder))
            .onHover { hovered = $0 }
    }
}
