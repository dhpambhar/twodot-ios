import SwiftUI

struct LevelIntroSheet: View {
    @EnvironmentObject private var store: ProgressStore
    let spec: LevelSpec
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(LevelGenerator.worldName(forLevel: spec.number).uppercased())
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.muted)
                .padding(.top, 24)
            Text(spec.title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            StarRow(stars: store.stars(for: spec.number), size: 22)

            VStack(spacing: 10) {
                ForEach(spec.goals) { goal in
                    HStack {
                        Circle().fill(goal.kind.tint).frame(width: 26, height: 26)
                            .overlay {
                                if !isColorGoal(goal) {
                                    Image(systemName: goal.kind.symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                        Text(description(goal))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                }
                HStack {
                    Image(systemName: "hand.draw.fill").frame(width: 26).foregroundStyle(Theme.muted)
                    Text("in \(spec.moves) moves").font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                }
            }
            .padding(18)
            .background(Theme.boardWell, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .padding(.horizontal, 24)

            Button("Play", action: onPlay)
                .buttonStyle(PillButtonStyle())
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private func isColorGoal(_ goal: Goal) -> Bool {
        if case .color = goal.kind { return true }
        return false
    }

    private func description(_ goal: Goal) -> String {
        switch goal.kind {
        case .color(let c): return "Clear \(goal.target) \(c.name) dots"
        case .seed: return "Plant \(goal.target) seeds (drop them to the bottom)"
        case .frost: return "Melt all \(goal.target) frost tiles"
        case .ember: return "Put out every ember"
        }
    }
}
