from __future__ import annotations

import argparse
from pathlib import Path

from racingline_analyzer.bundle import build_bundle_from_analysis
from racingline_analyzer.paths import PROCESSED_DIR


def main() -> None:
    parser = argparse.ArgumentParser(description="Build an Openplanet-ready analysis_bundle.json.")
    parser.add_argument(
        "--analysis-json",
        type=Path,
        default=None,
        help="Processed analysis_data.json produced by trajectory.py.",
    )
    parser.add_argument(
        "--map",
        dest="map_name",
        default=None,
        help="Map folder name under data/processed. Used when --analysis-json is not provided.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output bundle path. Defaults to analysis-json directory / bundle name.",
    )
    parser.add_argument(
        "--bundle-name",
        default="analysis_bundle.json",
        help="Output bundle filename when --output is not provided.",
    )
    parser.add_argument(
        "--range",
        dest="rank_range",
        default=None,
        help="Leaderboard rank range used to derive the default bundle name, for example 1000-1010.",
    )
    parser.add_argument("--map-uid", default=None, help="Trackmania map UID to write into bundle metadata.")
    parser.add_argument("--sample-mode", default=None, help="Analysis sample mode to write into bundle metadata.")
    parser.add_argument("--sample-count", type=int, default=None, help="Resolved analysis sample count to write into bundle metadata.")
    parser.add_argument("--generator", default="pipeline.py", help="Generator name/version to write into bundle metadata.")
    args = parser.parse_args()

    analysis_json = args.analysis_json
    if analysis_json is None:
        if args.map_name is None:
            parser.error("Provide either --analysis-json or --map.")
        analysis_json = PROCESSED_DIR / args.map_name / "analysis_data.json"

    bundle_name = args.bundle_name
    if args.rank_range is not None and bundle_name == "analysis_bundle.json":
        bundle_name = f"top_{_normalize_range(args.rank_range)}.analysis_bundle.json"

    output_path = args.output or analysis_json.parent / bundle_name
    rank_from, rank_to = _parse_rank_range(args.rank_range)
    build_bundle_from_analysis(
        analysis_json,
        output_path,
        map_uid=args.map_uid,
        rank_range=args.rank_range,
        rank_from=rank_from,
        rank_to=rank_to,
        sample_mode=args.sample_mode,
        sample_count=args.sample_count,
        generator=args.generator,
    )
    print(f"Saved: {output_path}")


def _normalize_range(rank_range: str) -> str:
    return rank_range.strip().replace("-", "_")


def _parse_rank_range(rank_range: str | None) -> tuple[int | None, int | None]:
    if rank_range is None:
        return None, None

    parts = rank_range.strip().split("-", 1)
    if len(parts) != 2:
        return None, None

    try:
        start = int(parts[0])
        end = int(parts[1])
    except ValueError:
        return None, None

    if start < 1 or end < start:
        return None, None
    return start, end


if __name__ == "__main__":
    main()
