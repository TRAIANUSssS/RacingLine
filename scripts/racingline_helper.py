from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import traceback
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PIPELINE_SCRIPT = PROJECT_ROOT / "pipeline.py"


@dataclass(frozen=True)
class Dataset:
    map_uid: str
    map_name: str
    rank_from: int
    rank_to: int
    folder: Path
    manifest_path: Path | None
    mine_name: str

    @property
    def range_text(self) -> str:
        return f"{self.rank_from}-{self.rank_to}"

    @property
    def range_folder(self) -> str:
        return f"top_{self.rank_from}_{self.rank_to}"

    @property
    def task_id(self) -> str:
        return f"task_{sanitize_path_part(self.map_uid)}_{self.range_folder}"

    @property
    def bundle_name(self) -> str:
        return f"{self.range_folder}.analysis_bundle.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Watch Openplanet RacingLine downloads and build bundles automatically.")
    parser.add_argument(
        "--storage-root",
        type=Path,
        default=Path.home() / "OpenplanetNext" / "PluginStorage" / "RacingLine",
        help="Openplanet RacingLine PluginStorage root.",
    )
    parser.add_argument("--poll-seconds", type=float, default=1.0, help="Watcher scan interval.")
    parser.add_argument("--stable-seconds", type=float, default=3.0, help="How long a dataset must be unchanged before processing.")
    parser.add_argument("--once", action="store_true", help="Process ready datasets once and exit.")
    parser.add_argument("--force", action="store_true", help="Rebuild even if the target bundle already exists.")
    args = parser.parse_args()

    storage_root = args.storage_root.resolve()
    ensure_storage_layout(storage_root)
    print(f"RacingLine helper watching: {storage_root / 'downloads'}", flush=True)

    seen_signatures: dict[Path, tuple[int, int, float]] = {}
    stable_since: dict[Path, float] = {}

    while True:
        try:
            datasets = discover_datasets(storage_root)
            if args.once:
                for dataset in datasets:
                    process_dataset(dataset, storage_root, force=args.force)
                return

            now = time.monotonic()
            for dataset in datasets:
                signature = dataset_signature(dataset.folder)
                previous = seen_signatures.get(dataset.folder)
                if previous != signature:
                    seen_signatures[dataset.folder] = signature
                    stable_since[dataset.folder] = now
                    continue

                if now - stable_since.get(dataset.folder, now) < args.stable_seconds:
                    continue

                process_dataset(dataset, storage_root, force=args.force)
                stable_since[dataset.folder] = now
        except KeyboardInterrupt:
            print("Stopping RacingLine helper.", flush=True)
            return
        except Exception:
            traceback.print_exc()

        time.sleep(max(0.1, args.poll_seconds))


def ensure_storage_layout(storage_root: Path) -> None:
    for relative in ("downloads", "bundles", "tasks/pending", "tasks/running", "tasks/done", "logs"):
        (storage_root / relative).mkdir(parents=True, exist_ok=True)


def discover_datasets(storage_root: Path) -> list[Dataset]:
    downloads_root = storage_root / "downloads"
    if not downloads_root.exists():
        return []

    datasets: list[Dataset] = []
    for map_dir in sorted(path for path in downloads_root.iterdir() if path.is_dir()):
        for range_dir in sorted(path for path in map_dir.iterdir() if path.is_dir() and path.name.startswith("top_")):
            parsed_range = parse_range_folder(range_dir.name)
            if parsed_range is None:
                continue
            replay_files = list(iter_replay_files(range_dir))
            if not replay_files:
                continue

            rank_from, rank_to = parsed_range
            manifest_path = range_dir / "manifest.json"
            manifest = load_json(manifest_path)
            map_uid = str(manifest.get("map_uid") or map_dir.name) if isinstance(manifest, dict) else map_dir.name
            map_name = str(manifest.get("map_name") or map_uid) if isinstance(manifest, dict) else map_uid
            mine_name = extract_mine_name(manifest)
            datasets.append(
                Dataset(
                    map_uid=map_uid,
                    map_name=map_name,
                    rank_from=rank_from,
                    rank_to=rank_to,
                    folder=range_dir,
                    manifest_path=manifest_path if manifest_path.exists() else None,
                    mine_name=mine_name,
                )
            )
    return datasets


