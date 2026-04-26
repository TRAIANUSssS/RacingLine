from __future__ import annotations

import argparse
import math
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent
RAW_REPLAYS_DIR = PROJECT_ROOT / "data" / "raw" / "replays"
RAW_GHOSTS_DIR = PROJECT_ROOT / "data" / "raw" / "ghosts"
RAW_TRAJECTORIES_DIR = PROJECT_ROOT / "data" / "raw" / "trajectories"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
PLOTS_DIR = PROJECT_ROOT / "output" / "plots"
TEMP_DIR = PROJECT_ROOT / "data" / "temp"
EXTRACTOR_PROJECT = PROJECT_ROOT / "src" / "extractor-csharp" / "RacingLine.csproj"
TRAJECTORY_SCRIPT = PROJECT_ROOT / "src" / "analyzer-python" / "trajectory.py"
BUNDLE_BUILDER_SCRIPT = PROJECT_ROOT / "src" / "analyzer-python" / "bundle_builder.py"
GHOST_DOWNLOADER_SCRIPT = PROJECT_ROOT / "scripts" / "download_ghosts.py"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run RacingLine extraction, analysis, bundle build, and install.")
    parser.add_argument("--map", required=True, dest="map_name", help="Map name / folder name.")
    parser.add_argument("--mine", required=True, help="Player login or nickname to use as mine_line.")
    parser.add_argument("--range", required=True, dest="rank_range", help="Leaderboard rank range, e.g. 1000-1010.")
    parser.add_argument(
        "--replay-input-dir",
        type=Path,
        default=None,
        help="Directory containing .Replay.Gbx or .Ghost.Gbx files. Defaults to data/raw/replays/<map> if it exists.",
    )
    parser.add_argument("--download-ghosts", action="store_true", help="Download Trackmania.io ghosts before extraction.")
    parser.add_argument("--leaderboard-id", default=None, help="Trackmania.io leaderboard/campaign id for --download-ghosts.")
    parser.add_argument("--map-uid", default=None, help="Trackmania map UID for --download-ghosts.")
    parser.add_argument(
        "--ghost-output-root",
        type=Path,
        default=RAW_GHOSTS_DIR,
        help="Root directory for downloaded ghosts.",
    )
    parser.add_argument(
        "--ghost-output-dir",
        type=Path,
        default=None,
        help="Exact directory for downloaded ghosts. Overrides --ghost-output-root/<map>/top_<range>.",
    )
    parser.add_argument("--force-download-ghosts", action="store_true", help="Redownload ghosts that already exist.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignore pipeline cache, redownload ghosts when enabled, re-extract inputs, rerun analysis, and rebuild the bundle.",
    )
    parser.add_argument("--disable-cache", action="store_true", help="Disable input hash cache and use the legacy full rebuild flow.")
    parser.add_argument(
        "--include-mine-replay",
        action="store_true",
        help="Add a separately downloaded mine .Replay.Gbx file to the extraction input.",
    )
    parser.add_argument(
        "--mine-replay-path",
        type=Path,
        default=None,
        help="Path to the mine .Replay.Gbx file. Defaults to Openplanet PluginStorage/RacingLine/tmp/<map>/mine.Replay.Gbx.",
    )
    parser.add_argument(
        "--trajectory-output-root",
        type=Path,
        default=RAW_TRAJECTORIES_DIR,
        help="Root directory for extracted trajectory JSON.",
    )
    parser.add_argument(
        "--bundle-name",
        default=None,
        help="Output bundle filename. Defaults to top_<range>.analysis_bundle.json.",
    )
    parser.add_argument(
        "--storage-root",
        type=Path,
        default=Path.home() / "OpenplanetNext" / "PluginStorage" / "RacingLine",
        help="Openplanet RacingLine plugin storage root.",
    )
    parser.add_argument(
        "--sample-mode",
        choices=("manual", "auto"),
        default="manual",
        help="Use a fixed sample count or derive it from trajectory duration.",
    )
    parser.add_argument("--samples", type=int, default=300, help="Manual analysis sample count.")
    parser.add_argument(
        "--auto-samples-per-second",
        type=float,
        default=10.0,
        help="Auto sample density. Used only with --sample-mode auto.",
    )
    parser.add_argument("--skip-extract", action="store_true", help="Skip replay extraction.")
    parser.add_argument("--skip-plots", action="store_true", help="Skip plot outputs during analysis.")
    parser.add_argument("--skip-install", action="store_true", help="Build bundle but do not copy it to Openplanet storage.")
    parser.add_argument("--recursive-replays", action="store_true", help="Include replay files from nested directories.")
    parser.add_argument("--allow-missing-mine", action="store_true", help="Allow building a center-only bundle if mine replay is missing.")
    parser.add_argument(
        "--keep-old-trajectories",
        action="store_true",
        help="Do not remove existing trajectory JSON files from the selected map output folder before extraction.",
    )
    parser.add_argument(
        "--keep-old-plots",
        action="store_true",
        help="Do not remove existing plot files from the selected map output folder before analysis.",
    )
    args = parser.parse_args()
    if args.force:
        args.force_download_ghosts = True

    replay_input_dir = args.replay_input_dir or _default_replay_input_dir(args.map_name)
    bundle_name = args.bundle_name or f"top_{_normalize_range(args.rank_range)}.analysis_bundle.json"
    ghost_output_dir = args.ghost_output_dir or args.ghost_output_root / _sanitize_path_part(args.map_name) / f"top_{_normalize_range(args.rank_range)}"
    trajectory_source_dir = args.trajectory_output_root / args.map_name
    analysis_json = PROCESSED_DIR / args.map_name / "analysis_data.json"
    bundle_path = PROCESSED_DIR / args.map_name / bundle_name
    plot_output_dir = PLOTS_DIR / args.map_name
    cache_manifest_path = _cache_manifest_path(args.map_name, args.rank_range)
    cache_enabled = not args.disable_cache and not args.skip_extract
    cache_skipped_build = False
    analysis_samples: int | None = resolve_analysis_sample_count(args, trajectory_source_dir, required=False)
    cache_settings = build_cache_settings(args, analysis_samples)

    if args.download_ghosts:
        if not args.leaderboard_id:
            raise ValueError("--leaderboard-id is required with --download-ghosts.")
        if not args.map_uid:
            raise ValueError("--map-uid is required with --download-ghosts.")

        download_cmd = [
            sys.executable,
            str(GHOST_DOWNLOADER_SCRIPT),
            "--leaderboard-id",
            args.leaderboard_id,
            "--map-uid",
            args.map_uid,
            "--map",
            args.map_name,
            "--range",
            args.rank_range,
            "--output-dir",
            str(ghost_output_dir),
        ]
        if args.force_download_ghosts:
            download_cmd.append("--force")
        _run(download_cmd)
        replay_input_dir = ghost_output_dir

    if args.include_mine_replay:
        mine_replay_path = args.mine_replay_path or _default_mine_replay_path(args.storage_root, args.map_name)
        replay_input_dir = prepare_combined_replay_input_dir(
            replay_input_dir=replay_input_dir,
            mine_replay_path=mine_replay_path,
            map_name=args.map_name,
            mine_name=args.mine,
            rank_range=args.rank_range,
            recursive=args.recursive_replays,
        )

    current_inputs: list[dict[str, Any]] = []
    previous_manifest: dict[str, Any] | None = None
    changed_inputs: list[dict[str, Any]] | None = None
    extraction_input_dir = replay_input_dir
    extraction_recursive = args.recursive_replays

    if cache_enabled:
        current_inputs = build_input_manifest_entries(replay_input_dir, args.recursive_replays, args.map_name, trajectory_source_dir)
        previous_manifest = load_cache_manifest(cache_manifest_path)
        cache_state = evaluate_cache_state(
            previous_manifest=previous_manifest,
            current_inputs=current_inputs,
            current_settings=cache_settings,
            trajectory_source_dir=trajectory_source_dir,
            analysis_json=analysis_json,
            bundle_path=bundle_path,
            map_name=args.map_name,
        )

        if cache_state["complete"] and not args.force:
            print("Pipeline cache hit: replay/ghost inputs unchanged; skipping extraction, analysis, and bundle rebuild.", flush=True)
            cache_skipped_build = True
        elif not args.force and cache_state["can_extract_partial"]:
            changed_inputs = cache_state["changed_inputs"]
            remove_stale_cached_trajectories(previous_manifest, current_inputs)
            if len(changed_inputs) == 0:
                print("Pipeline cache: inputs unchanged but derived outputs are missing; reusing trajectories and rebuilding analysis/bundle.", flush=True)
                args.skip_extract = True
            else:
                extraction_input_dir = prepare_cached_extraction_input_dir(changed_inputs, args.map_name, args.rank_range)
                extraction_recursive = False
                print(
                    f"Pipeline cache: extracting {len(changed_inputs)} changed/new input(s); "
                    f"reusing {len(current_inputs) - len(changed_inputs)} cached trajectory file(s).",
                    flush=True,
                )
        elif args.force:
            print("Pipeline cache bypassed by --force; rebuilding all pipeline outputs.", flush=True)

    if cache_skipped_build:
        if not args.skip_install:
            installed_path = install_bundle(bundle_path, args.storage_root, args.map_name, bundle_name)
            print(f"Installed: {installed_path}")
        return

    if not args.skip_extract:
        if not args.keep_old_trajectories and (not cache_enabled or args.force or changed_inputs is None):
            clean_trajectory_dir(trajectory_source_dir)

        extract_cmd = [
            "dotnet",
            "run",
            "--project",
            str(EXTRACTOR_PROJECT),
            "--",
            "--replay-dir",
            str(extraction_input_dir),
            "--output-root",
            str(args.trajectory_output_root),
            "--map",
            args.map_name,
        ]
        if extraction_recursive:
            extract_cmd.append("--recursive")
        _run(extract_cmd)

    analysis_samples = resolve_analysis_sample_count(args, trajectory_source_dir, required=True)
    cache_settings = build_cache_settings(args, analysis_samples)

    if not args.skip_plots and not args.keep_old_plots:
        clean_plot_dir(plot_output_dir)

    analyze_cmd = [
        sys.executable,
        str(TRAJECTORY_SCRIPT),
        "--source-dir",
        str(trajectory_source_dir),
        "--mine",
        args.mine,
        "--expected-map-prefix",
        args.map_name,
        "--samples",
        str(analysis_samples),
    ]
    if args.skip_plots:
        analyze_cmd.append("--skip-plots")
    if not args.allow_missing_mine:
        analyze_cmd.append("--require-mine")
    _run(analyze_cmd)

    _run(
        [
            sys.executable,
            str(BUNDLE_BUILDER_SCRIPT),
            "--analysis-json",
            str(analysis_json),
            "--output",
            str(bundle_path),
            "--range",
            args.rank_range,
        ]
    )

    if cache_enabled:
        save_cache_manifest(
            cache_manifest_path,
            map_name=args.map_name,
            rank_range=args.rank_range,
            inputs=current_inputs,
            settings=cache_settings,
            analysis_json=analysis_json,
            bundle_path=bundle_path,
        )

    if not args.skip_install:
        installed_path = install_bundle(bundle_path, args.storage_root, args.map_name, bundle_name)
        print(f"Installed: {installed_path}")


