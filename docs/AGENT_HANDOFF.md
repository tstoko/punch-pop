# Punch Pop — agent handoff

Updated 23 October 2026. Start with this file and the root README. The repository contains the complete Godot source and test evidence; no account or backend is required to play.

## Current state

The implemented build is **0.4.0**, a native portrait Godot 4.5.1 game written in GDScript. It is playable on the user's Mac. An Android export preset exists, but no APK or physical-device QA has been completed. This is not a web game.

The user wants a satisfying, replayable puzzle game with the polish and appeal of leading block games. They liked the new dark arcade artwork, then reported that automatic clearing was confusing and survival too easy. Version 0.3 clarified clears and replaced pastel smiling blocks with faceless bevelled blocks. Version 0.4 added real time pressure and harder supply.

## Actual rules in 0.4

- Board: 7 columns × 9 rows; four colours. Three colour-specific cutters: corner, line, square.
- A cut must remove at least two blocks of the cutter's colour. Other colours inside the footprint stay.
- Gravity settles the board. Orthogonally connected same-colour groups of four or more clear automatically; subsequent falling matches form chains. Full rows and diagonals have no separate clearing rule.
- Direct cuts score 10 per block. Automatic matches score 20 × cascade-wave number per block. Each cascade sequence begins at wave 1.
- A cumulative decision clock begins at 8 seconds. Expiry inserts the previewed row at the bottom and lifts all existing blocks one cell. Any existing top-row block prevents insertion and ends the run atomically.
- Cuts do not reset the timer. Menus, animations, training and app focus loss pause it. No offline catch-up occurs. Long frame stalls do not queue unseen rises.
- Pressure level is the greater of one level per 12 cuts or per 20 active seconds, capped at 8. Each level shortens the next clock interval by 0.75 seconds, down to 3.5 seconds. The current interval finishes normally.
- Move pressure ALSO inserts rows: every two cuts initially; every cut from cut 24; two rows on every third cut from cut 48. Upcoming double rises are labelled in the HUD.
- Sparse-board refills target 14 blocks, stop early for tall boards, and recover legal moves. Preview generation avoids immediate automatic clears on the current board. Intervening cuts may still create a row-assisted match.
- Default input is tap-to-snap. Optional Aim exposes exact top-left cutter origins. Hover/hold predicts direct and cascade points before supply.
- One-step undo restores a cut and its random future but never refunds thinking time. A timed rise invalidates undo. Undo works after cut-caused overflow, not timer death.
- Three untimed authored lessons and a repeated deliberate-chain endless opening teach the rules. Tray chain badges currently reveal available multi-wave opportunities.

## Architecture and persistence

`RoundModel` is authoritative and computes complete event timelines before presentation. `GameManager` animates those events and handles input/lifecycle; `UIManager` draws the interface. Keep model rules and visible explanations in agreement.

- `scripts/core/round_model.gd`: rules, forecasts, clock state, checkpoints and event generation.
- `scripts/core/spawn_manager.gd`: atomic bottom rises and preview generation; old top-drop helpers remain for historical tests.
- `scripts/core/supply_system.gd`: pressure intervals, move cadence and recovery.
- `scripts/core/cutter_manager.gd`: colour filtering, geometry, snapping, usable and varied offers.
- `scripts/core/match_system.gd`, `gravity_system.gd`, `combo_manager.gd`: resolution and scoring.
- `scripts/core/lesson_book.gd`: teaching layouts and endless opening.
- `scripts/core/turn_summary.gd`: receipts from actual events.
- `scripts/game_manager.gd`, `ui_manager.gd`, `effects_manager.gd`, `save_store.gd`: presentation, effects and atomic local saves.

Normal data lives in Godot `user://punch_pop.cfg`, outside this repository. Preserve best scores, preferences and valid saved rounds. Current checkpoint schema is version 3; version 2 loads through migration with a full initial eight-second clock. RNG seed/state are serialized as strings to preserve 64-bit precision. A timed rise saves its expired clock before animation, so interruption owes that rise after Continue. Use isolated test saves, never the player's normal save.

## Run and verify

Install **Godot 4.5.1** (Compatibility renderer) and place `godot` or `godot4` on PATH. macOS launchers also detect `/Applications/Godot.app`. The original Mac development runtime under `/private/tmp` is temporary and is not shipped in Git.

From the repository root:

```sh
./tools/run.sh --headless --editor --import --quit
./tools/test.sh
./tools/test.sh --real-clock
./tools/run.sh --headless --script res://tools/pressure_audit.gd
```

The shell launchers use Bash for macOS/Linux portability. Windows agents can invoke Godot directly: import with `godot --headless --path . --editor --import --quit`, then run `godot --headless --path . --script res://tests/test_runner.gd`. Check for engine script errors as well as the completion marker: Godot can return zero after a script error. `tools/test.sh` enforces both.

Latest validated results:

- Main suite: **4,653 checks, zero failures**. Counts can vary with how long randomized controller scenarios survive.
- Real frame-clock test: **13 checks, zero failures**. It pauses, saves a partially consumed clock, cold-reloads behind Continue, then reaches timer death after 24 active seconds with zero cuts and zero points.
- Pressure audit: **200 seeded sessions**, no stuck runs and no runs reaching the 150-cut cap. At three seconds per decision, medians are 10 cuts random, 17 score seeking, and 25 height aware. See `docs/v4-pressure-audit.json` and `docs/v4-runtime-smoke.json`.
- Desktop renderer: board and tray fit 360×640, 390×844 and 768×1024. These are desktop checks, not phone performance or retention evidence.

Graphical capture tools (`tools/capture.gd` and `tools/render_audit.gd`) open native windows and use isolated Mac `/private/tmp` saves. Adapt those paths when running elsewhere. `next_balance.gd` aliases the current pressure audit. Older audit files and v0.2/v0.3 notes are historical; they do not describe current rules.

## Latest design critique — proposed, NOT implemented

After 0.4, the user asked what would improve the game. The assistant's assessment was that difficulty had improved faster than depth. It proposed:

1. Simplify to ONE timed bottom-rise pressure system, removing move-based rises and keeping restocks only when play would otherwise stop.
2. Make cutter outcomes clearer, phase out automatic chain hints after training, and vary fair opening boards.
3. Give planned chains stronger audiovisual payoff while ordinary cuts stay fast; reduce small technical UI labels.

These are proposals, not changes already made. The current request was to publish the project for another agent. The next agent should use the user's next instructions to select the design work rather than assume these proposals are approved implementation requirements. Preserve the clear four-block explanations while improving the loop. Do not claim commercial superiority or human retention based on bots.

## User workflow preference

**Do not disrupt the user's active Mac desktop.** Keep coding and automated tests in the background. Open or focus native game/browser windows only on **Desktop 2**. Godot (`org.godotengine.godot`) was confirmed assigned to Desktop 2 on the original Mac, but that assignment is an OS preference and is not included in this repository. Verify it before GUI work; if unavailable, use headless checks and leave the GUI closed. Do not create or message other Codex chats unless the user explicitly authorizes it.

## Assets and licensing

Artwork and sounds are generated in project code; `assets/icon.svg` is original vector art. Barlow Condensed is bundled with its SIL Open Font License at `assets/fonts/OFL.txt`. No open-source license has been chosen for the original game code. The repository is private by default. Generated Godot caches, credentials, signing keys and player save data do not belong in Git.
