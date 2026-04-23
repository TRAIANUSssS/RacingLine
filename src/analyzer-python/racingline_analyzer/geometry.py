from __future__ import annotations

from typing import Any

import numpy as np

from .models import ResampledTrajectory


def extract_arrays(
    points: list[dict[str, Any]],
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray | None]:
    x_values: list[float] = []
    y_values: list[float] = []
    z_values: list[float] = []
    t_values: list[float] = []
    speed_values: list[float] = []
    has_speed_for_all = True

    for i, point in enumerate(points):
        if not isinstance(point, dict):
            continue
        x = point.get("x")
        y = point.get("y")
        z = point.get("z")
        t = point.get("t")
        speed = point.get("speed")

        if isinstance(x, (int, float)) and isinstance(y, (int, float)) and isinstance(
            z, (int, float)
        ):
            x_values.append(float(x))
            y_values.append(float(y))
            z_values.append(float(z))
            t_values.append(float(t) if isinstance(t, (int, float)) else float(i))
            if isinstance(speed, (int, float)):
                speed_values.append(float(speed))
            else:
                has_speed_for_all = False
        else:
            raise ValueError(f"Point at index {i} has invalid x/y/z values: {point}")

    if not x_values:
        raise ValueError("No valid x/y/z points found in trajectory.")

    speed_array: np.ndarray | None = None
    if has_speed_for_all and len(speed_values) == len(x_values):
        speed_array = np.asarray(speed_values, dtype=float)

    return (
        np.asarray(x_values, dtype=float),
        np.asarray(y_values, dtype=float),
        np.asarray(z_values, dtype=float),
        np.asarray(t_values, dtype=float),
        speed_array,
    )


def compute_progress(x: np.ndarray, z: np.ndarray) -> np.ndarray | None:
    if x.size < 2 or z.size < 2:
        return None
    dx = np.diff(x)
    dz = np.diff(z)
    segment_lengths = np.sqrt(dx**2 + dz**2)
    cumulative = np.concatenate(([0.0], np.cumsum(segment_lengths)))
    total_length = float(cumulative[-1])
    if total_length <= 0.0:
        return None
    return cumulative / total_length


def resample_trajectory(
    x: np.ndarray,
    y: np.ndarray,
    z: np.ndarray,
    speed: np.ndarray | None,
    progress: np.ndarray,
    common_progress: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray | None]:
    unique_progress, unique_idx = np.unique(progress, return_index=True)
    if unique_progress.size < 2:
        raise ValueError("Progress has fewer than 2 unique points.")

    x_unique = x[unique_idx]
    y_unique = y[unique_idx]
    z_unique = z[unique_idx]
    x_interp = np.interp(common_progress, unique_progress, x_unique)
    y_interp = np.interp(common_progress, unique_progress, y_unique)
    z_interp = np.interp(common_progress, unique_progress, z_unique)

    speed_interp: np.ndarray | None = None
    if speed is not None:
        speed_unique = speed[unique_idx]
        speed_interp = np.interp(common_progress, unique_progress, speed_unique)

    return x_interp, y_interp, z_interp, speed_interp


def build_center_trajectory(
    resampled_items: list[ResampledTrajectory],
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray | None, np.ndarray]:
    all_x = np.vstack([item.x for item in resampled_items]).astype(float)
    all_y = np.vstack([item.y for item in resampled_items]).astype(float)
    all_z = np.vstack([item.z for item in resampled_items]).astype(float)

    x_center = np.median(all_x, axis=0)
    y_center = np.median(all_y, axis=0)
    z_center = np.median(all_z, axis=0)

    x_std = np.std(all_x, axis=0)
    z_std = np.std(all_z, axis=0)
    spread = np.sqrt(x_std**2 + z_std**2)

    all_speed = [item.speed for item in resampled_items if item.speed is not None]
    speed_center: np.ndarray | None = None
    if all_speed:
        speed_center = np.median(np.vstack(all_speed).astype(float), axis=0)

    return x_center, y_center, z_center, speed_center, spread
