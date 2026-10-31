import Foundation

/// Tracks the chain the player is drawing. Pure value type, no UI.
struct PathTracer: Equatable {
    enum Event: Equatable { case none, began, extended, backtracked, closedLoop }

    private(set) var path: [Pos] = []
    private(set) var isLoop = false
    private(set) var color: DotColor?

    var isEmpty: Bool { path.isEmpty }

    /// Number of distinct dots in the chain (a loop repeats its first dot).
    var distinctCount: Int { isLoop ? path.count - 1 : path.count }

    mutating func begin(at p: Pos, color: DotColor) -> Event {
        path = [p]
        isLoop = false
        self.color = color
        return .began
    }

    mutating func move(to p: Pos, colorAt: (Pos) -> DotColor?) -> Event {
        guard let last = path.last, p != last else { return .none }

        // Dragging back onto the previous dot undoes the last link.
        if path.count >= 2, p == path[path.count - 2] {
            path.removeLast()
            isLoop = false
            return .backtracked
        }

        guard !isLoop, last.isAdjacent(p), colorAt(p) == color else { return .none }

        if path.contains(p) {
            // With orthogonal links a closed shape always has 4+ dots.
            path.append(p)
            isLoop = true
            return .closedLoop
        }

        path.append(p)
        return .extended
    }

    mutating func reset() {
        path = []
        isLoop = false
        color = nil
    }
}
