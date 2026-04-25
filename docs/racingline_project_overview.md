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

- Trackmania `.Replay.Gbx` files from `data/raw/replays` or a selected replay subfolder such as `data/raw/replays/2`

Output:

- raw trajectory JSON in `data/raw/trajectories/<map-name>/`

Point format:

```json
{ "t": ..., "x": ..., "y": ..., "z": ..., "speed": ... }
```

This layer uses C# and GBX.NET because replay parsing is already working there and should stay outside Openplanet.

The extractor scans only the selected replay directory by default. Nested folders are included only with `--recursive`.

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
- the plugin detects the current map and loads bundles from `PluginStorage/RacingLine/bundles/<map>/`
- the default bundle filename is currently `top_1000_1010.analysis_bundle.json`
- the UI shows load status, error text, map info, mine run name, counts, toggles, and render debug counters
- the UI shows the current Openplanet user name/login for future automatic player matching
- the UI shows available bundle files for the current map folder as a combo box
- the UI block order is `Status`, `Data`, `Pipeline`, `Toggles`, `Info`
- the UI generates and copies a terminal command for `pipeline.py`
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
4. later, download replay files for a leaderboard range
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
- no upper leaderboard limit is enforced yet; this should later come from leaderboard metadata
- the plugin generates a PowerShell command for `pipeline.py`
- the plugin can copy the generated command to the clipboard
- the plugin does not execute external processes

### Stage 5 - Replay preparation handoff

Current lightweight implementation:

- the Openplanet UI does not download replay files yet
- replay files are expected to already exist in the selected replay input folder
- the generated command points `pipeline.py` at that folder

```text
data/raw/replays/<map>/
```

Goal:

- reduce manual command construction before full replay download automation exists

Future extension note:

- use leaderboard metadata to set the maximum valid `Rank to` value instead of leaving it open-ended

### Stage 6 - Replay download (semi-automatic)

Implement a script to:

- fetch replay/ghost files for a leaderboard rank range
- store them in:

```text
data/raw/replays/<map>/
```

Goal:

- eliminate manual replay downloading

### Stage 7 - Full pipeline trigger

Allow running the full pipeline from a single command:

```powershell
full_pipeline.bat
```

or Python equivalent.

Later extension:

- optional OpenPlanet button to trigger pipeline

### Stage 8 - Bundle management

Support multiple bundles per map:

```text
top_100_110.analysis_bundle.json
top_1000_1010.analysis_bundle.json
```

Ensure OpenPlanet UI:

- lists available bundles
- allows switching between them

### Stage 9 - Caching

Avoid recomputation when possible:

- reuse already downloaded replays
- skip already processed trajectories
- skip bundle rebuild if inputs unchanged

Goal:

- faster iteration
- less redundant work

### Stage 10 - Stability and testing

Verify full pipeline:

- from raw replays to in-game visualization
- across multiple maps
- across different leaderboard ranges

Goal:

- ensure end-to-end reliability

### Stage 11 - Preparation for distribution

Prepare two usage modes:

1. Developer mode (current):
   - full pipeline (C# + Python + OpenPlanet)
2. User mode (future):
   - OpenPlanet viewer plugin
   - consumes prebuilt bundles

Decision point:

- whether to move parts of pipeline into AngelScript
- or keep heavy processing external

Current recommendation:

- keep extraction and analytics outside OpenPlanet
- publish viewer-first plugin initially