def install_bundle(bundle_path: Path, storage_root: Path, map_name: str, bundle_name: str) -> Path:
    if not bundle_path.exists():
        raise FileNotFoundError(f"Bundle file not found: {bundle_path}")

    target_dir = storage_root / "bundles" / _sanitize_path_part(map_name)
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / bundle_name
    shutil.copy2(bundle_path, target_path)
    return target_path


def build_cache_settings(args: argparse.Namespace, analysis_samples: int | None) -> dict[str, Any]:
    return {
        "map_name": args.map_name,
        "rank_range": args.rank_range,
        "mine": args.mine,
        "sample_mode": args.sample_mode,
        "manual_samples": args.samples,
        "auto_samples_per_second": args.auto_samples_per_second,
        "resolved_samples": analysis_samples,
        "allow_missing_mine": args.allow_missing_mine,
        "bundle_contract_version": 3,
    }


def resolve_analysis_sample_count(args: argparse.Namespace, trajectory_source_dir: Path, required: bool) -> int | None:
    if args.sample_mode == "manual":
        return max(2, int(args.samples))

    try:
        duration_seconds = estimate_trajectory_duration_seconds(trajectory_source_dir)
    except FileNotFoundError:
        if required:
            raise
        return None

    samples = int(math.ceil(duration_seconds * args.auto_samples_per_second))
    samples = max(2, samples)
    if required:
        print(
            f"Auto samples: duration={duration_seconds:.2f}s density={args.auto_samples_per_second:g}/s samples={samples}",
            flush=True,
        )
    return samples


