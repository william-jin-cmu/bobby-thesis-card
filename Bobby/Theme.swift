import SwiftUI
import CoreText

enum Theme {
    static let bg = Color(red: 0.965, green: 0.965, blue: 0.975)
    static let card = Color.white
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let ink2 = Color(red: 0.42, green: 0.42, blue: 0.47)
    static let ink3 = Color(red: 0.64, green: 0.64, blue: 0.68)
    static let hairline = Color.black.opacity(0.06)
    static let up = Color(red: 0.10, green: 0.62, blue: 0.40)
    static let down = Color(red: 0.90, green: 0.28, blue: 0.30)
    static let amber = Color(red: 0.93, green: 0.60, blue: 0.10)
    static let violet = Color(red: 0.48, green: 0.40, blue: 1.0)
    static let sky = Color(red: 0.33, green: 0.63, blue: 1.0)
    static let brand = LinearGradient(colors: [violet, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Font {
    /// Noto Serif SC (OFL), subset to the glyphs this prototype uses. Registered in FontLoader.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular, .light, .thin, .ultraLight: name = "NotoSerifSC-Regular"
        case .medium: name = "NotoSerifSC-Medium"
        default: name = "NotoSerifSC-SemiBold"
        }
        return .custom(name, fixedSize: size)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            )
    }
}

extension View {
    func card(_ radius: CGFloat = 22) -> some View { modifier(CardBackground(radius: radius)) }
}

struct BobbyMark: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Theme.brand)
            Text("B")
                .font(.serif(size * 0.62, .semibold))
                .foregroundStyle(.white)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

struct CircleIconButton: View {
    let systemName: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

struct TickerPill: View {
    let ticker: String
    let change: Double
    var dark = false
    var body: some View {
        HStack(spacing: 6) {
            Text(ticker).font(.system(size: 12, weight: .bold))
            Rectangle().fill((dark ? Color.white : Color.black).opacity(0.15)).frame(width: 1, height: 10)
            Text(String(format: "%+.2f%%", change))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(change >= 0 ? Theme.up : Theme.down)
        }
        .foregroundStyle(dark ? .white : Theme.ink)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(dark ? Color.white.opacity(0.10) : Color.black.opacity(0.04)))
        .overlay(Capsule().stroke(dark ? Color.white.opacity(0.12) : .clear, lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.ink3)
    }
}

struct StatusBadge: View {
    let status: ThesisStatus
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 6, height: 6)
            Text(status.label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(status.color.opacity(0.10)))
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Capsule().fill(Theme.ink))
        }
        .buttonStyle(PressStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Capsule().fill(Color.black.opacity(0.05)))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Animated nebula used on hero cards — evokes Bobby's current dark cards.
struct NebulaBackground: View {
    var seed: Double = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 0.25 + seed
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [Float(0.5 + 0.18 * sin(t)), Float(0.45 + 0.12 * cos(t * 1.3))], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    Color(red: 0.62, green: 0.70, blue: 0.66), Color(red: 0.35, green: 0.42, blue: 0.48), Color(red: 0.16, green: 0.18, blue: 0.26),
                    Color(red: 0.28, green: 0.30, blue: 0.40), Color(red: 0.36, green: 0.30, blue: 0.62), Color(red: 0.10, green: 0.12, blue: 0.20),
                    Color(red: 0.06, green: 0.06, blue: 0.09), Color(red: 0.05, green: 0.05, blue: 0.08), Color(red: 0.04, green: 0.04, blue: 0.06)
                ]
            )
        }
    }
}

extension Double {
    var usd: String { String(format: "$%.2f", self) }
    var usd0: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
    var pct: String { String(format: "%.0f%%", self * 100) }
}


enum FontLoader {
    static func register() {
        for n in ["NotoSerifSC-Regular", "NotoSerifSC-Medium", "NotoSerifSC-SemiBold"] {
            if let url = Bundle.main.url(forResource: n, withExtension: "otf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
