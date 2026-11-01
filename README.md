# Punch Pop · 0.9.0

> **0.9.0 work in progress — this README below still describes 0.8.0.** 0.9 is turn-based (no clock): every square of a shape must sit on a block, a new PILLAR shape joins the hand, each punch fills a NEXT ROW meter (matching punches fill it less, early chains are free), and consecutive matching punches build a score streak. The presentation was rebuilt with glossy blocks, match previews and praise pop-ups. Balance comes from `tools/curve_lab.gd` bot sweeps (`./tools/test.sh --lab`). The core and flow test suites have **not** been updated for these rules yet and currently fail.

A colourful portrait puzzle game in Godot 4.5+. Punch a shape through the blocks, let them fall and connect colours for chains. Version 0.8 keeps the approved shape-punch interface and makes efficient decisions matter: punches spend the pressure clock, chains earn time back, and punch costs increase through the run.

**Working with another agent? Read [the handoff](docs/AGENT_HANDOFF.md).** Current changes and verified limits are in [v0.8 build notes](docs/v8-build-notes.md). See [the game direction](docs/game-direction.md) for priorities. Earlier reports remain historical.

## Play

Double-click **Play Punch Pop.command** or run `./tools/run.sh`. The launcher finds Godot on PATH, `/Applications/Godot.app` or the temporary development runtime. Import `project.godot` in [Godot 4.5+](https://godotengine.org/download/) and press F5 to edit/run.

The starting menu offers Play, Learn to Play and Settings. Saved rounds show Continue and New Run. Play starts arcade directly; training is optional, with marked goals and a required teaching cut in each lesson. Best scores, settings and compatible saved rounds are preserved.

## Rules and controls

- **Drag a punch from its card.** A full-size footprint sits above your finger, easing closer near the bottom row so it stays reachable. Release a valid placement to punch at least two blocks, regardless of colour. A card tap only selects it. Return to the tray or release outside the board to cancel.
- **Tap placement also works.** Select a card and tap blocks. Hovering or holding shows the footprint and its expected reward before release.
- **Use your hand of three shapes.** Each punch is spent after use. Keep planning with the remaining cards; a new hand is dealt when none of the current cards can be used.
- **Connect four of one colour.** Gravity drops remaining blocks. Four or more same-colour neighbours touching sides clear automatically; falling blocks can create further waves. Diagonals do not connect, and full rows have no special rule.
- **Fill the footprint for a perfect punch.** Direct hits earn 10 points each. A completely filled stamp adds 5 per block. Automatic matches earn 20 × wave number per block.
- **Every punch spends time.** The current punch cost is shown beside Undo. Aiming shows the net clock change after chain credit and warns when the punch will trigger rows. Invalid placements, canceled gestures and training spend no punch time.
- **Chains buy time.** A cut with two or more automatic waves earns half a second for each wave after the first, capped at 1.5 seconds and the current interval. Chain credit offsets the same punch’s cost before expiry is decided. A single automatic match earns points without adding time. Incoming-row matches do not farm extra time.
- **Make room before the clock expires.** The first interval is 12 seconds. Row intervals gradually shorten to four seconds. Levels advance every eight cuts or 25 active seconds, and punch costs continue increasing after the row interval reaches its floor. Expiry pushes a previewed row up from below. A block already at the top causes loss. Cuts spend the countdown instead of resetting it; any cost beyond zero carries into the next interval.
- **New rows create setups.** Supply favours pairs and triples that can turn into a match after a deliberate punch. Preview generation avoids an immediate clear on the current board; later punches can create row-assisted matches.
- **Recovery keeps a move available.** Recovery rows are added only when no punch can remove at least two blocks. Sparse playable boards remain sparse.
- **Undo restores one cut.** The board, score, punch supply and RNG return to their previous state. Thinking time and punch costs remain spent, and earned chain time is removed. A timed rise clears undo.
- **Pause and Settings** provide sound, vibration, quick or explained clear presentation, reduced motion and stronger colours. Training and Main Menu remain available. Exact Aim is an advanced option; ordinary play uses dragging or tapping.

The clock stops in menus, training, animations and on app switching. Fresh installations use quick presentation; saved explanation preferences remain respected. Keyboard: Esc menu, Z undo, A exact Aim, M sound.

## Saving and privacy

Settled turns and timed rises checkpoint the board, countdown and undo to Godot `user://punch_pop.cfg`. Reopening shows Continue without offline rows. An interrupted cut restores the last completed board. An interrupted expired rise remains owed on Continue. Atomic file replacement protects saves; invalid round data is rejected while valid preferences and best scores remain available.

Checkpoint version 5 migrates versions 2, 3 and 4. It adds cumulative punch effort and any unpaid cost at expiry; v4 boards, lessons and RNG remain unchanged. Legacy cutter colours become unrestricted punches without consuming RNG; valid endless board, score and clock state remain. Legacy training restarts the same lesson with its current teaching layout. RNG seed/state use strings to preserve 64-bit precision. Ending a run clears its resumable checkpoint.

There are no accounts, ads, purchases, analytics or network dependencies. Artwork and sounds are generated locally. Display typography is [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed), under the bundled SIL Open Font License at `assets/fonts/OFL.txt`.

## Architecture

`RoundModel` calculates authoritative turns and event timelines before animation. Forecasts, controller, undo and bots share its rules.

- `scripts/core/round_model.gd`: turns, forecasts, clocks, checkpoints and migrations.
- `scripts/core/cutter_manager.gd`: shape geometry, wildcard hits, placement and punch supply.
- `scripts/core/match_system.gd`, `gravity_system.gd`, `combo_manager.gd`: connected groups, falling, resolution and scoring.
- `scripts/core/lesson_book.gd`, `supply_system.gd`, `spawn_manager.gd`: lessons, openings, pressure and recovery.
- `scripts/game_manager.gd`, `ui_manager.gd`, `effects_manager.gd`: input, lifecycle, drawing, animation and sound.
- `scripts/save_store.gd`, `scripts/core/turn_summary.gd`: atomic storage and actual-event receipts.

## Verify

```sh
./tools/test.sh
./tools/test.sh --flow
./tools/test.sh --real-clock
./tools/test.sh --audit
```

The main suite checks rules, deterministic restore/replay, saves and controller behaviour. The flow suite independently exercises current menu navigation, reachable shape placements, mixed-colour dragging, chain credit, disk saving and undo. Real-clock verification uses actual frame time in a windowless session. The policy audit compares random, greedy and height-aware bots and counts opening opportunities; it writes `docs/v8-pressure-audit.json`. Bot results are engineering evidence, not human playtest results.

On macOS, the wrapper creates a disposable shadow project and uses `/etc/ssl/cert.pem` as public CA roots to avoid sandboxed Keychain lookup. TLS verification and strict engine-error checking remain enabled. The shipped game contains no machine-local certificate path.

Graphical tools `tools/capture.gd` and `tools/render_audit.gd` open native windows. Run them only when Godot's Desktop 2 assignment has been verified, respecting the owner's workflow. Their captures require the same desktop assignment; historical screenshots do not prove the current layout or phone performance.

## Device direction

The owner plans personal testing on iPhone 15 Pro. iOS export, signing and distribution are deferred while gameplay improves. An ARM64 Android export preset remains available, identifying 0.8.0; no device build or physical-phone result is claimed.

For Android export, install matching Godot export templates, OpenJDK 17 and the Android SDK following the [official instructions](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html), then export the Android preset. Physical touch, safe areas, sound, vibration, focus/relaunch and thermal/frame behaviour need device QA.
