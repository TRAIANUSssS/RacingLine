# Pipeline

RacingLine currently works as an offline-first pipeline with an Openplanet in-game viewer.

## End-to-end flow

1. Put `.Replay.Gbx` or `.Ghost.Gbx` files in `data/raw/replays`, `data/raw/ghosts`, or a selected subfolder
2. Run the C# extractor
3. Inspect generated trajectory JSON in `data/raw/trajectories/<map-name>/`
4. Run the Python analyzer for one map
5. Inspect plots in `output/plots/<map-name>/`
6. Inspect processed data in `data/processed/<map-name>/analysis_data.json`
7. Build a named `.analysis_bundle.json` bundle
8. Install that bundle into Openplanet plugin storage under `bundles/<map>/`
9. Load that bundle from the Openplanet UI
10. Render `center_line`, `mine_line`, and `problem_zones` in-game through the Openplanet viewer

## Layers

### Extraction

- Code: `src/extractor-csharp`
- Entry point: `Program.cs`
- Reads: `data/raw/replays`, `data/raw/ghosts`, or the selected replay/ghost input directory
- Writes: `data/raw/trajectories`

This layer parses `.Replay.Gbx` and `.Ghost.Gbx` files and exports raw points with `t/x/y/z/speed`. It scans only the selected directory by default and reads nested directories only with `--recursive`.

### Ghost download

- Code: `scripts/download_ghosts.py`
- Reads: Trackmania.io leaderboard metadata and ghost download URLs
- Writes: `data/raw/ghosts/<map_uid>/top_<range>/` for new generated downloads

This layer fetches leaderboard entries from:

```text
https://trackmania.io/api/leaderboard/<leaderboard-id>/<map-uid>?offset=<offset>&length=<length>
```

Ranks in the RacingLine CLI are 1-based and inclusive. For example, `--range "1000-1010"` becomes `offset=999&length=11`.

The downloader writes:

- `.Ghost.Gbx` files
- `manifest.json` with source metadata, local paths, player names, ranks, times, and download status

Trackmania.io exposes only the first 10000 ranks in the web UI/API flow used here, so the downloader rejects ranges above rank `10000`.

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
- Writes: `data/processed/<map-name>/<bundle-name>.analysis_bundle.json`

This layer stabilizes the contract for Openplanet. The bundle now includes:

- metadata
- `map.uid` and `map.name`
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
- detects the current map UID from Openplanet
- uses `bundles/<map_uid>/top_1000_1010.analysis_bundle.json` as the default new bundle path
- still lists legacy `.analysis_bundle.json` files from `bundles/<map_name>/` when present
- loads and parses `analysis_bundle.json`
- exposes a reload button
- exposes a pipeline command block with map/nickname/rank/replay-dir propagation
- shows load status, bundle error text, map name, mine run name, point counts, toggles, and render counters
- shows current Openplanet user name/login
- exposes render sliders for center line width, mine line width, problem marker size, and visible problem zone count
- projects world points through the official Openplanet `Camera` dependency
- renders the `center_line` as a connected in-game overlay line
- can recolor the center line by `speed_delta` from red (mine slower) to green (mine faster)
- renders the `mine_line` as a connected in-game overlay line
- renders `problem_zones` as in-game markers
- lets `Show Center`, `Show Mine`, and `Show Problem Zones` independently control those layers
- keeps `Status`, `Data`, `Pipeline`, `Toggles`, and `Info` as the UI block order

Expected storage location for a relative bundle path:

- `OpenplanetNext/PluginStorage/RacingLine/bundles/<map_uid>/top_1000_1010.analysis_bundle.json`

## Common commands

```powershell
python .\pipeline.py --map "Spring 2026 - 02" --mine "TRAIANUSssS" --range "1000-1010" --replay-input-dir ".\data\raw\replays\2"
```

