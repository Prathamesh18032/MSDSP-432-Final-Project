#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import io
import os
import shutil
import subprocess
from pathlib import Path


DATASET_SLUG = "odins0n/ucf-crime-dataset"
# Use the exact folder names as they appear in the Kaggle dataset (Test/NormalVideos, not "Normal Videos")
DEFAULT_CLASSES = ("Assault", "Robbery", "RoadAccidents", "Fighting", "Burglary", "Stealing", "Shoplifting", "NormalVideos")
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


def normalize_class_name(value: str) -> str:
    normalized = value.strip().lower().replace("_", " ").replace("-", " ")
    # Handle "Normal Videos" (with space) and "NormalVideos" (Kaggle folder name, no space)
    if normalized in {"normal", "normal videos", "normalvideos", "normalvideo"}:
        return "normal"
    # Handle "RoadAccidents" (Kaggle folder) and variants
    if normalized in {"roadaccidents", "road accidents", "road accident", "accident", "crash"}:
        return "roadaccidents"
    if normalized in {"theft", "steal", "stealing"}:
        return "stealing"
    return normalized.replace(" ", "")


def display_class_name(normalized: str) -> str:
    if normalized == "normal":
        return "Normal"
    if normalized == "roadaccidents":
        return "RoadAccidents"
    return normalized.title()


def class_from_path(path: Path, wanted_classes: set[str]) -> str | None:
    for part in path.parts:
        normalized = normalize_class_name(part)
        if normalized in wanted_classes:
            return normalized
    return None


def iter_local_images(source_dir: Path, wanted_classes: set[str]) -> list[Path]:
    return [
        path
        for path in sorted(source_dir.rglob("*"))
        if path.is_file()
        and path.suffix.lower() in IMAGE_EXTENSIONS
        and class_from_path(path, wanted_classes) is not None
    ]


def has_matching_images(source_dir: Path, wanted_classes: set[str]) -> bool:
    return source_dir.exists() and any(iter_local_images(source_dir, wanted_classes))


