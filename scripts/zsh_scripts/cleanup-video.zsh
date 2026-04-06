#!/usr/bin/env zsh
# DaVinci Resolve prep: run auto-editor (--export resolve) on a video via cleanup-video.py.
# Entry: clean-video (alias in .zshrc). Forwards all args to the Python script.
#
# Omit the input path to open a GTK file picker (zenity) starting in ~.
#
# Options (see cleanup-video.py --help):
#   --margin STR       auto-editor margin (default: 0.3s)
#   --audio-stream N   0-based stream for detection (default: 1; single-stream files use 0)
#
# Output: Resolve XML beside the source — import in Resolve (File → Import → Timeline… / XML).

function cleanup-video() {
  local _cleanup_video_py="${${(%):-%x}:A:h}/../gtnh/cleanup-video.py"
  if [[ ! -f "$_cleanup_video_py" ]]; then
    echo "cleanup-video: missing script: $_cleanup_video_py" >&2
    return 1
  fi
  if ! command -v python3 &>/dev/null; then
    echo "cleanup-video: python3 not found in PATH" >&2
    return 1
  fi
  python3 "$_cleanup_video_py" "$@"
}
