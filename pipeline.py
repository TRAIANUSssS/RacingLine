from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
RAW_REPLAYS_DIR = PROJECT_ROOT / "data" / "raw" / "replays"
RAW_TRAJECTORIES_DIR = PROJECT_ROOT / "data" / "raw" / "trajectories"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
PLOTS_DIR = PROJECT_ROOT / "output" / "plots"
EXTRACTOR_PROJECT = PROJECT_ROOT / "src" / "extractor-csharp" / "RacingLine.csproj"
TRAJECTORY_SCRIPT = PROJECT_ROOT / "src" / "analyzer-python" / "trajectory.py"
BUNDLE_BUILDER_SCRIPT = PROJECT_ROOT / "src" / "analyzer-python" / "bundle_builder.py"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run RacingLine extraction, analysis, bundle build, and install.")
    parser.add_argument("--map", required=True, dest="map_name", help="Map name / folder name.")
    parser.add_argument("--mine", required=True, help="Player login or nickname to use as mine_line.")
    parser.add_argument("--range", required=True, dest="rank_range", help="Leaderboard rank range, e.g. 1000-1010.")
    parser.add_argument(
        "--replay-input-dir",
        type=Path,
        default=None,
        help="Directory containing .Replay.Gbx files. Defaults to data/raw/replays/<map> if it exists.",
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
    trajectory_source_dir = args.trajectory_output_root / args.map_name
    analysis_json = PROCESSED_DIR / args.map_name / "analysis_data.json"
    bundle_path = PROCESSED_DIR / args.map_name / bundle_name
    plot_output_dir = PLOTS_DIR / args.map_name

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


def _default_replay_input_dir(map_name: str) -> Path:
    map_dir = RAW_REPLAYS_DIR / map_name
    return map_dir if map_dir.exists() else RAW_REPLAYS_DIR


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
