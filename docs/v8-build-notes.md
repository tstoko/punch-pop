# Punch Pop 0.8.0 — make each punch count

26 October 2026.

The owner reports that v0.7.1 is still too easy and authorized a coordinated gameplay improvement. This update keeps the approved interface and input while making efficient punches matter. See [game direction](game-direction.md) for the design commitments and release sequence.

## Rules

Each successful arcade punch now spends the existing visible pressure clock. Cost starts at 1.2 seconds and increases with the pressure level. Automatic matches still clear space; cut-created multi-wave chains return 0.5 seconds per wave after the first, capped at 1.5 seconds. The reward offsets punch cost before deciding expiry. Training, invalid placements and canceled gestures pay no cost.

Pressure advances every eight cuts or 25 active decision seconds, whichever is ahead. Row intervals follow 12, 10, 8.5, 7, 6, 5, 4.5 and 4 seconds. Levels continue after the interval reaches four seconds. Cost is the current interval multiplied by `min(1.5, 0.1 + 0.1 × (level − 1))`; at the normal late-game four-second interval it reaches six seconds at level 15 (112 cuts or 350 active seconds).

The cost is carried across countdown boundaries. A late-game punch can therefore trigger two rises. There is still one pressure clock and one row preview; each owed rise uses the existing animation, checkpoint and atomic ceiling-loss rules. The next punch cannot bypass an owed rise. Chain credit is settled before this calculation so a chain can prevent a rise.

## Feedback

Aiming shows the net clock change after chain credit, plus an amber ROW / ROWS ×N warning when the move will trigger supply. Clock-dependent fields update while holding the same placement, without recomputing the cached board resolution. This also fixes the stale chain-time preview identified in the earlier review.

The footer beside Undo shows current gross punch cost and explains that chains buy time. Home, help, training footer and level notices explain the new rule within the existing layout. Headless font measurements confirmed that extreme preview strings fit the existing 420-pixel region using its existing text sizing. No graphical screenshot or physical-phone layout check is claimed.

## Saving and undo

Checkpoint version 5 adds cumulative gross `effort_seconds` and `pending_effort` for unpaid cost at a zero countdown. Versions 2–4 initialize these fields to zero. Version 4 boards, lessons, saved countdowns, hands and RNG survive unchanged. Older colour-selective saves retain the existing conversion. Historical 2.75-second intervals remain accepted and move onto the new curve after their next expiry.

Undo restores the board, score, hand and random future while retaining both actual thinking time and all spent punch effort. It removes chain credit. Replaying a reversed punch pays again. Timed rises still clear undo.

Independent review found and fixed a validation edge case: removing chain credit after using it to think can legitimately leave debt greater than cumulative punch effort. A regression now checks save/reload and deterministic row resolution for that case. Existing preferences and high scores remain; scores from different balance versions are not directly comparable.

## Verification

On Godot 4.5.1:

- Core/controller suite: **9,751 checks, zero failures**.
- Independent flow suite: **271 checks, zero failures**.
- Actual-frame-time suite: **13 checks, zero failures**, five expiries and 56 active seconds before idle ceiling loss. Evidence: [runtime report](v8-runtime-smoke.json).
- Fresh copied project with no `.godot` cache: import and core suite passed with clean engine output. On this sandboxed Mac, the clean import needed access to the public certificate store; TLS verification remained enabled.
- Diff whitespace checks passed. No native game windows were opened, and normal player data was not used by the tests.

New regressions cover last-second cost carryover, blocked input at zero clock, deterministic owed rises after save/reload, multiple consecutive live rises, live row warnings while holding aim, training exemption, v4 migration, undo retaining cost, and the chain-funded-thinking save case. The aggregate check count changes with how soon seeded replay sessions end; the lower count than v0.7.1 does not represent removed test scenarios.

## Strategy evidence

The full [v0.8 audit](v8-pressure-audit.json) ran **240 seeded sessions**, 40 per cohort, with a 150-move cutoff and **zero stuck runs**. Policies, seeds and decision-time cohorts match the historical [v0.7.1 audit](v7-1-pressure-audit.json). All legal drag placements remain available, including partial punches.

- Height-aware play at three seconds per move: median **88 moves** (p10 69, p90 114), **0/40 capped**, versus v0.7.1's 150-move median and 40/40 capped.
- Height-aware play at 1.5 seconds: median **123 moves** (p10 101, p90 150), **4/40 capped**, versus 150 and 40/40 capped.
- Random play at three seconds: median **31 moves**, versus 46.
- Greedy play at three seconds: median **47 moves**, versus 60.
- Height-aware play at six seconds: median **34 moves**, versus 33. Slower play is not materially harder in this cohort; the four-second interval preserves more thinking time.
- The zero-thinking-time diagnostic still capped **30/40** sessions. This update does not establish a finite survival limit for an instantaneous strategy with complete forecasts.

These results support a stronger challenge for fast, efficient play while preserving a skill gradient: height-aware play outlasts greedy play, which outlasts random play at the same decision time. They do not establish human enjoyment, retention or phone performance.

The matched five-seed [baseline screen](v7-1-pressure-baseline-quick.json) and [final candidate screen](v8-pressure-screening.json) are preserved separately from the full report. The full audit supersedes screening for the shipped candidate.

## Next decision

Restart the game to play v0.8.0; an already-running process keeps its old rules. Begin a fresh run for a clean balance comparison. Observe when pressure becomes meaningful, whether an inefficient punch explains the loss, and whether a chain provides satisfying recovery. Tune cost growth first if the result feels punitive or rushed. Keep packaging, extra modes and monetization behind this playtest.

Application and Android export metadata identify 0.8.0, Android version code 9. No export, signing, device build, repository push or release publication was performed.
