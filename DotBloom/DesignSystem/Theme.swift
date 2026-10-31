import SwiftUI

enum Theme {
    static let background = dynamic(light: UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1),
                                    dark: UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1))
    static let surface = dynamic(light: .white,
                                 dark: UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1))
    static let boardWell = dynamic(light: UIColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1),
                                   dark: UIColor(red: 0.12, green: 0.12, blue: 0.17, alpha: 1))
    static let ink = dynamic(light: UIColor(red: 0.18, green: 0.17, blue: 0.22, alpha: 1),
                             dark: UIColor(red: 0.95, green: 0.94, blue: 0.97, alpha: 1))
    static let muted = dynamic(light: UIColor(red: 0.50, green: 0.48, blue: 0.55, alpha: 1),
                               dark: UIColor(red: 0.62, green: 0.61, blue: 0.68, alpha: 1))
    static let accent = Color(red: 0.96, green: 0.38, blue: 0.52)
    static let gold = Color(red: 0.99, green: 0.76, blue: 0.20)

    static let corner: CGFloat = 22

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .frame(minWidth: 160)
            .background(tint, in: Capsule())
            .shadow(color: tint.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct StarRow: View {
    let stars: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Theme.gold : Theme.muted.opacity(0.5))
            }
        }
    }
}

struct CoinPill: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Theme.gold)
            Text("\(coins)").monospacedDigit()
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.surface, in: Capsule())
    }
}

/// The brand mark: two overlapping petals linked by a line. Original artwork, drawn in code.
struct BloomMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(DotColor.allCases[i].color)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(y: -size * 0.24)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle().fill(Theme.surface).frame(width: size * 0.3, height: size * 0.3)
            Circle().fill(DotColor.allCases[5].color).frame(width: size * 0.18, height: size * 0.18)
        }
        .frame(width: size, height: size)
    }
}
