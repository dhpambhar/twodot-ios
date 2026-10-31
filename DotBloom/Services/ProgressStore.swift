import SwiftUI

/// Everything the player owns, saved as JSON in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    struct DailyResult: Codable, Equatable {
        var dateKey: String
        var won: Bool
        var stars: Int
        var score: Int
        var movesLeft: Int
        var moveLog: [String]
    }

    struct State: Codable {
        var stars: [Int: Int] = [:]
        var bestScores: [Int: Int] = [:]
        var coins = 150
        var boosters: [Booster: Int] = [.hammer: 2, .burst: 1, .shuffle: 2, .moves: 1]
        var daily: DailyResult?
        var dailyStreak = 0
        var lastDailyWin: String?
        var arcadeBest = 0
        var soundOn = true
        var hapticsOn = true
        var colorblind = false
        var seenTutorial = false
    }

    @Published private(set) var state: State {
        didSet { save() }
    }

    private static let key = "dotbloom.progress.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: - Reads

    /// Highest level the player may start.
    var currentLevel: Int { (state.stars.keys.max() ?? 0) + 1 }
    var totalStars: Int { state.stars.values.reduce(0, +) }
    func stars(for level: Int) -> Int { state.stars[level] ?? 0 }
    func count(_ b: Booster) -> Int { state.boosters[b] ?? 0 }

    var todaysDaily: DailyResult? {
        guard let d = state.daily, d.dateKey == LevelGenerator.todayKey() else { return nil }
        return d
    }

    /// Streak still counts if the last win was today or yesterday.
    var liveStreak: Int {
        guard let last = state.lastDailyWin else { return 0 }
        let today = LevelGenerator.todayKey()
        let yesterday = LevelGenerator.todayKey(.now.addingTimeInterval(-86_400))
        return (last == today || last == yesterday) ? state.dailyStreak : 0
    }

    // MARK: - Writes

    func recordLevel(_ n: Int, stars: Int, score: Int) {
        let earned = 10 + stars * 5 + (state.stars[n] == nil ? 15 : 0)
        state.stars[n] = max(state.stars[n] ?? 0, stars)
        state.bestScores[n] = max(state.bestScores[n] ?? 0, score)
        state.coins += earned
    }

    func recordDaily(_ result: DailyResult) {
        guard todaysDaily == nil else { return }
        state.daily = result
        if result.won {
            state.dailyStreak = liveStreak + 1
            state.lastDailyWin = result.dateKey
            state.coins += 40 + state.dailyStreak * 5
        }
    }

    func recordArcade(score: Int) {
        state.arcadeBest = max(state.arcadeBest, score)
        state.coins += score / 100
    }

    @discardableResult
    func use(_ b: Booster) -> Bool {
        guard count(b) > 0 else { return false }
        state.boosters[b, default: 0] -= 1
        return true
    }

    @discardableResult
    func buy(_ b: Booster) -> Bool {
        guard state.coins >= b.price else { return false }
        state.coins -= b.price
        state.boosters[b, default: 0] += 1
        return true
    }

    func set<T>(_ path: WritableKeyPath<State, T>, _ value: T) {
        state[keyPath: path] = value
    }

    func resetProgress() {
        state = State()
    }
}
