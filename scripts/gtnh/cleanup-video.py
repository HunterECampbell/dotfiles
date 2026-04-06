#!/usr/bin/env python3
"""
cleanup-video.py — Run auto-editor to export a DaVinci Resolve timeline (XML) next to the source.

Does not re-encode the whole video in Python; auto-editor writes an XML you import in Resolve
(File → Import → Timeline… → FCP7 XML / “AAF, EDL, XML…” depending on Resolve version).

Dependencies: ffmpeg (auto-editor uses it), ffprobe, zenity for the GUI picker, auto-editor on PATH.
Install auto-editor: pip install --user auto-editor  (ensure ~/.local/bin is on PATH).

--edit syntax for stream index: https://auto-editor.com/ref/edit
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# auto-editor default loudness threshold for the `audio` edit method (see edit reference above).
DEFAULT_AUDIO_THRESHOLD = "0.04"
DEFAULT_MARGIN = "0.3s"
DEFAULT_AUDIO_STREAM = 1

SUBPROCESS_KW = {"text": True, "encoding": "utf-8", "errors": "replace"}


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


def require_cmd(name: str, install_hint: str) -> None:
    if not shutil.which(name):
        die(f"Missing '{name}'. {install_hint}")


def format_eta_human(seconds: float) -> str:
    s = max(0.0, seconds)
    if s < 60:
        return f"{int(s)}s"
    m = int(s // 60)
    rem = int(s % 60)
    if m < 60:
        return f"{m}m {rem}s" if rem else f"{m}m"
    h = m // 60
    m = m % 60
    return f"{h}h {m}m"


def format_elapsed_wall(seconds: float) -> str:
    s = max(0.0, seconds)
    if s < 60:
        return f"{s:.1f}s"
    return format_eta_human(s)


def pick_video_path() -> str | None:
    require_cmd("zenity", "Install with: sudo apt install zenity")
    start_dir = str(Path.home()) + os.sep
    cmd = [
        "zenity",
        "--file-selection",
        f"--filename={start_dir}",
        "--title=Select video",
        "--file-filter=Video files | *.mkv *.mp4 *.mov *.webm *.avi *.m4v",
        "--file-filter=All files | *",
    ]
    result = subprocess.run(cmd, capture_output=True, **SUBPROCESS_KW)
    if result.returncode != 0:
        return None
    path = (result.stdout or "").strip()
    return path or None


def count_audio_streams(media_path: str) -> int:
    require_cmd("ffprobe", "Install with: sudo apt install ffmpeg")
    cmd = [
        "ffprobe",
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_streams",
        "-select_streams",
        "a",
        media_path,
    ]
    result = subprocess.run(cmd, capture_output=True, **SUBPROCESS_KW)
    if result.returncode != 0:
        die(
            f"ffprobe failed for {media_path!r}.\n{result.stderr or '(no stderr)'}",
        )
    data = json.loads(result.stdout or "{}")
    streams = data.get("streams") or []
    return len(streams)


def resolve_audio_stream_index(num_streams: int, requested: int) -> int:
    if num_streams < 1:
        die("No audio streams found in file.")
    if num_streams == 1:
        if requested != 0:
            print(
                f"Note: only one audio stream; using [0] (not [{requested}]).",
                file=sys.stderr,
            )
        return 0
    if not (0 <= requested < num_streams):
        die(
            f"--audio-stream {requested} invalid; file has {num_streams} "
            f"audio stream(s) (indices 0–{num_streams - 1}).",
        )
    return requested


def build_edit_expression(stream_index: int) -> str:
    return f"audio:{DEFAULT_AUDIO_THRESHOLD},stream={stream_index}"


def run_auto_editor(input_path: str, margin: str, edit_expr: str) -> None:
    cmd = [
        "auto-editor",
        input_path,
        "--export",
        "resolve",
        "--margin",
        margin,
        "--edit",
        edit_expr,
    ]
    print(f"\nRunning: {' '.join(cmd)}\n", flush=True)
    # Let auto-editor draw its own progress; inherit stdout/stderr.
    result = subprocess.run(cmd)
    if result.returncode != 0:
        die(f"auto-editor exited with code {result.returncode}.")


def _run(args: argparse.Namespace) -> None:
    require_cmd("ffmpeg", "Install with: sudo apt install ffmpeg")
    require_cmd(
        "auto-editor",
        "Install with: pip install --user auto-editor "
        "and ensure ~/.local/bin is on your PATH.",
    )

    input_path = args.input
    if not input_path:
        input_path = pick_video_path()
        if not input_path:
            print("No file selected.", file=sys.stderr)
            sys.exit(0)

    if not os.path.isfile(input_path):
        die(f"File not found: {input_path}")

    n_audio = count_audio_streams(input_path)
    stream_idx = resolve_audio_stream_index(n_audio, args.audio_stream)
    edit_expr = build_edit_expression(stream_idx)

    print(
        f"\nAudio streams: {n_audio}; analyzing stream [{stream_idx}] "
        f"(margin {args.margin}).\n"
        "Output: Resolve XML beside the source (see auto-editor log for exact path).",
        flush=True,
    )

    run_auto_editor(input_path, args.margin, edit_expr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Export a DaVinci Resolve timeline via auto-editor (XML next to your file). "
            "Import in Resolve: File → Import → Timeline… (FCP7 / XML as offered)."
        ),
    )
    parser.add_argument(
        "input",
        nargs="?",
        default=None,
        help="Input video (optional: omit to open a file picker via zenity)",
    )
    parser.add_argument(
        "--margin",
        default=DEFAULT_MARGIN,
        help=f"auto-editor --margin (default: {DEFAULT_MARGIN!r})",
    )
    parser.add_argument(
        "--audio-stream",
        type=int,
        default=DEFAULT_AUDIO_STREAM,
        metavar="N",
        help=(
            "0-based audio stream for loud/silent detection (default: "
            f"{DEFAULT_AUDIO_STREAM} = second stream; single-stream files use [0])"
        ),
    )

    args = parser.parse_args()

    wall_start = time.time()
    print(
        f"Started: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(wall_start))}",
        flush=True,
    )
    try:
        _run(args)
    finally:
        wall_end = time.time()
        print(
            f"\nFinished: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(wall_end))}  "
            f"Total elapsed: {format_elapsed_wall(wall_end - wall_start)}",
            flush=True,
        )


if __name__ == "__main__":
    main()
