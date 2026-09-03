import SwiftUI
import UIKit

// The single committed visual world, ported from the web build.
// Colour encodes the mechanic:
//   magenta = FAKE   cyan = REAL   hazard yellow = SPONSORED   ink = HIGH ROT
enum Theme {
    static let ground     = Color(hex: 0x12060F)
    static let groundDeep = Color(hex: 0x0A0309)
    static let surface    = Color(hex: 0x1E0B1C)
    static let surfaceHi  = Color(hex: 0x2C1129)
    static let line       = Color(hex: 0x3D1B39)

    static let fake       = Color(hex: 0xFF2E88)
    static let real       = Color(hex: 0x00E5FF)
    static let sponsor    = Color(hex: 0xFFE600)
    static let sponsorInk = Color(hex: 0x1A1400)

    static let ink        = Color(hex: 0xFFF4FB)
    static let inkSoft    = Color(hex: 0xB9A3B6)   // mauve-biased neutral, not grey
    static let inkFaint   = Color(hex: 0x6E5A6C)

    static let cardTop    = Color(hex: 0x33143A)
    static let cardBottom = Color(hex: 0x1A0819)
    static let hardTop    = Color(hex: 0x4A2350)
    static let hardBottom = Color(hex: 0x210B21)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255.0,
            green:   Double((hex >> 8)  & 0xFF) / 255.0,
            blue:    Double( hex        & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Type
//
// The web build uses Anton / Bungee / Archivo / DM Mono. Drop those .ttf files
// into the target (see ios/README.md) and they're picked up automatically.
// Without them these fall back to system faces chosen to match the same role,
// so the app looks intentional either way rather than defaulting to body text.
enum Fonts {
    private static let installed: Set<String> = {
        var names = Set<String>()
        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) { names.insert(name) }
        }
        return names
    }()

    private static func custom(_ name: String, _ size: CGFloat) -> Font? {
        installed.contains(name) ? .custom(name, size: size) : nil
    }

    /// Condensed heavy display face — card terms, scores, buttons.
    static func display(_ size: CGFloat) -> Font {
        custom("Anton-Regular", size) ?? .system(size: size, weight: .black).width(.condensed)
    }

    /// Wordmark only.
    static func logo(_ size: CGFloat) -> Font {
        custom("Bungee-Regular", size) ?? .system(size: size, weight: .black).width(.expanded)
    }

    /// UI and body copy.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let heavy: Set<Font.Weight> = [.semibold, .bold, .heavy, .black]
        let face = heavy.contains(weight) ? "Archivo-Bold" : "Archivo-Regular"
        return custom(face, size) ?? .system(size: size, weight: weight)
    }

    /// Labels, stats, anything with digits that should line up.
    static func mono(_ size: CGFloat) -> Font {
        custom("DMMono-Regular", size) ?? .system(size: size, weight: .medium, design: .monospaced)
    }

    // MARK: UIKit (the native ad card is UIKit underneath)

    enum Role { case display, ui, mono }

    static func uiFont(_ role: Role, _ size: CGFloat) -> UIFont {
        switch role {
        case .display:
            if installed.contains("Anton-Regular"), let f = UIFont(name: "Anton-Regular", size: size) { return f }
            let base = UIFont.systemFont(ofSize: size, weight: .black)
            let traits: [UIFontDescriptor.TraitKey: Any] = [.width: -0.3, .weight: UIFont.Weight.black.rawValue]
            let condensed = base.fontDescriptor.withDesign(.default)?
                .addingAttributes([.traits: traits])
            return condensed.map { UIFont(descriptor: $0, size: size) } ?? base
        case .ui:
            if installed.contains("Archivo-Regular"), let f = UIFont(name: "Archivo-Regular", size: size) { return f }
            return .systemFont(ofSize: size)
        case .mono:
            if installed.contains("DMMono-Regular"), let f = UIFont(name: "DMMono-Regular", size: size) { return f }
            return .monospacedSystemFont(ofSize: size, weight: .medium)
        }
    }
}

// MARK: - Shared bits

/// The ambient feed-glow behind everything.
struct AmbientBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.groundDeep
            RadialGradient(
                colors: [Theme.fake.opacity(0.30), .clear],
                center: UnitPoint(x: 0.18, y: 0.08), startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [Theme.real.opacity(0.22), .clear],
                center: UnitPoint(x: 0.84, y: 0.88), startRadius: 0, endRadius: 420
            )
        }
        .ignoresSafeArea()
        .scaleEffect(drift ? 1.12 : 1.0)
        .animation(.easeInOut(duration: 24).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }
}

/// Uppercase mono label used above every stat.
struct StatLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Fonts.mono(10))
            .tracking(1.6)
            .foregroundStyle(Theme.inkFaint)
    }
}

extension View {
    /// Rounded card/panel surface used throughout.
    func panel(_ fill: Color = Theme.surfaceHi, stroke: Color = Theme.line, radius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 1)
        )
    }
}
