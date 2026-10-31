import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: ProgressStore
    @StateObject private var vm: GameViewModel
    let onExit: () -> Void
    let onReplay: (LevelSpec) -> Void

    @State private var confirmQuit = false

    init(spec: LevelSpec, store: ProgressStore, onExit: @escaping () -> Void, onReplay: @escaping (LevelSpec) -> Void) {
        _vm = StateObject(wrappedValue: GameViewModel(spec: spec, store: store))
        self.onExit = onExit
        self.onReplay = onReplay
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            (vm.armedColor?.color ?? .clear)
                .opacity(0.16)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: vm.armedColor)

            VStack(spacing: 14) {
                hud
                goals
                Spacer(minLength: 8)
                BoardView(vm: vm, colorblind: store.state.colorblind)
                    .aspectRatio(CGFloat(vm.board.cols) / CGFloat(vm.board.rows), contentMode: .fit)
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 12)
                Spacer(minLength: 8)
                boosterTray
            }
            .padding(.vertical, 12)

            if let toast = vm.toast {
                Text(toast.text)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(toast.color)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .id(toast.id)
                    .allowsHitTesting(false)
            }

            if showTutorial {
                tutorial
            }

            if vm.phase == .won || vm.phase == .lost {
                Color.black.opacity(0.35).ignoresSafeArea()
                ResultCard(vm: vm, onExit: onExit, onReplay: onReplay)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: vm.phase)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .confirmationDialog("Leave this level?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onExit)
        } message: {
            Text(vm.isDaily ? "Today's daily will count as not finished. You can come back to it." : "Your progress in this level will be lost.")
        }
        .statusBarHidden()
    }

    private var showTutorial: Bool {
        vm.spec.mode == .level && vm.spec.number == 1 && !store.state.seenTutorial && vm.moveLog.isEmpty
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Button {
                if vm.phase == .playing && !vm.moveLog.isEmpty { confirmQuit = true } else { onExit() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            VStack(spacing: 0) {
                if let t = vm.timeLeft {
                    Text("\(t)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(t <= 10 ? DotColor.coral.color : Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                    Text("seconds").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                } else {
                    Text("\(vm.movesLeft)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(vm.movesLeft <= 3 ? DotColor.coral.color : Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                    Text("moves").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                }
            }
            .animation(.snappy, value: vm.movesLeft)
            .animation(.snappy, value: vm.timeLeft)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(vm.score)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: vm.score)
                Text(vm.spec.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var goals: some View {
        if !vm.spec.goals.isEmpty {
            HStack(spacing: 10) {
                ForEach(vm.spec.goals) { goal in
                    GoalChip(goal: goal, remaining: vm.remaining(goal), colorblind: store.state.colorblind)
                }
            }
            .padding(.horizontal, 16)
        } else if vm.isArcade {
            Text("Clear as many dots as you can!")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
    }

    private var boosterTray: some View {
        HStack(spacing: 14) {
            ForEach(Booster.allCases) { b in
                if !(vm.isArcade && b == .moves) {
                    BoosterButton(booster: b, count: store.count(b), active: vm.activeBooster == b) {
                        vm.select(b)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let b = vm.activeBooster {
                Text(b == .hammer ? "Tap a dot to pop it" : "Tap a spot to burst it")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.surface, in: Capsule())
                    .offset(y: -40)
            }
        }
        .padding(.horizontal)
    }

    private var tutorial: some View {
        VStack(spacing: 10) {
            Text("Drag to link dots of the same color")
                .font(.system(.headline, design: .rounded).weight(.bold))
            Text("Close a square or loop to clear every dot of that color, and burst anything trapped inside.")
                .font(.system(.subheadline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            Button("Got it") { store.set(\.seenTutorial, true) }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
        }
        .foregroundStyle(Theme.ink)
        .padding(22)
        .card()
        .padding(28)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 80)
    }
}

struct GoalChip: View {
    let goal: Goal
    let remaining: Int
    let colorblind: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(goal.kind.tint).frame(width: 22, height: 22)
                if case .color(let c) = goal.kind {
                    if colorblind {
                        Image(systemName: c.glyph).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                } else {
                    Image(systemName: goal.kind.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            if remaining == 0 {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(DotColor.mint.color)
            } else {
                Text("\(remaining)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .animation(.snappy, value: remaining)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: Capsule())
    }
}

struct BoosterButton: View {
    let booster: Booster
    let count: Int
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: booster.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(active ? .white : Theme.ink)
                    .frame(width: 56, height: 56)
                    .background(active ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                Text(count > 0 ? "\(count)" : "+")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(count > 0 ? DotColor.sky.color : Theme.gold, in: Capsule())
                    .offset(x: 6, y: -6)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(active ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: active)
        .accessibilityLabel("\(booster.name), \(count) left")
    }
}
