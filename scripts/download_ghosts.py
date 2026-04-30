from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "data" / "raw" / "ghosts"
TRACKMANIA_IO_BASE_URL = "https://trackmania.io"
TRACKMANIA_IO_MAX_RANK = 10000
DEFAULT_TIMEOUT_SECONDS = 30
USER_AGENT = "RacingLine/0.1 (+https://trackmania.io)"


@dataclass(frozen=True)
class RankRange:
    start: int
    end: int

    @property
    def length(self) -> int:
        return self.end - self.start + 1

    @property
    def offset(self) -> int:
        return self.start - 1

    @property
    def normalized(self) -> str:
        return f"{self.start}_{self.end}"

    @property
    def label(self) -> str:
        return f"{self.start}-{self.end}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Download Trackmania.io leaderboard ghosts for a rank range.")
    parser.add_argument("--leaderboard-id", required=True, help="Trackmania.io leaderboard/campaign id.")
    parser.add_argument("--map-uid", required=True, help="Trackmania map UID.")
    parser.add_argument("--map", required=True, dest="map_name", help="Map name / output folder name.")
    parser.add_argument("--range", required=True, dest="rank_range", help="Inclusive rank range, e.g. 1000-1010.")
    parser.add_argument(
        "--output-root",
        type=Path,
        default=DEFAULT_OUTPUT_ROOT,
        help="Root directory for downloaded ghosts. Defaults to data/raw/ghosts.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Exact output directory. Overrides --output-root/<map>/top_<range>.",
    )
    parser.add_argument(
        "--base-url",
        default=TRACKMANIA_IO_BASE_URL,
        help="Trackmania.io base URL.",
    )
    parser.add_argument(
        "--max-length",
        type=int,
        default=100,
        help="Maximum number of ghosts to fetch in one run.",
    )
    parser.add_argument("--force", action="store_true", help="Redownload files that already exist.")
    parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="Fetch leaderboard metadata and write manifest without downloading ghost files.",
    )
    args = parser.parse_args()

    rank_range = parse_rank_range(args.rank_range)
    if args.max_length < 1:
        raise ValueError("--max-length must be at least 1.")
    if rank_range.length > args.max_length:
        raise ValueError(f"Requested range has {rank_range.length} ranks, but --max-length is {args.max_length}.")

    output_dir = args.output_dir or args.output_root / sanitize_path_part(args.map_uid) / f"top_{rank_range.normalized}"
    output_dir.mkdir(parents=True, exist_ok=True)

    leaderboard = fetch_leaderboard(args.base_url, args.leaderboard_id, args.map_uid, 0, 1)
    player_count = int(leaderboard.get("playercount") or 0)
    max_allowed_rank = min(player_count, TRACKMANIA_IO_MAX_RANK) if player_count > 0 else TRACKMANIA_IO_MAX_RANK
    if rank_range.end > max_allowed_rank:
        raise ValueError(
            f"Rank range {rank_range.label} exceeds available rank limit {max_allowed_rank} "
            f"(playercount={player_count}, trackmania.io limit={TRACKMANIA_IO_MAX_RANK})."
        )

    payload = fetch_leaderboard(
        args.base_url,
        args.leaderboard_id,
        args.map_uid,
        rank_range.offset,
        rank_range.length,
    )
    tops = payload.get("tops")
    if not isinstance(tops, list):
        raise ValueError("Unexpected Trackmania.io response: 'tops' is missing or is not a list.")

    entries: list[dict[str, Any]] = []
    for top in tops:
        if not isinstance(top, dict):
            continue
        entries.append(process_top_entry(args.base_url, output_dir, top, args.force, args.metadata_only))

    if not args.metadata_only:
        remove_stale_ghost_files(output_dir, entries)

    manifest = {
        "schema": "racingline.trackmaniaio_ghost_manifest.v1",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": {
            "base_url": args.base_url,
            "leaderboard_id": args.leaderboard_id,
            "map_uid": args.map_uid,
            "map_name": args.map_name,
            "rank_range": rank_range.label,
            "offset": rank_range.offset,
            "length": rank_range.length,
            "playercount": player_count,
            "locked_leaderboard": bool(payload.get("lockedLeaderboard", False)),
            "max_rank": max_allowed_rank,
        },
        "output_dir": str(output_dir),
        "entries": entries,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    downloaded_count = sum(1 for entry in entries if entry["status"] == "downloaded")
    cached_count = sum(1 for entry in entries if entry["status"] == "cached")
    failed_count = sum(1 for entry in entries if entry["status"] == "failed")
    print(f"Output: {output_dir}")
    print(f"Manifest: {manifest_path}")
    print(f"Entries: {len(entries)} downloaded={downloaded_count} cached={cached_count} failed={failed_count}")

    if failed_count > 0:
        raise SystemExit(1)


def remove_stale_ghost_files(output_dir: Path, entries: list[dict[str, Any]]) -> None:
    expected_paths = {
        Path(str(entry["local_path"])).resolve()
        for entry in entries
        if entry.get("local_path")
    }
    removed_count = 0
    for path in output_dir.glob("*.Ghost.Gbx"):
        if path.resolve() in expected_paths:
            continue
        path.unlink()
        removed_count += 1

    if removed_count > 0:
        print(f"Removed stale ghost files: {removed_count}")


