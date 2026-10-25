# Punch Pop 0.7.1 — stronger pressure

23 October 2026.

The owner approved the v0.7 UI and controls, but found the game far too easy. This patch changes balance only. The UI, input, wildcard punches, finite hands, matching, scoring and incoming-row setup generation remain as in v0.7.

## Balance changes

- Keep the 12-second first interval, then progress through 9.5, 8, 6.5, 5.5, 4.5, 3.25 and 2.75 seconds. Levels advance every 10 cuts or 20 active seconds, whichever is ahead. A pending countdown still finishes normally before its new interval is chosen.
- Single-wave matches earn points but no clock credit. A multi-wave chain earns 0.5 seconds for each wave after the first, capped at 1.5 seconds and the current interval. Forecast and actual events use the same shared calculation; undo removes earned time without refunding thinking time.
- The checkpoint schema remains version 4. Existing rounds retain their saved countdown and valid clock period. The valid lower bound now includes 2.75 seconds; legacy 3.5-second periods remain accepted.
- Application/export versions identify 0.7.1; Android version code is 8. The already-running game is not restarted by this patch.

## Evidence

The v0.7 reports remain preserved. `v7-1-prior-balance.json` extracts the prior policy summaries, including uncapped counts and medians; the original full runs remain in `v7-pressure-audit.json`.

The main suite passed **9,912 checks**, the independent flow suite **271 checks**, and actual-frame-time verification **13 checks**, all with zero failures and clean engine output. The untouched opening ended after 51 active seconds and five timed expiries, with zero moves/score; wall time was 53.248 seconds.

The final audit completed **240 seeded sessions with zero stuck runs**. At three seconds per decision, random play had a median of **46 moves** (p10 41, p90 56), compared with 96 in v0.7. Greedy play had a median of **60 moves** (p10 49, p90 83), compared with the prior 150-move cap. Only 1/40 greedy sessions capped, down from 33/40. Its 39 uncapped sessions had a median of 59 moves.

Height-aware play at six seconds per decision had a median of **33 moves** (p10 25, p90 51), with no capped sessions; v0.7 had capped all 40. The strongest height-aware policy still capped all 40 runs at three seconds, as did its 1.5-second diagnostic and zero-time control cohorts. Expert survival therefore remains bounded only by the audit's 150-move cutoff. The patch measurably hardens random, greedy and slower play; it does not establish a finite survival limit for the strongest bot.

Current results are in `v7-1-pressure-audit.json` and `v7-1-runtime-smoke.json`. The first, intermediate 3.25-second-floor candidate is preserved in `v7-1-first-balance-audit.json`. The final audit uses every legal drag placement and the same seeded policies/caps as the prior v0.7 audit, with an additional 1.5-second height-aware cohort. Capped sessions and uncapped distributions are reported separately. These bot comparisons assess difficulty, not human retention or phone performance.

No graphical or physical-device test is claimed. The approved UI layout, colours, controls and input behaviour are unchanged. One help sentence now says chains buy back time, matching the narrower credit rule.
