# Openplanet Handoff

Location: `src/openplanet`

## Purpose

This layer is intended to be a lightweight in-game viewer for prepared RacingLine data.

It should:

- load `analysis_bundle.json`
- expose simple UI toggles
- render center line, mine line, and problem zones

It should not:

- parse `.Replay.Gbx`
- compute centerlines
- run offline analysis inside AngelScript

## Current status

- plugin lives in `src/openplanet/RacingLine`
- `info.toml` exists
- `main.as`, `Config.as`, `Models.as`, `Loader.as`, `Ui.as`, and `Renderer.as` are implemented
- bundle parsing is implemented
- UI window is implemented
- bundle selection and reload are implemented
- bundles are loaded from `bundles/{map}/` under Openplanet plugin storage
- the default bundle filename is `top_1000_1010.analysis_bundle.json`
- current map detection is implemented from `GetApp().RootMap.MapName`
- current mine replay download is implemented through the `NadeoServices` dependency
- pipeline command generation is implemented in the UI
- `Show Center`, `Show Mine`, and `Show Problem Zones` toggles are implemented
- runtime sliders for line widths, marker size, and visible problem zone count are implemented
- `center_line` world rendering is implemented
- `mine_line` world rendering is implemented
- `problem_zones` world marker rendering is implemented
- `info.toml` now depends on the official Openplanet `Camera` dependency

## Expected input

The viewer should consume:

- `.analysis_bundle.json` files from Openplanet plugin storage
- default path: `PluginStorage/RacingLine/bundles/<map>/top_1000_1010.analysis_bundle.json`

The most important bundle fields for the MVP are:

- `center_line`
- `mine_run_name`
- `mine_line`
- `analysis_points`
- `problem_zones`

The bundle now already contains:

- real `x/y/z` world coordinates for center and mine lines
- aligned progress samples
- problem zone coordinates copied from centerline points

## Current plugin behavior

The current viewer can:

- auto-load on startup
- reload on demand from the UI
- detect the current map name
- show the current Openplanet user name/login
- generate and copy a PowerShell command for `pipeline.py`
- download the current player's personal-best replay for the current map into plugin storage
- look for bundles in the detected map folder
- select available `.analysis_bundle.json` files from a combo box
- show whether loading succeeded
- show the last error message
- show:
  - map name
  - mine run name
  - center point count
  - mine point count
  - problem zone count
  - projected/skipped center segment counts
  - projected/skipped mine segment counts
  - projected/skipped problem zone counts
- project world positions through the official `Camera` dependency
- draw the `center_line` as a connected overlay line when `Show Center` is enabled
- recolor the center line by speed delta when `Color Center By Speed Delta` is enabled
- draw the `mine_line` as a connected overlay line when `Show Mine` is enabled
- draw problem zone markers when `Show Problem Zones` is enabled
- adjust center line width, mine line width, problem marker size, and visible problem zone count from the UI

Current UI block order:

1. `Status`
2. `Data`
3. `Pipeline`
4. `Toggles`
5. `Info`

The `Pipeline` block includes:

- editable project root
- editable leaderboard rank range start/end
- editable replay input directory
- a mine replay download button
- a `Use mine replay` toggle that appends `--include-mine-replay --mine-replay-path ...` to the generated command
- generated terminal command
- copy button for the generated command

The `Data` block lists installed bundles for the current map as compact rank ranges such as `100-110` and `1000-1020`, sorted by numeric range start/end. The underlying files remain named `top_<range>.analysis_bundle.json`. The list refreshes automatically while the UI is open and can still be refreshed manually.

Mine replay storage:

```text
OpenplanetNext/PluginStorage/RacingLine/tmp/<map>/mine.Replay.Gbx
```

The plugin resolves the current map UID, translates it to a Nadeo map ID, fetches the current account's personal-best record, and downloads the record replay URL via `NadeoServices`.

Pipeline range rules:

- `Rank from` and `Rank to` cannot be lower than `1`
- `Rank to` is clamped to `Rank from + 20`
- no upper leaderboard limit is enforced yet; this should later be read from leaderboard metadata

## Storage path

The loader resolves relative bundle paths inside Openplanet plugin storage.

Default expected location for the current constant range:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\<map>\top_1000_1010.analysis_bundle.json
```

Example:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\Spring 2026 - 03\top_1000_1010.analysis_bundle.json
```

The old flat storage path `PluginStorage/RacingLine/analysis_bundle.json` is no longer the default viewer target.

## Suggested next rendering work

1. Add viewer render distance filtering based on distance from the current car position
2. Add optional rendering for other analyzed player trajectories
3. Expose analysis sample count in the pipeline UI / generated command
4. Add a developer/debug mode toggle and move technical UI details behind it
5. Improve styling for problem zone markers if needed
6. Add richer zone labels or details only after the marker layer is stable
7. Avoid redesigning the bundle schema unless the analyzer needs new viewer fields

Render distance filtering is the preferred first solution for reducing far-away visual clutter. A future time-window mode, such as rendering only the next 5 seconds of the route, would require reliable live-run progress matching and should be treated as a later extension.

Other player trajectory rendering should start with a simple `Show Other Runs` checkbox that draws all non-mine runs quietly. A per-player checkbox list can be added later if the bundle metadata and UI complexity justify it.

## Pipeline automation

Current Openplanet integration is intentionally lightweight:

- the plugin detects the current map
- the plugin detects the current user login/name
- the generated command uses the display nickname for `--mine`, not the account login/id
- the plugin generates a terminal command for `pipeline.py`
- the plugin can copy that command to the clipboard

The plugin does not execute external processes. It can download only the current player's mine replay into plugin storage; leaderboard ghost downloading still happens in the external Python pipeline.

## Current constraint

The data contract is ready, the loader/UI plugin is working, and world projection is solved through the official `Camera` dependency. The next Openplanet steps should refine rendering from the existing bundle, not redesign the schema or return to manual camera math.
