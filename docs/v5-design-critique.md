# Playtest feedback and next design questions

23 October 2026. Recorded at the owner's request after playing v0.5.

**Status: proposals, not implemented.** The owner asked to publish the current build unchanged alongside this critique. This document is not authorization to silently add these mechanics in a future task.

## What the player said

The current build is good, but needs more compelling combos and reasons to keep playing. Selecting a cutter and placing it can feel awkward even with a mouse, raising concerns about phone usability. Preserve this feedback with the source so the next iteration addresses actual play friction.

## 1. Reward the quality of a cut

A valid cut currently needs at least two matching blocks. The player proposes a bigger reward for hitting three blocks or filling the entire three- or four-cell cutter footprint.

Current behavior: every directly removed block earns 10 points, so larger cuts already earn proportionally more; they do not receive an explicit completion bonus. Falling matches already have wave multipliers, but that may not communicate the immediate combo feeling the player wants.

Proposed experiment: keep two hits as the minimum, distinguish a three-hit cut from a complete footprint, and show an unmistakable “Perfect cut” reward. Evaluate a bonus for completion rather than only increasing points per block. A three-cell full cutter and a four-cell full cutter should both feel worthwhile; do not accidentally make one shape always optimal. Explain bonuses in the move preview and keep scoring deterministic for undo and resume.

## 2. Build a streak before the next row

The player proposes increasing rewards for consecutive cuts before new blocks arrive.

Proposed experiment: a visible streak grows on qualifying cuts and resets when a timed row rises. Decide explicitly whether emergency recovery rows also reset it. Distinguish this streak from the existing falling-match wave multiplier. Bound the multiplier and show the reset rule clearly.

Critique: this could give each countdown a satisfying short-term objective, but may encourage rushed tapping over deliberate chain planning. Do not reward rapid low-value cuts so strongly that the puzzle becomes a tapping race. Undo, interrupted animations and saved rounds must restore streak state consistently; undo must never refund the clock.

## 3. Make difficulty grow predictably

Current behavior: pressure already increases every 12 cuts or 20 active seconds, whichever is ahead. The interval starts at eight seconds and bottoms out at 3.5 seconds. The player wants a stronger sense of progression and suggested a mathematical speed curve.

Critique: a complicated equation is not inherently better. Test a readable, bounded curve with a forgiving opening, a noticeable middle phase and a practical minimum interval. Tune decision time and board pressure together. Preserve the current interval when levels change so an expected deadline does not suddenly jump. Bot survival distinguishes policies, but cannot tell us whether people find the pace fair or enjoyable.

## 4. Explore a temporary bomb

The player suggested a bomb that lasts a couple of turns and does something extra when hit, possibly “adds three.” The intended reward is not yet defined: it might refer to score, a multiplier, extra time or a blast effect.

Treat this as an exploratory idea. Before implementing, define its appearance, trigger, lifetime, reward, expiry behavior and interaction with gravity, matches and rows. Prototype one clear rule. A two-turn bomb must display its remaining turns and must not introduce confusing automatic clears. Avoid layering bombs on top of unclear selection and scoring.

## 5. Fix placement friction before adding complexity

This is direct playtest feedback, not a hypothetical issue: selecting boxes sometimes feels fiddly with a mouse. Phone interaction is unvalidated.

Current behavior: select a cutter, then tap an outlined matching block to snap to a legal placement; hold or hover previews the result. Optional Aim exposes exact origins. Automatic snapping may choose a valid placement that differs from what the player intended.

Recommended next investigation:

- Observe which taps miss or select an unexpected footprint. Distinguish card selection errors from board-placement ambiguity.
- Prototype drag-from-card placement with a preview offset above the finger, alongside the current tap flow.
- Keep the selected cutter obvious and show the complete footprint and exactly which blocks will disappear before release.
- Evaluate forgiving hit targets and stable snapping without allowing a distant or unintended cut.
- Test one-handed on physical phones, including small screens, screen edges, cancellation and sliding between valid placements. Desktop layout screenshots do not validate touch usability.

## Suggested order for the next iteration

1. Investigate and improve input reliability on mouse and phone.
2. Prototype fuller-cut bonuses and a readable timed streak; compare whether players understand both.
3. Tune progressive difficulty around observed human decision times.
4. Explore a bomb only once the base interaction and rewards are clear.

The desired outcome is satisfying mastery and voluntary replay. Claims about addictiveness, retention or advertising revenue still require player evidence. No ads, analytics or monetization changes are included in this publication.
