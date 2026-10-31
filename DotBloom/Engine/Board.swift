import Foundation

/// What one clear did, used for goals, score and effects.
struct ClearReport: Equatable {
    var cleared: Set<Pos> = []
    var bursts: [Pos] = []
    var colorCounts: [DotColor: Int] = [:]
    var frostLayers = 0
    var embersOut = 0
    var wasLoop = false

    var dotCount: Int { colorCounts.values.reduce(0, +) }
}

/// The game board. A value type so SwiftUI republishes on every change and
/// tests can copy it freely.
struct Board: Equatable {
    let rows: Int
    let cols: Int
    let colors: [DotColor]
    private(set) var cells: [[Cell]]
    private(set) var seedsToSpawn: Int
    private var rng: SeededRNG
    private var nextId = 1

    static func == (a: Board, b: Board) -> Bool {
        a.cells == b.cells && a.seedsToSpawn == b.seedsToSpawn
    }

    init(spec: LevelSpec) {
        rows = spec.rows
        cols = spec.cols
        colors = spec.colors
        seedsToSpawn = spec.seedsToSpawn
        rng = SeededRNG(seed: spec.seed)
        cells = Array(repeating: Array(repeating: Cell(), count: spec.cols), count: spec.rows)

        for p in spec.holes where inBounds(p) { cells[p.r][p.c].isHole = true }
        for (p, layers) in spec.frost where isPlayable(p) { cells[p.r][p.c].frost = layers }
        for p in spec.embers where isPlayable(p) { cells[p.r][p.c].ember = true }

        for r in 0..<rows {
            for c in 0..<cols where !cells[r][c].isHole {
                cells[r][c].piece = makeDot()
            }
        }

        // Starting seeds go in the top playable cell of random columns.
        var columns = Array(0..<cols).shuffled(using: &rng)
        var placed = 0
        while placed < spec.startSeeds, let c = columns.popLast() {
            if let r = (0..<rows).first(where: { !cells[$0][c].isHole }), r < rows - 1 {
                cells[r][c].piece = Piece(id: takeId(), kind: .seed)
                placed += 1
            }
        }

        if !hasMoves { shuffle() }
    }

    // MARK: - Lookup

    func inBounds(_ p: Pos) -> Bool { p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols }
    func isPlayable(_ p: Pos) -> Bool { inBounds(p) && !cells[p.r][p.c].isHole }
    subscript(_ p: Pos) -> Cell { cells[p.r][p.c] }
    func color(at p: Pos) -> DotColor? { isPlayable(p) ? cells[p.r][p.c].piece?.color : nil }

    var allPositions: [Pos] {
        (0..<rows).flatMap { r in (0..<cols).map { Pos(r: r, c: $0) } }
    }

    var frostCount: Int { allPositions.filter { self[$0].frost > 0 }.count }
    var emberCount: Int { allPositions.filter { self[$0].ember }.count }
    var seedsOnBoard: Int { allPositions.filter { self[$0].piece?.kind == .seed }.count }

    var hasMoves: Bool {
        for p in allPositions {
            guard let c = color(at: p) else { continue }
            if color(at: Pos(r: p.r, c: p.c + 1)) == c || color(at: Pos(r: p.r + 1, c: p.c)) == c {
                return true
            }
        }
        return false
    }

    // MARK: - Moves

    /// Resolve a finished chain.
    mutating func resolve(path: [Pos], isLoop: Bool) -> ClearReport {
        guard let first = path.first, let color = color(at: first) else { return ClearReport() }
        var targets = Set(path)
        var bursts: [Pos] = []

        if isLoop || targets.count >= 13 {
            for p in allPositions where self.color(at: p) == color { targets.insert(p) }
        }
        if isLoop {
            bursts = enclosedCells(by: Set(path)).filter { isPlayable($0) }
        }

        var report = clear(targets, bursts: bursts)
        report.wasLoop = isLoop
        return report
    }

    /// Clear cells, setting off any bursts (chain reactions included).
    mutating func clear(_ initial: Set<Pos>, bursts initialBursts: [Pos]) -> ClearReport {
        var report = ClearReport()
        var targets = initial.filter { isPlayable($0) }
        var queue = initialBursts
        for p in targets where self[p].piece?.kind == .burst { queue.append(p) }
        var detonated = Set<Pos>()

        while let b = queue.popLast() {
            guard detonated.insert(b).inserted else { continue }
            report.bursts.append(b)
            for n in [b] + b.neighbors8 where isPlayable(n) {
                targets.insert(n)
                if self[n].piece?.kind == .burst, !detonated.contains(n) { queue.append(n) }
            }
        }

        for p in targets {
            var cell = cells[p.r][p.c]
            if cell.piece?.kind == .seed { continue }   // seeds only leave by being planted
            if cell.frost > 0 {
                cell.frost -= 1
                report.frostLayers += 1
            }
            if cell.ember {
                cell.ember = false
                report.embersOut += 1
            }
            if let c = cell.piece?.color { report.colorCounts[c, default: 0] += 1 }
            if cell.piece != nil { report.cleared.insert(p) }
            cell.piece = nil
            cells[p.r][p.c] = cell
        }
        return report
    }