def process_dataset(dataset: Dataset, storage_root: Path, force: bool) -> None:
    bundle_path = storage_root / "bundles" / sanitize_path_part(dataset.map_uid) / dataset.bundle_name
    done_status_path = status_path(storage_root, "done", dataset.task_id)
    input_signature = dataset_signature_payload(dataset.folder)
    previous_status = load_json(done_status_path)
    if (
        bundle_path.exists()
        and isinstance(previous_status, dict)
        and previous_status.get("input_signature") == input_signature
        and not force
    ):
        return

    running_path = status_path(storage_root, "running", dataset.task_id)
    log_path = storage_root / "logs" / f"{dataset.task_id}.log"
    write_status(running_path, dataset, "running", "queued", None, bundle_path, log_path, input_signature)

    command = build_pipeline_command(dataset, storage_root)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"\n[{utc_now()}] Starting task {dataset.task_id}\n")
            log.write("Command: " + subprocess.list2cmdline(command) + "\n")
            log.flush()

            write_status(running_path, dataset, "running", "pipeline", None, bundle_path, log_path, input_signature)
            result = subprocess.run(
                command,
                cwd=PROJECT_ROOT,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )

            if result.returncode != 0:
                raise RuntimeError(f"pipeline.py failed with exit code {result.returncode}")

            log.write(f"[{utc_now()}] Done: {bundle_path}\n")

        if running_path.exists():
            running_path.unlink()
        write_status(done_status_path, dataset, "done", "done", None, bundle_path, log_path, input_signature)
    except Exception as exc:
        error = str(exc)
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"[{utc_now()}] FAILED: {error}\n")
            log.write(traceback.format_exc())
        if running_path.exists():
            running_path.unlink()
        write_status(done_status_path, dataset, "failed", "failed", error, bundle_path, log_path, input_signature)


def build_pipeline_command(dataset: Dataset, storage_root: Path) -> list[str]:
    command = [
        sys.executable,
        str(PIPELINE_SCRIPT),
        "--map",
        dataset.map_name,
        "--map-uid",
        dataset.map_uid,
        "--mine",
        dataset.mine_name,
        "--range",
        dataset.range_text,
        "--replay-input-dir",
        str(dataset.folder),
        "--storage-root",
        str(storage_root),
        "--sample-mode",
        "auto",
    ]

    mine_replay_path = storage_root / "tmp" / sanitize_path_part(dataset.map_uid) / "mine.Replay.Gbx"
    if mine_replay_path.exists():
        command.extend(["--include-mine-replay", "--mine-replay-path", str(mine_replay_path)])
    else:
        command.append("--allow-missing-mine")

    return command


def write_status(
    path: Path,
    dataset: Dataset,
    status: str,
    progress: str,
    error: str | None,
    bundle_path: Path,
    log_path: Path,
    input_signature: dict[str, Any],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "racingline.helper_task.v1",
        "task_id": dataset.task_id,
        "status": status,
        "map_uid": dataset.map_uid,
        "map_name": dataset.map_name,
        "range": dataset.range_text,
        "rank_from": dataset.rank_from,
        "rank_to": dataset.rank_to,
        "progress": progress,
        "error": error,
        "download_folder": str(dataset.folder),
        "bundle_path": str(bundle_path),
        "log_path": str(log_path),
        "input_signature": input_signature,
        "updated_at": utc_now(),
    }
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    temp_path.replace(path)


def status_path(storage_root: Path, state: str, task_id: str) -> Path:
    return storage_root / "tasks" / state / f"{task_id}.json"


def dataset_signature(folder: Path) -> tuple[int, int, float]:
    files = list(iter_replay_files(folder))
    total_size = sum(path.stat().st_size for path in files)
    latest_mtime = max((path.stat().st_mtime for path in files), default=0.0)
    return len(files), total_size, latest_mtime


def dataset_signature_payload(folder: Path) -> dict[str, Any]:
    files = list(iter_replay_files(folder))
    return {
        "count": len(files),
        "total_size": sum(path.stat().st_size for path in files),
        "files": [
            {
                "name": path.name,
                "size": path.stat().st_size,
                "mtime": int(path.stat().st_mtime),
            }
            for path in files
        ],
    }


def iter_replay_files(folder: Path):
    yield from sorted(path for path in folder.glob("*.Replay.Gbx") if path.is_file())
    yield from sorted(path for path in folder.glob("*.Ghost.Gbx") if path.is_file())


def parse_range_folder(folder_name: str) -> tuple[int, int] | None:
    parts = folder_name.split("_")
    if len(parts) != 3 or parts[0] != "top":
        return None
    try:
        rank_from = int(parts[1])
        rank_to = int(parts[2])
    except ValueError:
        return None
    if rank_from < 1 or rank_to < rank_from:
        return None
    return rank_from, rank_to


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def extract_mine_name(manifest: dict[str, Any] | None) -> str:
    if isinstance(manifest, dict):
        for key in ("mine_name", "current_user_name", "current_user_login"):
            value = manifest.get(key)
            if isinstance(value, str) and value.strip():
                return strip_trackmania_format_codes(value).strip()
    return "mine"


def strip_trackmania_format_codes(value: str) -> str:
    result: list[str] = []
    i = 0
    while i < len(value):
        if value[i] != "$":
            result.append(value[i])
            i += 1
            continue
        if i + 3 < len(value) and all(ch in "0123456789abcdefABCDEF" for ch in value[i + 1 : i + 4]):
            i += 4
        else:
            i += 2
    return "".join(result)


def sanitize_path_part(value: str) -> str:
    invalid_chars = '<>:"/\\|?*'
    sanitized = "".join("_" if char in invalid_chars or ord(char) < 32 else char for char in value).strip()
    return sanitized or "unknown"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


if __name__ == "__main__":
    main()
