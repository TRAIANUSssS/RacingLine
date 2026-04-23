# Analyzer Handoff

Location: `src/analyzer-python`

## Purpose

This layer owns all offline analytics. It should stay the source of truth for:

- progress resampling
- centerline aggregation
- spread
- deviation
- importance
- speed delta
- problem zone detection
- processed data export
- bundle preparation inputs

## Entry points

- `trajectory.py`
- `bundle_builder.py`

## Internal modules

- `racingline_analyzer/analysis.py`
- `racingline_analyzer/geometry.py`
- `racingline_analyzer/metrics.py`
- `racingline_analyzer/io_utils.py`
- `racingline_analyzer/bundle.py`
- `racingline_analyzer/plotting.py`

## Inputs

- raw trajectory JSON in `data/raw/trajectories/<map-name>/`

Each raw point is expected to contain:

```json
{ "t": ..., "x": ..., "y": ..., "z": ..., "speed": ... }
```

## Outputs

### Plots

Written to `output/plots/<map-name>/`

Examples:

- overlay plots
- center speed plot
- spread plot
- mine deviation plot
- importance plot
- problem zone zooms

### Processed analysis

Written to `data/processed/<map-name>/analysis_data.json`

This file contains:

- `runs`
- `center_line`
- `mine_name`
- `mine_line`
- `problem_zones`

Unlike older revisions, `center_line` and `mine_line` now include real `y` coordinates after resampling.

## Run

```powershell
python .\src\analyzer-python\trajectory.py --source-dir ".\data\raw\trajectories\Spring 2026 - 03"
python .\src\analyzer-python\bundle_builder.py --analysis-json ".\data\processed\Spring 2026 - 03\analysis_data.json"
```

## Important implementation notes

- progress is computed from horizontal path length in `x/z`
- `x`, `y`, `z`, and `speed` are all interpolated on the common progress grid
- centerline `x/y/z` uses median aggregation
- spread is still based on `x/z`, not full 3D distance
- `analysis_points` in the bundle are the preferred canonical metric layer
- duplicate analysis fields inside `mine_line` are currently kept for compatibility

