# Punch Pop — game direction

26 October 2026 · v0.8.0 development direction

## The game we are making

A short, tense arcade puzzle about spending three shape punches to arrange satisfying colour chains. The central skill is choosing a punch that clears space now while improving the next move. Speed helps, but clearing isolated blocks as fast as possible should not be a reliable long-term strategy.

Keep the approved portrait interface, direct dragging/tapping, four colours, finite hands and side-connected matches. The board and the next row should explain the problem. Every new rule must fit that readable loop.

## What prompted this update

The owner reports that v0.7.1 is still too easy. Its pressure curve reaches a fixed ceiling. Guaranteed playable hands and generous supply setups let efficient shallow cutting repeatedly clear more blocks than arrive. Animation time also pauses the clock, so faster cutting receives extra opportunities to inspect the board. Raising timer speed alone increasingly tests touch speed.

The next experiment makes every punch spend the same visible countdown that already controls incoming rows. Efficient matches remove more blocks for the cost; multi-wave chains return some time. Punch costs grow over the run, so settling into a safe repetitive strategy stops being enough. Rows still enter through one clock, with a visible preview and atomic ceiling loss.

## Design commitments

- **Make the tradeoff visible.** Show the punch's net clock change and any owed rows while aiming, and show the current punch cost beside Undo. Forecasts must update even when the finger stays still.
- **Give time to plan.** Keep a readable opening and stop shortening row intervals at four seconds. Punches spend that interval too; later difficulty comes from increasingly costly decisions as well as incoming speed.
- **Reward board understanding.** Perfect punches earn their existing score bonus. Matching and multi-wave chains clear more space; chains also return time. Avoid adding a second scoring currency or a hidden row counter.
- **Keep consequences honest.** No free time from undo, no free cost at the countdown boundary, no idle score farming, and no clock movement while paused or in training.
- **Preserve trust.** Keep best scores, settings, compatible boards and random state. Explain that existing high scores span different balance versions; do not erase them silently.

## Release sequence

1. **v0.8.0 — make decisions matter.** Implement escalating punch cost, live clock forecasts and safe save/undo behavior. Compare the same seeded bot policies against v0.7.1. Pass core, controller and real-clock checks.
2. **Owner playtest — find the actual failure mode.** Play several complete runs. Record when pressure first feels real, whether losses follow weak board decisions or rushed input, and whether chains provide a satisfying recovery. Keep the interface stable while tuning one factor at a time.
3. **Observed newcomer test.** Watch 5–10 people start without coaching. Look for understanding of shape cost, spent cards, colour matches and the next row; record voluntary replay. Small samples guide iteration, not retention claims.
4. **iPhone 15 Pro build.** Resume packaging when the owner is ready. Validate touch precision, safe areas, one-handed reach, haptics, focus changes, interruption recovery and frame behavior on the actual device.
5. **Wider validation.** Only after the loop is understandable and worth replaying, assess repeat play over subsequent days and decide whether to pursue a broader release.

## What would make us change direction

If players find punch costs arbitrary, first improve explanation and adjust cost rather than add compensating bonuses. If players understand the cost but only rush, lower its peak or slow progression. If experts still sustain repetitive shallow cutting, inspect supply generosity and action efficiency before reducing the decision interval. If chains are powerful but hard to read, improve their feedback within the existing layout.

Do not add bombs, more modes, daily tasks, unlock currencies, accounts or advertising to solve a weak core loop. A new mechanic earns its place by addressing an observed problem in the current game.

## Evidence boundary

Automated policies are regression and strategy probes. Their complete move forecasts exceed normal human knowledge. A harder bot distribution supports the claim that the rules changed strategically; only observed play can establish that the result is more enjoyable. Headless checks do not establish phone performance or touch quality.
