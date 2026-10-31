import Foundation

/// Builds levels from a number (campaign), a date (daily) or for arcade.
/// Mechanics unlock gradually: colors → seeds (4) → frost (8) → holes (12) → embers (18).
enum LevelGenerator {
    static let levelsPerWorld = 15

    static let worldNames = [
        "Sprout Meadow", "Lantern Lagoon", "Frostberry Hills", "Ember Canyon",
        "Moonpetal Grove", "Coral Cove", "Starfield Orchard", "Cloudline Peaks",
    ]

    static func worldName(forLevel n: Int) -> String {
        let index = (n - 1) / levelsPerWorld
        let base = worldNames[index % worldNames.count]
        let lap = index / worldNames.count
        return lap == 0 ? base : "\(base) \(lap + 1)"
    }

    static func level(_ n: Int) -> LevelSpec {
        var rng = SeededRNG(seed: UInt64(n) &* 0x2545_F491_4F6C_DD1D &+ 17)
        let seed = rng.next()
        return build(number: n, difficulty: n, rng: &rng, seed: seed, mode: .level)
    }

    static func daily(_ dateKey: String) -> LevelSpec {
        let digits = UInt64(dateKey) ?? 1
        var rng = SeededRNG(seed: digits &* 0x9E37_79B9 &+ 7)
        // Mid-campaign difficulty with every mechanic in the mix.
        let difficulty = 22 + Int(rng.next() % 14)
        let seed = rng.next()
        var spec = build(number: difficulty, difficulty: difficulty, rng: &rng, seed: seed, mode: .daily(dateKey))
        spec.number = dailyNumber(dateKey)
        return spec
    }

    static func arcade(seed: UInt64) -> LevelSpec {
        LevelSpec(number: 0, rows: 7, cols: 7, colors: Array(DotColor.allCases.prefix(5)),
                  moves: 0, goals: [], seed: seed, timeLimit: 60, mode: .arcade)
    }

    /// Days since launch, shown as "Daily #N" on the share card.
    static func dailyNumber(_ dateKey: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let d = f.date(from: dateKey), let start = f.date(from: "20261101") else { return 1 }
        return max(1, Int(d.timeIntervalSince(start) / 86_400) + 1)
    }

    static func todayKey(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Builder

    private static func build(number: Int, difficulty d: Int, rng: inout SeededRNG,
                              seed: UInt64, mode: GameMode) -> LevelSpec {
        let size = d <= 10 ? 6 : (d <= 30 ? 7 : 8)
        let colorCount = d <= 5 ? 4 : (d <= 40 ? 5 : 6)
        let colors = Array(DotColor.allCases.shuffled(using: &rng).prefix(colorCount))

        var spec = LevelSpec(number: number, rows: size, cols: size, colors: colors,
                             moves: 20, goals: [], seed: seed, mode: mode)

        // Which mechanics this level features.
        var features: [GoalKind] = []
        if d >= 4, d % 3 != 2 || d == 4 { features.append(.seed) }
        if d >= 8, d % 2 == 0 || d == 8 { features.append(.frost) }
        if d >= 18, d % 4 == 2 || d == 18 { features.append(.ember) }
        if d >= 12, rng.chance(0.55) { spec.holes = holePattern(size: size, rng: &rng) }

        // Keep it readable: at most two obstacle types at once.
        while features.count > 2 { features.remove(at: Int(rng.next() % UInt64(features.count))) }

        var goals: [Goal] = []
        var effort = 0   // rough number of moves the goals need

        for f in features {
            switch f {
            case .seed:
                let count = min(2 + d / 8, 6)
                spec.startSeeds = min(2, count)
                spec.seedsToSpawn = count - spec.startSeeds
                goals.append(Goal(kind: .seed, target: count))
                effort += count * 3
            case .frost:
                let area = frostPattern(size: size, amount: min(6 + d / 3, size * size / 2), rng: &rng)
                    .filter { !spec.holes.contains($0) }
                let layers = d >= 25 ? 2 : 1
                guard !area.isEmpty else { break }
                for p in area { spec.frost[p] = (d >= 45 && rng.chance(0.3)) ? 3 : layers }
                goals.append(Goal(kind: .frost, target: area.count))
                effort += area.count * layers / 2 + 2
            case .ember:
                var embers = Set<Pos>()
                while embers.count < min(2 + d / 15, 5) {
                    let p = Pos(r: Int(rng.next() % UInt64(size)), c: Int(rng.next() % UInt64(size)))
                    if !spec.holes.contains(p), spec.frost[p] == nil { embers.insert(p) }
                }
                spec.embers = embers
                goals.append(Goal(kind: .ember, target: embers.count))
                effort += embers.count * 2
            case .color:
                break
            }
        }

        // Always at least one color goal, two on most levels.
        let colorGoals = goals.isEmpty ? 2 : (d % 2 == 0 ? 1 : 0)
        for color in colors.prefix(colorGoals) {
            let target = 10 + d / 2 + Int(rng.next() % 6)
            goals.append(Goal(kind: .color(color), target: min(target, 45)))
            effort += target / 4
        }
        if goals.isEmpty { goals.append(Goal(kind: .color(colors[0]), target: 12)) }

        // Generous early, tighter later, never brutal.
        let slack = d <= 10 ? 1.6 : (d <= 40 ? 1.35 : 1.2)
        spec.moves = max(12, min(40, Int(Double(effort + 6) * slack)))
        spec.goals = goals
        return spec
    }

    private static func holePattern(size: Int, rng: inout SeededRNG) -> Set<Pos> {
        let last = size - 1
        switch rng.next() % 4 {
        case 0: // corners
            return [Pos(r: 0, c: 0), Pos(r: 0, c: last), Pos(r: last, c: 0), Pos(r: last, c: last)]
        case 1: // centre pillar
            let m = size / 2
            return [Pos(r: m - 1, c: m - 1), Pos(r: m, c: m - 1), Pos(r: m - 1, c: m), Pos(r: m, c: m)]
        case 2: // side notches
            let m = size / 2
            return [Pos(r: m, c: 0), Pos(r: m, c: last), Pos(r: m - 1, c: 0), Pos(r: m - 1, c: last)]
        default: // diamond-ish
            return [Pos(r: 0, c: 0), Pos(r: 0, c: 1), Pos(r: 1, c: 0),
                    Pos(r: 0, c: last), Pos(r: 0, c: last - 1), Pos(r: 1, c: last)]
        }
    }

    private static func frostPattern(size: Int, amount: Int, rng: inout SeededRNG) -> [Pos] {
        // Bottom rows first: frost is harder to reach there, which makes it a real goal.
        var cells: [Pos] = []
        var r = size - 1
        while cells.count < amount, r >= size / 2 {
            for c in 0..<size where cells.count < amount { cells.append(Pos(r: r, c: c)) }
            r -= 1
        }
        if rng.chance(0.5) {
            // Mirror into a checker pattern for variety.
            cells = cells.enumerated().filter { $0.offset % 2 == 0 || rng.chance(0.4) }.map(\.element)
        }
        return cells
    }
}