def copy_sampled_dataset(
    source_dir: Path,
    output_dir: Path,
    wanted_classes: set[str],
    limit_bytes: int,
    max_normal: int,
    max_anomaly: int,
    city: str,
) -> tuple[int, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    per_class: dict[str, int] = {class_name: 0 for class_name in wanted_classes}
    grouped: dict[str, list[Path]] = {class_name: [] for class_name in wanted_classes}
    for path in iter_local_images(source_dir, wanted_classes):
        class_name = class_from_path(path, wanted_classes)
        if class_name is not None:
            grouped[class_name].append(path)
    total_bytes = 0
    copied = 0
    class_order = sorted(wanted_classes)
    while True:
        copied_this_round = False
        for class_name in class_order:
            allowed_max = max_normal if class_name == "normal" else max_anomaly
            if per_class[class_name] >= allowed_max:
                continue
            class_files = grouped.get(class_name, [])
            if per_class[class_name] >= len(class_files):
                continue
            path = class_files[per_class[class_name]]
            size = path.stat().st_size
            if total_bytes + size > limit_bytes:
                continue
            camera_id = f"demo-{class_name}"
            target_dir = output_dir / f"city={city}" / f"camera={camera_id}"
            target_dir.mkdir(parents=True, exist_ok=True)
            target = target_dir / f"{display_class_name(class_name)}_{per_class[class_name]:04d}{path.suffix.lower()}"
            shutil.copy2(path, target)
            per_class[class_name] += 1
            total_bytes += size
            copied += 1
            copied_this_round = True
        if not copied_this_round:
            break
    print("\n--- Safety AI Dataset Summary ---")
    for class_name in class_order:
        print(f" * {display_class_name(class_name)}: {per_class[class_name]} images copied")
    print("---------------------------------\n")
    return copied, total_bytes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare a <200 MB UCF-Crime Safety AI image demo dataset")
    parser.add_argument("--dataset", default=os.getenv("VIDEO_AGENT_KAGGLE_DATASET", DATASET_SLUG))
    parser.add_argument("--source-dir", default=os.getenv("VIDEO_AGENT_DATASET_SOURCE_DIR", ""))
    parser.add_argument("--cache-dir", default=os.getenv("VIDEO_AGENT_KAGGLE_CACHE_DIR", "data/kaggle_ucf_crime"))
    parser.add_argument("--output", default=os.getenv("VIDEO_AGENT_DATASET_DIR", "data/video_inbox"))
    parser.add_argument("--max-mb", type=int, default=int(os.getenv("VIDEO_AGENT_DATASET_MAX_MB", "200")))
    parser.add_argument("--max-normal", type=int, default=int(os.getenv("VIDEO_AGENT_DATASET_MAX_NORMAL", "70")))
    parser.add_argument("--max-anomaly", type=int, default=int(os.getenv("VIDEO_AGENT_DATASET_MAX_ANOMALY", "15")))
    parser.add_argument("--city", default=os.getenv("VIDEO_AGENT_CITY", "chicago"))
    parser.add_argument("--classes", default=os.getenv("VIDEO_AGENT_DATASET_CLASSES", ",".join(DEFAULT_CLASSES)))
    parser.add_argument("--no-download", action="store_true", help="only sample from local --source-dir")
    parser.add_argument("--use-kagglehub", action="store_true", help="download the full Kaggle archive first; can be about 11 GB")
    return parser.parse_args()


def wanted_classes(value: str) -> set[str]:
    return {normalize_class_name(item) for item in value.split(",") if item.strip()}


def download_with_kagglehub(dataset: str) -> Path:
    try:
        import kagglehub
    except ImportError as exc:
        raise SystemExit(
            "The 'kagglehub' package is missing. Run: python -m pip install -r services/video-agent/requirements.txt"
        ) from exc

    print(f"Checking/downloading Kaggle dataset {dataset} with kagglehub...")
    return Path(kagglehub.dataset_download(dataset))


def kaggle_files_page(dataset: str, page_token: str | None) -> tuple[str | None, list[dict[str, str]]]:
    cmd = ["kaggle", "datasets", "files", dataset, "--csv", "--page-size", "200"]
    if page_token:
        cmd.extend(["--page-token", page_token])
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    next_token = None
    csv_lines: list[str] = []
    for line in result.stdout.splitlines():
        if line.startswith("Next Page Token = "):
            next_token = line.split("=", 1)[1].strip()
        elif line.startswith("name,") or csv_lines:
            csv_lines.append(line)
    if not csv_lines:
        return next_token, []
    return next_token, list(csv.DictReader(io.StringIO("\n".join(csv_lines))))


def select_kaggle_files(
    dataset: str,
    wanted: set[str],
    limit_bytes: int,
    max_normal: int,
    max_anomaly: int,
) -> list[str]:
    selected: list[str] = []
    per_class: dict[str, int] = {class_name: 0 for class_name in wanted}
    selected_bytes = 0
    page_token: str | None = None
    pages = 0
    while True:
        page_token, rows = kaggle_files_page(dataset, page_token)
        pages += 1
        for row in rows:
            name = row.get("name", "")
            path = Path(name)
            class_name = class_from_path(path, wanted)
            if class_name is None or path.suffix.lower() not in IMAGE_EXTENSIONS:
                continue
            if "test" not in {part.lower() for part in path.parts}:
                continue
            allowed_max = max_normal if class_name == "normal" else max_anomaly
            if per_class[class_name] >= allowed_max:
                continue
            try:
                size = int(row.get("size", "0") or "0")
            except ValueError:
                size = 0
            if selected_bytes + size > limit_bytes:
                continue
            selected.append(name)
            per_class[class_name] += 1
            selected_bytes += size
        if all(per_class[class_name] >= (max_normal if class_name == "normal" else max_anomaly) for class_name in wanted):
            break
        if not page_token:
            break
    print(f"Selected {len(selected)} Kaggle files from {pages} listing pages.")
    for class_name in sorted(wanted):
        allowed_max = max_normal if class_name == "normal" else max_anomaly
        print(f"  {display_class_name(class_name)}: {per_class[class_name]}/{allowed_max}")
    return selected


def download_selected_kaggle_files(dataset: str, cache_dir: Path, selected_files: list[str]) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    for index, file_name in enumerate(selected_files, start=1):
        # Expected destination preserving the full relative path
        target = cache_dir / file_name
        if target.exists():
            continue

        # Also check if it was already downloaded but flattened (basename only)
        basename = Path(file_name).name
        flat_candidate = cache_dir / basename
        if flat_candidate.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            import shutil as _shutil
            _shutil.copy2(flat_candidate, target)
            continue

        target.parent.mkdir(parents=True, exist_ok=True)
        print(f"[{index}/{len(selected_files)}] Downloading {file_name}")
        try:
            subprocess.run(
                [
                    "kaggle",
                    "datasets",
                    "download",
                    dataset,
                    "--file",
                    file_name,
                    "--path",
                    str(cache_dir),
                    "--unzip",
                    "--quiet",
                ],
                check=True,
            )
        except subprocess.CalledProcessError as exc:
            print(f"  Warning: kaggle download failed for {file_name}: {exc}")
            continue

        # After download+unzip, kaggle CLI may place the file at:
        # 1. cache_dir / file_name  (full path preserved — ideal)
        # 2. cache_dir / basename   (flattened — common with --unzip)
        # 3. somewhere under cache_dir (deep search fallback)
        if not target.exists():
            # Try flat location first
            if flat_candidate.exists():
                _shutil.copy2(flat_candidate, target)
            else:
                # Deep search: find any file matching the basename
                basename_matches = list(cache_dir.rglob(basename))
                # Filter out the target itself to avoid false matches
                basename_matches = [m for m in basename_matches if m.resolve() != target.resolve()]
                if basename_matches:
                    import shutil as _shutil2
                    _shutil2.copy2(str(basename_matches[0]), target)
                else:
                    print(f"  Warning: could not locate downloaded file for {file_name}")
    return cache_dir


def download_partial_with_kaggle_cli(
    dataset: str,
    cache_dir: Path,
    wanted: set[str],
    limit_bytes: int,
    max_normal: int,
    max_anomaly: int,
) -> Path:
    print(f"Listing Kaggle dataset {dataset} and downloading only selected Test images...")
    selected = select_kaggle_files(dataset, wanted, limit_bytes, max_normal, max_anomaly)
    if not selected:
        raise SystemExit("No matching files were found in Kaggle listing.")
    return download_selected_kaggle_files(dataset, cache_dir, selected)


def main() -> int:
    args = parse_args()
    wanted = wanted_classes(args.classes)
    limit_bytes = args.max_mb * 1024 * 1024

    if args.source_dir:
        source_dir = Path(args.source_dir)
    else:
        if args.no_download:
            print("Error: --no-download was set but no --source-dir was provided.")
            return 1
        if args.use_kagglehub:
            source_dir = download_with_kagglehub(args.dataset)
        else:
            source_dir = download_partial_with_kaggle_cli(
                args.dataset,
                Path(args.cache_dir),
                wanted,
                limit_bytes,
                args.max_normal,
                args.max_anomaly,
            )

    if not has_matching_images(source_dir, wanted):
        print(f"No matching UCF-Crime image files found at {source_dir}.")
        print("Set VIDEO_AGENT_DATASET_SOURCE_DIR to a local Kaggle Test folder, or confirm Kaggle credentials can access the dataset.")
        return 1

    copied, total_bytes = copy_sampled_dataset(
        source_dir=source_dir,
        output_dir=Path(args.output),
        wanted_classes=wanted,
        limit_bytes=limit_bytes,
        max_normal=args.max_normal,
        max_anomaly=args.max_anomaly,
        city=args.city,
    )
    print(f"Prepared {copied} images, {total_bytes / (1024 * 1024):.1f} MB under {args.output}")
    return 0 if copied else 1


if __name__ == "__main__":
    raise SystemExit(main())
