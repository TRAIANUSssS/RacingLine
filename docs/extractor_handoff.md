# Extractor Handoff

Location: `src/extractor-csharp`

## Purpose

The extractor parses Trackmania replay files and exports raw trajectory JSON for later analytics.

## Current behavior

- Parses `.Replay.Gbx` files with GBX.NET
- Reads ghost data from replay nodes
- Extracts vehicle samples from the best available `RecordData -> EntList[*].Samples` entry
- Exports `t/x/y/z/speed`
- Groups outputs by map name
- Scans only the selected replay directory by default
- Scans nested replay folders only when `--recursive` is passed

## Inputs

- `data/raw/replays`
- or a specific map/rank folder such as `data/raw/replays/2`

Nested folders are allowed, but they are ignored unless recursive scanning is explicitly enabled.

## Outputs

- `data/raw/trajectories/<map-name>/...trajectory.json`

Example point:

```json
{ "t": 123.0, "x": 1072.0, "y": 2.002, "z": 656.00006, "speed": 40.7 }
```

## Run

```powershell
dotnet run --project .\src\extractor-csharp\RacingLine.csproj
```

For a specific replay folder and forced map output folder:

```powershell
dotnet run --project .\src\extractor-csharp\RacingLine.csproj -- --replay-dir ".\data\raw\replays\2" --output-root ".\data\raw\trajectories" --map "Spring 2026 - 02"
```

Or through the helper script:

```powershell
.\scripts\extract.ps1
.\scripts\extract.ps1 --replay-dir ".\data\raw\replays\2" --output-root ".\data\raw\trajectories" --map "Spring 2026 - 02"
```

Use `--recursive` only when replay files should be read from nested directories too.

## Important notes

- raw replay and raw trajectory files are meant to be preserved
- this layer is intentionally separate from Openplanet
- no heavy analytics should move here
