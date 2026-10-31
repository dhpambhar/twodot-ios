import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feel") {
                    Toggle("Sound", isOn: binding(\.soundOn) { Feedback.shared.soundOn = $0 })
                    Toggle("Haptics", isOn: binding(\.hapticsOn) { Feedback.shared.hapticsOn = $0 })
                }
                Section {
                    Toggle("Colorblind shapes", isOn: binding(\.colorblind))
                } footer: {
                    Text("Adds a shape to every dot so colors never matter.")
                }
                Section("Progress") {
                    LabeledContent("Levels cleared", value: "\(store.state.stars.count)")
                    LabeledContent("Stars", value: "\(store.totalStars)")
                    LabeledContent("Rush best", value: "\(store.state.arcadeBest)")
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                }
                Section {
                    Text("DotBloom has no lives and no timers on retries. Play as much as you like.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetProgress() }
            }
        }
    }

    private func binding(_ path: WritableKeyPath<ProgressStore.State, Bool>, onSet: ((Bool) -> Void)? = nil) -> Binding<Bool> {
        Binding(get: { store.state[keyPath: path] },
                set: { store.set(path, $0); onSet?($0) })
    }
}

struct ShopView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Booster.allCases) { b in
                        HStack(spacing: 14) {
                            Image(systemName: b.symbol)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading) {
                                Text(b.name).font(.headline)
                                Text("You have \(store.count(b))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                store.buy(b)
                            } label: {
                                Label("\(b.price)", systemImage: "circle.hexagongrid.fill")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.gold)
                            .disabled(store.state.coins < b.price)
                        }
                    }
                } footer: {
                    Text("Earn coins by clearing levels, keeping your daily streak and setting Rush records.")
                }
            }
            .navigationTitle("Shop")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CoinPill(coins: store.state.coins) } }
        }
    }
}
