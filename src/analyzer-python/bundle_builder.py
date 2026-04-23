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
        default=PROCESSED_DIR / "Spring 2026 - 09" / "analysis_data.json",
        help="Processed analysis_data.json produced by trajectory.py.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output bundle path. Defaults to analysis-json directory / analysis_bundle.json.",
    )
    args = parser.parse_args()

    output_path = args.output or args.analysis_json.parent / "analysis_bundle.json"
    build_bundle_from_analysis(args.analysis_json, output_path)
    print(f"Saved: {output_path}")


if __name__ == "__main__":
    main()

