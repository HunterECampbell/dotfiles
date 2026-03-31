#!/usr/bin/env python3
"""Patch a staged world's level.dat only: set allowCommands so cheats work (SP/LAN)."""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: gtnh_world_share_patch_level.py <world_directory>", file=sys.stderr)
        return 1
    world = Path(sys.argv[1])
    level = world / "level.dat"
    if not level.is_file():
        print(f"warning: no level.dat at {level}, skipping", file=sys.stderr)
        return 0
    try:
        import nbtlib
        from nbtlib import Byte
    except ImportError:
        print("error: nbtlib required (pip install nbtlib)", file=sys.stderr)
        return 1
    try:
        nbt = nbtlib.load(str(level))
    except Exception as e:
        print(f"error: failed to load {level}: {e}", file=sys.stderr)
        return 1
    data = nbt.get("Data")
    if data is None:
        print("error: level.dat missing Data compound", file=sys.stderr)
        return 1
    data["allowCommands"] = Byte(1)
    try:
        nbt.save()
    except Exception as e:
        print(f"error: failed to save {level}: {e}", file=sys.stderr)
        return 1
    print(f"Patched allowCommands=1 in staged {level.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
