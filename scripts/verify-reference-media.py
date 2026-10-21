#!/usr/bin/env python3
"""Ensure the exact, original 2824.mp4 video remains recoverable in Git."""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "reference-media" / "2824-original.mp4"
SHA256 = "e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4"
SIZE = 2305045


def main() -> int:
    if not SOURCE.is_file():
        print("FAIL: original Jelly Bricks reference video is missing", file=sys.stderr)
        return 1
    actual_bytes = SOURCE.read_bytes()
    if len(actual_bytes) != SIZE:
        print(f"FAIL: changed original size {len(actual_bytes)} != {SIZE}", file=sys.stderr)
        return 1
    actual_hash = hashlib.sha256(actual_bytes).hexdigest()
    if actual_hash != SHA256:
        print("FAIL: 2824.mp4 no longer matches the original SHA-256", file=sys.stderr)
        return 1
    if b"ftyp" not in actual_bytes[:64]:
        print("FAIL: reference is not a valid MP4 file", file=sys.stderr)
        return 1
    required = [
        "2824-contact-sheet.png",
        "2824-stack.jpg",
        "2824-collapse.jpg",
        "README.md",
    ]
    for item in required:
        if not (SOURCE.parent / item).is_file():
            print(f"FAIL: missing supporting reference file {item}", file=sys.stderr)
            return 1
    print(f"PASS: original 2824.mp4 is recoverable, {SIZE} bytes, sha256={SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
