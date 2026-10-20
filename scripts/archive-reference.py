#!/usr/bin/env python3
"""Stage an ORIGINAL user reference for durable, verifiable GitHub archiving.

Usage:
    python scripts/archive-reference.py /path/to/photo-or-video.mp4 \
        --note "Visual reference" --push

Requires an authenticated git remote when --push is used.
Never compresses, transforms or uploads a preview instead of the original.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

MAX_DIRECT_GIT_BYTES = 10 * 1024 * 1024
MAX_GIT_FILE_BYTES = 95 * 1024 * 1024
MEDIA_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif", ".heic",
    ".mp4", ".mov", ".webm", ".mkv", ".m4v", ".avi",
    ".wav", ".mp3", ".ogg", ".flac", ".pdf",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip(".-")
    return cleaned[:120] or "reference.bin"


def git(root: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=root, check=True)


def archive(root: Path, source: Path, note: str, date: str) -> tuple[Path, Path, bool]:
    root = root.resolve()
    source = source.resolve(strict=True)
    if not source.is_file() or source.suffix.lower() not in MEDIA_EXTENSIONS:
        raise ValueError("Use a real photo, video, audio, or PDF file as original")
    size = source.stat().st_size
    if size == 0 or size > MAX_GIT_FILE_BYTES:
        raise ValueError("Empty or oversized input; use a GitHub Release asset for files >= 95 MiB")
    digest = sha256(source)
    relative = Path("references/media") / date / (digest[:12] + "-" + safe_name(source.name))
    destination = root / relative
    catalog_path = root / "references/catalog" / (date + "-" + digest[:12] + ".json")
    existing = destination.exists()
    if existing and (destination.stat().st_size != size or sha256(destination) != digest):
        raise ValueError("Reference destination exists with different bytes")
    if not existing:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    if sha256(destination) != digest:
        raise ValueError("SHA-256 mismatch after copying original; aborting")
    meta = {
        "date": date,
        "original_filename": source.name,
        "original_relative_path": relative.as_posix(),
        "sha256": digest,
        "size_bytes": size,
        "note": note,
        "github_original_status": "staged_locally_not_verified_online",
        "kind": source.suffix.lower().lstrip("."),
        "source_preserved_without_transcoding": True,
    }
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    if catalog_path.exists():
        previous = json.loads(catalog_path.read_text(encoding="utf-8"))
        if previous.get("sha256") != digest:
            raise ValueError("Catalog ID collision; preserving the previous reference")
        return destination, catalog_path, size > MAX_DIRECT_GIT_BYTES
    catalog_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")
    return destination, catalog_path, size > MAX_DIRECT_GIT_BYTES


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Unmodified original reference")
    parser.add_argument("--note", default="User-supplied visual reference")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--date", default=dt.date.today().isoformat())
    parser.add_argument("--push", action="store_true", help="Commit and push the binary + catalog")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
        parser.error("--date must be YYYY-MM-DD")
    try:
        original, catalog, lfs = archive(args.root, args.source, args.note, args.date)
        root = args.root.resolve()
        if lfs:
            if shutil.which("git-lfs") is None:
                raise RuntimeError("Git LFS required for references larger than 10 MiB")
            git(root, "lfs", "install", "--local")
            git(root, "lfs", "track", f"*{original.suffix.lower()}")
        if args.push:
            if shutil.which("git") is None:
                raise RuntimeError("Git must be installed before pushing to GitHub")
            staged = [str(original.relative_to(root)), str(catalog.relative_to(root))]
            if lfs:
                staged.append(".gitattributes")
            git(root, "add", "--", *staged)
            # Use a distinct commit, keeping the original and its metadata atomic.
            git(root, "commit", "-m", f"assets(reference): preserve {original.name}")
            git(root, "push")
            print("Git push succeeded; verify GitHub blob/Release URL before recording archived status.")
        else:
            print("Staged only; no GitHub upload. Re-run with --push in an authenticated clone.")
        print("Original:", original.relative_to(root))
        print("Catalog:", catalog.relative_to(root))
        print("SHA-256:", sha256(original))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"Reference archive FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
