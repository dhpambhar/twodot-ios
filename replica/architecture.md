# DotBloom architecture

Offline single-player game, no backend for v1.

| layer | choice | why |
| --- | --- | --- |
| UI | SwiftUI, iOS 17+, iPhone + iPad | one codebase, native animation |
| Engine | pure Swift value types (`Board`, `PathTracer`) | deterministic, unit-tested, no UI imports |
| Levels | `LevelGenerator` seeded by level number / date | infinite content, same daily board for everyone |
| State | `ProgressStore` (Codable JSON in UserDefaults) | small data, no migration pain |
| Feedback | UIKit haptics + AVAudioEngine synthesized pentatonic tones | no licensed audio |
| Sharing | `ShareLink` with an emoji result card | Wordle-style organic growth |
| Project | XcodeGen `project.yml` | no merge conflicts on .xcodeproj |

## Engine rules

- Drag through 2+ orthogonally adjacent dots of one color. Drag back to undo.
- Returning to a dot already in the chain closes a **loop**: every dot of that
  color clears and every cell inside the loop **bursts** (3×3 blast).
- 13+ dots in one chain also clears the whole color.
- **Seeds** can't be linked; they fall and are planted when they reach the
  bottom cell of their column.
- **Frost** (1–3 layers) sits under a dot; each clear on that cell removes a layer.
- **Embers** sit under a dot; clear the dot to put them out. A move that puts
  out no ember lets one spread to a neighbour.
- Holes shape the board. No valid move → auto-shuffle.

## Build order

1. Engine + tests (vertical slice: one level playable)
2. Board view, drag, gravity animation
3. Goals, win/lose, stars, map
4. Boosters, coins
5. Daily challenge + share card + streak, Arcade
6. Sound, haptics, colorblind glyphs, iPad layout
