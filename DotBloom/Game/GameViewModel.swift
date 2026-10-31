import SwiftUI

struct PlacedPiece: Identifiable {
    let piece: Piece
    let pos: Pos
    var id: Int { piece.id }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

/// Runs one game: input, turn resolution, animation pacing, goals and results.
@MainActor
final class GameViewModel: ObservableObject {
    enum Phase: Equatable { case playing, resolving, won, lost }

    let spec: LevelSpec
    private let store: ProgressStore
    private let feedback = Feedback.shared

    @Published private(set) var board: Board
    @Published private(set) var tracer = PathTracer()
    @Published private(set) var finger: CGPoint?
    @Published private(set) var movesLeft: Int
    @Published private(set) var score = 0
    @Published private(set) var collected: [GoalKind: Int] = [:]
    @Published private(set) var phase: Phase = .playing
    /// New pieces start above the board; this holds their start row until they fall.
    @Published private(set) var spawnRows: [Int: Int] = [:]
    @Published private(set) var activeBooster: Booster?
    @Published private(set) var toast: Toast?
    @Published private(set) var timeLeft: Int?
    @Published private(set) var flashes: [Pos] = []
    private(set) var moveLog: [String] = []

    private var timeUp = false
    private var recorded = false
    private var timerTask: Task<Void, Never>?

    init(spec: LevelSpec, store: ProgressStore) {
        self.spec = spec
        self.store = store
        board = Board(spec: spec)
        movesLeft = spec.moves
        timeLeft = spec.timeLimit
        feedback.soundOn = store.state.soundOn
        feedback.hapticsOn = store.state.hapticsOn
    }

    deinit { timerTask?.cancel() }

    var isArcade: Bool { spec.mode == .arcade }
    var isDaily: Bool { if case .daily = spec.mode { return true }; return false }
    var armedColor: DotColor? { tracer.isLoop ? tracer.color : nil }

    var placedPieces: [PlacedPiece] {
        board.allPositions.compactMap { p in board[p].piece.map { PlacedPiece(piece: $0, pos: p) } }
    }

    // MARK: - Goals

    func remaining(_ goal: Goal) -> Int {
        switch goal.kind {
        case .color, .seed: return max(0, goal.target - collected[goal.kind, default: 0])
        case .frost: return board.frostCount
        case .ember: return board.emberCount
        }
    }

    var allGoalsMet: Bool {
        !spec.goals.isEmpty && spec.goals.allSatisfy { remaining($0) == 0 }
    }

    var stars: Int {
        if isArcade { return score >= 6000 ? 3 : (score >= 3500 ? 2 : (score >= 1500 ? 1 : 0)) }
        guard phase == .won else { return 0 }
        let ratio = Double(movesLeft) / Double(max(spec.moves, 1))
        return ratio >= 0.3 ? 3 : (ratio >= 0.12 ? 2 : 1)
    }

    // MARK: - Lifecycle

