import XCTest
@testable import DotBloom

final class EngineTests: XCTestCase {
    private func spec(rows: Int = 6, cols: Int = 6, colors: [DotColor] = [.coral, .sky, .mint, .sun]) -> LevelSpec {
        LevelSpec(number: 1, rows: rows, cols: cols, colors: colors, moves: 20, goals: [], seed: 42)
    }

    /// Paint the whole board in a checker of two colors so nothing links by accident.
    private func checkerBoard(_ b: inout Board) {
        for p in b.allPositions { b.setPiece(.dot((p.r + p.c) % 2 == 0 ? .sky : .mint), at: p) }
    }

    // MARK: PathTracer

    func testTracerLinksSameColorOrthogonally() {
        var b = Board(spec: spec())
        checkerBoard(&b)
        b.setPiece(.dot(.coral), at: Pos(r: 0, c: 0))
        b.setPiece(.dot(.coral), at: Pos(r: 0, c: 1))
        b.setPiece(.dot(.coral), at: Pos(r: 1, c: 1))

        var t = PathTracer()
        _ = t.begin(at: Pos(r: 0, c: 0), color: .coral)
        XCTAssertEqual(t.move(to: Pos(r: 1, c: 1)) { b.color(at: $0) }, .none, "diagonal must not link")
        XCTAssertEqual(t.move(to: Pos(r: 0, c: 1)) { b.color(at: $0) }, .extended)
        XCTAssertEqual(t.move(to: Pos(r: 0, c: 2)) { b.color(at: $0) }, .none, "other color must not link")
        XCTAssertEqual(t.move(to: Pos(r: 1, c: 1)) { b.color(at: $0) }, .extended)
        XCTAssertEqual(t.move(to: Pos(r: 0, c: 1)) { b.color(at: $0) }, .backtracked)
        XCTAssertEqual(t.distinctCount, 2)
    }

    func testTracerClosesSquare() {
        var b = Board(spec: spec())
        checkerBoard(&b)
        let square = [Pos(r: 2, c: 2), Pos(r: 2, c: 3), Pos(r: 3, c: 3), Pos(r: 3, c: 2)]
        for p in square { b.setPiece(.dot(.coral), at: p) }

        var t = PathTracer()
        _ = t.begin(at: square[0], color: .coral)
        for p in square.dropFirst() { _ = t.move(to: p) { b.color(at: $0) } }
        XCTAssertEqual(t.move(to: square[0]) { b.color(at: $0) }, .closedLoop)
        XCTAssertTrue(t.isLoop)
        XCTAssertEqual(t.distinctCount, 4)
        XCTAssertEqual(t.move(to: square[3]) { b.color(at: $0) }, .backtracked)
        XCTAssertFalse(t.isLoop)
    }

    // MARK: Board

    func testChainClearsOnlyPath() {
        var b = Board(spec: spec())
        checkerBoard(&b)
        b.setPiece(.dot(.coral), at: Pos(r: 5, c: 0))
        b.setPiece(.dot(.coral), at: Pos(r: 5, c: 1))
        b.setPiece(.dot(.coral), at: Pos(r: 0, c: 5))   // same color, not in the chain

        let report = b.resolve(path: [Pos(r: 5, c: 0), Pos(r: 5, c: 1)], isLoop: false)
        XCTAssertEqual(report.colorCounts[.coral], 2)
        XCTAssertEqual(b.color(at: Pos(r: 0, c: 5)), .coral)
        XCTAssertNil(b[Pos(r: 5, c: 0)].piece)
    }

    func testLoopClearsColorAndBurstsInside() {
        var b = Board(spec: spec())
        checkerBoard(&b)
        // 3x3 ring of coral around (2,2), plus a far coral dot.
        let ring = [Pos(r: 1, c: 1), Pos(r: 1, c: 2), Pos(r: 1, c: 3), Pos(r: 2, c: 3),
                    Pos(r: 3, c: 3), Pos(r: 3, c: 2), Pos(r: 3, c: 1), Pos(r: 2, c: 1)]
        for p in ring { b.setPiece(.dot(.coral), at: p) }
        b.setPiece(.dot(.coral), at: Pos(r: 5, c: 5))

        XCTAssertEqual(b.enclosedCells(by: Set(ring)), [Pos(r: 2, c: 2)])

        let report = b.resolve(path: ring + [ring[0]], isLoop: true)
        XCTAssertTrue(report.wasLoop)
        XCTAssertEqual(report.bursts, [Pos(r: 2, c: 2)])
        XCTAssertNil(b[Pos(r: 5, c: 5)].piece, "loop clears every dot of the color")
        XCTAssertNil(b[Pos(r: 2, c: 2)].piece, "enclosed dot bursts")
    }

