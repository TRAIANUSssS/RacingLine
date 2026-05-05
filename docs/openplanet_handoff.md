# Openplanet Handoff

Location: `src/openplanet`

## Purpose

This layer is intended to be a lightweight in-game viewer for prepared RacingLine data.

It should:

- load `analysis_bundle.json`
- expose simple UI toggles
- render center line, mine line, and problem zones

It should not:

- compute centerlines
- run offline analysis inside AngelScript

Direct GBX parsing remains outside AngelScript. The Stage 5 runtime-sampling trajectory export POC was removed from the active UI after `DataFileMgr.Replay_Load` failed to load Core-downloaded leaderboard replay files. The current MVP v3 path is Openplanet download + local helper processing through the existing C# GBX.NET extractor and Python analyzer.

## Current status

- plugin lives in `src/openplanet/RacingLine`
- `info.toml` exists
- `main.as`, `Config.as`, `Models.as`, `Loader.as`, `Ui.as`, and `Renderer.as` are implemented
- bundle parsing is implemented
- UI window is implemented
- bundle selection and reload are implemented
- new bundles are loaded from `bundles/{map_uid}/` under Openplanet plugin storage
- legacy `bundles/{map_name}/` folders are still listed when present
- the default bundle filename is `top_1000_1010.analysis_bundle.json`
- current map detection is implemented from `GetApp().RootMap.MapName`
- current map UID detection is implemented from `GetApp().RootMap.MapInfo.MapUid`
- current mine replay download is implemented through the `NadeoServices` dependency
- leaderboard record download is implemented through `NadeoServices` Live/Core APIs as a Stage 4 POC
- local helper status display is implemented for file-based processing handoff
- pipeline command generation is implemented in the UI
- `Show Center`, `Show Mine`, and `Show Problem Zones` toggles are implemented
- `Show Other Runs` is implemented for bundles that include `runs[].line`
- runtime sliders for line widths, marker size, and visible problem zone count are implemented
- `Show Full Trajectory` and `Render Distance` controls are implemented
- `center_line` world rendering is implemented
- `mine_line` world rendering is implemented
- `problem_zones` world marker rendering is implemented
- `info.toml` now depends on the official Openplanet `Camera` dependency

## Expected input

The viewer should consume:

- `.analysis_bundle.json` files from Openplanet plugin storage
- default path: `PluginStorage/RacingLine/bundles/<map_uid>/top_1000_1010.analysis_bundle.json`
- legacy fallback path: `PluginStorage/RacingLine/bundles/<map_name>/top_1000_1010.analysis_bundle.json`

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
- detect the current map UID
- show a compact user UI by default
- switch to the full technical dev UI through `Dev mode`
- show the current Openplanet user name/login
- generate and copy a PowerShell command for `pipeline.py`
- choose automatic or manual analysis sample count in the generated command
- download the current player's personal-best replay for the current map into plugin storage
- download leaderboard record replay files for the selected rank range into plugin storage
- show local helper task status written under `PluginStorage/RacingLine/tasks/`
- look for bundles in the detected map UID folder, with a legacy map-name folder fallback
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
- draw all non-mine `runs[].line` trajectories when `Show Other Runs` is enabled
- draw problem zone markers when `Show Problem Zones` is enabled
- adjust center line width, mine line width, problem marker size, and visible problem zone count from the UI
- limit rendered overlay layers by distance from the current car unless `Show Full Trajectory` is enabled

Current UI block order:

Compact user UI:

1. `Current map`
2. bundle selector
3. reload and bundle refresh controls
4. rank range controls
5. generate / force-generate controls
6. sample mode controls
7. render toggles
8. optional advanced render settings
9. `Dev mode`

Dev UI:

1. `Status`
2. `Data`
3. `Pipeline`
4. `Toggles`
5. `Info`

The `Pipeline` block includes:

- editable project root
- editable leaderboard rank range start/end
- auto/manual sample count controls
- editable replay input directory
- a mine replay download button
- a `Use mine replay` toggle that appends `--include-mine-replay --mine-replay-path ...` to the generated command
- generated terminal command
- copy button for the generated command
- automatic replay input directory targeting `data/raw/ghosts/<map_uid>/top_<range>/`
- an `Auto replay dir` toggle for manually overriding the input directory in dev mode
- leaderboard record download controls and status
- local helper status and log path

