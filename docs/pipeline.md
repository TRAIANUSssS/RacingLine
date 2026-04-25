# Pipeline

RacingLine currently works as an offline-first pipeline with an Openplanet in-game viewer.

## End-to-end flow

1. Put `.Replay.Gbx` files in `data/raw/replays`
2. Run the C# extractor
3. Inspect generated trajectory JSON in `data/raw/trajectories/<map-name>/`
4. Run the Python analyzer for one map
5. Inspect plots in `output/plots/<map-name>/`
6. Inspect processed data in `data/processed/<map-name>/analysis_data.json`
7. Build `analysis_bundle.json`
8. Install that bundle into Openplanet plugin storage under `bundles/<map>/`
9. Load that bundle from the Openplanet UI
10. Render `center_line`, `mine_line`, and `problem_zones` in-game through the Openplanet viewer

## Layers

### Extraction

- Code: `src/extractor-csharp`
- Entry point: `Program.cs`
- Reads: `data/raw/replays`
- Writes: `data/raw/trajectories`

This layer parses `.Replay.Gbx` files and exports raw points with `t/x/y/z/speed`.

### Analysis

- Code: `src/analyzer-python`
- Entry point: `trajectory.py`
- Reads: `data/raw/trajectories/<map-name>/`
- Writes:
  - `output/plots/<map-name>/`
  - `data/processed/<map-name>/analysis_data.json`

This layer resamples runs over a shared progress grid and computes:

- center line
- spread
- deviation
- importance
- speed delta
- problem zones

Runs matching the excluded center nickname are still exported and can still be used as `mine_line`, but they are excluded from center line and spread computation. The current default excluded nickname is `TRAIANUSssS`.

### Bundle

- Code: `src/analyzer-python/bundle_builder.py`
- Reads: `data/processed/<map-name>/analysis_data.json`
- Writes: `data/processed/<map-name>/analysis_bundle.json`

This layer stabilizes the contract for Openplanet. The bundle now includes:

- metadata
- `runs`
- `center_line` with `x/y/z`
- `mine_run_name`
- `mine_line` with `x/y/z`
- `analysis_points`
- `problem_zones` with copied world coordinates

### Viewer

- Code: `src/openplanet`
- Plugin folder: `src/openplanet/RacingLine`
- Current state: loader + UI implemented, `center_line`, `mine_line`, and `problem_zones` world rendering implemented

The viewer currently:

- resolves bundle paths relative to Openplanet plugin storage
- detects the current map name from Openplanet
- uses `bundles/<map>/top_1000_1010.analysis_bundle.json` as the default bundle path
- lists available `.analysis_bundle.json` files from the current map folder
- loads and parses `analysis_bundle.json`
- exposes a reload button
- shows load status, bundle error text, map name, mine run name, point counts, toggles, and render counters
- shows current Openplanet user name/login
- exposes render sliders for center line width, mine line width, problem marker size, and visible problem zone count
- projects world points through the official Openplanet `Camera` dependency
- renders the `center_line` as a connected in-game overlay line
- can recolor the center line by `speed_delta` from red (mine slower) to green (mine faster)
- renders the `mine_line` as a connected in-game overlay line
- renders `problem_zones` as in-game markers
- lets `Show Center`, `Show Mine`, and `Show Problem Zones` independently control those layers
- keeps `Status`, `Data`, `Toggles`, and `Info` as the UI block order

Expected storage location for a relative bundle path:

- `OpenplanetNext/PluginStorage/RacingLine/bundles/<map>/top_1000_1010.analysis_bundle.json`

## Common commands

```powershell
.\scripts\extract.ps1
.\scripts\analyze.ps1 --source-dir ".\data\raw\trajectories\Spring 2026 - 03"
.\scripts\build_bundle.ps1 --analysis-json ".\data\processed\Spring 2026 - 03\analysis_data.json"
.\scripts\install_bundle.ps1 -BundlePath ".\data\processed\Spring 2026 - 03\analysis_bundle.json"
```

The install step copies the resulting bundle to Openplanet storage:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\Spring 2026 - 03\top_1000_1010.analysis_bundle.json
```

## Planned automation

The intended next pipeline evolution is:

- select leaderboard rank ranges from the Openplanet UI
- download replay files from the Openplanet UI
- run extraction, analysis, bundle building, and installation automatically
- pass detected map and player identity into scripts instead of relying on manual constants
- support multiple maps and player nicknames without manual path edits

## Default paths

- Raw replays: `data/raw/replays`
- Raw trajectories: `data/raw/trajectories`
- Processed analysis: `data/processed`
- Plots: `output/plots`
- Reports: `output/reports`
- Temporary/debug files: `data/temp`
