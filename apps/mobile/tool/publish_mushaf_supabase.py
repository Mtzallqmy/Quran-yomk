#!/usr/bin/env python3
"""Publish immutable Mushaf assets to a public Supabase Storage bucket.

The server key is read only from the environment. Existing objects are never
blindly overwritten: duplicate paths are downloaded and SHA-256 compared.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CACHE_CONTROL_SECONDS = "31536000"


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def request(url: str, *, method: str = "GET", data=None, headers=None):
    req = urllib.request.Request(url, method=method, data=data, headers=headers or {})
    return urllib.request.urlopen(req, timeout=180)


def public_url(project_url: str, bucket: str, object_name: str) -> str:
    quoted = "/".join(urllib.parse.quote(part) for part in object_name.split("/"))
    return f"{project_url}/storage/v1/object/public/{bucket}/{quoted}"


def upload_url(project_url: str, bucket: str, object_name: str) -> str:
    quoted = "/".join(urllib.parse.quote(part) for part in object_name.split("/"))
    return f"{project_url}/storage/v1/object/{bucket}/{quoted}"


def remote_sha256(project_url: str, bucket: str, object_name: str) -> str | None:
    digest = hashlib.sha256()
    try:
        with request(public_url(project_url, bucket, object_name)) as response:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    return digest.hexdigest()


def content_type(path: Path) -> str:
    overrides = {
        ".svg": "image/svg+xml",
        ".webp": "image/webp",
        ".json": "application/json",
        ".zip": "application/zip",
        ".txt": "text/plain",
    }
    return overrides.get(path.suffix.lower()) or mimetypes.guess_type(path.name)[0] or "application/octet-stream"


def upload_one(project_url: str, server_key: str, bucket: str, root: Path, path: Path) -> None:
    relative = path.relative_to(root).as_posix()
    local_sha = sha256_path(path)
    headers = {
        "Authorization": f"Bearer {server_key}",
        "apikey": server_key,
        "Content-Type": content_type(path),
        "cache-control": CACHE_CONTROL_SECONDS,
        "x-upsert": "false",
    }
    try:
        with path.open("rb") as handle:
            data = handle.read()
        with request(
            upload_url(project_url, bucket, relative),
            method="POST",
            data=data,
            headers=headers,
        ) as response:
            if response.status not in (200, 201):
                raise RuntimeError(f"unexpected upload status {response.status}: {relative}")
        print(f"uploaded {relative}")
        return
    except urllib.error.HTTPError as error:
        if error.code not in (400, 409):
            raise

    existing_sha = remote_sha256(project_url, bucket, relative)
    if existing_sha == local_sha:
        print(f"verified existing {relative}")
        return
    raise SystemExit(
        f"immutable object conflict at {relative}; publish a new asset version instead of overwriting"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--bucket", default="mushaf-assets")
    args = parser.parse_args()

    project_url = os.environ.get("SUPABASE_PROJECT_URL", "").rstrip("/")
    server_key = os.environ.get("SUPABASE_SERVER_KEY", "")
    if not project_url or not server_key:
        raise SystemExit(
            "SUPABASE_PROJECT_URL and SUPABASE_SERVER_KEY are required; configure the key as a GitHub Secret"
        )
    if not args.root.is_dir():
        raise SystemExit(f"publish root does not exist: {args.root}")

    paths = [path for path in args.root.rglob("*") if path.is_file()]
    # Manifests are commit markers for an edition, so upload them after their payloads.
    paths.sort(key=lambda path: (path.name == "manifest.json", path.as_posix()))
    for path in paths:
        upload_one(project_url, server_key, args.bucket, args.root, path)

    print(json.dumps({"status": "PASS", "bucket": args.bucket, "objects": len(paths)}))


if __name__ == "__main__":
    main()
