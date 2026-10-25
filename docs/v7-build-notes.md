# Punch Pop 0.7 — shape punches and breathing room

23 October 2026.

This redesign simplifies both the rules and the active game screen. A shape now punches every occupied block beneath it; colours determine the matches that happen afterward. The player plans the order of a three-shape hand while watching one rising-row clock.

## Rules and feel

- Punches are unrestricted (`color = -1`). Any occupied footprint cell counts toward the two-hit minimum. Mixed-colour full stamps can earn perfect rewards, including the square, without needing an already-clearing same-colour group.
- The three shapes form a finite hand. A used card stays empty while another current card is usable. Unusable cards are discarded after the board changes; a fresh hand is dealt when no current card remains usable. Sparse boards recover only when no shape can punch two blocks.
- Direct hits earn 10 points each, with 5 extra per block for a full stamp. Colour groups of four or more still clear through gravity, with wave multipliers.
- Cut-created automatic waves earn one second each, capped at three seconds and the current interval. Forecasts and turn receipts include awarded breathing time. Incoming rows and recovery clears do not earn time.
- The clock starts at 12 seconds, then uses 11, 10, 9, 8, 7, 6 and 5 seconds. Pressure levels advance every 12 cuts or 30 active seconds. Menus, animation, training and app focus loss pause it.
- Incoming rows favour short same-colour pairs/triples and bounded searches for a future punch-triggered match, while rejecting immediate arrival matches on the current board. Later punches can change the previewed row’s outcome. This creates deliberate setups without automatic idle score.
- Opening boards vary by seed and contain a discoverable automatic match opportunity; some seek a two-wave chain. Three optional lessons now teach wildcard punches, colour matching and multi-wave chains using the same current rules. Goal markers identify each required teaching cut; other cuts cannot silently skip its intended result.

## Interface and persistence

The board, score, countdown, hand and Undo lead the game screen. Extra flow diagrams, active Aim controls and milestone prompts no longer compete with play. Full-size punch previews hover above the finger, with restrained snapping and clear invalid placement. Card taps select, short movements cannot accidentally cut, and returning to the tray cancels.

The home screen offers direct arcade play, optional training, Continue and Settings. New installations use quick clear presentation; existing explanation preferences remain respected. Exact Aim remains an advanced pause/keyboard option. Audio, haptics, reduced motion and stronger colours remain available.

Checkpoint version 4 accepts versions 2 and 3 and migrates coloured cutter cards to unrestricted punches without consuming RNG. Valid endless boards, scores, clocks and local preferences remain supported. In-progress legacy training restarts the same lesson using its revised layout. Partial hands are valid checkpoints. Undo removes chain-earned time while retaining thinking time spent since the cut, including when saved/reloaded.

The project and Android preset identify **0.7.0**, Android code 7. The owner's personal test device is iPhone 15 Pro; iOS packaging remains deferred.

## Verification

`./tools/test.sh` passed **9,902 checks, zero failures**, with strict engine-error checking enabled. Coverage includes wildcard and legacy geometry, finite hands, every reachable punch shape, full mixed-colour stamps, chain forecasts/receipts, deterministic migrations, lessons, saving, controller input and clock behaviour.

`./tools/test.sh --flow` passed **271 checks, zero failures**. This independent flow suite checks 24 varied openings, all three shapes' reachable perfect punches, actual mixed-colour drag release on the bottom row, continuous downward dragging through snap hysteresis, spent-card selection and checkpoint validity, direct arcade launch, menu navigation, earned time through disk saves, and live/reloaded undo that removes time credit without refunding half a second of thinking.

`./tools/test.sh --real-clock` passed **13 checks, zero failures**. The untouched opening ended after 58 active seconds and five timed expiries, with zero score and moves. Menu pauses, disk serialization, Continue and final save clearing passed. Wall time was 60.31 seconds; see `v7-runtime-smoke.json`.

`./tools/test.sh --audit` completed **200 sessions with zero stuck runs**, using every legal drag placement, including deliberate partial punches. At three seconds per decision, random play lasted a median of 96 moves. Greedy and height-aware medians both reached the 150-move audit cap; 33/40 greedy and all 40 height-aware sessions were capped. All six-second height-aware sessions also reached that cap. Instant bots were capped too because they spend no decision time. These capped results establish a lower bound on survival, not typical human session length.

Supply tuning improved cut-triggered automatic matches under the same policies/caps. Greedy three-second play increased from 6.84% to **17.15%** of cuts making an automatic wave; multi-wave chains rose from 0.77% to 1.33%. Height-aware three-second play increased from 11.8% to **18.77%** matching cuts, with 2.78% multi-wave chains. Six-second height-aware play produced matches on 48.63% of cuts and multi-wave chains on 16.25%. Timer/refill clears are counted separately. The pre-tuning comparison is preserved in `v7-pre-tuning-audit.json`; full current results are in `v7-pressure-audit.json`. These bot measurements guide tuning and do not establish human enjoyment or retention.

Across 100 opening seeds, every board offered all three shapes, a perfect punch and a discoverable automatic match. 62 offered a multi-wave setup; the minimum was 51 legal placements across the hand. Reset time was median 6.322 ms, p95 30.405 ms and maximum 56.162 ms on this Mac during background tests. These are not phone benchmarks.

Visual QA remains unverified: the required Desktop 2 app assignment is absent in the current read-only OS preference result. Headless Godot uses a dummy renderer. Capture/render-audit tools use v7 output paths and current teaching fixtures, but no v7 screenshot or physical-phone result is claimed. Historic v6/v5 screenshots and reports are preserved.
