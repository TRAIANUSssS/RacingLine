# Analysis Bundle Schema

`analysis_bundle.json` is the stable handoff artifact between the offline Python analyzer and the Openplanet viewer.

Current schema version: `1`

Current analysis version: `1`

## Purpose

The bundle should be easy to consume from AngelScript:

- flat top-level arrays
- simple scalar fields
- no heavy recomputation required in Openplanet

## Top-level structure

```json
{
  "schema_version": 1,
  "analysis_version": 1,
  "created_at": "2026-04-23T00:00:00+00:00",
  "metadata": {
    "schema_version": 1,
    "map_uid": "2pYyYky9ccXdTBaaLncWOjFc6jf",
    "map_name": "Spring 2026 - 03",
    "rank_from": 1000,
    "rank_to": 1010,
    "sample_mode": "auto",
    "sample_count": 470,
    "created_at": "2026-04-23T00:00:00+00:00",
    "generator": "pipeline.py"
  },
  "map": {
    "uid": "2pYyYky9ccXdTBaaLncWOjFc6jf",
    "name": "Spring 2026 - 03"
  },
  "coordinate_system": {
    "world_axes": {
      "x": "Trackmania world X",
      "z": "Trackmania world Z"
    },
    "top_down_plot": "-X vs Z"
  },
  "source": {
    "analysis_json": "data\\processed\\Spring 2026 - 03\\analysis_data.json",
    "source_dir": "data\\raw\\trajectories\\Spring 2026 - 03",
    "rank_range": "1000-1010",
    "rank_from": 1000,
    "rank_to": 1010,
    "sample_mode": "auto",
    "sample_count": 470,
    "generator": "pipeline.py"
  },
  "runs": [],
  "center_line": [],
  "mine_run_name": "Spring 2026 - 03_TRAIANUSssS_...",
  "mine_line": [],
  "analysis_points": [],
  "mine": {
    "name": "Spring 2026 - 03_TRAIANUSssS_...",
    "line": []
  },
  "problem_zones": []
}
```

`metadata` is the preferred stable machine-readable block for MVP v3 and later. `map.uid` duplicates `metadata.map_uid` for convenient viewer access. Older bundles without these fields remain loadable.

## `runs`

Each item describes one raw trajectory used in the batch:

```json
{
  "name": "run name",
  "point_count": 455,
  "has_speed": true,
  "used_for_center": true,
  "line": []
}
```

`used_for_center` is false for runs excluded from center line and spread computation, for example the current player's own run.

When present, `line` contains the run resampled onto the same normalized progress grid as `center_line`:

```json
{
  "progress": 0.0,
  "x": 1072.0,
  "y": 2.002,
  "z": 656.00006,
  "speed": 0.8105306
}
```

Openplanet uses `runs[].line` for the optional `Show Other Runs` layer. Older bundles may omit this field; they remain loadable, but the other-runs layer has no geometry to draw.

## `center_line`

Canonical center geometry for rendering and comparison.

```json
{
  "progress": 0.0,
  "x": 1072.0,
  "y": 2.002,
  "z": 656.00006,
  "speed": 0.8105306,
  "spread": 0.0
}
```

Notes:

- `progress` is normalized in `[0, 1]`
- `x/y/z` are world coordinates
- `speed` is median speed on the common progress grid
- `spread` is currently derived from horizontal `x/z` variation
- excluded player runs do not contribute to center line or spread values

## `mine_line`

Player trajectory on the same progress grid as `center_line`.

```json
{
  "progress": 0.0,
  "x": 1072.0,
  "y": 2.002,
  "z": 656.00006,
  "speed": 0.8105306,
  "deviation": 0.0,
  "importance": 0.0,
  "speed_delta": 0.0
}
```

Notes:

- `x/y/z` are world coordinates
- `speed` is mine speed on the shared progress grid
- analysis fields are duplicated here for backward compatibility

## `analysis_points`

Canonical analytical layer aligned 1:1 with `center_line` and `mine_line`.

```json
{
  "progress": 0.0,
  "deviation": 0.0,
  "importance": 0.0,
  "speed_delta": 0.0
}
```

Use this block for charts, thresholds, and logic that does not need full geometry.

## `problem_zones`

Top importance peaks for viewer overlays and review.

```json
{
  "id": 1,
  "rank": 1,
  "index": 43,
  "progress": 0.14381270903010032,
  "importance": 2.5583468466395933,
  "deviation": 3.913706536343318,
  "spread": 1.5297617806262186,
  "center_speed": 323.501,
  "mine_speed": 322.958,
  "x": 1169.462,
  "y": 5.5067,
  "z": 823.794
}
```

Notes:

- sorted by importance rank
- `x/y/z` are copied from the matching `center_line` point
- designed to make Openplanet rendering trivial

## Alignment guarantees

The following arrays are aligned by index and progress:

- `center_line`
- `mine_line`
- `analysis_points`

That means element `i` in each array refers to the same normalized progress sample.

## Current computation assumptions

- `y` is resampled with the same interpolation logic as `x` and `z`
- centerline `y` is computed with the same median aggregation used for `x` and `z`
- `problem_zones` coordinates are copied from the matching `center_line` point
