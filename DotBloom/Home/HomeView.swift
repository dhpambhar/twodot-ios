import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let spec: LevelSpec
}

private struct IntroItem: Identifiable {
    let id: Int
}

struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var intro: IntroItem?
    @State private var session: GameSession?
    @State private var showSettings = false
    @State private var showShop = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    header
                    DailyCard { session = GameSession(spec: LevelGenerator.daily(LevelGenerator.todayKey())) }
                    RushCard { session = GameSession(spec: LevelGenerator.arcade(seed: UInt64.random(in: 1...UInt64.max))) }
                    LevelMap(current: store.currentLevel) { intro = IntroItem(id: $0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .onAppear { proxy.scrollTo(store.currentLevel, anchor: .center) }
            .onChange(of: session == nil) { _, closed in
                if closed { withAnimation { proxy.scrollTo(store.currentLevel, anchor: .center) } }
            }
        }
        .sheet(item: $intro) { item in
            LevelIntroSheet(spec: LevelGenerator.level(item.id)) {
                intro = nil
                session = GameSession(spec: LevelGenerator.level(item.id))
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShop) { ShopView().presentationDetents([.medium, .large]) }
        .fullScreenCover(item: $session) { s in
            GameView(spec: s.spec, store: store,
                     onExit: { session = nil },
                     onReplay: { session = GameSession(spec: $0) })
                .id(s.id)
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BloomMark(size: 36)
            Text("DotBloom")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { showShop = true } label: { CoinPill(coins: store.state.coins) }
                .accessibilityLabel("Shop, \(store.state.coins) coins")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }
}

// MARK: - Daily

struct DailyCard: View {
    @EnvironmentObject private var store: ProgressStore
    let onPlay: () -> Void

    var body: some View {
        let key = LevelGenerator.todayKey()
        let result = store.todaysDaily

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY BLOOM #\(LevelGenerator.dailyNumber(key))")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(result == nil ? "Same puzzle for everyone today" : (result!.won ? "You bloomed today!" : "Better luck tomorrow"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                if store.liveStreak > 0 {
                    Label("\(store.liveStreak)", systemImage: "flame.fill")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.2), in: Capsule())
                        .accessibilityLabel("\(store.liveStreak) day streak")
                }
            }

            if let result {
                HStack {
                    StarRow(stars: result.stars, size: 18)
                    Text("\(result.score) pts").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    ShareLink(item: ShareText.daily(result, streak: store.liveStreak)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("Next daily in \(countdown(from: ctx.date))")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                Button(action: onPlay) {
                    Text("Play today's puzzle")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Theme.accent, DotColor.grape.color], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
        )
        .shadow(color: Theme.accent.opacity(0.3), radius: 14, y: 6)
    }

    private func countdown(from now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let next = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now
        let s = max(0, Int(next.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

struct RushCard: View {
    @EnvironmentObject private var store: ProgressStore
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(DotColor.sky.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bloom Rush").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
                    Text("60 seconds, endless moves · Best \(store.state.arcadeBest)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(DotColor.sky.color)
            }
            .padding(14)
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Map

struct LevelMap: View {
    @EnvironmentObject private var store: ProgressStore
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let lastShown = ((current + 10) / LevelGenerator.levelsPerWorld + 1) * LevelGenerator.levelsPerWorld
        let worlds = stride(from: 1, through: lastShown, by: LevelGenerator.levelsPerWorld).map { $0 }

        LazyVStack(spacing: 0) {
            ForEach(worlds, id: \.self) { first in
                worldHeader(first: first)
                ForEach(first..<(first + LevelGenerator.levelsPerWorld), id: \.self) { n in
                    LevelNode(number: n, stars: store.stars(for: n), state: state(n)) { onSelect(n) }
                        .offset(x: sin(Double(n) * 0.85) * 92)
                        .padding(.vertical, 6)
                        .id(n)
                }
            }
        }
        .padding(.top, 8)
    }

    private func state(_ n: Int) -> LevelNode.State {
        n < current ? .cleared : (n == current ? .current : .locked)
    }

    private func worldHeader(first: Int) -> some View {
        let range = first..<(first + LevelGenerator.levelsPerWorld)
        let earned = range.reduce(0) { $0 + store.stars(for: $1) }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("WORLD \((first - 1) / LevelGenerator.levelsPerWorld + 1)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.muted)
                Text(LevelGenerator.worldName(forLevel: first))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Label("\(earned)/\(range.count * 3)", systemImage: "star.fill")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.gold)
        }
        .padding(16)
        .card()
        .padding(.vertical, 14)
    }
}

struct LevelNode: View {
    enum State { case cleared, current, locked }

    let number: Int
    let stars: Int
    let state: State
    let action: () -> Void

    @SwiftUI.State private var pulse = false

    private var tint: Color {
        DotColor.allCases[(number - 1) % DotColor.allCases.count].color
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if state == .current {
                        Circle()
                            .stroke(tint.opacity(0.4), lineWidth: 6)
                            .frame(width: 84, height: 84)
                            .scaleEffect(pulse ? 1.12 : 0.95)
                            .opacity(pulse ? 0.2 : 1)
                    }
                    Circle()
                        .fill(state == .locked ? AnyShapeStyle(Theme.boardWell) : AnyShapeStyle(tint.gradient))
                        .frame(width: state == .current ? 72 : 62, height: state == .current ? 72 : 62)
                        .shadow(color: state == .locked ? .clear : tint.opacity(0.35), radius: 8, y: 4)
                    if state == .locked {
                        Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                    } else {
                        Text("\(number)")
                            .font(.system(size: state == .current ? 26 : 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 90, height: 90)
                if state == .cleared { StarRow(stars: stars, size: 12) }
                if state == .current {
                    Text("PLAY")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(tint)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
        .onAppear {
            guard state == .current else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel(state == .locked ? "Level \(number), locked" : "Level \(number), \(stars) stars")
    }
}
