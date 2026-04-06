#!/usr/bin/env python3
"""
cleanup-video.py — Remove silent pauses from video based on one audio track (e.g. voice).

Cuts apply to all streams; silence is detected on the chosen audio track only.
The original file is never modified.

Dependencies: ffmpeg, ffprobe, zenity for the GUI picker (sudo apt install zenity).
With no input path, the picker opens in your home directory (~).

Examples:
    clean-video                              # zenity picker, then process
    clean-video --dry-run                    # picker or use explicit path after flags
    clean-video /path/to/recording.mkv
    clean-video recording.mkv --voice-track 0 --threshold -40
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DEFAULT_THRESHOLD_DB = -35.0
DEFAULT_MIN_SILENCE = 1.5
DEFAULT_PADDING = 0.15
DEFAULT_VOICE_TRACK_MULTI = 1

SUBPROCESS_KW = {"text": True, "encoding": "utf-8", "errors": "replace"}


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


def require_cmd(name: str, install_hint: str) -> None:
    if not shutil.which(name):
        die(f"Missing '{name}'. {install_hint}")


def run_cmd(cmd: list[str], capture: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(cmd, capture_output=capture, **SUBPROCESS_KW)
    if result.returncode != 0 and capture:
        print(f"Error running: {' '.join(cmd)}", file=sys.stderr)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        sys.exit(1)
    return result


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


def get_audio_tracks(input_file: str) -> list[dict]:
    cmd = [
        "ffprobe",
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_streams",
        "-select_streams",
        "a",
        input_file,
    ]
    result = run_cmd(cmd)
    data = json.loads(result.stdout)
    return data.get("streams", [])


def detect_silence(
    input_file: str,
    voice_track_index: int,
    threshold_db: float,
    min_silence_duration: float,
) -> list[tuple[float, float | None]]:
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-i",
        input_file,
        "-map",
        f"0:a:{voice_track_index}",
        "-af",
        f"silencedetect=n={threshold_db}dB:d={min_silence_duration}",
        "-f",
        "null",
        "-",
    ]
    result = subprocess.run(cmd, capture_output=True, **SUBPROCESS_KW)
    stderr = result.stderr or ""

    silence_starts: list[float] = []
    silence_ends: list[float] = []

    for line in stderr.split("\n"):
        match_start = re.search(r"silence_start:\s*([\d.]+)", line)
        if match_start:
            silence_starts.append(float(match_start.group(1)))
        match_end = re.search(r"silence_end:\s*([\d.]+)", line)
        if match_end:
            silence_ends.append(float(match_end.group(1)))

    intervals: list[tuple[float, float | None]] = []
    for i in range(len(silence_ends)):
        start = silence_starts[i] if i < len(silence_starts) else 0.0
        end = silence_ends[i]
        intervals.append((start, end))

    if len(silence_starts) > len(silence_ends):
        intervals.append((silence_starts[-1], None))

    if result.returncode != 0 and not intervals:
        die(f"ffmpeg silencedetect failed (exit {result.returncode}).\n{stderr[:2000]}")

    return intervals


def get_duration(input_file: str) -> float:
    cmd = [
        "ffprobe",
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_format",
        input_file,
    ]
    result = run_cmd(cmd)
    data = json.loads(result.stdout)
    return float(data["format"]["duration"])


def compute_segments(
    silence_intervals: list[tuple[float, float | None]],
    total_duration: float,
    padding: float,
) -> list[tuple[float, float]]:
    keep_segments: list[tuple[float, float]] = []

    if not silence_intervals:
        return [(0, total_duration)]

    first_silence_start = silence_intervals[0][0]
    if first_silence_start > 0:
        keep_segments.append((0, first_silence_start))

    for i in range(len(silence_intervals) - 1):
        current_end = silence_intervals[i][1]
        next_start = silence_intervals[i + 1][0]
        if current_end is not None and next_start > current_end:
            keep_segments.append((current_end, next_start))

    last_silence_end = silence_intervals[-1][1]
    if last_silence_end is not None and last_silence_end < total_duration:
        keep_segments.append((last_silence_end, total_duration))

    padded: list[tuple[float, float]] = []
    for start, end in keep_segments:
        padded_start = max(0, start - padding)
        padded_end = min(total_duration, end + padding)
        padded.append((padded_start, padded_end))

    if not padded:
        return []

    merged = [padded[0]]
    for start, end in padded[1:]:
        prev_start, prev_end = merged[-1]
        if start <= prev_end:
            merged[-1] = (prev_start, max(prev_end, end))
        else:
            merged.append((start, end))

    return merged


def format_eta_human(seconds: float) -> str:
    """Short ETA string for linear segment-average estimate."""
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
    """Wall-clock duration for run summary (sub-minute shows one decimal)."""
    s = max(0.0, seconds)
    if s < 60:
        return f"{s:.1f}s"
    return format_eta_human(s)


def segment_progress_line(
    done: int,
    total: int,
    bar_width: int = 20,
    eta_seconds: float | None = None,
) -> str:
    """ASCII bar for segment encode progress (done/total complete)."""
    if total <= 0:
        return f"[{'#' * bar_width}] 0/0 (100%)"
    pct = min(100, int(100 * done / total))
    filled = min(bar_width, (done * bar_width + total - 1) // total)
    bar = "#" * filled + "-" * (bar_width - filled)
    line = f"[{bar}] {done}/{total} ({pct}%)"
    if eta_seconds is not None and 0 < done < total:
        line += f"  ~{format_eta_human(eta_seconds)} left"
    return line


def build_output(input_file: str, output_file: str, segments: list[tuple[float, float]]) -> None:
    if not segments:
        die("No non-silent segments found. Nothing to output.")

    total_seg = len(segments)
    print(f"Cutting {total_seg} segments (this can take a while)...", flush=True)

    t0 = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="cleanup_video_") as tmpdir:
        segment_files: list[str] = []
        for i, (start, end) in enumerate(segments):
            duration = end - start
            seg_file = os.path.join(tmpdir, f"seg_{i:04d}.mkv")
            segment_files.append(seg_file)

            cmd = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "warning",
                "-i",
                input_file,
                "-ss",
                str(start),
                "-t",
                str(duration),
                "-map",
                "0",
                "-c:v",
                "libx264",
                "-preset",
                "ultrafast",
                "-crf",
                "18",
                "-c:a",
                "aac",
                "-b:a",
                "192k",
                "-avoid_negative_ts",
                "make_zero",
                seg_file,
            ]
            result = subprocess.run(cmd, capture_output=True, **SUBPROCESS_KW)
            if result.returncode != 0:
                print(file=sys.stderr)
                die(
                    f"ffmpeg failed cutting segment {i + 1}/{total_seg} "
                    f"({start:.2f}s–{end:.2f}s).\n"
                    f"{result.stderr or '(no stderr)'}",
                )
            done = i + 1
            elapsed = time.perf_counter() - t0
            eta: float | None = None
            if done < total_seg:
                eta = (elapsed / done) * (total_seg - done)
            print(
                f"\rCutting {segment_progress_line(done, total_seg, eta_seconds=eta)}",
                end="",
                flush=True,
            )

        print(flush=True)

        concat_file = os.path.join(tmpdir, "concat.txt")
        with open(concat_file, "w", encoding="utf-8") as f:
            for seg in segment_files:
                f.write(f"file '{seg}'\n")

        print("Joining segments...")
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            concat_file,
            "-map",
            "0",
            "-c",
            "copy",
            output_file,
        ]
        result = subprocess.run(cmd, capture_output=True, **SUBPROCESS_KW)
        if result.returncode != 0:
            die(f"Error concatenating:\n{result.stderr or '(no stderr)'}")

    print(f"Done: {output_file}")


def format_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = seconds % 60
    return f"{h}:{m:02d}:{s:05.2f}"


def resolve_voice_track(
    args_voice: int | None,
    num_tracks: int,
) -> int:
    if args_voice is not None:
        if not (0 <= args_voice < num_tracks):
            die(f"--voice-track {args_voice} invalid; file has {num_tracks} audio stream(s) (0–{num_tracks - 1}).")
        return args_voice
    if num_tracks == 1:
        return 0
    idx = DEFAULT_VOICE_TRACK_MULTI
    if idx < num_tracks:
        return idx
    return 0


def _run(args: argparse.Namespace) -> None:
    require_cmd("ffmpeg", "Install with: sudo apt install ffmpeg")
    require_cmd("ffprobe", "Install with: sudo apt install ffmpeg")

    input_path = args.input
    if not input_path:
        input_path = pick_video_path()
        if not input_path:
            print("No file selected.", file=sys.stderr)
            sys.exit(0)

    if not os.path.isfile(input_path):
        die(f"File not found: {input_path}")

    tracks = get_audio_tracks(input_path)
    if not tracks:
        die("No audio tracks found in file.")

    print(f"\nFound {len(tracks)} audio track(s):")
    for i, track in enumerate(tracks):
        codec = track.get("codec_name", "unknown")
        channels = track.get("channels", "?")
        channel_layout = track.get("channel_layout", "")
        tags = track.get("tags", {})
        title = tags.get("title", "")
        label = f"  [{i}] {codec}, {channels}ch"
        if channel_layout:
            label += f" ({channel_layout})"
        if title:
            label += f' — "{title}"'
        print(label)

    voice_track = resolve_voice_track(args.voice_track, len(tracks))
    if len(tracks) == 1:
        print("\nOnly one audio track; using [0].")
    elif args.voice_track is None:
        print(f"\nUsing track [{voice_track}] for silence detection (default for multi-track).")

    print(
        f"\nAnalyzing track [{voice_track}] for silence "
        f"(threshold: {args.threshold}dB, min duration: {args.min_silence}s)...",
    )

    silence_intervals = detect_silence(
        input_path,
        voice_track,
        args.threshold,
        args.min_silence,
    )

    if not silence_intervals:
        print(
            "No silence detected with current settings. "
            "Try raising --threshold or lowering --min-silence.",
        )
        sys.exit(0)

    total_duration = get_duration(input_path)

    total_silence = sum(
        (end or total_duration) - start for start, end in silence_intervals
    )

    print(f"\nFound {len(silence_intervals)} silent sections totaling {format_time(total_silence)}")
    print(f"Original duration:  {format_time(total_duration)}")
    print(f"Estimated output:   {format_time(total_duration - total_silence)}")
    print(
        f"Time saved:         {format_time(total_silence)} "
        f"({total_silence / total_duration * 100:.1f}%)",
    )

    if args.dry_run:
        print("\n--- Silence intervals ---")
        for i, (start, end) in enumerate(silence_intervals):
            end_str = format_time(end) if end else "EOF"
            dur = (end or total_duration) - start
            print(f"  {i + 1:3d}. {format_time(start)} -> {end_str}  ({dur:.2f}s)")
        print("\nDry run complete. No files created.")
        sys.exit(0)

    segments = compute_segments(silence_intervals, total_duration, args.padding)

    if args.output:
        output_file = args.output
    else:
        p = Path(input_path)
        output_file = str(p.parent / f"{p.stem}_desilenced{p.suffix}")

    if os.path.exists(output_file):
        print(f"\nOutput file already exists: {output_file}")
        try:
            confirm = input("Overwrite? [y/N]: ").strip().lower()
            if confirm != "y":
                print("Aborted.")
                sys.exit(0)
        except (EOFError, KeyboardInterrupt):
            print("\nAborted.")
            sys.exit(0)

    print()
    build_output(input_path, output_file, segments)

    if os.path.isfile(output_file):
        out_sz = os.path.getsize(output_file) / (1024 * 1024)
        in_sz = os.path.getsize(input_path) / (1024 * 1024)
        print(f"\nInput:  {in_sz:.1f} MB")
        print(f"Output: {out_sz:.1f} MB")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove silent pauses from video based on a specific audio track.",
    )
    parser.add_argument(
        "input",
        nargs="?",
        default=None,
        help="Input video (optional: omit to open a file picker via zenity)",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output file (default: <input_stem>_desilenced.<ext> next to input)",
    )
    parser.add_argument(
        "--voice-track",
        type=int,
        default=None,
        metavar="N",
        help=(
            f"0-based audio stream for silence detection (default: 0 if one stream, "
            f"else {DEFAULT_VOICE_TRACK_MULTI} i.e. second stream)"
        ),
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD_DB,
        help=f"Silence threshold in dB (default: {DEFAULT_THRESHOLD_DB}). More negative = stricter.",
    )
    parser.add_argument(
        "--min-silence",
        type=float,
        default=DEFAULT_MIN_SILENCE,
        help=f"Minimum silence duration in seconds to cut (default: {DEFAULT_MIN_SILENCE})",
    )
    parser.add_argument(
        "--padding",
        type=float,
        default=DEFAULT_PADDING,
        help=f"Padding in seconds around kept speech (default: {DEFAULT_PADDING})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show silence intervals and stats; do not write output",
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
