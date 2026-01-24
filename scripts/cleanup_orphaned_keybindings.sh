#!/usr/bin/env bash
# Cleanup orphaned custom keybindings from dconf
# Reports what was removed and what (if anything) replaced it

set -euo pipefail

CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

# Get registered custom keybindings
registered=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

# Get all existing custom directories
existing=$(dconf list "${CUSTOM_PATH}/" 2>/dev/null | grep -E '^custom[0-9]+/$' || true)

if [[ -z "$existing" ]]; then
  echo "No custom keybindings found."
  exit 0
fi

# Build maps of managed bindings for replacement detection
declare -A managed_names
declare -A managed_commands
for dir in $existing; do
  dir_path="${CUSTOM_PATH}/${dir}"
  if [[ "$registered" == *"${dir_path%/}/"* ]]; then
    binding=$(dconf read "${dir_path}binding" 2>/dev/null | tr -d "'" || echo "")
    name=$(dconf read "${dir_path}name" 2>/dev/null | tr -d "'" || echo "")
    cmd=$(dconf read "${dir_path}command" 2>/dev/null | tr -d "'" || echo "")
    if [[ -n "$binding" ]]; then
      managed_names["$binding"]="$name"
      managed_commands["$binding"]="$cmd"
    fi
  fi
done

# Find and remove orphaned entries
orphan_count=0
for dir in $existing; do
  dir_path="${CUSTOM_PATH}/${dir}"

  # Check if this is orphaned (not in registered list)
  if [[ "$registered" != *"${dir_path%/}/"* ]]; then
    # Get details before removing
    name=$(dconf read "${dir_path}name" 2>/dev/null | tr -d "'" || echo "(unknown)")
    binding=$(dconf read "${dir_path}binding" 2>/dev/null | tr -d "'" || echo "(unknown)")
    command=$(dconf read "${dir_path}command" 2>/dev/null | tr -d "'" || echo "(unknown)")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ORPHANED: ${dir%/}"
    echo "  Name:    $name"
    echo "  Binding: $binding"
    echo "  Command: $command"

    # Check if a managed keybinding uses the same binding
    if [[ -n "$binding" && -n "${managed_names[$binding]:-}" ]]; then
      echo "  REPLACED BY:"
      echo "    Name:    ${managed_names[$binding]}"
      echo "    Binding: $binding"
      echo "    Command: ${managed_commands[$binding]}"
    fi

    # Remove the orphaned entry
    dconf reset -f "$dir_path"
    echo "  STATUS: Removed"

    ((orphan_count++)) || true
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $orphan_count -eq 0 ]]; then
  echo "No orphaned keybindings found."
else
  echo "Cleaned up $orphan_count orphaned keybinding(s)."
fi
