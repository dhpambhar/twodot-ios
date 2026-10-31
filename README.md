# DotBloom

An original connect-the-dots puzzle game for iPhone and iPad, built in SwiftUI.
Inspired by the gameplay pattern of games like Two Dots. All code, names, art
(drawn in code), sounds (synthesized) and levels (generated) are our own. See
`replica/recon.md` for the research and `replica/features.csv` for parity.

## How to play

- Drag through 2+ dots of one color, up/down/left/right. Drag back to undo.
- Close a **loop** to clear every dot of that color. Anything trapped inside **bursts**.
- 13+ dots in one chain also clears the color.
- **Seeds** can't be linked. Clear the dots below them so they drop to the bottom and get planted.
- **Frost** tiles melt one layer each time the dot on them clears.
- **Embers** go out when the dot on them clears. Skip them for a move and they spread.

## What's in v1

- Endless campaign: worlds of 15 levels, seeded generator with a difficulty
  curve that unlocks mechanics gradually (colors → seeds → frost → holes → embers).
- **Daily Bloom**: one puzzle per day, the same for everyone, with a
  spoiler-free emoji result card for sharing and a daily streak.
- **Bloom Rush**: 60-second score attack.
- Boosters (Pop, Burst, Shuffle, +5 Moves) bought with earned coins.
- No lives, no energy timers, no ads.
- Pentatonic link sounds that rise with chain length, haptics, colorblind
  shapes, dark mode, iPad layout.

## Run it (Mac)

```bash
brew install xcodegen
cd DotBloom && xcodegen generate && open DotBloom.xcodeproj
```

Pick an iPhone or iPad simulator and press Run. `Cmd+U` runs the engine tests.
Set your team and bundle id in `project.yml` before TestFlight.

## Layout

```
DotBloom/
  App/            entry point
  Models/         Pos, DotColor, Piece, Cell, Goal, LevelSpec, Booster
  Engine/         Board (rules), PathTracer (input), LevelGenerator, SeededRNG
  Game/           GameViewModel, GameView, BoardView, ResultCard
  Home/           map, daily card, rush card, intro sheet, settings, shop
  Services/       ProgressStore, Feedback (sound + haptics), ShareText
  DesignSystem/   colors, buttons, brand mark
DotBloomTests/    engine unit tests
```

## Before shipping

- App icon (light, dark and tinted) is in `Assets.xcassets/AppIcon`. Regenerate with `node tools/render-icon.js <out.png> light|dark|tinted`.
- Replace `ShareText.appLink` with the real App Store URL.
- Run the trademark, domain and App Store name checks for "DotBloom" (`/replica-brand`).
- Optional next: Game Center leaderboard for the daily and Rush, StoreKit coin
  packs, season pass, more obstacle types.
