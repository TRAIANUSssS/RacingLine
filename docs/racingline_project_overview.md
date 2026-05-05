# RacingLine Project Overview

## What this project is

**RacingLine** is a Trackmania trajectory analysis toolchain.

Its job is to:

1. collect replay / ghost data
2. extract world-space trajectory points
3. analyze many runs together
4. compute a representative center line and quality metrics
5. export a stable bundle for an Openplanet viewer

The project is not just about plotting lines. The real goal is driving analysis and coaching support.

## Main user goal

The main questions RacingLine is built to answer are:

- where does my line differ from strong players?
- where is that deviation actually important?
- where am I losing speed?
- which turns or segments are the real problem zones?
- what is the stable good trajectory across a group of fast runs?

## Current architecture

The repository is now organized into four layers.

### 1. Extraction

Location: `src/extractor-csharp`

Input:

- Trackmania `.Replay.Gbx` files from `data/raw/replays`
- Trackmania `.Ghost.Gbx` files from `data/raw/ghosts`
- or a selected input subfolder such as `data/raw/replays/2` or `data/raw/ghosts/<map_uid>/top_1000_1010`

Output:

- raw trajectory JSON in `data/raw/trajectories/<map-name>/`

Point format:

```json
{ "t": ..., "x": ..., "y": ..., "z": ..., "speed": ... }
```

This layer uses C# and GBX.NET because replay/ghost parsing is already working there and should stay outside Openplanet.

The extractor scans only the selected replay/ghost directory by default. Nested folders are included only with `--recursive`.

### 2. Analysis

Location: `src/analyzer-python`

Input:

- many raw trajectory JSON files for one map

What happens:

- trajectories are loaded
- path progress is computed from `x/z`
- runs are resampled on a shared normalized progress grid
- `x`, `y`, `z`, and `speed` are interpolated on that grid
- a median center line is computed
- runs matching the current excluded nickname are not used for center line and spread computation
- spread is computed from the horizontal `x/z` variation
- mine deviation is computed against the center line
- importance is computed as:

```python
importance = deviation / (spread + epsilon)
```

- peak detection identifies problem zones

Outputs:

- plots in `output/plots/<map-name>/`
- processed machine-readable data in `data/processed/<map-name>/analysis_data.json`

### 3. Bundle

Location: `src/analyzer-python/bundle_builder.py`

Input:

- `data/processed/<map-name>/analysis_data.json`

Output:

- `data/processed/<map-name>/<bundle-name>.analysis_bundle.json`

This is the main bridge between offline analytics and the Openplanet viewer.

The bundle is now MVP-ready for a viewer-first plugin and includes:

- metadata and schema fields
- `runs`
- `center_line`
- `mine_run_name`
- `mine_line`
- `analysis_points`
- `problem_zones`

### 4. Viewer

Location: `src/openplanet`

Current status:

- a working plugin exists in `src/openplanet/RacingLine`
- the plugin depends on `Camera` and `NadeoServices`
- the plugin detects the current map and loads new bundles from `PluginStorage/RacingLine/bundles/<map_uid>/`
- the default bundle filename is currently `top_1000_1010.analysis_bundle.json`
- the UI shows load status, error text, map info, mine run name, counts, toggles, and render debug counters
- the UI shows the current Openplanet user name/login for future automatic player matching
- the UI shows available bundle files for the current map folder as a combo box
- the UI block order is `Status`, `Data`, `Pipeline`, `Toggles`, `Info`
- the UI generates and copies a terminal command for `pipeline.py`
- the UI can download the current player's personal-best replay for the current map into `PluginStorage/RacingLine/tmp/<map_uid>/mine.Replay.Gbx`
- the generated pipeline command can include that mine replay through `--include-mine-replay --mine-replay-path`
- the UI exposes runtime render controls for center line width, mine line width, problem zone marker size, and visible problem zone count
- `center_line` world rendering is implemented
- `mine_line` world rendering is implemented
- `problem_zones` world marker rendering is implemented
- `Show Center`, `Show Mine`, and `Show Problem Zones` toggles control rendering independently
- `Color Center By Speed Delta` recolors the center line from red to green using `mine_speed - center_speed`
- projection now uses the official Openplanet `Camera` dependency instead of manual camera math

Design rule:

- Openplanet should load prepared data and render it
- heavy replay parsing and analytics stay offline

## Why multiple languages

### C#

Used for:

- GBX parsing
- ghost extraction
- raw trajectory export

Reason:

- stable replay parsing with GBX.NET

### Python

Used for:

- resampling
- centerline aggregation
- spread / deviation / importance metrics
- problem zone detection
- bundle preparation
- plotting

Reason:

- fast experimentation and easy numerical work

### AngelScript / Openplanet

Used for:

- UI
- bundle loading
- in-game rendering

Reason:

- correct runtime for Trackmania overlays

## Core analytical concepts

### Raw trajectory

A sequence of replay-derived points with:

