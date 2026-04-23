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
- `main.as`, `Config.as`, `Models.as`, `Loader.as`, `Ui.as`, and `Renderer.as` are implemented
- bundle parsing is implemented
- UI window is implemented
- `center_line` world rendering is implemented
- `info.toml` now depends on the official Openplanet `Camera` dependency

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
  - projected/skipped center segment counts
- project world positions through the official `Camera` dependency
- draw the `center_line` as a connected overlay line when `Show Center` is enabled

It currently does not:

- draw `mine_line`
- draw problem zone markers

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

1. Keep current loader, UI, and `center_line` rendering stable
2. Render mine line
3. Render problem zone markers
4. Add simple world-space toggles and styling

## Current constraint

The data contract is ready, the loader/UI plugin is working, and `center_line` projection is now solved through the official `Camera` dependency. The next Openplanet steps should extend rendering from the existing bundle, not redesign the schema or return to manual camera math.
