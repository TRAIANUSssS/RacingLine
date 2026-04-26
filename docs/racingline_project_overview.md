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
- or a selected input subfolder such as `data/raw/replays/2` or `data/raw/ghosts/<map>/top_1000_1010`

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
- the plugin detects the current map and loads bundles from `PluginStorage/RacingLine/bundles/<map>/`
- the default bundle filename is currently `top_1000_1010.analysis_bundle.json`
- the UI shows load status, error text, map info, mine run name, counts, toggles, and render debug counters
- the UI shows the current Openplanet user name/login for future automatic player matching
- the UI shows available bundle files for the current map folder as a combo box
- the UI block order is `Status`, `Data`, `Pipeline`, `Toggles`, `Info`
- the UI generates and copies a terminal command for `pipeline.py`
- the UI can download the current player's personal-best replay for the current map into `PluginStorage/RacingLine/tmp/<map>/mine.Replay.Gbx`
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
4. install that bundle into `PluginStorage/RacingLine/bundles/<map>/`
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
4. copy the bundle into `PluginStorage/RacingLine/bundles/<map>/`

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
bundles/<map>/top_<range>.analysis_bundle.json
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

### Stage 5 - Replay preparation handoff

Current lightweight implementation:

- the Openplanet UI can download only the current player's mine replay
- leaderboard replay/ghost files are expected to already exist in the selected replay input folder or be downloaded by `pipeline.py --download-ghosts`
- the generated command points `pipeline.py` at that folder

```text
data/raw/replays/<map>/
```

Goal:

- reduce manual command construction before full replay download automation exists

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
- the Openplanet plugin downloads mine replay files through NadeoServices into `PluginStorage/RacingLine/tmp/<map>/mine.Replay.Gbx`

Default storage:

```text
data/raw/ghosts/<map>/top_<range>/
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
- bundle files are stored per map under `bundles/<map>/`
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

### Stage 4 - Download all ghosts into one folder, then use the old processor

First useful MVP v3 milestone:

- Openplanet detects current map data and selected rank range
- ghosts for the selected range are downloaded into one predictable local folder
- the existing extractor/analyzer/bundle builder processes that folder
- the generated bundle is installed into plugin storage and loaded by the viewer

This stage should preserve the current working data processing path and change only the input preparation and orchestration around it.

Open question:

- Openplanet currently does not execute external processes
- if that remains true, this stage may still generate/copy a command after preparing the ghost folder
- if a safe local helper or external process trigger is introduced, the UI can become a true one-button local generation flow

### Stage 5 - Download and unpack on the plugin side

Next migration stage:

- Openplanet downloads ghosts itself
- replay/ghost unpacking moves closer to the plugin
- the Python analyzer and bundle builder can remain external at first

Main risk:

- GBX parsing is already solved in C# through GBX.NET
- reimplementing GBX parsing in AngelScript may be expensive and fragile
- a small local helper may be more practical than a full AngelScript parser

### Stage 6 - Download, unpack, and create bundle on the plugin side

Longer-term target:

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

- do not start MVP v3 here
- only attempt this after the local folder layout, metadata contract, no-plot normal flow, and old-pipeline orchestration are stable
