from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class RawTrajectory:
    name: str
    x: np.ndarray
    y: np.ndarray
    z: np.ndarray
    speed: np.ndarray | None


@dataclass(frozen=True)
class ResampledTrajectory:
    name: str
    x: np.ndarray
    y: np.ndarray
    z: np.ndarray
    speed: np.ndarray | None


@dataclass(frozen=True)
class AnalysisResult:
    source_dir: Path
    map_name: str
    raw_trajectories: list[RawTrajectory]
    resampled_trajectories: list[ResampledTrajectory]
    common_progress: np.ndarray
    center_x: np.ndarray
    center_y: np.ndarray
    center_z: np.ndarray
    center_speed: np.ndarray | None
    spread: np.ndarray
    mine_raw: RawTrajectory | None
    mine_resampled: ResampledTrajectory | None
    deviation: np.ndarray | None
    importance: np.ndarray | None
    problem_zones: list[dict[str, float | int | None]]
    speed_delta: np.ndarray | None
