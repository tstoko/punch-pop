# Punch Pop — agent handoff

Updated 23 October 2026. Start with this file and the root README. The repository contains the complete Godot source and test evidence; no account or backend is required to play.

## Latest owner feedback

The owner approved publishing v0.5 as-is with comments. Read [the playtest critique](v5-design-critique.md) before future design work: fuller-cut bonuses, streaks between rows, progressive difficulty, an exploratory bomb and, especially, fiddly mouse/phone selection. These are recorded proposals, not implemented features.

## Current state

The implemented build is **0.5.0**, a native portrait Godot 4.5.1 game. Read [v0.5 build notes](v5-build-notes.md). Android export exists, but physical-device QA and commercial validation remain.

The latest request authorized a team-led improvement of aesthetics and gameplay. The implemented pass replaces dual pressure with one visible timed rise, varies endless openings, preserves clear match explanations, adds score milestones, and improves tiles, cutter cards, effects and sound.

## Actual rules in 0.5

- Board: 7 × 9, four colours, three colour-specific cutter cards. A cut removes at least two blocks of its own colour.
- Gravity settles blocks. Four or more same-colour orthogonal neighbours automatically clear. Further waves multiply match points. Direct cuts award 10 per block; automatic waves award 20 × wave per block.
- The cumulative decision clock starts at eight seconds. Expiry pushes a previewed bottom row upward; a block already at the top causes atomic loss. Cuts never reset the clock or schedule rows.
- Pressure level increases each 12 cuts or 20 active seconds, capped at eight. Future clock intervals shorten to 3.5 seconds. Menus, animation, training and focus loss pause time.
- Replenishment occurs only when no legal cutter exists. Sparse playable boards remain sparse, giving successful cuts value.
- Endless openings vary by seed; the fixed authored chain pocket is training-only. Automatic tray chain hints are training-only, but selected-move forecasts remain.
- Score milestone UI and celebrations start at 500, then 1,000, 2,000, 3,500, 5,000 and every 2,500 thereafter. These are presentation goals, not score bonuses.
- One-step undo restores cut state and RNG but never thinking time. Timed rises clear undo. Resume preserves completed state and partial time without offline catch-up.
- Reduced motion, strong colours, audio, haptics, help and three untimed lessons remain available.

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

Latest validated results are documented in `docs/v5-build-notes.md`, `docs/v5-render-audit.json`, `docs/v5-pressure-audit.json` and `docs/v5-runtime-smoke.json`. The main suite passed 9,205 checks. Old v4 reports are historical.

Graphical audit/capture tools use isolated temporary saves. They open windows and must obey the desktop preference below. Bots and desktop frame timings do not demonstrate human retention or phone performance.

## User workflow preference

**Do not disrupt the user's active Mac desktop.** Keep coding and automated tests in the background. Open or focus native game/browser windows only on **Desktop 2**. Godot (`org.godotengine.godot`) was confirmed assigned to Desktop 2 on the original Mac, but that assignment is an OS preference and is not included in this repository. Verify it before GUI work; if unavailable, use headless checks and leave the GUI closed. Do not create or message other Codex chats unless the user explicitly authorizes it.

## Assets and licensing

Artwork and sounds are generated in project code; `assets/icon.svg` is original vector art. Barlow Condensed is bundled with its SIL Open Font License at `assets/fonts/OFL.txt`. No open-source license has been chosen for the original game code. The repository is private by default. Generated Godot caches, credentials, signing keys and player save data do not belong in Git.
