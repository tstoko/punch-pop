# Punch Pop — next steps

**Historical review, superseded 26 October 2026.** The local v0.7.1 state was subsequently committed, and v0.8.0 now implements punch costs, live clock forecasts and compatible save accounting. Use [game direction](game-direction.md) and [v0.8 build notes](v8-build-notes.md) for current priorities and evidence. The GitHub synchronization and device milestones below still need completion.

Reviewed 24 October 2026 against GitHub `main` at `76f61f1e87b2336359ebe0a2503783242863cf16` and the local v0.7.1 working tree.

## Recommendation

Make the current game reproducible, then validate its difficulty with people. Preserve the approved interface and controls. The immediate milestone is a verified v0.7.1 playtest baseline, rather than another feature expansion.

## What exists

- GitHub has two commits and currently contains v0.5.0. Its only branch is `main`; no open issues, open pull requests, or workflow runs were returned. There is no `.github` directory on `main`.
- The local checkout contains v0.7.1: unrestricted shape punches, finite hands, drag placement, perfect-punch rewards, revised training, and stronger timed pressure. There are 21 modified tracked files and 13 untracked files at review time. These changes are not recoverable from GitHub yet.
- Fresh headless runs passed 9,912 core checks, 271 flow checks and 13 real-clock checks with zero failures and clean engine output. The idle round ended after 51 active seconds and five timed rises (53.239 wall seconds). The smoke script stamps its historical date internally; this rerun took place on 24 October.
- The existing 23 October pressure audit covers 240 seeded sessions with no stuck runs. At three seconds per decision, random play has a 46-move median and greedy play a 60-move median. All 40 height-aware sessions still reach the 150-move cutoff. That establishes neither endless expert survival nor a need to make the game harder again.
- The current notes identify iPhone 15 Pro as the intended personal test device. Packaging/signing are deferred. There is an Android preset but no iOS preset or recorded physical-phone validation.

Sources: [current handoff](AGENT_HANDOFF.md), [v0.7.1 notes](v7-1-build-notes.md), [stored audit](v7-1-pressure-audit.json), and [GitHub commit](https://github.com/tstoko/punch-pop/commit/76f61f1e87b2336359ebe0a2503783242863cf16).

## 1. Preserve and verify the current baseline

Review the complete local diff, including untracked tests and reports. Put the coherent v0.7.1 state on a `codex/` branch with current README, handoff and evidence; publish it through a reviewed commit/PR when authorized. Keep caches, player saves and signing files excluded. Update GitHub's repository description, which still describes colour-selective cutters.

Add a small headless CI workflow pinned to the verified Godot 4.5.1 runtime. Start with import, the core suite, and the flow suite. Run real-clock checks separately if their duration is inconvenient on every change; keep the larger balance audit manual or scheduled. Exercise a fresh checkout without `.godot` caches.

**Complete when:** a clean checkout from GitHub reproduces the same version and passes both suites, with all necessary source, tests and evidence committed.

## 2. Check the live forecast before further tuning

Code inspection found a specific risk: `GameManager.preview()` caches a forecast by origin, and `select_cutter()` clears that cache. The forecast includes `time_bonus`, which depends on the changing `rise_remaining` clock. Holding the same placement while time passes can therefore retain an earlier, smaller time reward. The UI displays that cached value.

Reproduce this with a known multi-wave placement: preview soon after a rise, advance active time without changing the selected card or origin, then compare the displayed forecast with a fresh model forecast and the actual award. Keep the expensive board calculation cached if needed, but refresh clock-dependent credit. Add one regression covering this sequence.

**Complete when:** the displayed credit stays accurate while holding a placement, and matches the awarded time on release. This is a source-level finding; no graphical reproduction was performed during this review.

## 3. Run a small observed balance test

Begin with the owner and 5–10 new players before recruiting the original plan's larger group. Let new players choose Play or Learn to Play without coaching. Record build version, first successful punch, placement mistakes, whether they understand colour matches and spent cards, round duration, decision time, cause of loss, and whether they voluntarily start another round. Manual notes are sufficient for this pass.

Preserve v0.7.1 as the comparison baseline. Change one balance factor at a time only after observing a repeatable problem. The current strongest bot uses complete forecasts of every legal move; its results are useful for strategy analysis, not a substitute for human decision times.

**Complete when:** there is a short written decision to keep the curve, soften a specific phase, or strengthen a specific phase, supported by observed sessions. Treat this sample as directional rather than retention evidence. Expand to 20–30 players if the first pass is promising; the existing 80% tutorial-completion and 70% replay targets remain provisional.

## 4. Prepare the iPhone test milestone

Do this when gameplay is stable enough to justify resuming the deferred packaging work. Establish the local Xcode/export-template/signing setup, create an iOS export configuration, and produce a development build for the iPhone 15 Pro.

Check safe areas and home-indicator clearance, one-handed reach, all board edges, drag cancellation, sound, haptics, lock/unlock, switching apps, relaunch/Continue, and interrupted cut/rise recovery. Current layout code centres a fixed logical canvas and does not explicitly use device safe-area APIs; physical layout validation is necessary. Measure frame behaviour on the phone before deciding whether generation/forecast code needs optimisation.

**Complete when:** the named device runs a traceable build, input is reliable, no important UI is obscured, saves survive lifecycle checks, and any measured performance problems are recorded.

## 5. Decide whether to expand

After input and balance pass the first human/device tests, widen testing and measure repeat play over subsequent days. Use the existing development plan's retention goals as hypotheses. Revisit the old eight-week schedule so completed work and outstanding experiments are explicit.

Keep bombs, streak systems, extra modes, accounts, ads and purchases deferred. Fuller-cut rewards, drag input and stronger progression from the old v0.5 critique have already received implementations; that critique should not be treated as an untouched backlog. A new mechanic should address an observed problem in the current version.

## Suggested next implementation task

“Reproduce and fix stale chain-time forecasts without changing the approved UI or balance; add the targeted regression; verify the complete v0.7.1 working tree from a fresh import; prepare the baseline commit and headless CI.”

This review changed documentation only. It did not commit, push, create issues, add CI, change gameplay, or start device packaging.
