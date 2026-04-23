from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection
from matplotlib.colors import LinearSegmentedColormap, Normalize

from .models import RawTrajectory, ResampledTrajectory


def plot_single_trajectory(
    x: np.ndarray,
    z: np.ndarray,
    speed: np.ndarray | None,
    output_path: Path,
    title: str,
) -> None:
    neg_x = -x
    fig, ax = plt.subplots(figsize=(11, 9))

    if speed is None or len(neg_x) < 2:
        ax.plot(neg_x, z, linewidth=2.0, color="#0057d9")
    else:
        speed_max = float(np.max(speed))
        norm = Normalize(vmin=0.0, vmax=speed_max if speed_max > 0 else 1.0)
        cmap = LinearSegmentedColormap.from_list("red_to_green", ["#ff0000", "#00aa00"])
        points = np.column_stack([neg_x, z]).reshape(-1, 1, 2)
        segments = np.concatenate([points[:-1], points[1:]], axis=1)
        segment_speed = (speed[:-1] + speed[1:]) / 2.0
        lc = LineCollection(segments, cmap=cmap, norm=norm, linewidth=2.0)
        lc.set_array(segment_speed)
        ax.add_collection(lc)
        ax.autoscale()
        colorbar = fig.colorbar(lc, ax=ax)
        colorbar.set_label("Speed (0 to max)")

    ax.set_title(title)
    ax.set_xlabel("-X")
    ax.set_ylabel("Z")
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal", adjustable="box")
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_overlay_with_center(
    raw_series: list[RawTrajectory],
    center_x: np.ndarray,
    center_z: np.ndarray,
    mine_series: RawTrajectory | None,
    output_path: Path,
) -> None:
    fig, ax = plt.subplots(figsize=(11, 9))
    for item in raw_series:
        ax.plot(-item.x, item.z, color="#808080", linewidth=1.0, alpha=0.35)

    ax.plot(-center_x, center_z, color="#0057d9", linewidth=3.0, label="Center")
    if mine_series is not None:
        ax.plot(-mine_series.x, mine_series.z, color="#ff0000", linewidth=3.0, label=f"Mine: {mine_series.name}")

    ax.set_title("Overlay: all + center + mine")
    ax.set_xlabel("-X")
    ax.set_ylabel("Z")
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal", adjustable="box")
    ax.legend(loc="best")
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_center_speed(
    center_x: np.ndarray,
    center_z: np.ndarray,
    center_speed: np.ndarray | None,
    output_path: Path,
) -> None:
    fig, ax = plt.subplots(figsize=(11, 9))
    neg_x_center = -center_x

    if center_speed is None or len(neg_x_center) < 2:
        ax.plot(neg_x_center, center_z, color="#0057d9", linewidth=3.0)
    else:
        speed_max = float(np.max(center_speed))
        norm = Normalize(vmin=0.0, vmax=speed_max if speed_max > 0 else 1.0)
        cmap = LinearSegmentedColormap.from_list("red_to_green", ["#ff0000", "#00aa00"])
        points = np.column_stack([neg_x_center, center_z]).reshape(-1, 1, 2)
        segments = np.concatenate([points[:-1], points[1:]], axis=1)
        segment_speed = (center_speed[:-1] + center_speed[1:]) / 2.0
        lc = LineCollection(segments, cmap=cmap, norm=norm, linewidth=3.0)
        lc.set_array(segment_speed)
        ax.add_collection(lc)
        ax.autoscale()
        colorbar = fig.colorbar(lc, ax=ax)
        colorbar.set_label("Center speed")

    ax.set_title("Central trajectory (-X vs Z, colored by speed)")
    ax.set_xlabel("-X")
    ax.set_ylabel("Z")
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal", adjustable="box")
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_spread(common_progress: np.ndarray, spread: np.ndarray, output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.plot(common_progress, spread, color="#0057d9", linewidth=2.5)
    ax.set_title("Trajectory spread by progress")
    ax.set_xlabel("Progress")
    ax.set_ylabel("Spread")
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_deviation(common_progress: np.ndarray, deviation: np.ndarray, output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.plot(common_progress, deviation, color="#ff0000", linewidth=2.5)
    ax.set_title("My deviation from center")
    ax.set_xlabel("Progress")
    ax.set_ylabel("Deviation")
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_importance(
    common_progress: np.ndarray,
    importance: np.ndarray,
    peak_rows: list[dict[str, float | int | None]],
    output_path: Path,
) -> None:
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.plot(common_progress, importance, color="#1a1a1a", linewidth=2.0)

    for row in peak_rows:
        idx = int(row["index"])
        rank = int(row["rank"])
        x = float(common_progress[idx])
        y = float(importance[idx])
        ax.scatter([x], [y], color="#ff0000", s=30, zorder=5)
        ax.text(x, y, f" #{rank}", color="#ff0000", fontsize=9)

    ax.set_title("Importance by progress")
    ax.set_xlabel("Progress")
    ax.set_ylabel("Importance")
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_problem_zone_zoom(
    rank: int,
    peak_progress: float,
    common_progress: np.ndarray,
    resampled_items: list[ResampledTrajectory],
    center_x: np.ndarray,
    center_z: np.ndarray,
    mine_resampled: ResampledTrajectory | None,
    output_path: Path,
) -> None:
    left = max(0.0, peak_progress - 0.03)
    right = min(1.0, peak_progress + 0.03)
    mask = (common_progress >= left) & (common_progress <= right)
    if np.count_nonzero(mask) < 2:
        return

    fig, ax = plt.subplots(figsize=(11, 9))
    for item in resampled_items:
        ax.plot(-item.x[mask], item.z[mask], color="#808080", linewidth=1.0, alpha=0.35)

    ax.plot(-center_x[mask], center_z[mask], color="#0057d9", linewidth=3.0, label="Center")
    if mine_resampled is not None:
        ax.plot(-mine_resampled.x[mask], mine_resampled.z[mask], color="#ff0000", linewidth=3.0, label="Mine")

    ax.set_title(f"Problem zone #{rank} (progress={peak_progress:.3f})")
    ax.set_xlabel("-X")
    ax.set_ylabel("Z")
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal", adjustable="box")
    ax.legend(loc="best")
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)


def plot_speed_delta(
    common_progress: np.ndarray,
    speed_delta: np.ndarray,
    output_path: Path,
) -> None:
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.plot(common_progress, speed_delta, color="#6a0dad", linewidth=2.2)
    ax.set_title("Speed delta by progress")
    ax.set_xlabel("Progress")
    ax.set_ylabel("Mine speed - Center speed")
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=200)
    plt.close(fig)

