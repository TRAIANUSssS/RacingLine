# Extractor Handoff

Location: `src/extractor-csharp`

## Purpose

The extractor parses Trackmania replay files and exports raw trajectory JSON for later analytics.

## Current behavior

- Parses `.Replay.Gbx` files with GBX.NET
- Reads ghost data from replay nodes
- Extracts samples from `RecordData -> EntList[0].Samples`
- Exports `t/x/y/z/speed`
- Groups outputs by map name
- Scans replay folders recursively

## Inputs

- `data/raw/replays`

Nested folders are allowed.

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

Or through the helper script:

```powershell
.\scripts\extract.ps1
```

## Important notes

- raw replay and raw trajectory files are meant to be preserved
- this layer is intentionally separate from Openplanet
- no heavy analytics should move here

