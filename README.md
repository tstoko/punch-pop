# Punch Pop · 0.5

**Working on this with another agent? Start with [the agent handoff](docs/AGENT_HANDOFF.md).**

A portrait Godot 4.5+ puzzle game about colour-selective cuts, gravity and chain reactions. Version 0.5 gives the game one readable timed pressure system, varied opening puzzles, score milestones and a richer arcade presentation. Previous saved boards, preferences and high scores are preserved.

## Play

Double-click **Play Punch Pop.command** or run `./tools/run.sh`. The launcher finds Godot on PATH, in `/Applications/Godot.app`, or in the temporary development runtime. Install [Godot 4.5+](https://godotengine.org/download/) for ongoing use if macOS removes that temporary runtime. Import `project.godot` in Godot and press **F5** to edit/run.

Your best score and preferences from the first prototype are preserved. The new three-part tutorial is offered once, and is always available through **pause → Training**.

## How it plays

- **Tap an outlined block.** A cutter is ready automatically. It removes at least two blocks of its own colour. Other colours inside the footprint stay put.
- Pick a different cutter card to change colour or shape. The tray prefers distinct usable cutters and new colours when the board permits.
- **Hover or hold/slide to preview.** Checkmarks show the direct hits; the text predicts direct and cascade points **before incoming rows/refills**. Training chain badges help teach multi-wave setups; endless mode leaves discovery to the player.
- Gravity drops the remaining blocks. **Four or more of the same colour touching sides clear automatically**, in any shape. Diagonals do not connect, and full rows have no special clearing rule. Each matching group is outlined, linked, counted and explained before removal. More waves earn higher multipliers. New rows can form matches using the same rule.
- **Beat the rising clock.** It starts at 8 seconds of active decision time. At zero, the previewed row enters from below and pushes every block up one cell. Cuts do not reset it. Pressure levels rise every 12 cuts or 20 active seconds, whichever is ahead, shortening future intervals down to 3.5 seconds. The current interval finishes normally when a level changes.
- **Cuts create breathing room.** Making a move never adds a scheduled row. The visible countdown is the only pressure source.
- **Keep below the ceiling.** If a rise would push an existing top-row block out of the board, the run ends atomically. Amber/red markers identify tall columns; the timer turns amber/red near expiry and sounds a two-second warning when sound is enabled.
- **Recovery keeps play possible.** Fresh rows are added only if no legal cutter remains. Low occupancy alone does not trigger a refill. Preview generation avoids immediate automatic clears on the current board; cuts can still create row-assisted matches.
- **Chase the next milestone.** The score meter advances through 500, 1,000, 2,000, 3,500 and 5,000 points, then every 2,500. Each run starts from a varied, settled puzzle.
- **Undo** restores one previous cut, including its cascades, rows, cutters, score and random state. It never refunds thinking time. A timer rise clears the undo, including on timer death. Undo still works after a move-caused overflow. High scores remain intact.
- **Aim** is optional. Tap a marked top-left corner to choose an exact stamp placement, including outcomes automatic snapping cannot select. Turn it off to return to easy block taps.
- **Pause** contains sound, optional vibration, clear explanations (on by default; switch to Quick for shorter anticipation), reduced motion, stronger colours, fresh round and training. Keyboard: **Esc** menu, **Z** undo, **A** Aim, **M** sound.

Training is untimed. The pressure clock pauses in menus, during animations and on app switching. Countdown expiry cancels held input before moving the board. There is no account, ad, in-app purchase, analytics or network dependency. Block artwork and sounds are generated locally in Godot. Display typography uses [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed), licensed under the SIL Open Font License; the bundled license is `assets/fonts/OFL.txt`.

## Resume and local data

Every settled cut or timed rise saves the round, partial pressure clock and available one-step undo to `user://punch_pop.cfg`, together with the best score, tutorial version and preferences. Reopening offers **Continue**; no offline rows accumulate. Model checkpoints include 64-bit RNG seed/state as strings, avoiding numeric precision loss.

If the app closes during a cut animation, the previous completed board and pre-cut clock remain on disk. A timer rise checkpoints its expired countdown before animation, so interruption replays the owed rise after Continue. Saving uses a temporary file and atomic rename. Invalid or incompatible round data is rejected while valid preferences and best scores remain available. App focus loss cancels held gestures; a resolving turn finishes and then pauses.

An overflow ending clears the resumable round. A cut-caused loss retains undo on the game-over screen; time-caused losses do not. Beginning a fresh round replaces the saved round.

## Architecture

- `scripts/core/turn_summary.gd`: direct-cut, automatic-match, row and score receipts from actual events.
- `scripts/core/round_model.gd`: authoritative pure turn calculation, event timeline, prediction and checkpoint validation.
- `scripts/core/supply_system.gd`: timer intervals and recovery row selection.
- `scripts/core/lesson_book.gd`: three authored lessons and varied endless openings.
- `scripts/core/board_manager.gd`: 7 × 9 cell array.
- `scripts/core/cutter_manager.gd`: footprints, legal moves, snapping and diverse cutter supply.
- `scripts/core/gravity_system.gd`: stable falling order and movement records.
- `scripts/core/match_system.gd`: orthogonal flood-fill groups.
- `scripts/core/combo_manager.gd`: shared scoring and cascade resolution.
- `scripts/game_manager.gd`: input, event presentation, undo, lifecycle and saving.
- `scripts/ui_manager.gd`: cached drawing styles, bevelled block art, forecasts, warnings and menus.
- `scripts/effects_manager.gd`: landing/anticipation feedback, particles, layered synthesised audio and haptics.
- `scripts/save_store.gd`: atomic local configuration and validated round storage.

The model calculates the complete turn before animations. UI, bot tests and undo use the same rules. Direct cuts award 10 points per block; automatic matches award 20 × wave number per block. Each new cascade phase starts at wave 1. Tutorial points do not affect the endless high score.

## Verification

```sh
./tools/test.sh
./tools/test.sh --real-clock
./tools/run.sh --headless --script res://tools/pressure_audit.gd
./tools/run.sh --script res://tools/capture.gd
./tools/run.sh --script res://tools/render_audit.gd
```

`./tools/test.sh --real-clock` runs an unattended, windowless session using actual frame time, including pause, disk reload and ceiling loss. The capture and renderer-audit commands open native windows; run those only on the desktop reserved for game testing.

The suite covers atomic upward insertion, reliable idle deaths, no idle point farming, clock persistence and migration, no time refunds through undo, interrupted rises, paused menus/animations/training/app focus, and cancellation of held input at expiry. It also verifies that highlighted groups exist on the visible board, every automatic clear has a cause, turn receipts match actual points, a multicolour full row stays intact, and explanation controls persist. It covers every cutter shape, colour exclusion, borders, gravity, matching, scoring, overflow, recovery, deterministic restore/replay, all three lessons, interruption recovery, undo after game over, corrupted checkpoints, legacy migration, touch cancellation and focus loss. The wrapper rejects GDScript errors even when Godot exits with status zero.

The historical v0.4 pressure audit ran 200 seeded sessions: random, score-seeking and height-aware policies at three seconds per decision, plus instant and six-second height-aware policies. The current command writes `docs/v5-pressure-audit.json`. Bot thinking time excludes presentation animations, matching the live clock. These are engineering checks, not evidence of human retention. `next_balance.gd` is a compatibility alias; the previous `docs/v2-balance.json` stays historical. Renderer checks capture small/tall/tablet layouts and desktop frame timings; they are not physical-phone benchmarks.

## Android

An ARM64 Android export preset is included. No APK or physical-device performance result is claimed.

1. Install matching export templates through **Editor → Manage Export Templates**.
2. Configure OpenJDK 17 and the Android SDK using the [official Godot Android export instructions](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html).
3. Create `builds/`, then export a debug APK through **Project → Export → Android**, or run `./tools/run.sh --headless --export-debug Android builds/PunchPop.apk`.
4. Test real touch, small-screen readability, notches/insets, audio, vibration, app switching, force-close/relaunch and frame pacing before distribution.

## Playtest direction

The owner’s [v0.5 playtest feedback and design critique](docs/v5-design-critique.md) records proposed cut bonuses, streaks, difficulty tuning, bombs and input improvements. These proposals are not implemented in this build.

## Development evidence

The original [quality review](docs/quality-review.md), [v0.2 notes](docs/v2-build-notes.md), [v0.3 notes](docs/v3-build-notes.md) and old simulations are historical baselines. See [v0.5 build notes](docs/v5-build-notes.md) for current changes and verification. Earlier screenshots and pressure reports are historical.

Human playtesting, Android QA and commercial validation remain. The next decision should come from 20–30 first-time players predicting cuts, planning chains and choosing another round voluntarily.
