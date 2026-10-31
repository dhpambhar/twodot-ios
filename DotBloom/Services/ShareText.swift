import Foundation

/// Spoiler-free result card, Wordle style: one emoji per move, a flower for
/// every loop. Pasted into group chats, it's the growth loop.
enum ShareText {
    static let appLink = "https://apps.apple.com/app/dotbloom"   // replace with the real App Store URL

    static func daily(_ r: ProgressStore.DailyResult, streak: Int) -> String {
        let number = LevelGenerator.dailyNumber(r.dateKey)
        let head = r.won
            ? "DotBloom Daily #\(number) \(String(repeating: "⭐", count: r.stars))"
            : "DotBloom Daily #\(number) 🥀"
        var lines = [head]
        lines.append(contentsOf: grid(r.moveLog))
        var footer = "Score \(r.score)"
        if r.won { footer += " · \(r.movesLeft) moves spare" }
        if streak > 1 { footer += " · 🔥\(streak)" }
        lines.append(footer)
        lines.append(appLink)
        return lines.joined(separator: "\n")
    }

    static func level(_ n: Int, stars: Int, score: Int) -> String {
        "I just bloomed Level \(n) in DotBloom \(String(repeating: "⭐", count: stars)) (\(score) pts). Your turn 🌸\n\(appLink)"
    }

    static func arcade(score: Int) -> String {
        "I scored \(score) in 60 seconds of DotBloom Rush ⚡️ Beat that.\n\(appLink)"
    }

    private static func grid(_ log: [String]) -> [String] {
        stride(from: 0, to: log.count, by: 8).map { log[$0..<min($0 + 8, log.count)].joined() }
    }
}
