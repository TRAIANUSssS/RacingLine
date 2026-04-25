from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

from .analysis import analyze_source_dir
from .io_utils import (
    export_analysis_data,
    export_center_trajectory,
    resolve_plot_output_dir,
    resolve_processed_output_dir,
    save_problem_zones_csv,
    save_problem_zones_json,
)
from .paths import DEFAULT_HIGHLIGHT_NICKNAME, DEFAULT_SOURCE_DIR
from .plotting import (
    plot_center_speed,
    plot_deviation,
    plot_importance,
    plot_overlay_with_center,
    plot_problem_zone_zoom,
    plot_single_trajectory,
    plot_speed_delta,
    plot_spread,
)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Batch trajectory analysis: plots, center line, spread, problem zones, and processed JSON."
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=DEFAULT_SOURCE_DIR,
        help="Directory with trajectory JSON files.",
    )
    parser.add_argument(
        "--highlight-nickname",
        default=DEFAULT_HIGHLIGHT_NICKNAME,
        help="Name fragment used to identify the user's trajectory.",
    )
    parser.add_argument(
        "--exclude-center-nickname",
        default=DEFAULT_HIGHLIGHT_NICKNAME,
        help="Name fragment excluded from center/spread computation.",
    )
    parser.add_argument(
        "--samples",
        type=int,
        default=300,
        help="Number of normalized-progress samples for center/deviation analysis.",
    )
    parser.add_argument("--skip-plots", action="store_true", help="Do not write PNG/CSV plot outputs.")
    parser.add_argument("--skip-processed", action="store_true", help="Do not write processed analysis JSON.")
    args = parser.parse_args()

    common_progress = np.linspace(0.0, 1.0, args.samples)
    result = analyze_source_dir(
        source_dir=args.source_dir,
        highlight_nickname=args.highlight_nickname,
        common_progress=common_progress,
        exclude_center_nickname=args.exclude_center_nickname,
    )

    if not args.skip_plots:
        write_plot_outputs(result)

    if not args.skip_processed:
        processed_dir = resolve_processed_output_dir(result.source_dir)
        analysis_data_path = processed_dir / "analysis_data.json"
        export_analysis_data(analysis_data_path, result)
        print(f"Saved: {analysis_data_path}")


def write_plot_outputs(result) -> None:
    output_dir = resolve_plot_output_dir(result.source_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for trajectory in result.raw_trajectories:
        single_output = output_dir / f"{trajectory.name}.png"
        plot_single_trajectory(
            x=trajectory.x,
            z=trajectory.z,
            speed=trajectory.speed,
            output_path=single_output,
            title=f"{trajectory.name}: -X vs Z",
        )
        print(f"Saved: {single_output}")

    overlay_center_path = output_dir / "overlay_center.png"
    plot_overlay_with_center(
        raw_series=result.raw_trajectories,
        center_x=result.center_x,
        center_z=result.center_z,
        mine_series=result.mine_raw,
        output_path=overlay_center_path,
    )
    print(f"Saved: {overlay_center_path}")

    center_speed_path = output_dir / "center_speed.png"
    plot_center_speed(
        center_x=result.center_x,
        center_z=result.center_z,
        center_speed=result.center_speed,
        output_path=center_speed_path,
    )
    print(f"Saved: {center_speed_path}")

    spread_path = output_dir / "spread_by_progress.png"
    plot_spread(common_progress=result.common_progress, spread=result.spread, output_path=spread_path)
    print(f"Saved: {spread_path}")

    center_json_path = output_dir / "center_trajectory.json"
    export_center_trajectory(
        output_path=center_json_path,
        common_progress=result.common_progress,
        center_x=result.center_x,
        center_y=result.center_y,
        center_z=result.center_z,
        center_speed=result.center_speed,
        spread=result.spread,
    )
    print(f"Saved: {center_json_path}")

    if result.mine_resampled is None or result.deviation is None or result.importance is None:
        print("Highlighted trajectory not found, mine_deviation/importance/problem zones are skipped.")
        return

    deviation_path = output_dir / "mine_deviation.png"
    plot_deviation(
        common_progress=result.common_progress,
        deviation=result.deviation,
        output_path=deviation_path,
    )
    print(f"Saved: {deviation_path}")

    importance_path = output_dir / "importance_by_progress.png"
    plot_importance(
        common_progress=result.common_progress,
        importance=result.importance,
        peak_rows=result.problem_zones,
        output_path=importance_path,
    )
    print(f"Saved: {importance_path}")

    problem_json_path = output_dir / "problem_zones.json"
    problem_csv_path = output_dir / "problem_zones.csv"
    save_problem_zones_json(problem_json_path, result.problem_zones)
    save_problem_zones_csv(problem_csv_path, result.problem_zones)
    print(f"Saved: {problem_json_path}")
    print(f"Saved: {problem_csv_path}")

    for row in result.problem_zones:
        rank = int(row["rank"])
        progress = float(row["progress"])
        zoom_path = output_dir / f"problem_zone_{rank:02d}.png"
        plot_problem_zone_zoom(
            rank=rank,
            peak_progress=progress,
            common_progress=result.common_progress,
            resampled_items=result.resampled_trajectories,
            center_x=result.center_x,
            center_z=result.center_z,
            mine_resampled=result.mine_resampled,
            output_path=zoom_path,
        )
        print(f"Saved: {zoom_path}")

    if result.speed_delta is not None:
        speed_delta_path = output_dir / "speed_delta_by_progress.png"
        plot_speed_delta(result.common_progress, result.speed_delta, speed_delta_path)
        print(f"Saved: {speed_delta_path}")

    print(f"Found {len(result.problem_zones)} problem zones")
    for row in result.problem_zones[:3]:
        print(
            f"#{int(row['rank'])} "
            f"progress={float(row['progress']):.3f} "
            f"importance={float(row['importance']):.2f} "
            f"deviation={float(row['deviation']):.2f} "
            f"spread={float(row['spread']):.2f}"
        )