- time
- `x/y/z`
- speed

### Center line

A representative trajectory built from many strong runs after resampling over normalized progress.

Current aggregation:

- median `x`
- median `y`
- median `z`
- median speed where available

### Spread

A measure of how much the fast runs diverge at a given progress value.

Current implementation:

- computed from horizontal `x/z` spread

Interpretation:

- low spread = stable optimal behavior
- high spread = more freedom or multiple viable lines

### Deviation

Distance between mine and center line in the analyzed top-down geometry.

### Importance

```python
importance = deviation / (spread + epsilon)
```

Interpretation:

- high deviation with low spread is likely a real mistake

### Problem zones

Top important peaks filtered so they are not too close to each other on progress.

### Speed delta

`mine_speed - center_speed`

Interpretation:

- helps distinguish harmless geometric variation from speed-losing mistakes
- in the viewer, the most negative visible delta is bright red and the most positive visible delta is bright green

## Current repository structure

```text
src/
  extractor-csharp/
  analyzer-python/
  openplanet/

data/
  raw/
    replays/
    trajectories/
  processed/
  temp/

output/
  plots/
  reports/

docs/
scripts/
tests/
```

## Important project principles

1. Preserve raw data.
2. Keep one stable JSON bundle contract between Python and Openplanet.
3. Keep Openplanet viewer-first, not calculator-first.
4. Prefer safe, incremental restructuring.
5. Keep handoff documentation up to date so work can continue across sessions.

## Current MVP direction

The current implemented MVP is:

1. extract replay data offline
2. analyze runs offline
3. build one stable `.analysis_bundle.json` bundle
4. install that bundle into `PluginStorage/RacingLine/bundles/<map_uid>/` for new bundles
5. load that bundle in Openplanet based on the current map
6. confirm bundle loading and metadata in UI
7. render center line in game
8. render mine line in game
9. render problem zone markers in game
10. use UI toggles and render sliders to inspect each overlay layer independently

This avoids rewriting working extractor and analytics logic too early.

## Planned next direction

The next larger project direction is to move more of the pipeline orchestration into the Openplanet UI:

1. choose leaderboard rank ranges for analysis from the UI
2. generate and copy the external pipeline command from the UI
3. pass the detected map and player nickname into scripts instead of relying on hardcoded defaults
4. download ghost files for a leaderboard range
5. later, run extraction, analysis, bundle building, and bundle installation automatically
6. support multiple maps and player nicknames without manual path or nickname edits

For now, replay parsing and analytics remain offline scripts.

## Useful mental model

Think about the project as:

- Extraction: replay -> raw trajectory points
- Analysis: trajectories -> center/spread/deviation/importance/problem zones
- Bundle: processed analysis -> one Openplanet-ready JSON
- Viewer: JSON -> in-game overlay

That separation should guide future code and documentation updates.

## MVP v2 Plan (Automation Phase)

The next stage of the project focuses on automating the offline pipeline and reducing manual steps.

### Stage 1 - Unified pipeline script

Create a single entrypoint script:

```powershell
python pipeline.py --map "<map_name>" --mine "<player_login>" --range "<rank_range>"
```

This script should:

