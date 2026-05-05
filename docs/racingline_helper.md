# RacingLine Local Helper

`scripts/racingline_helper.py` watches Openplanet plugin storage for downloaded leaderboard replay folders and runs the existing local pipeline automatically.

## Flow

1. Openplanet downloads records into:

```text
OpenplanetNext/PluginStorage/RacingLine/downloads/<map_uid>/top_<from>_<to>/
```

2. The helper detects the stable folder and runs:

```text
pipeline.py -> C# extractor -> Python analyzer -> bundle builder -> bundle install
```

3. The bundle is written to:

```text
OpenplanetNext/PluginStorage/RacingLine/bundles/<map_uid>/top_<from>_<to>.analysis_bundle.json
```

4. Openplanet auto-refreshes bundle files and can load the new bundle.

## Run

From the repository root:

```powershell
python .\scripts\racingline_helper.py
```

Useful development options:

```powershell
python .\scripts\racingline_helper.py --once
python .\scripts\racingline_helper.py --force --once
```

## Status Files

The helper writes task status JSON for the Openplanet UI:

```text
PluginStorage/RacingLine/tasks/running/task_<map_uid>_top_<from>_<to>.json
PluginStorage/RacingLine/tasks/done/task_<map_uid>_top_<from>_<to>.json
PluginStorage/RacingLine/logs/task_<map_uid>_top_<from>_<to>.log
```

The status JSON includes `status`, `map_uid`, `map_name`, `range`, `progress`, `error`, `bundle_path`, and `log_path`.

## Notes

- Openplanet does not run external processes.
- The helper does not download network data; it only consumes local files written by Openplanet.
- GBX parsing remains in the existing C# extractor through GBX.NET.
