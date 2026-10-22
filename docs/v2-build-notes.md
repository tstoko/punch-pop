# Punch Pop 0.2 · implemented rebuild

22 October 2026. This build addresses the previous quality audit in the playable game.

## The reward loop

Sparse boards now earn fresh batches instead of a no-move defeat. Supply aims for 21 jellies but stops early when a column reaches seven cells, so a reward cannot force an avoidable overflow onto an uneven board. Recovery generates a real playable row rather than inventing a move or silently changing existing colours. Normal incoming rows and their cascades still follow the previewed colours.

Endless runs end when a required row cannot fit. Incoming pressure rises in waves: initially one row every two moves, then two rows per three moves, then one per move, then increasingly frequent double drops. Waves advance every 18 moves and cap at wave 8. Amber/red column markers and the next-drop count make the pressure visible.

This changes the original game's design deliberately. It is not the old three-move cadence with a cosmetic patch.

## Chains you can understand

Three short authored puzzles teach a colour-only cut, a gravity-created match, and a deliberate two-wave chain. Endless starts with the same kind of available chain inside a varied board. The cutter cards identify multi-wave opportunities; a hovered/held placement forecasts hits, waves and points before incoming rows/refills.

Basic jelly tapping remains the default. Optional **Aim** exposes every legal top-left stamp origin, restoring choices automatic snapping cannot reach. Distinct usable cutters and new colours are preferred when replacing offers.

## Undo and resume

Undo restores the exact previous board, tray, incoming row, score, turn and random state. Replaying the move produces the same random future. It also works after overflow. One previous move survives a normal saved-round resume; high scores are preserved rather than rolled back.

Settled rounds save atomically to local configuration. A close during animation resumes the previous completed turn. Checkpoints are versioned and validated, including stable cells, cutter types, legal selections and bounded 64-bit RNG strings. Invalid checkpoints fall back safely without discarding valid old best scores and preferences. The upgraded tutorial is offered once to players migrating from version 0.1.

## Artwork, feedback and performance work

The existing candy artwork is retained and refined around clearer gameplay states: column-aligned incoming jellies, direct-hit checkmarks, exact chain forecasts, chain badges, landing squash, anticipation before matches, chain/fresh-batch/new-wave celebrations, and distinct synthesised cut/match/chain/landing/supply sounds. Four audio voices allow layers to overlap. Generated sounds are cached.

Reduced motion removes shake, landing distortion and moving particles, and shortens transitions. Stronger colours retain the colour-independent corner symbols. A bounded LRU style cache replaces repeatedly constructing all StyleBox drawing resources every frame. These are practical production improvements, not a claim of certified mobile performance.

## Verification

**4,659 automated checks passed cleanly**, including all three lessons, deliberate-chain forecasts, deterministic replay, corrupted-save rejection, legacy migration, mid-animation interruption, multi-touch cancellation, focus loss, round resume and undo from game over.

**300 seeded simulated sessions** used the actual new round model, 100 each for random, immediate-score-seeking and height-aware policies, capped at 150 moves. No session got stuck without a legal move; no session reached the cap.

- **Random:** median 23 moves; mean 25.15 moves and 2,074.5 points; 80/100 runs had a multi-wave chain; 6.7 moves per 100 had a multi-wave chain.
- **Greedy:** median 23 moves; mean 23.84 moves and 3,089.4 points; 99/100 runs had a multi-wave chain; 13.3 moves per 100 had a multi-wave chain.
- **Height aware:** median 48 moves; mean 47.75 moves and 7,067.3 points; 100/100 runs had a multi-wave chain; 16.9 moves per 100 had a multi-wave chain.

The height-aware policy uses only the board and the cut's settled result, with a penalty for tall/uneven columns; it does not inspect future RNG draws. Its median run was over twice random play's, providing a concrete model-level sign that managing the board matters. Score chasing earned more points than random play but did not consistently improve survival. These are bot results, not human retention or proof of commercial superiority.

The original random baseline had a median 25 moves, 142/150 no-move endings and 95/150 runs with no two-wave cascade. The new rules also change the opening and tray generation, so this is a whole-build comparison, not an isolated causal test of refilling alone. Original chain statistics counted cascade events; the new runner counts moves containing a chain, so those rates should not be treated as identical measures.

Render checks cover 360 × 640, 390 × 844 and 768 × 1024 desktop windows. Board and tray fit all three. The renderer capture includes a real animated twelve-move sequence; measured frame timings and cache size are in `render-audit.json`. Those desktop samples are not Android benchmarks.

## What remains

No physical Android/iPhone testing, APK validation, controlled audio-listening study, or human replay/retention test has been completed. The next gate is 20–30 first-time players on real phones, checking comprehension, intended-versus-actual cuts, planned chains, fair losses and voluntary replay. No accounts, ads or analytics have been added.

## Reproduce

- `./tools/test.sh` runs the suite and rejects engine script errors even if Godot exits zero.
- `./tools/run.sh --headless --script res://tools/next_balance.gd` repeats the current 300-session comparison and writes `v2-balance.json`.
- `./tools/run.sh --script res://tools/capture.gd` captures the new states using an isolated save file.
- `./tools/run.sh --script res://tools/render_audit.gd` checks desktop layouts, frame timing and animated play.

The original review and old-rule simulation files remain as a labelled historical baseline. They do not describe the current live game.
