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

- `info.toml` exists
- `main.as` contains a viewer shell
- bundle parsing is not implemented yet
- world rendering is not implemented yet

## Expected input

The viewer should consume:

- `data/processed/<map-name>/analysis_bundle.json`

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

## Suggested MVP rendering order

1. Load JSON
2. Parse line arrays
3. Parse problem zones
4. Add simple UI toggles
5. Render center line
6. Render mine line
7. Render problem zone markers

## Current constraint

The data contract is ready before the viewer. The next Openplanet step should focus on consuming the existing bundle, not redesigning the schema.

