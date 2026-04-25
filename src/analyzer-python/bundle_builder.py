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
    build_bundle_from_analysis(analysis_json, output_path)
    print(f"Saved: {output_path}")


def _normalize_range(rank_range: str) -> str:
    return rank_range.strip().replace("-", "_")


if __name__ == "__main__":
    main()