    /// Cells inside a closed loop: everything a flood fill from the edges can't reach.
    func enclosedCells(by loop: Set<Pos>) -> [Pos] {
        var outside = Set<Pos>()
        var stack = allPositions.filter { ($0.r == 0 || $0.c == 0 || $0.r == rows - 1 || $0.c == cols - 1) && !loop.contains($0) }
        while let p = stack.popLast() {
            guard inBounds(p), !loop.contains(p), outside.insert(p).inserted else { continue }
            stack.append(contentsOf: p.neighbors4)
        }
        return allPositions.filter { !loop.contains($0) && !outside.contains($0) }
    }

    // MARK: - Gravity

    /// Drop pieces into gaps and refill from the top.
    /// Returns new piece ids mapped to the row (above the board) they fall from.
    mutating func collapse() -> [Int: Int] {
        var spawned: [Int: Int] = [:]
        for c in 0..<cols {
            let playable = (0..<rows).filter { !cells[$0][c].isHole }
            let existing = playable.compactMap { cells[$0][c].piece }
            let missing = playable.count - existing.count
            guard missing > 0 else { continue }
            let fresh = (0..<missing).map { _ in spawnPiece() }
            let column = fresh + existing
            for (i, r) in playable.enumerated() { cells[r][c].piece = column[i] }
            for (i, piece) in fresh.enumerated() { spawned[piece.id] = i - missing }
        }
        return spawned
    }

    /// Plant seeds that reached the bottom of their column.
    mutating func plantSeeds() -> [Pos] {
        var planted: [Pos] = []
        for c in 0..<cols {
            guard let bottom = (0..<rows).last(where: { !cells[$0][c].isHole }) else { continue }
            if cells[bottom][c].piece?.kind == .seed {
                cells[bottom][c].piece = nil
                planted.append(Pos(r: bottom, c: c))
            }
        }
        return planted
    }

    /// Embers creep into one neighbouring cell when a move puts none out.
    mutating func spreadEmber() -> Pos? {
        let candidates = allPositions.filter { p in
            isPlayable(p) && !self[p].ember && self[p].frost == 0 && self[p].piece?.kind != .seed
                && p.neighbors4.contains { isPlayable($0) && self[$0].ember }
        }
        guard let pick = candidates.randomElement(using: &rng) else { return nil }
        cells[pick.r][pick.c].ember = true
        return pick
    }

    /// Re-deal dot colors until a move exists.
    mutating func shuffle() {
        let dotPositions = allPositions.filter { color(at: $0) != nil }
        guard dotPositions.count >= 2 else { return }
        for _ in 0..<60 {
            var palette = dotPositions.compactMap { color(at: $0) }
            palette.shuffle(using: &rng)
            for (i, p) in dotPositions.enumerated() {
                cells[p.r][p.c].piece?.kind = .dot(palette[i])
            }
            if hasMoves { return }
        }
        // Fallback: force a pair.
        for p in dotPositions {
            let right = Pos(r: p.r, c: p.c + 1)
            if let c = color(at: p), color(at: right) != nil {
                cells[right.r][right.c].piece?.kind = .dot(c)
                return
            }
        }
    }

    // MARK: - Boosters

    mutating func pop(at p: Pos) -> ClearReport {
        guard isPlayable(p), self[p].piece?.kind != .seed else { return ClearReport() }
        return clear([p], bursts: [])
    }

    mutating func burst(at p: Pos) -> ClearReport {
        guard isPlayable(p) else { return ClearReport() }
        return clear([], bursts: [p])
    }

    // MARK: - Spawning

    private mutating func takeId() -> Int {
        defer { nextId += 1 }
        return nextId
    }

    private mutating func makeDot() -> Piece {
        Piece(id: takeId(), kind: .dot(colors.randomElement(using: &rng) ?? .coral))
    }

    private mutating func spawnPiece() -> Piece {
        if seedsToSpawn > 0, seedsOnBoard < 2, rng.chance(0.14) {
            seedsToSpawn -= 1
            return Piece(id: takeId(), kind: .seed)
        }
        return makeDot()
    }

    /// Test hook: set a cell's piece directly.
    mutating func setPiece(_ kind: PieceKind?, at p: Pos) {
        cells[p.r][p.c].piece = kind.map { Piece(id: takeId(), kind: $0) }
    }
}
