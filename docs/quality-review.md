# Punch Pop: quality review and competitive development priorities

**Review date: 22 October 2026.**

**Historical review of version 0.1.** Version 0.2 implements a new loop, teaching puzzles, undo, resume and feedback improvements. See [the v0.2 build notes](v2-build-notes.md) and `v2-balance.json` for current results. The findings below describe the previous build.

Punch Pop is a promising playable prototype, but it is not yet at the standard of a mature mobile puzzle game. The most important gap is the relationship between clearing, survival and player choice. More decorative artwork alone will not close that gap.

Its best opportunity is a small, polished puzzle about deliberately setting up satisfying jelly cascades, with clear rules and fair outcomes. This is a design direction to validate, not a claim that it will beat Block Blast commercially.

## What was actually tested

- **2,344 automated checks pass** on Godot 4.5.1, including cutter rules, chains, exact scoring, overflow, touch cancellation, save/restart, and the new focus-loss regressions.
- **900 seeded simulated sessions**: 150 each for random and immediate-score-seeking play under the current three-move row cadence, a two-move cadence, and a separate sparse-board refill experiment. Each session has a 150-move cap.
- **3,078 cutter/board positions** across 60 further seeds, comparing distinct settled-board-plus-score outcomes with the outcomes reachable through snapping.
- **Real desktop rendering** at 360 × 640, 390 × 844 and 768 × 1024 window sizes. Board and cutter tray fit in all three. Screenshots were inspected.
- **An 11-move controller-driven rendered playthrough**, ending at 740 points with no matching pairs. Full move resolution ranged from about 0.16 to 1.68 seconds. This measures animation/settling duration, not physical input latency.
- A short desktop frame sample: 180 idle frames, median 16.67 ms, p95 21.72 ms. This Mac had other desktop activity; this is diagnostic evidence, not a controlled benchmark or an Android performance result.

There were no human participants, no physical Android/iPhone tests and no day-one/day-seven retention measurements. Native UI automation kept selecting Godot's project manager rather than the game window; the rendered playthrough therefore used engine/controller-driven input. The competitor comparison uses official descriptions and store materials, not a hands-on test of the Block Blast app.

## Finding 1: clearing can undermine survival

Under the current three-move cadence:

- Random play: median **25 moves**, mean 1,385 points; **142/150** runs ended with no legal move, 8 by overflow.
- Immediate-score-seeking play: median **16 moves**, mean 1,067 points; **144/150** ended with no legal move, 5 by overflow, 1 reached the cap.
- Across both groups, **286/300 runs (95.3%)** ended without a legal move. **253/300** specifically ended with no legal move and ten or fewer jellies remaining.

The board receives seven jellies every three moves. In the current simulations, random play removed an average 2.06 jellies directly plus 0.82 through matches per move; immediate-score-seeking play removed 2.12 directly plus 1.17 through matches. Actual additions averaged only about 2.2 per move because many runs ended before their next drop.

This supports the concern that strong clears can leave a sparse, unplayable board. The greedy bot is short-sighted, not an expert human, so its shorter sessions do not prove that skilled players will perform worse. They do show a concrete failure mode in the reward loop.

**Priority:** playtest a rule where successful clearing earns fresh material rather than producing a loss. Define a clear loss condition around genuinely unmanaged danger. A sparse-board refill needs its own pressure, pacing and upper bounds; it should not silently make the game endless.

### Experiments, kept outside the live game

**A row every two moves:** median observed runs rose to 34 moves for random play and 36 for score-seeking play. But **202/300 runs ended by overflow**. It moved the dominant failure mode rather than proving the game was fair or fun.

**Refill when no move remains:** retain the three-move cadence, but on a dead board drop the previewed row, resolve it, and try again, up to three additional rows. This reduced no-move endings to **12/300**, with 126 overflow endings and **162/300 runs reaching the 150-move cap**. Both observed medians were at 150; the cap prevents inferring their eventual session lengths. Chains also became rarer per move.

