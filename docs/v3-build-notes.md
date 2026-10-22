# Punch Pop 0.3 · clear rules, stronger arcade identity

22 October 2026. This update addresses the player's difficulty understanding blocks disappearing automatically, and replaces the pastel character styling with a broader arcade presentation.

## Why a block clears

A cut removes at least two blocks of the selected cutter's colour. Blocks fall into gaps, then groups of four or more of one colour touching sides clear. This can repeat as a chain. Incoming rows and sparse-board restocks can also form matches. Full rows and diagonals have no special matching rule.

The event model now supplies the exact groups and the cause of every clear. The presentation highlights those actual members before removing them: outlines, side-to-side connectors, a group count, colour name and a short reason. A persistent four-stage strip identifies cut, fall, match and incoming supply. New rows and low-board restocks receive separate explanations. A turn receipt separates blocks cut, blocks automatically cleared and points earned. The latest clear explanation remains visible briefly after resolution.

Clear explanations are enabled by default: first automatic groups anticipate for 0.70 seconds, later chain groups for 0.50 seconds. Pause → Clear explanations switches to Quick (0.12 seconds). Animations still follow the authoritative turn result, with input locked until the whole move is settled. Undo, score, pressure, forecasts, RNG and saved-round schema are unchanged.

The help panel gives a visual contrast between the player's colour-only cut and the automatic four-block rule. Training describes the actual cut, gravity match and second chain. It does not imply Block Blast's line-clearing rules.

## Artwork and UI

Original faceless bevelled blocks use orange, blue, green and violet, with geometric colour identifiers. A dark navy grid, restrained blue accent, condensed display typography, clearer score hierarchy and compact cutter cards replace the pastel candy appearance. Help, pause, resume, lesson and game-over panels share the same visual system. The application icon follows the new artwork. Barlow Condensed is bundled under its SIL Open Font License.

Old particles are cleared on resets and hidden behind menus. Larger explanatory type improves readability. Incoming blocks stay aligned with their destination columns, with tall-column warnings. Reduced motion, high contrast, sound and optional haptics remain available.

## Verification

**4,704 automated checks passed with zero failures.** The automated suite validates the actual visible group membership, colour and size before removal; exact score receipts; source labels for incoming-row matches; the absence of a special full-row rule; saved Quick preferences and pause controls; reset effects; and all existing gameplay, undo and save checks.

Graphical captures show direct previews, first and second automatic matches, an incoming-row-created match, training success, help, settings, high contrast and resume. Desktop Compatibility rendering is exercised at 360 × 640, 390 × 844 and 768 × 1024; board and cutter tray fit all three. `render-audit.json` records a twelve-move animated run and desktop frame samples.

These checks establish functional and visual correctness of this build on this Mac. Physical-phone touch/readability/performance and first-time-player comprehension still need observation. No claim of commercial superiority or human retention is made.
