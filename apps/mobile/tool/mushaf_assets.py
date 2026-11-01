#!/usr/bin/env python3
"""Build and verify immutable Mushaf page asset metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

PAGE_COUNT = 604


def verse_keys(values: list[dict]) -> set[tuple[int, int]]:
    return {
        (int(value["surahNumber"]), int(value["ayahNumber"]))
        for value in values
        if value.get("surahNumber") and value.get("ayahNumber")
    }


def split_bounds(source: Path, destination: Path) -> None:
    values = json.loads(source.read_text(encoding="utf-8"))
    pages: dict[int, list[dict]] = {page: [] for page in range(1, PAGE_COUNT + 1)}
    for value in values:
        pages[int(value["page"])].append(value)
    destination.mkdir(parents=True, exist_ok=True)
    for page, bounds in pages.items():
        (destination / f"{page:03}.json").write_text(
            json.dumps(bounds, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )


def validate(normal_root: Path, tajweed_root: Path) -> None:
    for page in range(1, PAGE_COUNT + 1):
        number = f"{page:03}"
        svg = normal_root / "svg" / f"{number}.svg"
        normal_json = normal_root / "json" / f"{number}.json"
        webp = tajweed_root / "pages" / f"{number}.webp"
        tajweed_json = tajweed_root / "bounds" / f"{number}.json"
        for path in (svg, normal_json, webp, tajweed_json):
            if not path.is_file() or path.stat().st_size == 0:
                raise SystemExit(f"missing Mushaf asset: {path}")
        if b"<svg" not in svg.read_bytes()[:1024]:
            raise SystemExit(f"invalid SVG page: {page}")
        data = webp.read_bytes()[:12]
        if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            raise SystemExit(f"invalid WebP page: {page}")
        normal = json.loads(normal_json.read_text(encoding="utf-8"))
        tajweed = json.loads(tajweed_json.read_text(encoding="utf-8"))
        if verse_keys(normal) != verse_keys(tajweed):
            missing_tajweed = sorted(verse_keys(normal) - verse_keys(tajweed))
            missing_normal = sorted(verse_keys(tajweed) - verse_keys(normal))
            raise SystemExit(
                f"page {page} verse mapping mismatch; "
                f"tajweed missing={missing_tajweed}, normal missing={missing_normal}"
            )
    print("MUSHAF_ASSETS_604_PAGE_MAPPING: PASS")


def write_manifest(
    root: Path,
    version: str,
    edition: str,
    generated_at: str | None = None,
) -> None:
    files: dict[str, dict[str, int | str]] = {}
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.name != "manifest.json":
            files[path.relative_to(root).as_posix()] = {
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "size": path.stat().st_size,
            }
    expected_pages = {f"pages/{page:03}" for page in range(1, PAGE_COUNT + 1)}
    actual_pages = {str(Path(name).with_suffix("")) for name in files if name.startswith("pages/")}
    if actual_pages != expected_pages:
        missing = sorted(expected_pages - actual_pages)
        extra = sorted(actual_pages - expected_pages)
        raise SystemExit(f"manifest page set mismatch; missing={missing[:5]} extra={extra[:5]}")
    expected_bounds = {f"bounds/{page:03}" for page in range(1, PAGE_COUNT + 1)}
    actual_bounds = {str(Path(name).with_suffix("")) for name in files if name.startswith("bounds/")}
    if actual_bounds != expected_bounds:
        missing = sorted(expected_bounds - actual_bounds)
        extra = sorted(actual_bounds - expected_bounds)
        raise SystemExit(f"manifest bounds set mismatch; missing={missing[:5]} extra={extra[:5]}")
    manifest = {
        "schema": 2,
        "version": version,
        "edition": edition,
        "pageCount": PAGE_COUNT,
        "generatedAt": generated_at
        or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "files": files,
    }
    (root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    split = subparsers.add_parser("split-bounds")
    split.add_argument("source", type=Path)
    split.add_argument("destination", type=Path)
    check = subparsers.add_parser("validate")
    check.add_argument("normal_root", type=Path)
    check.add_argument("tajweed_root", type=Path)
    manifest = subparsers.add_parser("manifest")
    manifest.add_argument("root", type=Path)
    manifest.add_argument("--version", default="v1")
    manifest.add_argument("--edition", required=True, choices=("hafs", "tajweed"))
    manifest.add_argument("--generated-at")
    args = parser.parse_args()
    if args.command == "split-bounds":
        split_bounds(args.source, args.destination)
    elif args.command == "validate":
        validate(args.normal_root, args.tajweed_root)
    else:
        write_manifest(args.root, args.version, args.edition, args.generated_at)


if __name__ == "__main__":
    main()
