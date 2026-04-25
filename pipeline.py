from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


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
    parser.add_argument("--samples", type=int, default=300, help="Analysis sample count.")
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

    replay_input_dir = args.replay_input_dir or _default_replay_input_dir(args.map_name)
    bundle_name = args.bundle_name or f"top_{_normalize_range(args.rank_range)}.analysis_bundle.json"
    ghost_output_dir = args.ghost_output_dir or args.ghost_output_root / _sanitize_path_part(args.map_name) / f"top_{_normalize_range(args.rank_range)}"
    trajectory_source_dir = args.trajectory_output_root / args.map_name
    analysis_json = PROCESSED_DIR / args.map_name / "analysis_data.json"
    bundle_path = PROCESSED_DIR / args.map_name / bundle_name
    plot_output_dir = PLOTS_DIR / args.map_name

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

    if not args.skip_extract:
        if not args.keep_old_trajectories:
            clean_trajectory_dir(trajectory_source_dir)

        extract_cmd = [
            "dotnet",
            "run",
            "--project",
            str(EXTRACTOR_PROJECT),
            "--",
            "--replay-dir",
            str(replay_input_dir),
            "--output-root",
            str(args.trajectory_output_root),
            "--map",
            args.map_name,
        ]
        if args.recursive_replays:
            extract_cmd.append("--recursive")
        _run(extract_cmd)

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
        str(args.samples),
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
