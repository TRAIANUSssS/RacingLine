from __future__ import annotations

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]

RAW_TRAJECTORIES_DIR = PROJECT_ROOT / "data" / "raw" / "trajectories"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
PLOTS_DIR = PROJECT_ROOT / "output" / "plots"

DEFAULT_SOURCE_DIR = RAW_TRAJECTORIES_DIR / "Spring 2026 - 09"
DEFAULT_HIGHLIGHT_NICKNAME = "TRAIANUSssS"