def parse_rank_range(value: str) -> RankRange:
    parts = value.strip().split("-", 1)
    try:
        start = int(parts[0])
        end = int(parts[1]) if len(parts) == 2 else start
    except ValueError as ex:
        raise ValueError(f"Invalid rank range: {value!r}. Expected format like 1000-1010.") from ex

    if start < 1 or end < 1:
        raise ValueError("Ranks are 1-based and must be at least 1.")
    if end < start:
        raise ValueError("Rank range end must be greater than or equal to start.")
    if end > TRACKMANIA_IO_MAX_RANK:
        raise ValueError(f"Trackmania.io exposes ghosts only up to rank {TRACKMANIA_IO_MAX_RANK}.")
    return RankRange(start=start, end=end)


def fetch_leaderboard(base_url: str, leaderboard_id: str, map_uid: str, offset: int, length: int) -> dict[str, Any]:
    path = f"/api/leaderboard/{leaderboard_id}/{map_uid}?offset={offset}&length={length}"
    url = urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    return fetch_json(url)


def process_top_entry(
    base_url: str,
    output_dir: Path,
    top: dict[str, Any],
    force: bool,
    metadata_only: bool,
) -> dict[str, Any]:
    player = top.get("player") if isinstance(top.get("player"), dict) else {}
    player_name = str(player.get("name") or "unknown")
    player_id = str(player.get("id") or "")
    position = int(top.get("position") or 0)
    time_ms = int(top.get("time") or top.get("score") or 0)
    timestamp = str(top.get("timestamp") or "")
    ghost_path = str(top.get("url") or "")
    source_filename = str(top.get("filename") or "")
    ghost_url = urljoin(base_url.rstrip("/") + "/", ghost_path.lstrip("/")) if ghost_path else ""
    ghost_id = ghost_path.rstrip("/").split("/")[-1] if ghost_path else ""

    file_name = build_ghost_file_name(position, player_name, time_ms, ghost_id)
    local_path = output_dir / file_name
    status = "metadata"
    error = None

    if not ghost_url:
        status = "failed"
        error = "Missing ghost download URL."
    elif metadata_only:
        status = "metadata"
    elif local_path.exists() and not force:
        status = "cached"
    else:
        try:
            download_binary(ghost_url, local_path)
            status = "downloaded"
        except (HTTPError, URLError, OSError) as ex:
            status = "failed"
            error = str(ex)

    return {
        "position": position,
        "player_name": player_name,
        "player_id": player_id,
        "time_ms": time_ms,
        "timestamp": timestamp,
        "source_filename": source_filename,
        "ghost_url": ghost_url,
        "ghost_id": ghost_id,
        "local_path": str(local_path),
        "status": status,
        "error": error,
    }


def fetch_json(url: str) -> dict[str, Any]:
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urlopen(request, timeout=DEFAULT_TIMEOUT_SECONDS) as response:
        data = response.read()

    payload = json.loads(data.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Unexpected JSON response from {url}: root is not an object.")
    return payload


def download_binary(url: str, path: Path) -> None:
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/octet-stream"})
    with urlopen(request, timeout=DEFAULT_TIMEOUT_SECONDS) as response:
        data = response.read()

    if not data:
        raise OSError(f"Empty response while downloading {url}.")

    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_bytes(data)
    temp_path.replace(path)


def build_ghost_file_name(position: int, player_name: str, time_ms: int, ghost_id: str) -> str:
    rank_part = f"rank_{position:05d}" if position > 0 else "rank_unknown"
    player_part = sanitize_path_part(strip_trackmania_format_codes(player_name)) or "unknown"
    time_part = format_time_ms(time_ms)
    ghost_part = sanitize_path_part(ghost_id) if ghost_id else "unknown"
    return f"{rank_part}_{player_part}_{time_part}_{ghost_part}.Ghost.Gbx"


def format_time_ms(time_ms: int) -> str:
    if time_ms <= 0:
        return "time_unknown"
    minutes = time_ms // 60000
    seconds = (time_ms % 60000) // 1000
    millis = time_ms % 1000
    return f"{minutes:02d}m{seconds:02d}s{millis:03d}ms"


def strip_trackmania_format_codes(value: str) -> str:
    return re.sub(r"\$([0-9a-fA-F]{3}|.)", "", value)


def sanitize_path_part(value: str) -> str:
    invalid_chars = '<>:"/\\|?*'
    sanitized = "".join("_" if char in invalid_chars or ord(char) < 32 else char for char in value).strip()
    sanitized = re.sub(r"\s+", " ", sanitized)
    sanitized = sanitized.replace(".", "_")
    return sanitized[:80].strip(" .") or "unknown"


if __name__ == "__main__":
    try:
        main()
    except Exception as ex:
        print(f"Ghost download failed: {ex}", file=sys.stderr)
        raise SystemExit(1)
