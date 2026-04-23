from __future__ import annotations

import numpy as np

try:
    from scipy.signal import find_peaks as scipy_find_peaks
except Exception:
    scipy_find_peaks = None


def compute_importance(deviation: np.ndarray, spread: np.ndarray, epsilon: float = 1e-6) -> np.ndarray:
    return deviation / (spread + epsilon)


def find_problem_peaks(
    importance: np.ndarray,
    min_peak_height: float,
    min_peak_distance: int = 12,
    max_peaks: int = 5,
) -> list[int]:
    if importance.size < 3:
        return []

    if scipy_find_peaks is not None:
        peak_indices, _ = scipy_find_peaks(
            importance,
            height=min_peak_height,
            distance=min_peak_distance,
        )
        indices = [int(i) for i in peak_indices]
    else:
        candidates = [
            i
            for i in range(1, len(importance) - 1)
            if importance[i] > importance[i - 1]
            and importance[i] >= importance[i + 1]
            and importance[i] >= min_peak_height
        ]
        candidates.sort(key=lambda i: float(importance[i]), reverse=True)
        indices = []
        for idx in candidates:
            if all(abs(idx - picked) >= min_peak_distance for picked in indices):
                indices.append(idx)

    indices.sort(key=lambda i: float(importance[i]), reverse=True)
    return indices[:max_peaks]


def build_problem_zone_summary(
    peak_indices: list[int],
    common_progress: np.ndarray,
    importance: np.ndarray,
    deviation: np.ndarray,
    spread: np.ndarray,
    speed_center: np.ndarray | None,
    mine_speed: np.ndarray | None,
) -> list[dict[str, float | int | None]]:
    rows: list[dict[str, float | int | None]] = []
    for rank, idx in enumerate(peak_indices, start=1):
        rows.append(
            {
                "rank": rank,
                "index": int(idx),
                "progress": float(common_progress[idx]),
                "importance": float(importance[idx]),
                "deviation": float(deviation[idx]),
                "spread": float(spread[idx]),
                "center_speed": float(speed_center[idx]) if speed_center is not None else None,
                "mine_speed": float(mine_speed[idx]) if mine_speed is not None else None,
            }
        )
    return rows