    func start() {
        guard isArcade, timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while let self, let t = self.timeLeft, t > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.timeLeft = t - 1
            }
            guard !Task.isCancelled, let self else { return }
            self.timeUp = true
            if self.phase == .playing {
                self.tracer.reset()
                self.finishTurn()
            }
        }
    }

    func stop() { timerTask?.cancel() }

    // MARK: - Input

    func drag(to point: CGPoint, cell: CGFloat) {
        guard phase == .playing, activeBooster == nil, let p = hit(point, cell: cell, strict: true) else {
            if !tracer.isEmpty { finger = point }
            return
        }
        finger = point

        if tracer.isEmpty {
            if let color = board.color(at: p) {
                _ = tracer.begin(at: p, color: color)
                feedback.link(0)
            }
            return
        }

        let snapshot = board
        var t = tracer
        let event = t.move(to: p) { snapshot.color(at: $0) }
        tracer = t
        switch event {
        case .extended, .backtracked: feedback.link(tracer.distinctCount - 1)
        case .closedLoop: feedback.loop()
        case .none, .began: break
        }
    }

    func release(at point: CGPoint, cell: CGFloat) {
        finger = nil
        if let booster = activeBooster {
            if let p = hit(point, cell: cell, strict: false) { useBooster(booster, at: p) }
            return
        }
        guard phase == .playing, tracer.distinctCount >= 2 else {
            tracer.reset()
            return
        }
        let path = tracer.path, loop = tracer.isLoop, color = tracer.color
        tracer.reset()
        Task { await play(path: path, loop: loop, color: color) }
    }

    private func hit(_ point: CGPoint, cell: CGFloat, strict: Bool) -> Pos? {
        let p = Pos(r: Int(floor(point.y / cell)), c: Int(floor(point.x / cell)))
        guard board.isPlayable(p) else { return nil }
        if strict {
            // Only count touches near the dot centre so diagonal swipes don't mis-link.
            let cx = (CGFloat(p.c) + 0.5) * cell, cy = (CGFloat(p.r) + 0.5) * cell
            guard hypot(point.x - cx, point.y - cy) < cell * 0.44 else { return nil }
        }
        return p
    }

    // MARK: - Turn

    private func play(path: [Pos], loop: Bool, color: DotColor?) async {
        phase = .resolving
        if !isArcade { movesLeft -= 1 }
        if let color { moveLog.append(loop ? "🌸" : color.emoji) }
        let report = withAnimation(.easeOut(duration: 0.2)) { board.resolve(path: path, isLoop: loop) }
        apply(report)
        await settle(emberOut: report.embersOut > 0)
    }

    private func apply(_ report: ClearReport) {
        for (c, n) in report.colorCounts { collected[.color(c), default: 0] += n }
        score += report.dotCount * 10 + report.bursts.count * 30 + report.frostLayers * 20 + report.embersOut * 25
        if report.wasLoop { score += 60 }

        if !report.bursts.isEmpty {
            feedback.burst()
            flashes = report.bursts
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                self.flashes = []
            }
        } else {
            feedback.clear(count: report.dotCount)
        }

        if report.dotCount >= 20 {
            show(Toast(text: "Superbloom!", color: Theme.gold))
        } else if report.wasLoop, let c = report.colorCounts.max(by: { $0.value < $1.value })?.key {
            show(Toast(text: ["Bloom!", "Lovely!", "Blossom!", "Petal power!"].randomElement()!, color: c.color))
        } else if report.dotCount >= 8 {
            show(Toast(text: "Nice chain!", color: Theme.accent))
        }
    }

    private func settle(emberOut: Bool) async {
        var planted = 0
        repeat {
            try? await Task.sleep(nanoseconds: 140_000_000)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                spawnRows = board.collapse()
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { spawnRows = [:] }
            try? await Task.sleep(nanoseconds: 380_000_000)

            let seeds = withAnimation(.easeIn(duration: 0.25)) { board.plantSeeds() }
            planted = seeds.count
            if planted > 0 {
                collected[.seed, default: 0] += planted
                score += 100 * planted
                feedback.burst()
                show(Toast(text: planted > 1 ? "Seeds planted!" : "Seed planted!", color: GoalKind.seed.tint))
            }
        } while planted > 0

        if !emberOut, board.emberCount > 0 {
            withAnimation(.easeInOut(duration: 0.3)) { _ = board.spreadEmber() }
        }
        finishTurn()
    }

    private func finishTurn() {
        if allGoalsMet {
            score += movesLeft * 25
            phase = .won
            feedback.win()
            record()
        } else if isArcade && timeUp {
            tracer.reset()
            phase = .won
            feedback.win()
            record()
        } else if !isArcade && movesLeft <= 0 {
            phase = .lost
            feedback.lose()
            if isDaily { record() }
        } else {
            if !board.hasMoves {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { board.shuffle() }
                show(Toast(text: "Shuffled", color: Theme.muted))
            }
            phase = .playing
        }
    }

    // MARK: - Boosters

    func select(_ booster: Booster) {
        guard phase == .playing else { return }
        if activeBooster == booster {
            activeBooster = nil
            return
        }
        guard store.count(booster) > 0 || store.buy(booster) else {
            show(Toast(text: "Need \(booster.price) coins", color: Theme.muted))
            return
        }
        switch booster {
        case .shuffle:
            store.use(.shuffle)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { board.shuffle() }
        case .moves:
            guard !isArcade else { return }
            store.use(.moves)
            movesLeft += 5
            show(Toast(text: "+5 moves", color: Theme.accent))
        case .hammer, .burst:
            activeBooster = booster
        }
    }

    private func useBooster(_ booster: Booster, at p: Pos) {
        guard phase == .playing else { return }
        activeBooster = nil
        store.use(booster)
        phase = .resolving
        let report = withAnimation(.easeOut(duration: 0.2)) {
            booster == .hammer ? board.pop(at: p) : board.burst(at: p)
        }
        apply(report)
        Task { await settle(emberOut: true) }
    }

    /// Keep playing after running out of moves (not allowed on the daily, to keep scores fair).
    func continueWithMoves() -> Bool {
        guard phase == .lost, !isDaily else { return false }
        guard store.count(.moves) > 0 || store.buy(.moves) else { return false }
        store.use(.moves)
        movesLeft += 5
        phase = .playing
        return true
    }

    // MARK: - Results

    private func record() {
        guard !recorded else { return }
        recorded = true
        switch spec.mode {
        case .level:
            store.recordLevel(spec.number, stars: stars, score: score)
        case .daily(let key):
            store.recordDaily(.init(dateKey: key, won: phase == .won, stars: stars, score: score,
                                    movesLeft: movesLeft, moveLog: moveLog))
        case .arcade:
            store.recordArcade(score: score)
        }
    }

    var shareText: String {
        switch spec.mode {
        case .level: return ShareText.level(spec.number, stars: stars, score: score)
        case .daily:
            guard let r = store.todaysDaily else { return ShareText.arcade(score: score) }
            return ShareText.daily(r, streak: store.liveStreak)
        case .arcade: return ShareText.arcade(score: score)
        }
    }

    private func show(_ t: Toast) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { toast = t }
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if self.toast?.id == t.id { withAnimation(.easeOut(duration: 0.25)) { self.toast = nil } }
        }
    }
}
