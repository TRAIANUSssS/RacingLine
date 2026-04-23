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
- `main.as`, `Config.as`, `Models.as`, `Loader.as`, and `Ui.as` are implemented
- bundle parsing is implemented
- UI window is implemented
- world rendering is not implemented yet

## Expected input

The viewer should consume:

- `analysis_bundle.json` from Openplanet plugin storage

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
- show whether loading succeeded
- show the last error message
- show:
  - map name
  - mine run name
  - center point count
  - mine point count
  - problem zone count

It currently does not:

- draw world lines
- draw problem markers
- project world positions to screen

## Storage path

If the UI bundle path is relative, the loader resolves it inside Openplanet plugin storage.

Default expected location:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\analysis_bundle.json
```

That allows the UI field to stay as:

```text
analysis_bundle.json
```

## Suggested MVP rendering order

1. Keep current loader and UI stable
2. Render center line
3. Render mine line
4. Render problem zone markers
5. Add simple world-space toggles and styling

## Current constraint

The data contract is ready and the first loader/UI plugin is working. The next Openplanet step should focus on rendering the existing bundle, not redesigning the schema.