def estimate_trajectory_duration_seconds(trajectory_source_dir: Path) -> float:
    if not trajectory_source_dir.exists() or not trajectory_source_dir.is_dir():
        raise FileNotFoundError(f"Trajectory source directory not found: {trajectory_source_dir}")

    durations: list[float] = []
    for path in sorted(trajectory_source_dir.glob("*.json")):
        if not path.is_file():
            continue

        duration_ms = read_trajectory_duration_ms(path)
        if duration_ms is not None and duration_ms > 0:
            durations.append(duration_ms)

    if not durations:
        raise FileNotFoundError(f"No trajectory JSON files with valid time values found in: {trajectory_source_dir}")

    durations.sort()
    median_duration_ms = durations[len(durations) // 2]
    return median_duration_ms / 1000.0


def read_trajectory_duration_ms(path: Path) -> float | None:
    try:
        points = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    if not isinstance(points, list):
        return None

    times: list[float] = []
    for point in points:
        if not isinstance(point, dict) or point.get("t") is None:
            continue
        try:
            times.append(float(point["t"]))
        except (TypeError, ValueError):
            continue

    if not times:
        return None
    return max(times) - min(times)


def build_input_manifest_entries(input_dir: Path, recursive: bool, map_name: str, trajectory_source_dir: Path) -> list[dict[str, Any]]:
    if not input_dir.exists() or not input_dir.is_dir():
        raise FileNotFoundError(f"Replay/ghost input directory not found: {input_dir}")

    entries: list[dict[str, Any]] = []
    for path in iter_replay_input_files(input_dir, recursive):
        resolved = path.resolve()
        entries.append(
            {
                "name": path.name,
                "path": str(resolved),
                "sha256": hash_file(resolved),
                "size": resolved.stat().st_size,
                "trajectory_path": str(expected_trajectory_path(trajectory_source_dir, map_name, path.name)),
            }
        )

    entries.sort(key=lambda entry: entry["name"].lower())
    if not entries:
        raise FileNotFoundError(f"No replay or ghost files found in: {input_dir}")
    return entries


def evaluate_cache_state(
    previous_manifest: dict[str, Any] | None,
    current_inputs: list[dict[str, Any]],
    current_settings: dict[str, Any],
    trajectory_source_dir: Path,
    analysis_json: Path,
    bundle_path: Path,
    map_name: str,
) -> dict[str, Any]:
    if previous_manifest is None:
        return {"complete": False, "can_extract_partial": False, "changed_inputs": current_inputs}
    settings_unchanged = previous_manifest.get("settings") == current_settings

    previous_inputs = previous_manifest.get("inputs")
    if not isinstance(previous_inputs, list):
        return {"complete": False, "can_extract_partial": False, "changed_inputs": current_inputs}

    previous_by_name = {
        str(entry.get("name")): entry
        for entry in previous_inputs
        if isinstance(entry, dict) and entry.get("name") is not None
    }
    current_by_name = {str(entry["name"]): entry for entry in current_inputs}

    changed_inputs: list[dict[str, Any]] = []
    for current in current_inputs:
        previous = previous_by_name.get(str(current["name"]))
        trajectory_path = Path(str(current["trajectory_path"]))
        if (
            previous is None
            or previous.get("sha256") != current["sha256"]
            or previous.get("size") != current["size"]
            or not trajectory_path.exists()
        ):
            changed_inputs.append(current)

    removed_names = set(previous_by_name.keys()) - set(current_by_name.keys())
    derived_outputs_exist = analysis_json.exists() and bundle_path.exists()
    all_trajectories_exist = all(Path(str(entry["trajectory_path"])).exists() for entry in current_inputs)
    unchanged = settings_unchanged and len(changed_inputs) == 0 and len(removed_names) == 0

    return {
        "complete": unchanged and all_trajectories_exist and derived_outputs_exist,
        "can_extract_partial": True,
        "changed_inputs": changed_inputs,
    }


def remove_stale_cached_trajectories(previous_manifest: dict[str, Any] | None, current_inputs: list[dict[str, Any]]) -> None:
    if previous_manifest is None:
        return

    previous_inputs = previous_manifest.get("inputs")
    if not isinstance(previous_inputs, list):
        return

    current_names = {str(entry["name"]) for entry in current_inputs}
    removed_count = 0
    for previous in previous_inputs:
        if not isinstance(previous, dict) or str(previous.get("name")) in current_names:
            continue

        trajectory_value = previous.get("trajectory_path")
        if not isinstance(trajectory_value, str):
            continue

        trajectory_path = Path(trajectory_value)
        if trajectory_path.exists() and trajectory_path.is_file():
            trajectory_path.unlink()
            removed_count += 1

    if removed_count > 0:
        print(f"Pipeline cache: removed {removed_count} stale trajectory file(s).", flush=True)


def prepare_cached_extraction_input_dir(changed_inputs: list[dict[str, Any]], map_name: str, rank_range: str) -> Path:
    input_dir = TEMP_DIR / "pipeline_cache_inputs" / _sanitize_path_part(map_name) / f"top_{_normalize_range(rank_range)}"
    clean_directory(input_dir)
    input_dir.mkdir(parents=True, exist_ok=True)

    for entry in changed_inputs:
        source = Path(str(entry["path"]))
        shutil.copy2(source, input_dir / str(entry["name"]))

    return input_dir


def load_cache_manifest(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def save_cache_manifest(
    path: Path,
    map_name: str,
    rank_range: str,
    inputs: list[dict[str, Any]],
    settings: dict[str, Any],
    analysis_json: Path,
    bundle_path: Path,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "racingline.pipeline_cache.v1",
        "map_name": map_name,
        "rank_range": rank_range,
        "settings": settings,
        "inputs": inputs,
        "analysis_json": str(analysis_json),
        "bundle_path": str(bundle_path),
    }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Pipeline cache manifest: {path}", flush=True)


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_trajectory_path(trajectory_source_dir: Path, map_name: str, input_file_name: str) -> Path:
    input_stem = Path(input_file_name).stem
    prefix = f"{map_name}_"
    output_stem = input_stem if input_stem.lower().startswith(prefix.lower()) else f"{prefix}{input_stem}"
    return trajectory_source_dir / f"{output_stem}.trajectory.json"


def _cache_manifest_path(map_name: str, rank_range: str) -> Path:
    return TEMP_DIR / "pipeline_cache" / _sanitize_path_part(map_name) / f"top_{_normalize_range(rank_range)}.json"


def clean_trajectory_dir(trajectory_source_dir: Path) -> None:
    if not trajectory_source_dir.exists():
        return

    removed_count = 0
    for path in trajectory_source_dir.glob("*.json"):
        if path.is_file():
            path.unlink()
            removed_count += 1

    if removed_count > 0:
        print(f"Removed old trajectory JSON files: {removed_count} from {trajectory_source_dir}", flush=True)


def clean_plot_dir(plot_output_dir: Path) -> None:
    if not plot_output_dir.exists():
        return

    removed_count = 0
    for pattern in ("*.png", "*.json", "*.csv"):
        for path in plot_output_dir.glob(pattern):
            if path.is_file():
                path.unlink()
                removed_count += 1

    if removed_count > 0:
        print(f"Removed old plot files: {removed_count} from {plot_output_dir}", flush=True)


def prepare_combined_replay_input_dir(
    replay_input_dir: Path,
    mine_replay_path: Path,
    map_name: str,
    mine_name: str,
    rank_range: str,
    recursive: bool,
) -> Path:
    replay_input_dir = replay_input_dir.resolve()
    mine_replay_path = mine_replay_path.resolve()
    if not replay_input_dir.exists() or not replay_input_dir.is_dir():
        raise FileNotFoundError(f"Replay/ghost input directory not found: {replay_input_dir}")
    if not mine_replay_path.exists() or not mine_replay_path.is_file():
        raise FileNotFoundError(f"Mine replay file not found: {mine_replay_path}")

    combined_dir = TEMP_DIR / "pipeline_inputs" / _sanitize_path_part(map_name) / f"top_{_normalize_range(rank_range)}"
    clean_directory(combined_dir)
    combined_dir.mkdir(parents=True, exist_ok=True)

    copied_count = 0
    for source_path in iter_replay_input_files(replay_input_dir, recursive):
        shutil.copy2(source_path, combined_dir / source_path.name)
        copied_count += 1

    mine_file_name = f"{_sanitize_path_part(mine_name)}_mine.Replay.Gbx"
    shutil.copy2(mine_replay_path, combined_dir / mine_file_name)
    print(f"Prepared combined input: {combined_dir} ({copied_count} leaderboard files + mine replay)", flush=True)
    return combined_dir


def iter_replay_input_files(input_dir: Path, recursive: bool):
    patterns = ("*.Replay.Gbx", "*.Ghost.Gbx")
    seen: set[Path] = set()
    for pattern in patterns:
        iterator = input_dir.rglob(pattern) if recursive else input_dir.glob(pattern)
        for path in iterator:
            if path.is_file() and path not in seen:
                seen.add(path)
                yield path


def clean_directory(path: Path) -> None:
    resolved = path.resolve()
    temp_root = TEMP_DIR.resolve()
    if not str(resolved).lower().startswith(str(temp_root).lower()):
        raise ValueError(f"Refusing to clean directory outside temp root: {resolved}")
    if path.exists():
        shutil.rmtree(path)


def _default_replay_input_dir(map_name: str) -> Path:
    map_dir = RAW_REPLAYS_DIR / map_name
    return map_dir if map_dir.exists() else RAW_REPLAYS_DIR


def _default_mine_replay_path(storage_root: Path, map_name: str) -> Path:
    return storage_root / "tmp" / _sanitize_path_part(map_name) / "mine.Replay.Gbx"


def _run(command: list[str]) -> None:
    print(f"Running: {subprocess.list2cmdline(command)}", flush=True)
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def _normalize_range(rank_range: str) -> str:
    return rank_range.strip().replace("-", "_")


def _sanitize_path_part(value: str) -> str:
    invalid_chars = '<>:"/\\|?*'
    sanitized = "".join("_" if char in invalid_chars or ord(char) < 32 else char for char in value).strip()
    return sanitized or "unknown_map"


if __name__ == "__main__":
    main()
