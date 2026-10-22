# Punch Pop — Game Development Plan

**Goal:** Develop a satisfying, replayable mobile puzzle game with potential for advertising revenue.

**Platform:** Android first, followed by iOS if the game shows promise.

**Technology:** Godot 4, GDScript, 2D graphics.

## 1. Core gameplay

The game consists of a 7 × 9 grid filled partially with four colours of jelly blocks.

The player has three randomly generated cutters available at a time. Each cutter has a colour and shape: an L, a straight line, or a 2 × 2 square.

**Gameplay loop:**
1. Player selects a coloured cutter and positions it over the grid.
2. The cutter removes only blocks matching its colour. A valid move must remove at least two blocks.
3. Blocks above the cleared spaces fall downward.
4. Connected groups of four or more matching blocks automatically explode.
5. Further falling blocks can produce chain reactions, increasing the combo multiplier.
6. Every three cutter moves, a new row of blocks falls into the board.
7. The game ends when a new row cannot fit or no valid move remains.

**Objective:** Survive as long as possible and achieve the highest score.

The key design difference to investigate is colour-selective cutting combined with gravity, rather than simply deleting every tile under a stamp.

## 2. Minimum viable product (MVP)

The first version must contain:

- [ ] 7 × 9 puzzle grid
- [ ] Four types of coloured jelly blocks
- [ ] Three cutter shapes
- [ ] Touch and drag controls
- [ ] Valid-move highlighting
- [ ] Block removal and gravity
- [ ] Automatic matching and chain reactions
- [ ] Score and combo multiplier
- [ ] Incoming rows and game-over rules
- [ ] Restart and best-score saving
- [ ] Basic animations and sound effects
- [ ] Short interactive tutorial

**Do not build yet:** accounts, multiplayer, 500 levels, skins, in-app purchases, advertisements or cloud saves.

## 3. Technical implementation

Create these main systems:

| System | Responsibility |
|---|---|
| BoardManager | Stores grid cells, colours and positions |
| CutterManager | Generates cutters, validates placement and removes blocks |
| GravitySystem | Moves blocks downward into empty spaces |
| MatchSystem | Finds connected groups of matching colours |
| ComboManager | Repeats matches and calculates combo scores |
| SpawnManager | Adds new rows and controls difficulty |
| GameManager | Handles start, restart, turns and game over |
| UIManager | Score display, cutter tray and menus |
| EffectsManager | Animation, particles, audio and vibration |

Use a simple grid array for the actual game rules. Visual animations should follow the calculated results.

Implement automated tests for cutter placement, falling blocks, combo resolution, score calculation and overflow conditions. Generate cutters intelligently enough that players aren't routinely defeated by impossible random combinations.

## 4. Eight-week development schedule

### Week 1 — Functional game board
- Set up Godot and the project structure.
- Display a 7 × 9 board.
- Implement selecting and placing cutters.
- Make blocks disappear under valid cutters.

**Deliverable:** A basic interactive puzzle board.

### Week 2 — Complete game rules
- Add gravity.
- Add automatic matching.
- Add combo scoring.
- Implement incoming rows, game over and restart.
- Fix impossible-move scenarios.

**Deliverable:** A complete playable endless game with placeholder graphics.

### Week 3 — Satisfying gameplay
- Add squashing and stretching.
- Add colourful particle bursts.
- Add distinct sound effects for punches, matches and combos.
- Add subtle screen movement and optional vibration.
- Improve touch responsiveness.

**Deliverable:** A visually satisfying gameplay prototype.

### Week 4 — First player tests
- Test with 20–30 people.
- Observe whether they understand the rules without lengthy instructions.
- Record replay behaviour and complaints.
- Adjust colours, cutter availability and difficulty.
- Remove mechanics that players find frustrating.

**Decision:** Continue only if the core mechanic is demonstrably enjoyable.

### Week 5 — Mobile-ready version
- Optimise portrait display and touchscreen controls.
- Add opening screen, tutorial, settings and best score.
- Save local progress.
- Test on different Android screen sizes.
- Add anonymous gameplay analytics with appropriate privacy handling.

**Deliverable:** Android test build.

### Week 6 — Wider testing
- Recruit 100–300 external players.
- Collect retention and session data.
- Test alternative difficulty curves.
- Fix crashes, freezes and confusing rules.
- Run a structured competitor comparison.

**Decision:** Improve, pivot or stop based on the evidence.

### Week 7 — Monetisation and discovery
Only if retention is promising:
- Test optional rewarded ads.
- Add carefully spaced advertisements at round boundaries.
- Record gameplay videos for TikTok, Instagram and YouTube.
- Prepare app icon, screenshots and store description.
- Begin any required store testing process.

### Week 8 — Limited release
- Release to a small audience where eligible.
- Monitor retention, crashes and ad revenue.
- Measure installs resulting from each marketing channel.
- Calculate revenue per player and acquisition cost.
- Decide whether the game deserves further investment.

## 5. Success criteria

Use these initial targets to guide decisions, not as promises of commercial success.

| Metric | Initial target |
|---|---|
| Tutorial completion | 80%+ |
| Players choosing another round | 70%+ in first playtest |
| Day-one retention | 30%+ in a larger test |
| Day-seven retention | 10%+ |
| Game-breaking bugs | Zero known |
| Acquisition economics | Projected lifetime value exceeds acquisition cost |

Small test groups are noisy. These results should be used to identify patterns, not treated as definitive proof.

## 6. Monetisation strategy

The game will be free.

Primary potential revenue:
- Optional rewarded video advertisements.
- Occasional full-screen ads between rounds.
- Optional one-time purchase to remove forced advertisements.

Do not put advertising in the first prototype. Add it only once retention is worth protecting.

The business objective is to earn more per player over their lifetime than it costs to acquire them.

## 7. Marketing strategy

- Create short clips of actual chain reactions and near-failures.
- Publish across TikTok, Shorts and Reels.
- Invite small mobile gaming creators to test the game.
- Add shareable high scores and daily challenges after launch.
- Track views, clicks, installs, repeat play and actual revenue.

Do not spend heavily on paid advertising until lifetime value and retention are measured.

## 8. Final decision

At the end of testing, choose one of three outcomes:

**Continue:** Players return voluntarily, feedback is strong, and monetisation shows a plausible route to profitability.

**Pivot:** Players enjoy the visual effects but the decisions are boring, confusing or too repetitive. Redesign the central mechanic.

**Stop:** Players don't replay after multiple iterations, and acquisition economics offer no convincing path to profit.

The priority is to build something people repeatedly choose to play, not to complete a feature list.