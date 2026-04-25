from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any

import numpy as np

from .models import AnalysisResult
from .paths import PLOTS_DIR, PROCESSED_DIR, PROJECT_ROOT, RAW_TRAJECTORIES_DIR


def load_trajectory(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as source:
        data = json.load(source)
    if not isinstance(data, list):
        raise ValueError("JSON root must be an array of points.")
    return data


def collect_json_files(source_dir: Path) -> list[Path]:
    return sorted(path for path in source_dir.glob("*.json") if path.is_file())


def resolve_plot_output_dir(source_dir: Path) -> Path:
    try:
        relative = source_dir.relative_to(RAW_TRAJECTORIES_DIR)
        return PLOTS_DIR / relative
    except ValueError:
        return PLOTS_DIR / source_dir.name


def resolve_processed_output_dir(source_dir: Path) -> Path:
    try:
        relative = source_dir.relative_to(RAW_TRAJECTORIES_DIR)
        return PROCESSED_DIR / relative
    except ValueError:
        return PROCESSED_DIR / source_dir.name


def save_problem_zones_json(output_path: Path, rows: list[dict[str, float | int | None]]) -> None:
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(rows, file, ensure_ascii=False, indent=2)


def save_problem_zones_csv(output_path: Path, rows: list[dict[str, float | int | None]]) -> None:
    fieldnames = [
        "rank",
        "index",
        "progress",
        "importance",
        "deviation",
        "spread",
        "center_speed",
        "mine_speed",
    ]
    with output_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def export_center_trajectory(
    output_path: Path,
    common_progress: np.ndarray,
    center_x: np.ndarray,
    center_y: np.ndarray,
    center_z: np.ndarray,
    center_speed: np.ndarray | None,
    spread: np.ndarray,
) -> None:
    rows: list[dict[str, float | None]] = []
    for i, progress in enumerate(common_progress):
        rows.append(
            {
                "progress": float(progress),
                "x": float(center_x[i]),
                "y": float(center_y[i]),
                "z": float(center_z[i]),
                "speed": float(center_speed[i]) if center_speed is not None else None,
                "spread": float(spread[i]),
            }
        )
    write_json(output_path, rows)


def export_analysis_data(output_path: Path, result: AnalysisResult) -> None:
    center_line = []
    for i, progress in enumerate(result.common_progress):
        center_line.append(
            {
                "progress": float(progress),
                "x": float(result.center_x[i]),
                "y": float(result.center_y[i]),
                "z": float(result.center_z[i]),
                "speed": _array_value(result.center_speed, i),
                "spread": float(result.spread[i]),
            }
        )

    mine_line = None
    if result.mine_resampled is not None:
        mine_line = []
        for i, progress in enumerate(result.common_progress):
            mine_line.append(
                {
                    "progress": float(progress),
                    "x": float(result.mine_resampled.x[i]),
                    "y": float(result.mine_resampled.y[i]),
                    "z": float(result.mine_resampled.z[i]),
                    "speed": _array_value(result.mine_resampled.speed, i),
                    "deviation": _array_value(result.deviation, i),
                    "importance": _array_value(result.importance, i),
                    "speed_delta": _array_value(result.speed_delta, i),
                }
            )

    payload = {
        "schema_version": 1,
        "map_name": result.map_name,
        "source_dir": format_repo_path(result.source_dir),
        "sample_count": int(result.common_progress.size),
        "runs": [
            {
                "name": item.name,
                "point_count": int(item.x.size),
                "has_speed": item.speed is not None,
                "used_for_center": any(center_item.name == item.name for center_item in result.center_source_trajectories),
            }
            for item in result.raw_trajectories
        ],
        "center_line": center_line,
        "mine_name": result.mine_raw.name if result.mine_raw is not None else None,
        "mine_line": mine_line,
        "problem_zones": result.problem_zones,
    }
    write_json(output_path, payload)


def write_json(output_path: Path, payload: Any) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)


def format_repo_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(resolved)


def _array_value(values: np.ndarray | None, index: int) -> float | None:
    return float(values[index]) if values is not None else None
