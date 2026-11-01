# Punch Pop — agent handoff

Updated 26 October 2026. Read this and the README before changing the game.

## Current direction

The owner approved the v0.7 interface but still found v0.7.1 too easy. They authorized a coordinated gameplay improvement. Version 0.8 keeps the layout/input, shape punches, finite hands and supply setups while charging each punch against the visible countdown. The direction is deliberate, efficient cuts and chains rather than shallow rapid cutting. See [game direction](game-direction.md). The personal test phone is iPhone 15 Pro; packaging/signing remains deferred.

The implemented build is **0.8.0**, native portrait Godot 4.5.1. Read [v0.8 build notes](v8-build-notes.md). Earlier build notes, screenshots and policy reports are historical. No physical-device performance or retention claim follows from the automated results.

## Current rules

- The board is 7 × 9, with four block colours. Three shape punches use `color = -1`: every occupied footprint cell is removed, with at least two hits needed. Colours matter for automatic matches only. Legacy colour-specific helpers remain for compatibility checks.
- Punches form a finite hand. Used slots stay empty; remaining legal punches are retained until no current card is usable, then a new three-shape hand is dealt. Unusable remaining cards may be discarded after the board changes. Empty slots are valid save data.
- Gravity settles blocks; connected orthogonal groups of four or more of one colour clear. Successive waves multiply match points. Direct hits earn 10 each, plus 5 each for a completely filled footprint. Automatic points are 20 × wave × block count.
- Only cut-triggered multi-wave chains earn time: half a second per wave after the first, capped at 1.5 seconds and the current interval. A single automatic wave grants no time. Forecasts include `time_bonus`; actual breathing events carry awarded time. Timer/refill clears do not earn it.
- The countdown opens at 12 seconds and row intervals shorten through 10, 8.5, 7, 6, 5, 4.5 and 4 seconds. Pressure advances every eight cuts or 25 active seconds; displayed levels continue beyond eight.
- A successful arcade punch spends `rise_period × min(1.5, 0.1 + 0.1 × (level - 1))` seconds. The opening cost is 1.2 seconds; a settled late-game cost is six seconds. Chain credit offsets the cost before expiry. The forecast shows net clock change and ROW / ROWS warnings; the footer shows gross cost.
- Cost beyond zero is carried in `pending_effort` and paid by subsequent clock intervals. Each owed rise still uses the ordinary preview, presentation, checkpoint and atomic-overflow path. No further punch can resolve with an expired clock. Menus, animation, training and focus loss pause active time.
- Incoming supply uses bounded candidate rows with pairs/triples and near-bottom punch-created match opportunities. It rejects immediate arrival matches; do not reintroduce idle point farming.
- Expiry pushes a previewed bottom row upward. An already occupied top row causes atomic loss. Recovery rows appear only if no two-block punch exists.
- Undo restores board/score/RNG and removes awarded chain time while retaining actual thinking time AND gross punch effort. `RoundModel.restore_undo()` owns this accounting; timed rises clear undo.
- Training marks a specific goal and accepts its required teaching cut, keeping the example consistent with its explanation.
- The home menu provides Play/Continue, New Run when saved, optional Learn to Play and Settings. Main Play enters arcade directly. Pause → Main Menu checkpoints the run.
- Card dragging requires 12 logical pixels of movement. Its full-size footprint sits up to 100 logical pixels above the finger, easing to 40 near the bottom edge; stable nearby placements prevent jitter. Returning to the tray or leaving board bounds cancels. Tapping a card selects it; tap placement remains. Exact Aim is an advanced pause option/keyboard shortcut rather than a main HUD control.
- Quick clear presentation is the fresh-install default. Existing saved explanation preferences remain respected. Reduced motion, stronger colours, sound and haptics remain.

## Architecture and saves

`RoundModel` calculates full turns before presentation. Keep forecast, model events, controller and visible explanations in agreement. Source responsibilities are listed in the README.

Normal player data lives in Godot `user://punch_pop.cfg`, outside the repository. Preserve it. Checkpoint version 5 adds `effort_seconds` and `pending_effort`; v2–4 initialize these to zero. Only v2–3 require changing legacy punch colours to -1 without RNG consumption. Version 4 lessons and RNG are preserved. Valid endless board, score, clock and RNG state remain; legacy training restarts the same lesson with its new layout; version 2 gains a full initial clock because it predates timer state. Seed/state are strings to preserve 64-bit precision. Tests use isolated temporary saves.

A timed rise checkpoints the expired clock before animation; interruption must replay the owed rise. The main-menu clock cannot advance. Undo must never retain chain credit or refund active thinking time or punch cost; derive both debits from the pre-cut checkpoint.

## Verification

```sh
./tools/test.sh
./tools/test.sh --flow
./tools/test.sh --real-clock
./tools/test.sh --audit
```

The wrapper retains strict engine-error filtering. On macOS it creates a disposable shadow project, with system PEM CA roots to avoid sandboxed Keychain lookup without disabling TLS verification. Never ship that machine-local path in `project.godot`.

Current evidence belongs in `v8-build-notes.md`, `v8-runtime-smoke.json` and `v8-pressure-audit.json`. Quick screening reports must remain clearly separated from full cohorts. The flow suite independently verifies present UX/rules; the policy audit counts opening affordability and compares bot strategies. Bot survival and desktop timings are not human engagement or phone performance.

## Owner workflow

**Do not disrupt the active Mac desktop.** Open/focus native game or browser windows only on Desktop 2. Godot (`org.godotengine.godot`) had that assignment on the original machine, but it is an OS preference and must be verified each time; an empty `defaults read com.apple.spaces app-bindings` result does not verify it. Prefer background/headless work otherwise. Do not create or message other Codex chats without explicit authorization.

Graphical capture/render-audit tools open native windows. Their v7 filenames preserve historical evidence, but do not run them without a verified desktop assignment. A currently open game is not permission to move windows or change OS preferences.

## Assets

Block art and audio are generated by project code. `assets/icon.svg` is original. Barlow Condensed and its SIL Open Font License are bundled. No licence has been chosen for original game code. Do not commit caches, player saves, credentials or signing material.