The second experiment is a better starting hypothesis for fairness, but it is not balanced enough to ship. **Neither experiment changes the live game.**

## Finding 2: the signature moment is too rare

Under the current rules, multi-wave cascade events occurred about **1.1 times per 100 random moves** and **2.7 times per 100 score-seeking moves**. A move has both a cut phase and sometimes an incoming-row phase; these are event rates, not percentages of unique moves.

**165/300 current-rule sessions had no two-wave cascade at all.** The game is positioned around chains, yet many simulated sessions never produce one.

**Priority:** create a few authored openings that teach a deliberate chain setup, then tune generation so cascades are understandable and achievable. The test should be whether people can predict and plan them, not simply whether random explosions occur more often. Avoid adding more unrelated mechanics before this works.

## Finding 3: simple snapping sacrifices some strategic control

The snap system made basic input easier, but it always favours the placement with the most matching jellies. In the choice audit:

- There were **7,307 distinct settled-board-plus-score results** from legal stamp placements.
- **6,586 (90.1%)** were reachable through the current jelly-tap snapping rule.
- **412 of 3,078 cutter/board positions (13.4%)** had at least one hidden result.

This comparison removes equivalent placements, rather than merely counting different anchors. It does not measure the value of each hidden choice, nor full future-game outcomes.

**Priority:** keep the easy one-tap default. Test whether players actually want the missing choices before adding an advanced placement gesture. A clearly explained free undo and an exact preview may improve confidence with less complexity. Test both hypotheses with people; do not reintroduce fussy dragging by default.

## Finding 4: the artwork is coherent, but feedback needs more craft

The cream/lilac layout, rounded characters, colour symbols and selected-cutter state are a sound visual foundation. Small desktop renders fit, although secondary text and faded non-target jellies need physical-phone readability and contrast checks.

The next art/audio pass should focus on gameplay states:

1. A short anticipation cue before a planned cascade.
2. A distinct landing squash and recovery, separate from the current position bounce.
3. Different sound layers for a cut, a match and an escalating chain.
4. Clear warning on tall columns and an incoming-row preview closer to the board.
5. Stronger celebration for a new best or a deliberate large chain, without covering the next decision.
6. Reduced-motion and higher-contrast options.

These are recommendations, not features implemented by this audit. Authored audio, better timing and readable state changes are more valuable now than buying a large asset pack or adding skins.

## Finding 5: production readiness remains incomplete

**Fixed during this review:** a held pointer/touch gesture survived application focus loss. A later release could commit a punch. Focus loss now cancels the gesture and opens the pause menu. If a turn is animating, it completes atomically and then pauses. Regressions cover both paths.

The test harness was also strengthened so an interrupted integration coroutine or a Godot script error cannot be mistaken for a clean test run. One overly strict save-test assertion was corrected to allow a previously saved best higher than the current round.

Still needed before calling this a polished mobile game:

- Save and restore the current settled round: board, tray, incoming row, score, turn count and RNG state, with versioned validation and safe failure recovery.
- Physical Android lifecycle tests: app switching, OS interruptions, force-close/relaunch, audio routing and vibration preferences.
- Real touch-target/readability checks on small and tall phones, including notches and system insets. Desktop pixel measurements are not Android density-independent touch measurements.
- Profile on a named midrange Android device, particularly particle bursts and chains. The UI currently rebuilds StyleBox resources while redrawing; investigate caching and static-layer redraws before assuming it meets a frame budget.
- Measure input-to-visible-feedback latency separately from complete cascade duration.
- Test corrupted/missing save files, rapid input, long sessions and large scores.

Suggested engineering targets, to be measured rather than assumed: visible tap feedback under 100 ms, p95 frame time at or below 16.7 ms on the chosen 60 Hz target device, no lost settled rounds and no known game-breaking bugs.

## What to learn from Block Blast

