#!/usr/bin/env zsh
# Remove silent stretches from a video using ffmpeg (voice track + silencedetect).
# Entry: clean-video (alias in .zshrc). Forwards all args to cleanup-video.py.
#
# Omit the input path to open a GTK file picker (zenity). Output defaults to
#   <same_dir>/<stem>_desilenced<ext> unless -o/--output is set.
#
# Flags (same as python script):
#   --voice-track N   0-based audio stream for detection (default: 0 if one stream, else 1)
#   --threshold DB    silence threshold in dB (default: -35)
#   --min-silence S   min silence length to cut in seconds (default: 1.5)
#   --padding S       keep this much audio around speech (default: 0.15)
#   --dry-run         print silence intervals only; no output file
#   -o / --output     explicit output path

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