    func testThirteenChainClearsColor() {
        var b = Board(spec: spec(rows: 8, cols: 8))
        checkerBoard(&b)
        var path: [Pos] = []
        for c in 0..<8 { path.append(Pos(r: 7, c: c)) }
        for c in stride(from: 7, through: 3, by: -1) { path.append(Pos(r: 6, c: c)) }
        for p in path { b.setPiece(.dot(.coral), at: p) }
        b.setPiece(.dot(.coral), at: Pos(r: 0, c: 0))

        _ = b.resolve(path: path, isLoop: false)
        XCTAssertNil(b[Pos(r: 0, c: 0)].piece)
    }

    func testCollapseFillsEveryPlayableCell() {
        var s = spec()
        s.holes = [Pos(r: 3, c: 3)]
        var b = Board(spec: s)
        _ = b.clear([Pos(r: 5, c: 3), Pos(r: 4, c: 3), Pos(r: 0, c: 0)], bursts: [])
        let spawned = b.collapse()
        XCTAssertEqual(spawned.count, 3)
        XCTAssertTrue(spawned.values.allSatisfy { $0 < 0 }, "new pieces fall from above")
        for p in b.allPositions where b.isPlayable(p) { XCTAssertNotNil(b[p].piece) }
        XCTAssertNil(b[Pos(r: 3, c: 3)].piece, "holes stay empty")
    }

    func testSeedPlantsAtBottom() {
        var b = Board(spec: spec())
        checkerBoard(&b)
        b.setPiece(.seed, at: Pos(r: 4, c: 2))
        _ = b.clear([Pos(r: 5, c: 2)], bursts: [])
        _ = b.collapse()
        XCTAssertEqual(b[Pos(r: 5, c: 2)].piece?.kind, .seed)
        XCTAssertEqual(b.plantSeeds(), [Pos(r: 5, c: 2)])
        XCTAssertNil(b[Pos(r: 5, c: 2)].piece)
    }

    func testFrostTakesOneLayerPerClear() {
        var s = spec()
        s.frost = [Pos(r: 5, c: 5): 2]
        var b = Board(spec: s)
        _ = b.pop(at: Pos(r: 5, c: 5))
        XCTAssertEqual(b[Pos(r: 5, c: 5)].frost, 1)
        _ = b.collapse()
        _ = b.pop(at: Pos(r: 5, c: 5))
        XCTAssertEqual(b.frostCount, 0)
    }

    func testEmberSpreadsToNeighbour() {
        var s = spec()
        s.embers = [Pos(r: 2, c: 2)]
        var b = Board(spec: s)
        let spread = b.spreadEmber()
        XCTAssertNotNil(spread)
        XCTAssertTrue(spread.map { $0.isAdjacent(Pos(r: 2, c: 2)) } ?? false)
        XCTAssertEqual(b.emberCount, 2)
    }

    func testShuffleGuaranteesAMove() {
        var b = Board(spec: spec(colors: DotColor.allCases))
        for p in b.allPositions { b.setPiece(.dot(DotColor.allCases[(p.r * 2 + p.c) % 6]), at: p) }
        XCTAssertFalse(b.hasMoves)
        b.shuffle()
        XCTAssertTrue(b.hasMoves)
    }

    // MARK: Levels

    func testLevelsAreDeterministicAndSane() {
        for n in 1...120 {
            let a = LevelGenerator.level(n), b = LevelGenerator.level(n)
            XCTAssertEqual(a, b)
            XCTAssertFalse(a.goals.isEmpty, "level \(n) needs a goal")
            XCTAssertTrue((12...40).contains(a.moves), "level \(n) moves \(a.moves)")
            XCTAssertTrue(a.goals.allSatisfy { $0.target > 0 })
            XCTAssertTrue(Board(spec: a).hasMoves)
        }
    }

    func testDailyIsSameForEveryone() {
        XCTAssertEqual(LevelGenerator.daily("20261115"), LevelGenerator.daily("20261115"))
        XCTAssertNotEqual(LevelGenerator.daily("20261115").seed, LevelGenerator.daily("20261116").seed)
        XCTAssertEqual(LevelGenerator.dailyNumber("20261101"), 1)
    }
}