The `Data` block lists installed bundles for the current map as compact rank ranges such as `100-110` and `1000-1020`, sorted by numeric range start/end. The underlying files remain named `top_<range>.analysis_bundle.json`. The list refreshes automatically while the UI is open and can still be refreshed manually.

If the currently selected/default bundle file does not exist for the current map, the UI shows `not found` as the bundle label.

Mine replay storage:

```text
OpenplanetNext/PluginStorage/RacingLine/tmp/<map_uid>/mine.Replay.Gbx
```

Leaderboard record download storage:

```text
OpenplanetNext/PluginStorage/RacingLine/downloads/<map_uid>/top_<range>/
```

The plugin downloads Core record replay URLs as `.Replay.Gbx` files and writes a `manifest.json` with source metadata, local paths, download/cache status, and errors. The same action also downloads or reuses the current player's mine replay in `tmp/<map_uid>/mine.Replay.Gbx`. After a successful download, the generated pipeline command points `--replay-input-dir` at this PluginStorage download folder and includes the mine replay flags.

The plugin resolves the current map UID, translates it to a Nadeo map ID, fetches the current account's personal-best record, and downloads the record replay URL via `NadeoServices`.

Local helper task storage:

```text
OpenplanetNext/PluginStorage/RacingLine/tasks/running/
OpenplanetNext/PluginStorage/RacingLine/tasks/done/
OpenplanetNext/PluginStorage/RacingLine/logs/
```

`scripts/racingline_helper.py` watches the `downloads/` folder, runs `pipeline.py`, and writes deterministic task files such as:

```text
tasks/running/task_<map_uid>_top_<from>_<to>.json
tasks/done/task_<map_uid>_top_<from>_<to>.json
logs/task_<map_uid>_top_<from>_<to>.log
```

The Openplanet UI reads the task file for the current map/range and displays status/progress/error text. Processing remains outside Openplanet.

Pipeline range rules:

- `Rank from` and `Rank to` cannot be lower than `1`
- `Rank to` is clamped to `Rank from + 20`
- `Rank from` and `Rank to` cannot be higher than `10000`, matching the current Trackmania.io downloader limit

## Storage path

The loader resolves relative bundle paths inside Openplanet plugin storage.

Default expected location for the current constant range:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\<map_uid>\top_1000_1010.analysis_bundle.json
```

Example:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\2pYyYky9ccXdTBaaLncWOjFc6jf\top_1000_1010.analysis_bundle.json
```

The old flat storage path `PluginStorage/RacingLine/analysis_bundle.json` is no longer the default viewer target.

## Suggested next rendering work

1. Add live progress lookahead rendering as a later extension if distance filtering is not enough
2. Add optional per-player run selection if all-runs rendering is too noisy
3. Improve styling for problem zone markers if needed
4. Add richer zone labels or details only after the marker layer is stable
5. Avoid redesigning the bundle schema unless the analyzer needs new viewer fields

Render distance filtering is the current solution for reducing far-away visual clutter. A future time-window mode, such as rendering only the next 5 seconds of the route, would require reliable live-run progress matching and should be treated as a later extension.

Other player trajectory rendering currently uses a simple `Show Other Runs` checkbox that draws all non-mine runs quietly. A per-player checkbox list can be added later if the bundle metadata and UI complexity justify it.

## Pipeline automation

Current Openplanet integration is intentionally lightweight:

- the plugin detects the current map
- the plugin detects the current user login/name
- the generated command uses the display nickname for `--mine`, not the account login/id
- the plugin generates a terminal command for `pipeline.py`
- the plugin can copy that command to the clipboard
- the plugin can download leaderboard record replay files into `PluginStorage/RacingLine/downloads/<map_uid>/top_<range>/`
- the same leaderboard download action also downloads or reuses the current player's mine replay

The plugin does not execute external processes. Extraction, analysis, bundle building, and bundle installation still happen through the external `pipeline.py` command copied from the UI.

## Current constraint

The data contract is ready, the loader/UI plugin is working, and world projection is solved through the official `Camera` dependency. The next Openplanet steps should refine rendering from the existing bundle, not redesign the schema or return to manual camera math.
