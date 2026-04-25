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
- bundle path editing and reload are implemented
- `Show Center`, `Show Mine`, and `Show Problem Zones` toggles are implemented
- `center_line` world rendering is implemented
- `mine_line` world rendering is implemented
- `problem_zones` world marker rendering is implemented
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
- edit the bundle path from the UI
- show whether loading succeeded
- show the last error message
- show:
  - map name
  - mine run name
  - center point count
  - mine point count
  - problem zone count
  - projected/skipped center segment counts
  - projected/skipped mine segment counts
  - projected/skipped problem zone counts
- project world positions through the official `Camera` dependency
- draw the `center_line` as a connected overlay line when `Show Center` is enabled
- draw the `mine_line` as a connected overlay line when `Show Mine` is enabled
- draw problem zone markers when `Show Problem Zones` is enabled

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

## Suggested next rendering work

1. Keep current loader, UI, toggles, and layer rendering stable
2. Improve styling for problem zone markers if needed
3. Add richer zone labels or details only after the marker layer is stable
4. Avoid redesigning the bundle schema unless the analyzer needs new viewer fields

## Current constraint

The data contract is ready, the loader/UI plugin is working, and world projection is solved through the official `Camera` dependency. The next Openplanet steps should refine rendering from the existing bundle, not redesign the schema or return to manual camera math.
