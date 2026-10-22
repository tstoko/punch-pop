# Punch Pop 0.4 · rising pressure

This update responds to first-play feedback that survival was too easy. It adds a real decision clock and makes supply more demanding while retaining colour-only cuts and visible four-block matches.

## Rules and fairness

The pressure clock begins at eight seconds. It counts only playable decision time, including holding a preview; cuts and chain reactions do not reset it. At zero, the exact previewed row rises from the bottom, lifting every existing block one cell. If a top-row block would be pushed out, the run ends without partially mutating the board.

Difficulty uses the higher of one level per twelve cuts or one per twenty active seconds. Each level shortens the next clock interval by 0.75 seconds, down to 3.5 seconds. An already-running interval finishes normally. Move pressure adds a row every two cuts initially, one per cut from cut 24, and a double row on every third cut from cut 48. All sources insert from below.

Rows are chosen and previewed in advance. Generation avoids a free automatic match against the board as it currently stands, while allowing the player's intervening cuts to change that setup. A bounded fallback supplies a real cut without an instant match. Sparse-board recovery targets fourteen blocks rather than twenty-one; it still protects tall boards from unnecessary refills. The four-block matching and scoring rules are unchanged.

The clock pauses in menus, during event animations, training and app switching. Long frame stalls do not produce a backlog of unseen rises. Held gestures are cancelled at expiry so a release cannot cut an unexpectedly shifted tile. The warning bar changes colour near expiry and a sound warns at two seconds. The bottom preview, upward animation, ceiling markers, TIME UP explanation and receipt make the source visible.

Undo restores a cut but keeps decision time already spent. Timed rises invalidate undo. Save files include the partial clock, its period, active time and timed-rise count. A rise saves its zero countdown before presentation; interruption owes that same rise after Continue. Offline time causes no catch-up. Previous version-two checkpoints migrate with board, cutters, score and RNG intact and receive a full first eight-second countdown. Best scores and preferences are retained.

## Tuning evidence

The final pressure audit runs forty seeds per profile, two hundred sessions in total, capped at 150 cuts. All sessions ended by overflow; no profile got stuck without a legal cutter and no run hit the cap.

At three seconds of active decision time per cut:

- Random: median 10 cuts, mean 8.9; 10th–90th percentile 4–14.
- Immediate score seeking: median 17 cuts, mean 15.85; 10th–90th percentile 8–25.
- Height aware: median 25 cuts, mean 24.925; 10th–90th percentile 17–34.

Height-aware instant decisions reached a median 41 cuts; six-second decisions reached a median 10. This shows that pace now matters, while managing height still outperforms random play at the same decision speed. The historical v0.2 untimed height-aware median was 48 cuts across a different 100-seed cohort. That is context, not a controlled isolated comparison: pressure, row insertion, generation and recovery all changed together.

Thirty additional idle-player seeds all hit the ceiling without making a cut or earning points. The audit JSON contains per-session records. These are bot results, not proof of human enjoyment, retention or competitor superiority. Real-player difficulty feedback should guide the next tuning pass.

## Verification

The final regression suite passes more than 4,600 checks with no failures. Automated tests cover upward row conservation, atomic ceiling failures, exact preview colours, expiry at zero, invalid clock inputs and saves, no cut bypass at expiry, single rearming, deterministic replay, legacy migration, training/animation/menu/focus pauses, stale gesture cancellation, undo timing and interrupted-rise recovery. Existing cutter, gravity, chain, save, forecast and controller tests remain in the suite.

A separate real-frame-clock smoke test passes thirteen checks: the game runs unattended through its normal frame loop, pauses, serializes a partial countdown, reloads behind Continue, then loses to the third expiry after 24 active seconds (about 26 seconds including menus and animation). It awards zero points and spends zero cuts. `v4-runtime-smoke.json` records the run. The HUD explicitly marks upcoming double-row move rises.

Graphical captures include timer urgency, a real mid-rise board, the settled result and timer-specific loss. Desktop renderer checks cover 360 × 640, 390 × 844 and 768 × 1024 and include a timed rise among actual animated moves. Physical-phone touch, audio and performance testing remains outstanding.

Reproduce with `./tools/test.sh`, `./tools/test.sh --real-clock`, `./tools/run.sh --headless --script res://tools/pressure_audit.gd`, `./tools/run.sh --script res://tools/capture.gd`, and `./tools/run.sh --script res://tools/render_audit.gd`.
