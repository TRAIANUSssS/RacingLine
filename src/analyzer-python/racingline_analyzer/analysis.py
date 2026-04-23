from __future__ import annotations

from pathlib import Path

import numpy as np

from .geometry import build_center_trajectory, compute_progress, extract_arrays, resample_trajectory
from .io_utils import collect_json_files, load_trajectory
from .metrics import build_problem_zone_summary, compute_importance, find_problem_peaks
from .models import AnalysisResult, RawTrajectory, ResampledTrajectory


def analyze_source_dir(
    source_dir: Path,
    highlight_nickname: str,
    common_progress: np.ndarray,
    max_problem_zones: int = 5,
    min_peak_distance: int = 12,
) -> AnalysisResult:
    source_dir = source_dir.resolve()
    if not source_dir.exists() or not source_dir.is_dir():
        raise ValueError(f"Source directory does not exist: {source_dir}")

    json_files = collect_json_files(source_dir)
    if not json_files:
        raise ValueError(f"No JSON files found in: {source_dir}")

    raw_trajectories: list[RawTrajectory] = []
    resampled_trajectories: list[ResampledTrajectory] = []
    mine_raw: RawTrajectory | None = None
    mine_resampled: ResampledTrajectory | None = None

    for json_file in json_files:
        name = json_file.stem
        try:
            points = load_trajectory(json_file)
            x, y, z, _t, speed = extract_arrays(points)
            progress = compute_progress(x, z)
            if progress is None:
                print(f"Skipped (too short or zero length): {json_file.name}")
                continue
            x_interp, y_interp, z_interp, speed_interp = resample_trajectory(
                x=x,
                y=y,
                z=z,
                speed=speed,
                progress=progress,
                common_progress=common_progress,
            )
        except Exception as ex:
            print(f"Skipped {json_file.name}: {ex}")
            continue

        raw = RawTrajectory(name=name, x=x, y=y, z=z, speed=speed)
        resampled = ResampledTrajectory(name=name, x=x_interp, y=y_interp, z=z_interp, speed=speed_interp)
        raw_trajectories.append(raw)
        resampled_trajectories.append(resampled)

        if highlight_nickname and highlight_nickname.lower() in name.lower():
            mine_raw = raw
            mine_resampled = resampled

    if len(resampled_trajectories) < 2:
        raise ValueError("Not enough usable trajectories for center/spread analysis (need at least 2).")

    center_x, center_y, center_z, center_speed, spread = build_center_trajectory(resampled_trajectories)

    deviation: np.ndarray | None = None
    importance: np.ndarray | None = None
    speed_delta: np.ndarray | None = None
    problem_zones: list[dict[str, float | int | None]] = []

    if mine_resampled is not None:
        deviation = np.sqrt((mine_resampled.x - center_x) ** 2 + (mine_resampled.z - center_z) ** 2)
        importance = compute_importance(deviation=deviation, spread=spread, epsilon=1e-6)
        min_peak_height = float(np.percentile(importance, 75))
        peak_indices = find_problem_peaks(
            importance=importance,
            min_peak_height=min_peak_height,
            min_peak_distance=min_peak_distance,
            max_peaks=max_problem_zones,
        )
        problem_zones = build_problem_zone_summary(
            peak_indices=peak_indices,
            common_progress=common_progress,
            importance=importance,
            deviation=deviation,
            spread=spread,
            speed_center=center_speed,
            mine_speed=mine_resampled.speed,
        )

        if center_speed is not None and mine_resampled.speed is not None:
            speed_delta = mine_resampled.speed - center_speed

    return AnalysisResult(
        source_dir=source_dir,
        map_name=source_dir.name,
        raw_trajectories=raw_trajectories,
        resampled_trajectories=resampled_trajectories,
        common_progress=common_progress,
        center_x=center_x,
        center_y=center_y,
        center_z=center_z,
        center_speed=center_speed,
        spread=spread,
        mine_raw=mine_raw,
        mine_resampled=mine_resampled,
        deviation=deviation,
        importance=importance,
        problem_zones=problem_zones,
        speed_delta=speed_delta,
    )