Block Blast's official materials emphasise an easy placement loop, row/column clearing, combos and strategic space management. The official site describes offline play and classic/adventure experiences; the App Store listing also describes daily puzzles. These are published product features, not independent evidence of their effectiveness. Sources: [official Google Play listing](https://play.google.com/store/apps/details?id=com.block.juggle), [official website](https://www.blockblast.com/), [official App Store listing](https://apps.apple.com/us/app/block-blast/id1617391485).

The relevant standard is: a player understands the next action immediately, can predict its consequence, sees a satisfying response, and feels that the eventual loss is understandable. Punch Pop currently asks players to learn two clearing rules—cut two of the cutter colour, then automatically match four—plus gravity and incoming rows. It needs to teach that extra complexity through play.

Punch Pop's opportunity to be better is **clearer fairness, distinctive planned cascades, readable characters, reliable round resume and an uninterrupted puzzle flow**. These are hypotheses for differentiation. There is no evidence yet that it outperforms Block Blast on enjoyment, retention, performance or revenue. Do not add advertising while the core reward loop is unresolved.

## Next build, in order

**1. Reward-loop prototype.** Build a separate, reversible refill/pressure variant. Test the current rules against it on the same starts. Keep score, danger and incoming material understandable. Exit criterion: players explain why they lost and do not report feeling punished for clearing well.

**2. Three teaching boards.** Teach one punch, a gravity setup and a deliberate two-wave chain. Then let players enter endless mode. Exit criterion: at least 80% of a first 20-person test complete without coaching and at least 90% correctly predict the jellies removed in a simple preview task. These are proposed gates, not measured results or universal industry benchmarks.

**3. Resume, undo trial and feedback pass.** Add reliable settled-round resume. Trial one clear undo interaction; refine cut/land/chain feedback. Validate on actual phones and with people who did not see development.

**4. Side-by-side player test.** Recruit 20–30 puzzle players. Counterbalance the order in which they play the official Block Blast app and Punch Pop; give equal time and no coaching. Observe first successful action, incorrect predictions, frustration, reason for loss and voluntary replay. Ask which they choose to play again and why. Do not count automated simulation or prompted retries as voluntary replay.

**5. Retention pilot only after the loop works.** Use the development plan's 70% voluntary second-round target for the first playtest and 30% D1/10% D7 targets for a larger pilot as provisional decisions, not promises. Define cohorts and denominators, report sample sizes, and handle privacy before collecting player data. Add one daily challenge only if players already want another session. Defer accounts, large content programmes and ads.

## Reproduce and inspect

- `./tools/test.sh`: complete suite, including rejection of script errors even if Godot exits successfully.
- `./tools/run.sh --headless --script res://tools/balance_audit.gd`: current cadence and two-move experiment, 600 simulated sessions.
- `./tools/run.sh --headless --script res://tools/balance_audit.gd -- --rescue-only`: 300 separate refill-experiment sessions.
- `./tools/run.sh --headless --script res://tools/choice_audit.gd`: distinct-outcome reachability audit.
- `./tools/run.sh --script res://tools/render_audit.gd`: desktop renders, frame sample and animated playthrough. This opens and closes a test window.

The balance simulations use base seed 20261022 plus episode index, with a separate action-choice RNG. Policies and variants share starting seeds but subsequent generation diverges with their actions. Random play samples distinct accessible stamp anchors uniformly across the tray. Greedy play maximises immediate cut-plus-cascade points before an incoming row; it has no future lookahead. Caps are reported, not treated as losses. These results are reproducible model behaviour, not human performance.

Raw evidence: [current/cadence experiment](balance-audit.json), [refill experiment](balance-rescue-experiment.json), [choice audit](choice-audit.json), [render audit](render-audit.json). The linked visual captures have since been refreshed for v0.2: [small screen](audit-360x640.png), [tall screen](audit-390x844.png), [tablet proportions](audit-768x1024.png), [playthrough ending](audit-after-play.png).
