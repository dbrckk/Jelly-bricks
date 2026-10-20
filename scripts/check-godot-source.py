#!/usr/bin/env python3
"""Reject corrupted Godot source before editor import or Android export.

Text fetched through tool transports must be written byte-exactly: a stray
C0 control byte may be invisible in code review but abort Godot's parser.
Only inspect source formats; imported .png/.mp4/.import assets are excluded.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

TEXT_EXTENSIONS = {".gd", ".gdshader", ".tscn", ".tres", ".godot", ".cfg"}
ALLOWED_CONTROLS = {9, 10, 13}


def find_corruption(root: Path) -> list[str]:
    failures: list[str] = []
    if not root.is_dir():
        return [f"Missing Godot source directory: {root}"]
    paths = sorted(
        path for path in root.rglob("*")
        if path.is_file()
        and path.suffix in TEXT_EXTENSIONS
        and ".godot" not in path.parts
    )
    if not paths:
        return [f"No source files found in {root}"]
    for path in paths:
        data = path.read_bytes()
        try:
            data.decode("utf-8", errors="strict")
        except UnicodeDecodeError as error:
            failures.append(f"{path}: invalid UTF-8 byte at {error.start}")
        for offset, byte in enumerate(data):
            if byte < 32 and byte not in ALLOWED_CONTROLS:
                line = data.count(b"\n", 0, offset) + 1
                failures.append(f"{path}:{line}: forbidden control U+{byte:04X} at byte {offset}")
        if b"\xef\xbf\xbd" in data:
            failures.append(f"{path}: Unicode replacement character U+FFFD detected")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path("native-godot"))
    args = parser.parse_args()
    failures = find_corruption(args.root)
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    print(f"PASS: clean Godot source bytes in {args.root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
