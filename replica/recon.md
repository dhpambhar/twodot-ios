# Recon map: Two Dots → DotBloom (original iOS/iPadOS game)

Clean-room rebuild of the **gameplay patterns** of Two Dots (Playdots / Zynga,
`com.weplaydots.twodotsandroid` v26.40.00). We did not open, decompile or reuse
anything inside the APK: no code, art, audio, level data, names or copy. Only the
archive's file listing (package id, version) was read. Everything below comes
from public sources.

## Scope

- **Platform:** iPhone + iPad, SwiftUI, iOS 17+, offline-first.
- **Slice:** the core loop (connect dots → meet goals in N moves → next level),
  its obstacles, boosters, map progression, a daily challenge and sharing.
- **Who it's for:** a new, original, ad-light casual puzzle brand built to be
  shared (daily seed + spoiler-free result card, like Wordle).

## Sources

| source | what it gave us |
| --- | --- |
| [Wikipedia: Two Dots](https://en.wikipedia.org/wiki/Two_Dots_(video_game)) | core rules (2+ orthogonal, loop clears color, enclosed dots become bombs, 13+ clears color, auto-scramble), lives 5 / 20 min, reception |
| [App Store listing](https://apps.apple.com/app/two-dots-brain-puzzle-games/id880178264) | modes (Scavenger Hunt, Arcade, Flip, Treasure Hunt, Rewind), season pass, IAP list and prices, Game Center, colorblind mode |
| [Helpshift FAQ: Treasure Hunts](https://dots.helpshift.com/hc/en/3-two-dots/faq/386-what-are-treasure-hunts) | 7-level timed events |
| [Gamezebo review](https://www.gamezebo.com/reviews/twodots-review-brother-can-you-spare-a-dot/) | lives system is the most disliked part |
| [iMore tips](https://www.imore.com/twodots-top-10-tips-hints-and-cheats-you-need-know) | anchors, ice, squares strategy |
| [Macworld](https://www.macworld.com/article/224594/you-should-play-twodots-brings-a-much-needed-twist-to-the-match-three-genre.html) | IAP prompts at tempting moments |
| [Kimola review analysis](https://kimola.com/reports/unlock-player-insights-with-two-dots-feedback-analysis-report-app-store-my-151207) | 2025 complaints: crashes, confusing levels, intrusive ads |

## Screen inventory

| ID | screen | how you get there | purpose | key components | states |
| --- | --- | --- | --- | --- | --- |
| S01 | Splash/launch | app open | brand | logo mark | — |
| S02 | World map | home tab | pick next level, see progress | winding path of level nodes, stars, world headers | locked, current, cleared (1–3★) |
| S03 | Level intro | tap node | show goals and moves | goal chips, booster toggles, Play | — |
| S04 | Game board | Play | the core loop | HUD (moves, goals, score), 6×6–8×8 grid, line drawing, booster tray | idle, dragging, loop armed, cascading, no-moves shuffle, paused |
| S05 | Win | goals met | reward, stars | stars, score, Next, Share | 1/2/3★ |
| S06 | Out of moves | moves = 0 | retry / continue | +5 moves offer, retry | — |
| S07 | Pause | pause button | settings in-game | resume, restart, quit, sound | — |
| S08 | Events/daily | events tab | time-limited content | daily puzzle card, streak | played, not played |
| S09 | Shop | coins tap | buy boosters/coins | packs | — |
| S10 | Settings | gear | sound, haptics, colorblind | toggles | — |
| S11 | Arcade/timed | events tab | beat the clock | timer HUD | — |

## User flows

```
F01 Play the next level (core loop)            happy path: 3 taps + drag
    S02 map -> S03 intro -> S04 board -> S05 win -> S02 (next node unlocked)
    edge: out of moves (S06), no valid moves (auto shuffle), quit mid-level (S07)

F02 Use a booster
    S04 -> tap booster -> tap dot / auto effect -> cascade
    edge: no boosters left -> S09

F03 Daily challenge and share
    S08 -> S04 (seeded board, same for everyone today) -> S05 -> share card
    edge: already played today -> show result + countdown

F04 Arcade (timed)
    S08 -> S11 -> score -> share
```

## Components

Level node (locked / current / 1–3★), goal chip (icon + remaining count, done
check), moves counter, dot (6 colors + shape glyph for colorblind), connector
line, booster button (count badge), primary pill button, modal sheet, star row,
coin pill, toast/combo burst.

## Inferred data model

```
Level      id, rows, cols, colors (count), moves, goals [Goal], layout (cell types),
           star thresholds                             evidence: S03/S04   confidence: high
Goal       kind (collect color | anchors | ice | fire | score), target
Cell       hole | normal, ice (hp 1–3), fire, anchor drop
Piece      dot(color) | anchor | bomb | (blocker)
Progress   level -> best stars/score, coins, boosters {hammer, shuffle, bomb, extraMoves}
           lives (we drop this), daily streak, last daily date
```

## Feature matrix

See `features.csv`.

## What cannot be cloned (skip)

- Name, logos, characters (Emily, Uncle Jack), art, music, level designs, story
  copy: owned by Zynga/Take-Two. DotBloom uses its own name, colors, glyphs,
  procedurally generated levels and synthesized sounds.
- 5,000+ handcrafted levels: replaced by a hand-tuned first world plus a seeded
  level generator with a difficulty curve.
- Scavenger Hunt hidden-object art, seasonal content pipeline, live-ops team.
- Network effects (friends leaderboards) beyond Game Center.

## Size

11 screens, 4 flows, 4 core entities. Hard parts: loop detection + enclosed-dot
bombs, gravity/cascade animation on SwiftUI, level difficulty tuning.
Size: **M** for a polished v1; the core playable build in this repo is the
vertical slice.

## What we do better (from the complaints)

1. **No lives / no energy wall.** Unlimited retries; the #1 complaint gone.
2. **No pop-up ads**; monetization later via cosmetic themes + optional booster packs.
3. **Daily seeded puzzle + emoji result card** for organic sharing.
4. **Colorblind glyphs on by default option**, haptics on every link.
5. Native iPad layout, no 600 MB download.
