import SwiftUI

/// A grid coordinate. Row 0 is the top of the board.
struct Pos: Hashable, Codable {
    var r: Int
    var c: Int

    func isAdjacent(_ other: Pos) -> Bool {
        abs(r - other.r) + abs(c - other.c) == 1
    }

    var neighbors4: [Pos] {
        [Pos(r: r - 1, c: c), Pos(r: r + 1, c: c), Pos(r: r, c: c - 1), Pos(r: r, c: c + 1)]
    }

    var neighbors8: [Pos] {
        var out: [Pos] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                out.append(Pos(r: r + dr, c: c + dc))
            }
        }
        return out
    }
}

enum DotColor: Int, CaseIterable, Codable, Hashable {
    case coral, tangerine, sun, mint, sky, grape

    var color: Color {
        switch self {
        case .coral: return Color(red: 0.96, green: 0.38, blue: 0.40)
        case .tangerine: return Color(red: 0.98, green: 0.60, blue: 0.24)
        case .sun: return Color(red: 0.98, green: 0.82, blue: 0.25)
        case .mint: return Color(red: 0.30, green: 0.80, blue: 0.58)
        case .sky: return Color(red: 0.30, green: 0.62, blue: 0.98)
        case .grape: return Color(red: 0.62, green: 0.42, blue: 0.94)
        }
    }

    /// Shape glyph so colors stay distinguishable in colorblind mode.
    var glyph: String {
        switch self {
        case .coral: return "heart.fill"
        case .tangerine: return "suit.club.fill"
        case .sun: return "star.fill"
        case .mint: return "leaf.fill"
        case .sky: return "drop.fill"
        case .grape: return "moon.fill"
        }
    }

    var emoji: String {
        switch self {
        case .coral: return "🟥"
        case .tangerine: return "🟧"
        case .sun: return "🟨"
        case .mint: return "🟩"
        case .sky: return "🟦"
        case .grape: return "🟪"
        }
    }

    var name: String {
        switch self {
        case .coral: return "Coral"
        case .tangerine: return "Tangerine"
        case .sun: return "Sun"
        case .mint: return "Mint"
        case .sky: return "Sky"
        case .grape: return "Grape"
        }
    }
}

enum PieceKind: Hashable {
    case dot(DotColor)
    /// Can't be linked. Falls with gravity and is planted at the bottom.
    case seed
    /// Bursts in a 3x3 area when cleared.
    case burst
}

struct Piece: Identifiable, Hashable {
    let id: Int
    var kind: PieceKind

    var color: DotColor? {
        if case .dot(let c) = kind { return c }
        return nil
    }
}

struct Cell: Hashable {
    var isHole = false
    /// Layers of frost under the piece (0 = none).
    var frost = 0
    var ember = false
    var piece: Piece?
}

enum GoalKind: Hashable, Codable {
    case color(DotColor)
    case seed
    case frost
    case ember

    var symbol: String {
        switch self {
        case .color: return "circle.fill"
        case .seed: return "arrow.down.circle.fill"
        case .frost: return "snowflake"
        case .ember: return "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .color(let c): return c.color
        case .seed: return Color(red: 0.55, green: 0.42, blue: 0.30)
        case .frost: return Color(red: 0.55, green: 0.80, blue: 0.95)
        case .ember: return Color(red: 0.95, green: 0.45, blue: 0.20)
        }
    }
}

struct Goal: Identifiable, Hashable {
    var kind: GoalKind
    var target: Int
    var id: GoalKind { kind }
}

enum GameMode: Hashable {
    case level
    case daily(String)   // yyyyMMdd
    case arcade
}

struct LevelSpec: Hashable {
    var number: Int
    var rows: Int
    var cols: Int
    var colors: [DotColor]
    var moves: Int
    var goals: [Goal]
    var holes: Set<Pos> = []
    var frost: [Pos: Int] = [:]
    var embers: Set<Pos> = []
    /// Seeds placed on the board at the start.
    var startSeeds = 0
    /// Seeds that may still drop in during play.
    var seedsToSpawn = 0
    var seed: UInt64
    var timeLimit: Int?
    var mode: GameMode = .level

    var title: String {
        switch mode {
        case .level: return "Level \(number)"
        case .daily: return "Daily Bloom"
        case .arcade: return "Bloom Rush"
        }
    }
}

enum Booster: String, CaseIterable, Codable, Identifiable {
    case hammer, burst, shuffle, moves
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hammer: return "hammer.fill"
        case .burst: return "sparkles"
        case .shuffle: return "shuffle"
        case .moves: return "plus.circle.fill"
        }
    }

    var name: String {
        switch self {
        case .hammer: return "Pop"
        case .burst: return "Burst"
        case .shuffle: return "Shuffle"
        case .moves: return "+5 Moves"
        }
    }

    /// Needs the player to tap a cell after picking it.
    var needsTarget: Bool { self == .hammer || self == .burst }

    var price: Int {
        switch self {
        case .hammer: return 60
        case .burst: return 90
        case .shuffle: return 40
        case .moves: return 120
        }
    }
}
