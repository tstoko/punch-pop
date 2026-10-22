# Punch Pop 0.5 — breathing room and chain payoff

23 October 2026.

This pass makes a successful cut feel useful: cuts remove blocks without also scheduling a new row. The visible countdown is now the only pressure source. Recovery adds blocks only when no legal cutter exists. Timing, scoring, four-block matching, undo's no-time-refund rule and checkpoint schema remain compatible.

## Gameplay and presentation

- Endless starts are seeded, varied, settled puzzles with three to five blocks per column and multiple usable cutter candidates. The authored two-wave pocket remains in training.
- Endless no longer labels the best chain on each cutter. Hold/hover forecasts still explain the selected move. Training retains chain hints.
- Score goals progress through 500, 1,000, 2,000, 3,500 and 5,000, then in 2,500-point steps. They derive from score, so undo and reload cannot corrupt progression.
- A darker indigo stage, inset board, rounded bevelled tiles and colour-coded cutter cards establish a stronger visual hierarchy. Pattern marks and stronger-colour mode remain available.
- Ordinary cuts have shorter impact animations. Chains have centered score feedback, explicit celebrations, layered sparks and rising musical chords. Explanations remain enabled by default, with shorter anticipation.
- Reduced motion uses stationary fading halos. Effects are capped at 240 particles and 72 rings; idle effects stop processing. Sound/haptics preferences are preserved.

## Verification

The main suite passed **9,205 checks, zero failures**. Added coverage includes varied legal openings, no move-triggered rises at late-game cut counts, no refill of sparse playable boards, score-target boundaries and training-only hints. Save tests use isolated temporary files.

The Desktop 2 renderer audit passed board/tray bounds at 360×640, 390×844 and 768×1024. Images are `v5-audit-*.png`; detailed results are in `v5-render-audit.json`. Median idle frame time was 11.22 ms, p95 12.96 ms on this Mac. These are desktop measurements, not physical-phone results.

The real frame-clock suite passed **13 checks, zero failures**, including pause, cold reload and an idle loss after 38.5 active seconds for the tested opening.

The **200-session** pressure audit found zero stuck runs. At three seconds per decision, median cuts were 35 for random play, 41 for score-seeking and 79 for height-aware play. Six of forty height-aware runs reached the 150-cut audit cap. Instant bots all reached that cap because no decision time elapsed; six-second height-aware bots lasted a median of 20 cuts. These checks show a skill-sensitive model, not human engagement.

`v5-pressure-audit.json` and `v5-runtime-smoke.json` contain the new model and real-clock evidence. Older reports and screenshots describe older versions.

## Commercial next steps

This is a stronger playable iteration, not evidence of retention or advertising revenue. No advertising SDK, analytics, purchases or network services have been added. Before monetization, observe first-time players learning cuts, predicting chains and voluntarily replaying; measure run length, tutorial completion and return rates with appropriate consent. Then validate voluntary rewarded placements between runs without interrupting decision time. Android touch, safe areas, thermal performance, audio and lifecycle behavior still need physical-device QA.
