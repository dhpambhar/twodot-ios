import SwiftUI

struct BoardView: View {
    @ObservedObject var vm: GameViewModel
    let colorblind: Bool

    var body: some View {
        GeometryReader { geo in
            let rows = CGFloat(vm.board.rows), cols = CGFloat(vm.board.cols)
            let cell = min(geo.size.width / cols, geo.size.height / rows)
            let selected = Set(vm.tracer.path)

            ZStack(alignment: .topLeading) {
                cellLayer(cell: cell)
                connector(cell: cell)

                ForEach(vm.placedPieces) { placed in
                    PieceView(piece: placed.piece, cell: cell,
                              selected: selected.contains(placed.pos),
                              armed: vm.armedColor != nil && placed.piece.color == vm.armedColor,
                              colorblind: colorblind)
                        .frame(width: cell, height: cell)
                        .position(center(placed, cell: cell))
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .scale(scale: 0.1).combined(with: .opacity)))
                }

                ForEach(vm.flashes, id: \.self) { p in
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.9), .white.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: cell * 1.5))
                        .frame(width: cell * 3, height: cell * 3)
                        .position(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.3), value: vm.flashes)
            .frame(width: cell * cols, height: cell * rows)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { vm.drag(to: $0.location, cell: cell) }
                    .onEnded { vm.release(at: $0.location, cell: cell) }
            )
            .clipped()
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game board")
    }

    private func center(_ placed: PlacedPiece, cell: CGFloat) -> CGPoint {
        let row = CGFloat(vm.spawnRows[placed.id] ?? placed.pos.r)
        return CGPoint(x: (CGFloat(placed.pos.c) + 0.5) * cell, y: (row + 0.5) * cell)
    }

    @ViewBuilder
    private func cellLayer(cell: CGFloat) -> some View {
        ForEach(vm.board.allPositions, id: \.self) { p in
            let c = vm.board[p]
            if !c.isHole {
                ZStack {
                    RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                        .fill(Theme.boardWell)
                    if c.frost > 0 {
                        RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                            .fill(GoalKind.frost.tint.opacity(0.25 + 0.2 * Double(c.frost)))
                        RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), lineWidth: max(1, cell * 0.03 * CGFloat(c.frost)))
                        Image(systemName: "snowflake")
                            .font(.system(size: cell * 0.18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(cell * 0.08)
                    }
                    if c.ember {
                        RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                            .fill(RadialGradient(colors: [GoalKind.ember.tint.opacity(0.75), GoalKind.ember.tint.opacity(0.15)],
                                                 center: .center, startRadius: 0, endRadius: cell * 0.6))
                        Image(systemName: "flame.fill")
                            .font(.system(size: cell * 0.18, weight: .bold))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(cell * 0.08)
                    }
                }
                .padding(cell * 0.04)
                .frame(width: cell, height: cell)
                .position(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func connector(cell: CGFloat) -> some View {
        if let color = vm.tracer.color, !vm.tracer.path.isEmpty {
            Path { path in
                let points = vm.tracer.path.map { CGPoint(x: (CGFloat($0.c) + 0.5) * cell, y: (CGFloat($0.r) + 0.5) * cell) }
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
                if let finger = vm.finger, !vm.tracer.isLoop { path.addLine(to: finger) }
            }
            .stroke(color.color, style: StrokeStyle(lineWidth: cell * 0.14, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)
        }
    }
}

struct PieceView: View {
    let piece: Piece
    let cell: CGFloat
    let selected: Bool
    let armed: Bool
    let colorblind: Bool

    @State private var pulse = false

    var body: some View {
        switch piece.kind {
        case .dot(let c):
            ZStack {
                Circle()
                    .stroke(c.color.opacity(0.35), lineWidth: cell * 0.07)
                    .frame(width: cell * 0.62, height: cell * 0.62)
                    .opacity(selected ? 1 : 0)
                    .scaleEffect(selected ? 1 : 0.6)
                Circle()
                    .fill(c.color)
                    .frame(width: cell * 0.46, height: cell * 0.46)
                    .shadow(color: c.color.opacity(armed ? 0.8 : 0.25), radius: armed ? 8 : 2, y: 1)
                if colorblind {
                    Image(systemName: c.glyph)
                        .font(.system(size: cell * 0.2, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .scaleEffect(selected ? 1.12 : (armed && pulse ? 1.1 : 1))
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: selected)
            .animation(armed ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .default, value: pulse)
            .onChange(of: armed) { _, isArmed in pulse = isArmed }

        case .seed:
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [GoalKind.seed.tint.opacity(0.85), GoalKind.seed.tint],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: cell * 0.56, height: cell * 0.56)
                Image(systemName: "arrow.down")
                    .font(.system(size: cell * 0.24, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Seed")

        case .burst:
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: DotColor.allCases.map(\.color) + [DotColor.coral.color], center: .center))
                    .frame(width: cell * 0.5, height: cell * 0.5)
                Image(systemName: "sparkles")
                    .font(.system(size: cell * 0.22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