This runs extraction, analysis, bundle building, and bundle installation. The installed bundle follows this naming convention:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\bundles\Spring 2026 - 02\top_1000_1010.analysis_bundle.json
```

Individual stages can still be run directly:

```powershell
python .\scripts\download_ghosts.py --leaderboard-id "2b5465cd-38a6-4103-b4c9-27f72adceba6" --map-uid "2pYyYky9ccXdTBaaLncWOjFc6jf" --map "Spring 2026 - 02" --range "1000-1010"
.\scripts\extract.ps1 --replay-dir ".\data\raw\replays\2" --output-root ".\data\raw\trajectories" --map "Spring 2026 - 02"
.\scripts\analyze.ps1 --map "Spring 2026 - 02" --mine "TRAIANUSssS" --expected-map-prefix "Spring 2026 - 02" --require-mine
.\scripts\build_bundle.ps1 --map "Spring 2026 - 02" --range "1000-1010"
.\scripts\install_bundle.ps1 -BundlePath ".\data\processed\Spring 2026 - 02\top_1000_1010.analysis_bundle.json" -BundleName "top_1000_1010.analysis_bundle.json"
```

With automatic ghost download:

```powershell
python .\pipeline.py --map "Spring 2026 - 02" --mine "TRAIANUSssS" --range "1000-1010" --download-ghosts --leaderboard-id "2b5465cd-38a6-4103-b4c9-27f72adceba6" --map-uid "2pYyYky9ccXdTBaaLncWOjFc6jf"
```

This downloads ghosts into:

```text
data/raw/ghosts/Spring 2026 - 02/top_1000_1010/
```

and then runs extraction from that folder.

With a mine replay downloaded by the Openplanet plugin:

```powershell
python .\pipeline.py --map "Spring 2026 - 02" --mine "TRAIANUSssS" --range "1000-1010" --download-ghosts --leaderboard-id "2b5465cd-38a6-4103-b4c9-27f72adceba6" --map-uid "2pYyYky9ccXdTBaaLncWOjFc6jf" --include-mine-replay
```

By default, `--include-mine-replay` reads:

```text
C:\Users\<user>\OpenplanetNext\PluginStorage\RacingLine\tmp\<map>\mine.Replay.Gbx
```

The path can be overridden with:

```powershell
--mine-replay-path "C:\path\to\mine.Replay.Gbx"
```

When a separate mine replay is included, `pipeline.py` creates a temporary combined input folder in `data/temp/pipeline_inputs/<map>/top_<range>/`, copies the leaderboard ghosts and mine replay there, and extracts from that combined folder. The copied mine replay is renamed with the `--mine` value so the analyzer can find `mine_line`.

Replay extraction scans only the selected replay directory by default. Nested map folders such as `data/raw/replays/1` or `data/raw/replays/9` are not scanned when the selected input directory is `data/raw/replays`. Use `--recursive-replays` on `pipeline.py` or `--recursive` on `extract.ps1` only when nested scanning is explicitly wanted.

Before extraction, `pipeline.py` removes old trajectory JSON files from `data/raw/trajectories/<map>/` unless `--keep-old-trajectories` is passed. Plot files are not generated in the normal pipeline flow. Pass `--write-plots` for developer/debug plots; when plots are enabled, old plot files from `output/plots/<map>/` are removed unless `--keep-old-plots` is passed.

## Planned automation

The first automation stage is implemented:

- `pipeline.py` is the unified entry point
- map, player identity, replay input directory, bundle filename, and rank range are CLI parameters
- bundle installation is automatic unless `--skip-install` is passed
- stale trajectory outputs are cleaned automatically unless `--keep-old-trajectories` is passed
- plot generation is disabled by default; `--write-plots` enables developer/debug plot outputs
- pipeline analysis requires the mine trajectory by default; use `--allow-missing-mine` only for center-only bundles
- the C# extractor searches all `EntList` entries and uses the best vehicle sample stream, which handles replay files where trajectory samples are not in `EntList[0]`

The Openplanet command handoff stage is implemented:

- the UI generates a PowerShell command for `pipeline.py`
- the generated command includes current map, current display nickname, selected rank range, and replay input directory
- the UI can copy the command to the clipboard
- the command still runs in an external terminal; Openplanet does not execute the pipeline
- the dev Pipeline block can add `--write-plots`; compact user commands do not generate plots
- rank range fields are clamped to rank values of at least `1` and a maximum span of `20`
- no upper leaderboard limit is enforced yet; this should later come from leaderboard metadata

The current pipeline cache behavior is:

- downloaded ghosts are reused unless `--force-download-ghosts` or `--force` is passed
- stale `.Ghost.Gbx` files in a downloaded range folder are removed when they are no longer present in the latest Trackmania.io manifest
- `pipeline.py` stores a SHA-256 input manifest and analysis settings under `data/temp/pipeline_cache/<map>/top_<range>.json`
- when replay/ghost inputs are unchanged and the derived bundle exists, extraction, analysis, and bundle building are skipped
- when only some inputs changed, only changed/new inputs are extracted, then analysis and bundle building rerun
- when inputs were removed, stale cached trajectory JSON files from the previous manifest are removed before analysis
- `--force` bypasses the pipeline cache, forces ghost redownload when ghost downloading is enabled, and rebuilds all outputs
- `--disable-cache` restores the legacy full extraction/rebuild behavior without using the input hash cache

The current sample-count behavior is:

- manual mode uses `--sample-mode manual --samples <count>`
- auto mode uses `--sample-mode auto`
- auto mode estimates median trajectory duration from extracted JSON `t` values
- auto mode uses `10` samples per second by default, so a 47-second map gets about `470` analysis samples
- the Openplanet generated command exposes both modes through an `Auto samples` checkbox and a manual `Sample points` slider

Current stability status:

- the end-to-end MVP flow has been verified from replay/ghost input through bundle installation and in-game visualization
- multiple maps can be handled through per-map bundle folders
- multiple leaderboard ranges can be handled through named bundles and Openplanet bundle selection
- future testing should focus on regressions, unusual maps, missing/partial inputs, and distribution packaging

## Default paths

- Raw replays: `data/raw/replays`
- Raw ghosts: `data/raw/ghosts`
- Raw trajectories: `data/raw/trajectories`
- Processed analysis: `data/processed`
- Plots: `output/plots`
- Reports: `output/reports`
- Temporary/debug files: `data/temp`