1. run replay extraction (C#)
2. run trajectory analysis (Python)
3. build a named `.analysis_bundle.json` bundle
4. copy the bundle into `PluginStorage/RacingLine/bundles/<map_uid>/` for new bundles

Goal:

- remove the need to manually run multiple commands
- make the pipeline reproducible and parameter-driven

Current implementation:

- `pipeline.py` exists at the repository root
- the default bundle filename is `top_<range>.analysis_bundle.json`, with hyphens normalized to underscores
- installation can be skipped with `--skip-install`
- extraction can be skipped with `--skip-extract` when trajectory JSON already exists
- old trajectory JSON files are removed from `data/raw/trajectories/<map>/` before extraction unless `--keep-old-trajectories` is passed
- old generated plot files are removed from `output/plots/<map>/` before analysis unless `--keep-old-plots` is passed
- mine trajectory presence is required by default; `--allow-missing-mine` allows center-only bundles explicitly

### Stage 2 - Parameterization

Remove hardcoded values from scripts.

Scripts now accept the main runtime values via CLI:

- map name
- player login / nickname
- replay input directory
- output bundle name
- leaderboard rank range

Goal:

- no manual edits inside code
- everything controlled via CLI arguments

Implemented entry points:

```powershell
python pipeline.py --map "Spring 2026 - 02" --mine "TRAIANUSssS" --range "1000-1010" --replay-input-dir ".\data\raw\replays\2"
.\scripts\extract.ps1 --replay-dir ".\data\raw\replays\2" --output-root ".\data\raw\trajectories" --map "Spring 2026 - 02"
.\scripts\analyze.ps1 --map "Spring 2026 - 02" --mine "TRAIANUSssS" --expected-map-prefix "Spring 2026 - 02" --require-mine
.\scripts\build_bundle.ps1 --map "Spring 2026 - 02" --range "1000-1010"
.\scripts\install_bundle.ps1 -BundlePath ".\data\processed\Spring 2026 - 02\top_1000_1010.analysis_bundle.json" -BundleName "top_1000_1010.analysis_bundle.json"
```

### Stage 3 - Automatic bundle installation

After building the bundle, the pipeline should:

- automatically place it into the correct Openplanet storage folder
- follow naming convention:

```text
bundles/<map_uid>/top_<range>.analysis_bundle.json
```

Goal:

- viewer immediately sees new bundles without manual copying

Current implementation:

- `pipeline.py` installs the bundle automatically by default
- installation can be disabled with `--skip-install`
- the storage root can be overridden with `--storage-root`
- the installed filename defaults to `top_<range>.analysis_bundle.json`

### Stage 4 - OpenPlanet integration (lightweight)

Add UI support in the plugin:

- display current map name
- display current player login/name
- generate CLI command string for pipeline
- choose leaderboard rank range from/to

Example:

```powershell
python pipeline.py --map "<current_map>" --mine "<current_nickname>" --range "1000-1010"
```

Goal:

- reduce friction between game and pipeline
- avoid full in-plugin execution for now

Current implementation:

- the plugin displays current map name and current user login/name
- the plugin uses the display nickname for `--mine`; login/account id is shown for reference but is not used as the default pipeline identity
- the plugin exposes editable pipeline project root and replay input directory fields
- the plugin exposes `Rank from` and `Rank to` fields
- rank values cannot be below `1`
- the current maximum rank span is `20`
- rank values cannot be above `10000`, matching the current Trackmania.io downloader limit
- the plugin generates a PowerShell command for `pipeline.py`
- the plugin can copy the generated command to the clipboard
- the plugin does not execute external processes
- the plugin can download the current player's mine replay into plugin storage through NadeoServices
- MVP v3 Stage 4 extends this with leaderboard record downloads into plugin storage

### Stage 5 - Replay preparation handoff

Historical lightweight implementation:

- the Openplanet UI could download only the current player's mine replay
- leaderboard replay/ghost files are expected to already exist in the selected replay input folder or be downloaded by `pipeline.py --download-ghosts`
- the generated command points `pipeline.py` at that folder

```text
data/raw/replays/<map>/
```

Goal:

- reduce manual command construction before full replay download automation exists

This has been superseded by MVP v3 Stage 4 for new work: the plugin can now download leaderboard record replays for the selected rank range into `PluginStorage/RacingLine/downloads/<map_uid>/top_<range>/`.

Future extension note:

- use leaderboard metadata to set the maximum valid `Rank to` value instead of leaving it open-ended

### Stage 6 - Ghost download (semi-automatic)

Current implementation:

- `scripts/download_ghosts.py` fetches Trackmania.io leaderboard metadata and ghost download URLs
- the script downloads `.Ghost.Gbx` files for an inclusive rank range
- downloaded files are cached unless `--force` is passed
- `manifest.json` records ranks, player names, times, source URLs, local paths, and download status
- ranges above rank `10000` are rejected because the Trackmania.io flow used here exposes only the first 10000 ranks
- `pipeline.py --download-ghosts` runs the downloader before extraction and then extracts directly from the downloaded `.Ghost.Gbx` files
- `pipeline.py --include-mine-replay` adds a separately downloaded mine `.Replay.Gbx` file to the extraction input
- the Openplanet plugin downloads mine replay files through NadeoServices into `PluginStorage/RacingLine/tmp/<map_uid>/mine.Replay.Gbx`

Default storage:

```text
data/raw/ghosts/<map_uid>/top_<range>/
```

Goal:

- eliminate manual ghost/replay downloading

Example:

```powershell
python .\pipeline.py --map "Spring 2026 - 02" --mine "TRAIANUSssS" --range "1000-1010" --download-ghosts --leaderboard-id "2b5465cd-38a6-4103-b4c9-27f72adceba6" --map-uid "2pYyYky9ccXdTBaaLncWOjFc6jf"
```

### Stage 7 - Full pipeline trigger

Status: skipped as unnecessary.

Reason:

- `pipeline.py` is already the single full-pipeline entry point
- the useful runtime variables are too numerous for one practical hardcoded `.bat`
- the OpenPlanet UI already generates the command with map, player, range, and replay input values

Future work should focus on better command presets/configuration instead of a single `full_pipeline.bat`.

### Stage 8 - Bundle management

Support multiple bundles per map:

```text
top_100_110.analysis_bundle.json
top_1000_1010.analysis_bundle.json
```

Ensure OpenPlanet UI:

- lists available bundles
- allows switching between them
- displays compact rank range labels instead of raw filenames
- sorts ranges from lower to higher ranks
- shows selected bundle metadata in the Info block
- refreshes the available bundle list automatically while the UI is open

Current implementation:

- implemented in the OpenPlanet viewer
- new bundle files are stored per map under `bundles/<map_uid>/`
- filenames still use `top_<range>.analysis_bundle.json` on disk
- the UI shows labels such as `100-110` and `1000-1020`
- the selected bundle can be reloaded after an external pipeline run

### Stage 9 - Caching

Avoid recomputation when possible:

- reuse already downloaded replays
- skip already processed trajectories
- skip bundle rebuild if inputs unchanged

Required scenarios:

1. All replay/ghost inputs are identical to the previous run:
   - skip extraction
   - skip analysis
   - skip bundle rebuild when the bundle already exists
2. Some replay/ghost inputs changed:
   - download only missing uncached ghosts unless forced
   - extract only changed/new inputs
   - rerun analysis and rebuild the bundle
3. Forced rebuild:
   - redownload ghosts when ghost downloading is enabled
   - re-extract all inputs
   - rerun analysis and rebuild the bundle regardless of cache state

Current implementation:

- downloaded ghosts are reused unless `--force-download-ghosts` or `--force` is passed
- stale `.Ghost.Gbx` files in a downloaded range folder are removed when the latest manifest no longer references them
- `pipeline.py` stores input SHA-256 hashes and analysis settings in `data/temp/pipeline_cache/<map>/top_<range>.json`
- unchanged inputs with an existing bundle skip extraction, analysis, and bundle rebuild
- changed/new inputs are extracted through a temporary cache input folder while existing trajectory JSON files are reused
- removed inputs delete their stale cached trajectory JSON files before analysis
- `--force` bypasses the cache and rebuilds everything
- `--disable-cache` keeps the old full-rebuild behavior

Goal:

- faster iteration
- less redundant work

### Stage 10 - Stability and testing

Status: complete for the current MVP.

Verified behavior:

- from raw replays to in-game visualization
- across multiple maps
- across different leaderboard ranges
- Openplanet detects the current map and loads bundles from that map folder
- the viewer can switch between installed bundles for the current map
- center line, mine line, problem zones, speed coloring, toggles, and render controls work with generated bundles
- the pipeline can download/reuse ghosts, include the current player's mine replay, build the bundle, install it, and let the viewer pick it up

Goal:

- ensure end-to-end reliability

Future stability work should focus on regression testing and edge cases, not on proving the MVP flow again.

### Stage 11 - Developer mode distribution preparation

Status: partially implemented.

Current developer mode:

- full pipeline uses C# + Python + OpenPlanet
- external `pipeline.py` orchestration is implemented
- Openplanet command handoff is implemented
- local bundle generation and installation are implemented

Goal:

- keep developer usage reproducible and documented before broader distribution
- avoid moving heavy processing into the plugin while the workflow is still changing

Current recommendation:

- keep extraction and analytics outside OpenPlanet for MVP v2
- publish/refine viewer-first plugin behavior against prepared bundles
- finish workflow and UX improvements around the existing external pipeline first

### Stage 12 - Viewer render distance filtering

Status: implemented for the simple distance-based MVP.

Problem:

- the viewer currently renders every projected point that is visible on screen
- this can show route segments that are far away from the car
- it can also show points behind walls or map geometry if the projection succeeds

Current implementation:

- the viewer has a `Show Full Trajectory` checkbox
- when full trajectory mode is enabled, the overlay renders the whole selected bundle as before
- when full trajectory mode is disabled, the viewer uses a `Render Distance` slider
- the default render distance is `300` game units
- center line, mine line, and problem zone markers all use the same distance filter
- line segments are kept when at least one segment endpoint is inside the configured distance from the current car position
- if the current car position is not available, the viewer falls back to rendering without distance filtering

Open question:

- whether Openplanet exposes a reliable depth/occlusion test for hiding points behind map geometry

### Stage 13 - Other player trajectory rendering

Status: implemented.

Goal:

- add an optional viewer layer for trajectories from the analyzed replay/ghost set

Current implementation:

- the analyzer exports resampled line points for every analyzed run into `analysis_data.json`
- the bundle builder copies normalized run line data into `runs[].line`
- the Openplanet loader parses `runs[].line`
- the viewer has a `Show Other Runs` checkbox
- the viewer renders all non-mine runs from the bundle as lightweight lines
- keep the layer visually quieter than center/mine lines
- respect the same render distance filtering as other overlay layers
- old bundles without `runs[].line` still load, but the other-runs layer has nothing to draw until the bundle is rebuilt

Reasoning:

- this is close to the existing mine line rendering path
- a single-player inspection can already be approximated by building a bundle with a range such as `1000-1000`

Possible later extension:

- add a selectable run list with checkboxes
- allow showing all runs, no runs, or selected specific players
- add filtering by rank/player name if the bundle contains enough metadata

### Stage 14 - Analysis sample count control

Status: implemented.

Problem:

- analysis currently uses a fixed sample count such as `300`
- short maps and long maps get the same number of key analysis points
- a 15-second map and a 3-minute map need different point density

Current implementation:

- `pipeline.py` supports `--sample-mode manual` and `--sample-mode auto`
- manual mode uses `--samples <count>`
- auto mode estimates representative map duration from extracted trajectory JSON `t` values
- auto mode uses `10` samples per second by default, so a 47-second map gets about `470` samples
- auto mode uses median trajectory duration across available runs to avoid one unusual replay dominating the value
- the Openplanet pipeline UI exposes an `Auto samples` checkbox
- when auto mode is disabled, the UI shows a manual `Sample points` slider
- generated pipeline commands include the selected sample mode

Notes:

- CLI default remains manual `300` samples for backward compatibility
- Openplanet UI defaults to auto samples for normal generated commands
- pipeline cache includes the sample mode and resolved sample count, so changing density rebuilds analysis and bundle output

### Stage 15 - UI cleanup and dev mode toggle

Status: implemented.

Problem:

- the current Openplanet UI exposes too much technical information for normal use
- paths, debug counters, technical status, and always-correct metadata make the player-facing UI noisy

Current implementation:

- the Openplanet window has two modes: compact user UI and dev UI
- compact user UI is the default
- dev UI keeps the previous technical blocks: `Status`, `Data`, `Pipeline`, `Toggles`, and `Info`
- both modes include a `Dev mode` checkbox, so the user can enter or leave dev UI
- compact user UI shows current map, bundle selector, reload/refresh buttons, rank range controls, command generation buttons, sample controls, render toggles, performance warning text, and optional advanced render settings

Compact UI layout:

- `Current map`
- bundle combo box
- `Reload` and `Refresh bundles` buttons on one line
- compact `Rank from` / `to` fields
- `Generate` and `Force generate` buttons
- `Auto samples` and either density text or manual sample slider
- six render checkboxes in two columns
- warning that other runs and full trajectory can hurt performance
- `Extra options` checkbox for render sliders
- `Dev mode` checkbox with a warning text

### Stage 16 - Live progress lookahead rendering

Status: future extension.

Goal:

- render only the next route window relative to the current live run progress, such as the next 5 seconds or nearest future trajectory segment

Possible approach:

- read the current live car position
- match it to the nearest progress point on `mine_line` or `center_line`
- render only a lookahead window from that matched progress/index
- smooth or constrain the matched index so it does not jump backward or between overlapping route sections

Reason to defer:

- it requires reliable real-time mapping between the current live run and the offline trajectory progress/time
- it may need live car sample tracking and nearest-progress matching
- this can be useful later, but distance filtering is simpler and likely good enough for the next viewer iteration

## MVP v3 Plan (Local User Automation)

MVP v3 is a separate project step focused on local automation, not on remote bundle distribution.

Primary goal:

- let a player open a map, choose a leaderboard rank range, generate a local bundle, and view it in Openplanet with minimal manual work
- keep generated bundles local for each player
- avoid introducing a separate server or hosted bundle repository

Current direction:

- do not rewrite the whole C# / Python pipeline into AngelScript at once
- move toward plugin-driven automation in stages
- keep the current extractor, analyzer, bundle builder, and cache behavior as the working reference implementation
- treat full plugin-side bundle generation as a later migration target, not the first MVP v3 step

### Current MVP v3 implementation

The current working MVP v3 architecture is file-based Openplanet-to-helper automation:

```text
Openplanet downloads replays
-> PluginStorage/RacingLine/downloads/<map_uid>/top_<from>_<to>/
-> scripts/racingline_helper.py watches downloads/
-> pipeline.py runs C# extraction + Python analysis + bundle building
-> PluginStorage/RacingLine/bundles/<map_uid>/top_<from>_<to>.analysis_bundle.json
-> Openplanet refreshes bundle list and renders
```

Openplanet responsibilities:

- detect current map and player
- choose rank range
- download leaderboard replay files and the current player's mine replay
- write `manifest.json` next to downloaded files
- read helper status files from `tasks/running/` and `tasks/done/`
- load and render installed bundles

Helper responsibilities:

- watch `PluginStorage/RacingLine/downloads/`
- detect stable downloaded datasets
- run the existing local pipeline through subprocesses
- rely on the C# GBX.NET extractor for replay parsing
- write task status JSON and logs under `PluginStorage/RacingLine/tasks/` and `PluginStorage/RacingLine/logs/`
- install bundles under `PluginStorage/RacingLine/bundles/<map_uid>/`

Reason for the helper:

- Openplanet cannot execute external processes
- Openplanet AngelScript is not a practical place to parse GBX files
- `DataFileMgr.Replay_Load` does not load the Core-downloaded leaderboard `.Replay.Gbx` files, while the C# GBX.NET extractor parses those same files successfully
- file-based communication keeps Openplanet UI-only and keeps heavy processing local

### Stage 1 - Stabilize bundle and data contract

Required cleanup:

- use `map_uid` as the stable map key for new generated paths and metadata
- keep `map_name` as display metadata and for backward compatibility where needed
- ensure bundle metadata includes:
  - `schema_version`
  - `map_uid`
  - `map_name`
  - `rank_from`
  - `rank_to`
  - `sample_mode`
  - `sample_count`
  - `created_at`
  - `generator`

Reasoning:

- map names can be duplicated, renamed, localized, or contain path-hostile characters
- `map_uid` gives the plugin and pipeline a shared durable identifier
- the same bundle contract should work whether the bundle is created by the current external pipeline or by a future plugin-side implementation

Current implementation:

- `pipeline.py --map-uid` now uses `map_uid` as the preferred storage key for new downloaded ghosts, cache/temp input folders, installed bundles, and default mine replay lookup
- the pipeline still uses `map_name` for trajectory and processed analysis folders because the current extractor/analyzer path contract is map-name based
- `bundle_builder.py` writes MVP v3 metadata into both `metadata` and `source`
- bundles include `map.uid` while keeping `map.name`
- the Openplanet viewer detects `map_uid`, prefers `bundles/<map_uid>/`, and still lists legacy `bundles/<map_name>/` folders when present
- generated pipeline commands include `--map-uid` when Openplanet can detect it

### Stage 2 - Clean local producer workflow

Goal:

- make the current pipeline a clean local bundle generator, not a debug/report generator by default

Expected normal output:

- downloaded `.Ghost.Gbx` files
- extracted trajectory JSON files
- processed analysis data if still needed as an intermediate artifact
- final `.analysis_bundle.json`

Graph behavior:

- plot generation should not be part of the normal user flow
- plots are useful for developer inspection when running the process manually
- keep plots behind an explicit dev/debug option

Current implementation:

- `pipeline.py` skips plot generation by default
- `pipeline.py --write-plots` enables developer/debug plot output
- the legacy `--skip-plots` flag is still accepted, but it is no longer needed because plots are disabled by default
- when `--write-plots` is used, pipeline cache is bypassed so plots are actually regenerated
- `trajectory.py` imports plotting dependencies only when plot output is requested
- the Openplanet compact user UI generates no-plot commands
- the Openplanet dev Pipeline block exposes a `Write debug plots` checkbox

### Stage 3 - Normalize local folders

New generated inputs should move toward `map_uid`-based paths:

```text
data/raw/ghosts/<map_uid>/top_<from>_<to>/
```

Installed bundles should move toward:

```text
PluginStorage/RacingLine/bundles/<map_uid>/top_<from>_<to>.analysis_bundle.json
```

Compatibility note:

- existing `map_name`-based folders can remain supported during migration
- new code should prefer `map_uid` when it is available

Current implementation:

- downloaded ghosts default to `data/raw/ghosts/<map_uid>/top_<range>/`
- installed bundles default to `PluginStorage/RacingLine/bundles/<map_uid>/top_<range>.analysis_bundle.json`
- mine replay storage defaults to `PluginStorage/RacingLine/tmp/<map_uid>/mine.Replay.Gbx`
- temporary pipeline input and cache folders use the same map storage key
- when `--replay-input-dir` is omitted, `pipeline.py` first checks the normalized ghost folder for the selected `map_uid` and rank range
- the Openplanet generated command uses the normalized ghost folder as its automatic replay input directory
- the Openplanet dev Pipeline block has an `Auto replay dir` toggle; disabling it allows manual legacy replay folders such as `data/raw/replays/6`
- trajectory and processed analysis folders still use `map_name` because the current extractor/analyzer contract is map-name based

### Stage 4 - Download all ghosts into one folder, then use the old processor

First useful MVP v3 milestone:

- Openplanet detects current map data and selected rank range
- ghosts for the selected range are downloaded into one predictable local folder
- the existing extractor/analyzer/bundle builder processes that folder
- the generated bundle is installed into plugin storage and loaded by the viewer

This stage should preserve the current working data processing path and change only the input preparation and orchestration around it.

Current implementation:

- `DownloadManager.as` implements a first Openplanet-side download POC
- the plugin fetches world leaderboard entries from the Nadeo Live leaderboard endpoint for `Personal_Best`
- the plugin resolves `map_uid` to `map_id` through the Core map info endpoint
- the plugin resolves record/replay URLs through Core `v2/mapRecords/by-account`
- downloaded files are written to:

```text
PluginStorage/RacingLine/downloads/<map_uid>/top_<from>_<to>/
```

- files are named as `.Replay.Gbx` because the Core record endpoint returns replay URLs
- existing files are skipped by default and can be overwritten with `Force download`
- the same download action also downloads or reuses the current player's mine replay in `PluginStorage/RacingLine/tmp/<map_uid>/mine.Replay.Gbx`
- after the combined download action, `--include-mine-replay --mine-replay-path ...` is enabled in the generated pipeline command
- `manifest.json` is written next to the downloaded files, including successes, skipped files, and per-entry errors
- after download, the generated pipeline command points `--replay-input-dir` directly at the PluginStorage download folder
- the plugin still does not execute the external pipeline
- the C# extractor merges dense vehicle streams from `RecordData.EntList`, so replay/ghost files that store the start and later route segments in separate streams still export a full trajectory from `t=0`

Open question:

- Openplanet currently does not execute external processes
- if that remains true, this stage may still generate/copy a command after preparing the ghost folder
- if a safe local helper or external process trigger is introduced, the UI can become a true one-button local generation flow
- if the C# extractor cannot parse Core-downloaded `.Replay.Gbx` files for some records, the follow-up is either extractor support or switching the download source for those entries

### Stage 5 - Download and unpack on the plugin side

Status: superseded by local helper automation.

Original migration stage:

- Openplanet downloads ghosts itself
- replay/ghost unpacking moves closer to the plugin
- the Python analyzer and bundle builder can remain external at first

Previous implementation:

- `ReplayExtractor.as` adds a first plugin-side trajectory export path
- the UI can run `Extract trajectories` after leaderboard replay download
- the plugin loads local `.Replay.Gbx` / `.Ghost.Gbx` files through the game's `DataFileMgr.Replay_Load`
- loaded ghosts are sampled at runtime through `Ghost_GetPosition`
- trajectory JSON is written to:

```text
PluginStorage/RacingLine/trajectories/<map_uid>/top_<from>_<to>/
```

- each exported file uses the existing raw trajectory point contract:

```json
{ "t": 0, "x": 0.0, "y": 0.0, "z": 0.0, "speed": 0.0 }
```

- `manifest.json` records source files, output files, point counts, and errors

Limitation:

- this is runtime ghost sampling, not a direct AngelScript GBX parser
- `RecordData -> EntList -> Samples` is still not exposed through normal Openplanet AngelScript API, so the C# GBX.NET extractor remains the higher-fidelity reference extractor

Main risk:

- GBX parsing is already solved in C# through GBX.NET
- reimplementing GBX parsing in AngelScript may be expensive and fragile
- a small local helper may be more practical than a full AngelScript parser

Outcome:

- Openplanet `DataFileMgr.Replay_Load` does not load the Core-downloaded leaderboard `.Replay.Gbx` files, even though the C# GBX.NET extractor parses the same files successfully
- the plugin-side runtime sampling path has been removed from the UI
- the project now uses `scripts/racingline_helper.py` as the MVP v3 local automation path
- Openplanet downloads replay files and reads helper status files
- the helper watches `PluginStorage/RacingLine/downloads/`, runs the existing C# + Python pipeline, writes status/log files, and installs bundles into `PluginStorage/RacingLine/bundles/<map_uid>/`

### Stage 6 - Download, unpack, and create bundle on the plugin side

Status: canceled for MVP v3.

Reason:

- the current helper architecture already provides the intended one-click local UX without moving heavy processing into AngelScript
- plugin-side bundle generation would require reimplementing stable C# and Python logic in Openplanet
- Openplanet `DataFileMgr.Replay_Load` is not reliable for the Core-downloaded leaderboard replay files used by the current download flow

Original longer-term target:

- Openplanet downloads ghosts
- Openplanet or a tightly integrated helper extracts trajectory data
- bundle generation happens without the current Python/C# developer pipeline
- the old pipeline remains as the developer/reference implementation

This stage is large because it requires moving or replacing:

- trajectory extraction
- resampling
- center line computation
- spread/deviation/importance computation
- problem zone detection
- sample count logic
- pipeline cache behavior

Recommendation:

- do not implement plugin-side bundle generation for MVP v3
- keep Openplanet UI-only
- keep extraction, analysis, bundle building, and cache behavior in the local helper / existing pipeline

## MVP v4 Plan (Production Polish)

MVP v4 is the polish and release-preparation stage.

Primary goal:

- bring the local one-button workflow to a state suitable for real user distribution
- reduce visual clutter in-game
- move developer-only controls out of the normal UI
- package the helper so normal users do not need to run Python manually
- verify that paths and storage behavior work on other computers

### Stage 1 - Multi-lap visual clutter

Problem:

- on maps with multiple laps, route segments can overlap in world space
- the current analyzer normalizes the whole run to one `0..1` progress range based on cumulative `x/z` distance
- when the same physical track section is driven multiple times, center/mine/other-run lines and problem markers can render on top of each other

Planned direction:

- avoid simply offsetting lines visually, because that would make the overlay less truthful
- add a progress-aware or lookahead render mode that shows only the currently relevant route window
- group or de-duplicate problem zones that are nearly identical in world-space position
- investigate whether lap/checkpoint information can be extracted reliably enough for a later explicit `lap_index`

MVP v4 target:

- reduce overlapping visual noise enough for multi-lap maps to be usable
- keep full trajectory rendering available as an advanced/debug option

### Stage 2 - Hide markers or overlay while paused

Problem:

- problem zone dots and/or trajectory overlay remain visible while the game is paused
- this adds visual noise when the player is not actively driving

Planned direction:

- detect paused/menu state from Openplanet/Trackmania runtime state
- add a setting such as `Hide overlay when paused`, enabled by default
- at minimum, hide problem zone markers while paused
- if reliable, hide the whole world overlay while paused

### Stage 3 - Move Extra Options into Openplanet settings

Problem:

- compact user UI currently exposes `Extra options` inside the main RacingLine window
- render sliders are useful, but they are advanced configuration rather than normal workflow controls

Planned direction:

- move render distance, line widths, problem marker size, max visible problem zones, and similar controls into Openplanet plugin settings
- persist user-facing toggles and render options through `[Setting]` values where appropriate
- keep the compact UI focused on map, bundle selection, generation/download status, and primary layer toggles

### Stage 4 - UI polish pass

Problem:

- MVP v3 UI is functional, but still has developer-flow artifacts
- final layout and copy should be tightened before production submission

Planned direction:

- revise compact UI layout after a separate UI pass
- keep developer-only pipeline and diagnostic details behind dev mode
- improve helper status text for normal users
- make successful and failed generation states easier to understand
- avoid exposing paths unless dev mode is enabled or there is an actionable error

### Stage 5 - Collapsible RacingLine window

Problem:

- the RacingLine window can be closed, but it cannot collapse to a small header-style bar
- other Openplanet plugins use a compact collapsed state that keeps the plugin visible without occupying screen space

Planned direction:

- add a collapsed state to the RacingLine window
- show a small title/header row when collapsed
- expand/collapse through a triangle button in the header
- preserve the existing menu toggle for fully showing/hiding the window

### Stage 6 - Helper executable packaging

Problem:

- the local helper currently runs as `python scripts/racingline_helper.py`
- normal users should not need Python knowledge or a developer terminal workflow

Planned direction:

- package the helper as a standalone `.exe`
- verify that the exe can watch `PluginStorage/RacingLine/downloads/`
- verify that it can run the pipeline or bundled processing dependencies from the expected install location
- verify task status files, logs, and installed bundles are still written in the current contract
- document how users start/stop the helper

Open question:

- whether the exe should bundle the whole processing stack or require the project/pipeline folder next to it for MVP v4

### Stage 7 - Path portability audit

Problem:

- production users will not have the same local paths as the developer machine
- the Openplanet config still contains a hardcoded developer project root

Known issue:

```angelscript
string PipelineProjectRoot = "E:/Projects/RacingLine";
```

Planned direction:

- remove hardcoded developer paths from Openplanet defaults
- prefer Openplanet storage-relative paths inside the plugin
- keep Python defaults based on `Path.home()` and CLI overrides
- verify behavior with Cyrillic/non-ASCII Windows usernames
- verify bundle, task, log, tmp, and download paths on a clean machine

### Stage 8 - Leaderboard record count limit

Problem:

- the UI currently clamps rank input to `10000`
- that limit matches the current downloader/API behavior, but it is not the real number of players with records on every map
- for maps with fewer records, users can choose invalid ranges that cannot fully download

Planned direction:

- investigate which Openplanet/Nadeo/Trackmania endpoint exposes the real record count for the current map
- look at existing plugins that display in-game record counts as a reference
- replace or supplement the fixed `10000` maximum with the real available record count when it can be detected
- keep `10000` as a safe fallback if the real count cannot be fetched
- show clear UI feedback when the selected rank range exceeds available records

MVP v4 target:

- prevent obviously invalid rank ranges for maps with fewer than `10000` records
- keep the downloader behavior predictable when the total count is unknown

### Stage 9 - Rendering performance guardrails

Problem:

- `Show Other Runs` and `Show Full Trajectory` can become expensive on large bundles
- rendering every segment of every run is not always necessary for user inspection

Planned direction:

- add limits or settings for maximum visible other runs
- consider downsampling other-run lines in the viewer or bundle
- keep render distance filtering enabled by default
- expose performance-heavy options only as advanced settings

### Stage 10 - Helper status and auto-load polish

Problem:

- Openplanet reads helper status files, but production UX should make the local automation state clearer
- after successful generation, the newly built bundle should be easy to select or load automatically

Planned direction:

- improve compact helper states: helper missing, waiting, building, done, failed
- auto-refresh bundle list after helper completion
- auto-select and reload the generated bundle for the current map/range when safe
- keep log paths available in dev mode or error details

### Stage 11 - Production documentation and release checklist

Problem:

- current docs are developer-focused
- production submission needs a clear install/use/debug path

Planned direction:

- add a user-facing install guide
- document helper exe startup
- document where bundles, downloads, logs, and task files are stored
- document known limitations such as multi-lap ambiguity and external helper requirement
- prepare a release checklist for Openplanet plugin submission
