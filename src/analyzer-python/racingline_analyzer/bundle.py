from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import json

from .io_utils import format_repo_path, write_json


def build_bundle_from_analysis(analysis_json_path: Path, output_path: Path) -> dict[str, Any]:
    with analysis_json_path.open("r", encoding="utf-8") as file:
        analysis = json.load(file)

    center_line = _normalize_center_line(analysis.get("center_line", []))
    mine_run_name = analysis.get("mine_name")
    mine_line = _normalize_mine_line(analysis.get("mine_line", []))
    analysis_points = _build_analysis_points(mine_line)
    problem_zones = _normalize_problem_zones(analysis.get("problem_zones", []), center_line)

    bundle = {
        "schema_version": 1,
        "analysis_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "map": {
            "name": analysis.get("map_name"),
        },
        "coordinate_system": {
            "world_axes": {
                "x": "Trackmania world X",
                "z": "Trackmania world Z",
            },
            "top_down_plot": "-X vs Z",
        },
        "source": {
            "analysis_json": format_repo_path(analysis_json_path),
            "source_dir": analysis.get("source_dir"),
            "sample_count": analysis.get("sample_count"),
        },
        "runs": analysis.get("runs", []),
        "center_line": center_line,
        "mine_run_name": mine_run_name,
        "mine_line": mine_line,
        "analysis_points": analysis_points,
        "mine": {
            "name": mine_run_name,
            "line": mine_line,
        },
        "problem_zones": problem_zones,
    }
    write_json(output_path, bundle)
    return bundle


def _normalize_center_line(center_line: list[dict[str, Any]]) -> list[dict[str, float | None]]:
    rows: list[dict[str, float | None]] = []
    for row in center_line:
        rows.append(
            {
                "progress": _to_float(row.get("progress")),
                "x": _to_float(row.get("x")),
                "y": _to_float(row.get("y")),
                "z": _to_float(row.get("z")),
                "speed": _to_float(row.get("speed")),
                "spread": _to_float(row.get("spread")),
            }
        )
    return rows


def _normalize_mine_line(mine_line: list[dict[str, Any]] | None) -> list[dict[str, float | None]]:
    if not mine_line:
        return []

    rows: list[dict[str, float | None]] = []
    for row in mine_line:
        rows.append(
            {
                "progress": _to_float(row.get("progress")),
                "x": _to_float(row.get("x")),
                "y": _to_float(row.get("y")),
                "z": _to_float(row.get("z")),
                "speed": _to_float(row.get("speed")),
                "deviation": _to_float(row.get("deviation")),
                "importance": _to_float(row.get("importance")),
                "speed_delta": _to_float(row.get("speed_delta")),
            }
        )
    return rows


def _build_analysis_points(mine_line: list[dict[str, float | None]]) -> list[dict[str, float | None]]:
    rows: list[dict[str, float | None]] = []
    for row in mine_line:
        rows.append(
            {
                "progress": row.get("progress"),
                "deviation": row.get("deviation"),
                "importance": row.get("importance"),
                "speed_delta": row.get("speed_delta"),
            }
        )
    return rows


def _normalize_problem_zones(
    problem_zones: list[dict[str, Any]],
    center_line: list[dict[str, float | None]],
) -> list[dict[str, float | int | None]]:
    rows: list[dict[str, float | int | None]] = []
    for idx, row in enumerate(problem_zones, start=1):
        center_point = _get_center_point(center_line, row)
        rows.append(
            {
                "id": idx,
                "rank": _to_int(row.get("rank")) or idx,
                "index": _to_int(row.get("index")),
                "progress": _to_float(row.get("progress")),
                "importance": _to_float(row.get("importance")),
                "deviation": _to_float(row.get("deviation")),
                "spread": _to_float(row.get("spread")),
                "center_speed": _to_float(row.get("center_speed")),
                "mine_speed": _to_float(row.get("mine_speed")),
                "x": center_point.get("x"),
                "y": center_point.get("y"),
                "z": center_point.get("z"),
            }
        )
    return rows


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    return float(value)


def _to_int(value: Any) -> int | None:
    if value is None:
        return None
    return int(value)


def _get_center_point(
    center_line: list[dict[str, float | None]],
    problem_zone: list[dict[str, Any]] | dict[str, Any],
) -> dict[str, float | None]:
    if not center_line:
        return {"x": None, "y": None, "z": None}

    if isinstance(problem_zone, dict):
        index = _to_int(problem_zone.get("index"))
        if index is not None and 0 <= index < len(center_line):
            point = center_line[index]
            return {"x": point.get("x"), "y": point.get("y"), "z": point.get("z")}

        progress = _to_float(problem_zone.get("progress"))
        if progress is not None:
            closest = min(
                center_line,
                key=lambda point: abs((point.get("progress") or 0.0) - progress),
            )
            return {"x": closest.get("x"), "y": closest.get("y"), "z": closest.get("z")}

    return {"x": None, "y": None, "z": None}
