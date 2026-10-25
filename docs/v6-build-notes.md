# Punch Pop 0.6 — brighter starts, easier cuts

23 October 2026.

The owner authorized a team-led improvement with a simpler, colourful interface and a starting menu. This build keeps timed arcade play, makes its opening more forgiving and improves finger placement. iPhone 15 Pro is the owner's intended personal test device; device packaging and signing are deferred.

## Changes

- A dedicated starting menu offers Let's Play, Learn to Play and Settings. Saved runs show Continue and New Run. Pause offers a route back to the main menu while checkpointing the round.
- Mint accents and a brighter indigo stage frame the existing orange, blue, green and violet blocks. A simpler rule strip, cutter cards and concise forecasts reduce competing instructions. Accessibility preferences and pattern marks remain available.
- Dragging from a cutter card raises the stamp preview 100 logical pixels above the finger. A small stability margin prevents placement jitter. Releasing outside the board or back in the cutter tray cancels without spending the cutter. A drag requires at least 12 logical pixels of movement, so tapping a card only selects it. Tapping blocks and optional exact Aim remain available.
- The opening clock is 12 seconds. Subsequent pressure levels use 10.5, 9, 7.5, 6.5, 5.5, 4.5 and 3.5 seconds. Level progression still follows 12 cuts or 20 active seconds; cuts do not reset thinking time. Menus, animation, training and app focus loss pause it.
- A fully matching footprint earns a perfect-cut bonus of 5 points per block: +15 for a full three-block line and +20 for a full four-block stamp. Forecasts include it before committing; actual events, receipts, celebration and undo use the same calculation.
- Project and Android export version metadata now both identify 0.6.0. Android version code is 6. Existing best scores, preferences and compatible rounds remain supported.

## Verification

`./tools/test.sh` completed **9,241 checks, zero failures** and exited successfully with no engine errors. New coverage checks perfect-cut forecasts, events and receipts; opening pressure; starting menu navigation; frozen menu time; settings return; training launch; above-finger drag placement; stable small motions; distant-placement rejection; horizontal/below-board release cancellation; short card taps and tray-return cancellation; Escape from settings after a completed run; focus cancellation; and a valid drag commit.

`./tools/test.sh --real-clock` completed **13 checks, zero failures** with actual frame time. The unattended opening reached timer loss after 54 active seconds and five timed expiries, with zero moves and zero score. Pause, disk reload, home-menu Continue, serialized countdown and removal of the completed resumable round were verified. The recorded run took 57.065 wall seconds; see `v6-runtime-smoke.json`.

On sandboxed macOS, tests run in a disposable shadow project with the system public CA bundle at `/etc/ssl/cert.pem`. This avoids the engine's blocked Keychain certificate lookup while keeping certificate verification and strict engine-error checks enabled. No machine-local certificate path is shipped in the game project.

Graphical QA was not performed in this pass: the required Godot assignment to Desktop 2 could not be verified. The installed headless display driver has a dummy renderer. The capture and renderer-audit tools now use v6 output paths and current menu fixtures; both passed syntax checks but were not executed graphically. Existing v5 screenshots and frame metrics are historical and do not validate the v6 layout. Physical iPhone touch, safe areas, performance and lifecycle still need a device build when packaging resumes.

The pressure-audit script now writes `v6-pressure-audit.json`, preserving the historical v5 report; no new v6 policy simulation result is claimed. Streaks and bombs remain future experiments.
