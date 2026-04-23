# Pipeline

RacingLine currently works as an offline-first pipeline with a future in-game viewer.

## End-to-end flow

1. Put `.Replay.Gbx` files in `data/raw/replays`
2. Run the C# extractor
3. Inspect generated trajectory JSON in `data/raw/trajectories/<map-name>/`
4. Run the Python analyzer for one map
5. Inspect plots in `output/plots/<map-name>/`
6. Inspect processed data in `data/processed/<map-name>/analysis_data.json`
7. Build `analysis_bundle.json`
8. Load that bundle from Openplanet later

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
- Current state: shell only

The viewer is expected to read `analysis_bundle.json` and render prepared world-space data.

## Common commands

```powershell
.\scripts\extract.ps1
.\scripts\analyze.ps1 --source-dir ".\data\raw\trajectories\Spring 2026 - 03"
.\scripts\build_bundle.ps1 --analysis-json ".\data\processed\Spring 2026 - 03\analysis_data.json"
```

## Default paths

- Raw replays: `data/raw/replays`
- Raw trajectories: `data/raw/trajectories`
- Processed analysis: `data/processed`
- Plots: `output/plots`
- Reports: `output/reports`
- Temporary/debug files: `data/temp`

