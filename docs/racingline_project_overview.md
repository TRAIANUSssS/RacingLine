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

Output:

- raw trajectory JSON in `data/raw/trajectories/<map-name>/`

Point format:

```json
{ "t": ..., "x": ..., "y": ..., "z": ..., "speed": ... }
```

This layer uses C# and GBX.NET because replay parsing is already working there and should stay outside Openplanet.

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

- `data/processed/<map-name>/analysis_bundle.json`

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
- the plugin loads `analysis_bundle.json` from plugin storage
- the UI shows load status, error text, map info, mine run name, counts, and basic render debug counters
- `center_line` world rendering is implemented
- projection now uses the official Openplanet `Camera` dependency instead of manual camera math
- `mine_line` and `problem_zones` rendering are still pending

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

The current preferred MVP is:

1. extract replay data offline
2. analyze runs offline
3. build one stable `analysis_bundle.json`
4. load that bundle in Openplanet
5. confirm bundle loading and metadata in UI
6. render center line in game
7. add mine line and problem zones in later steps

This avoids rewriting working extractor and analytics logic too early.

## Useful mental model

Think about the project as:

- Extraction: replay -> raw trajectory points
- Analysis: trajectories -> center/spread/deviation/importance/problem zones
- Bundle: processed analysis -> one Openplanet-ready JSON
- Viewer: JSON -> in-game overlay

That separation should guide future code and documentation updates.
