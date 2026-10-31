import SwiftUI

struct ResultCard: View {
    @EnvironmentObject private var store: ProgressStore
    @ObservedObject var vm: GameViewModel
    let onExit: () -> Void
    let onReplay: (LevelSpec) -> Void

    @State private var shownStars = 0
    @State private var notEnoughCoins = false

    private var won: Bool { vm.phase == .won }

    var body: some View {
        VStack(spacing: 18) {
            BloomMark(size: 54)
                .rotationEffect(.degrees(won ? 360 : 0))
                .animation(.easeOut(duration: 1.2), value: won)

            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)

            if won || vm.isArcade {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < shownStars ? "star.fill" : "star")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(i < shownStars ? Theme.gold : Theme.muted.opacity(0.4))
                            .scaleEffect(i < shownStars ? 1 : 0.8)
                    }
                }
            }

            VStack(spacing: 2) {
                Text("\(vm.score)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(subtitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }

            VStack(spacing: 12) {
                if !won && !vm.isDaily {
                    Button {
                        if !vm.continueWithMoves() { notEnoughCoins = true }
                    } label: {
                        Label(store.count(.moves) > 0 ? "+5 Moves (\(store.count(.moves)) left)" : "+5 Moves · \(Booster.moves.price)",
                              systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PillButtonStyle(tint: DotColor.sky.color))
                }

                if won, vm.spec.mode == .level {
                    Button("Next level") { onReplay(LevelGenerator.level(vm.spec.number + 1)) }
                        .buttonStyle(PillButtonStyle())
                } else if !vm.isDaily {
                    Button(won ? "Play again" : "Try again") { onReplay(replaySpec) }
                        .buttonStyle(PillButtonStyle(tint: won ? DotColor.grape.color : Theme.accent))
                }

                HStack(spacing: 12) {
                    ShareLink(item: vm.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Theme.boardWell, in: Capsule())
                    }
                    Button(action: onExit) {
                        Label("Map", systemImage: "map.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Theme.boardWell, in: Capsule())
                    }
                }
                .foregroundStyle(Theme.ink)
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
        .card()
        .padding(24)
        .task {
            let target = vm.stars
            for i in 0..<target {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shownStars = i + 1 }
                Feedback.shared.link(i * 3)
            }
        }
        .alert("Not enough coins", isPresented: $notEnoughCoins) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Win levels and play the daily to earn more.")
        }
    }

    private var title: String {
        if vm.isArcade { return "Time!" }
        if won { return vm.stars == 3 ? "Superbloom!" : "Bloomed!" }
        return "Out of moves"
    }

    private var subtitle: String {
        if vm.isArcade { return "Best \(max(store.state.arcadeBest, vm.score))" }
        if won { return "\(vm.movesLeft) moves to spare" }
        return vm.isDaily ? "Come back tomorrow for a new daily" : "So close. Give it another go"
    }

    private var replaySpec: LevelSpec {
        vm.isArcade ? LevelGenerator.arcade(seed: UInt64.random(in: 1...UInt64.max)) : vm.spec
    }
}
