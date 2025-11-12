#!/usr/bin/env bash
# Export comprehensive GNOME keybindings snapshot with disabled defaults.
#
# This script:
# 1. Reads allowed_keybindings.yml (the whitelist)
# 2. Queries ALL keybinding schemas from the system
# 3. Generates keybindings.yml with:
#    - Your allowed keybindings (from whitelist)
#    - ALL other keybindings set to disabled ([''])
#
# Regenerates: ansible/roles/gnome-settings/vars/keybindings.yml
# Based on: ansible/roles/gnome-settings/vars/allowed_keybindings.yml
#
# Notes:
# - Uses gsettings (must run inside a GNOME session / user bus).
# - Captures all keybinding schemas comprehensively
# - Disables all keybindings not in the allowed list

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWED_FILE="${REPO_ROOT}/ansible/roles/gnome-settings/vars/allowed_keybindings.yml"
OUT_FILE="${REPO_ROOT}/ansible/roles/gnome-settings/vars/keybindings.yml"
TMP_FILE="${OUT_FILE}.tmp"

# Schemas to scan for keybindings
keybinding_schemas=(
  "org.gnome.desktop.wm.keybindings"
  "org.gnome.settings-daemon.plugins.media-keys"
  "org.gnome.shell.keybindings"
  "org.gnome.mutter.keybindings"
  "org.gnome.mutter.wayland.keybindings"
)

command -v gsettings >/dev/null 2>&1 || { echo "gsettings not found (run inside GNOME session)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

if [[ ! -f "${ALLOWED_FILE}" ]]; then
  echo "ERROR: allowed_keybindings.yml not found at ${ALLOWED_FILE}"
  exit 1
fi

echo "Generating comprehensive GNOME keybindings snapshot -> ${OUT_FILE}"
echo "Using whitelist from: ${ALLOWED_FILE}"

# Write header
echo "---" > "${TMP_FILE}"
echo "# Generated GNOME keybindings snapshot (regenerated $(date -Iseconds))." >> "${TMP_FILE}"
echo "# Regenerate with: scripts/export_gnome_keybindings.sh" >> "${TMP_FILE}"
echo "# This list is applied by the gnome-settings role." >> "${TMP_FILE}"
echo "# " >> "${TMP_FILE}"
echo "# This file contains ALL GNOME keybindings:" >> "${TMP_FILE}"
echo "#   - Allowed keybindings (from allowed_keybindings.yml) with their values" >> "${TMP_FILE}"
echo "#   - All other keybindings set to disabled ([''])" >> "${TMP_FILE}"
echo "gnome_keybindings:" >> "${TMP_FILE}"
echo >> "${TMP_FILE}"

# Helper function to check if schema exists
have_schema() {
  gsettings list-schemas | grep -qx "$1"
}

# Helper function to convert schema.key to dconf path
schema_key_to_path() {
  local schema="$1"
  local key="$2"
  echo "/$schema/$key" | tr '.' '/'
}

# Parse allowed keybindings using Python to handle YAML properly
echo "Parsing allowed keybindings..."
ALLOWED_KEYS=$(python3 -c "
import yaml
import sys

with open('${ALLOWED_FILE}', 'r') as f:
    data = yaml.safe_load(f)

allowed = data.get('allowed_keybindings', [])
for item in allowed:
    schema = item.get('schema', '')
    key = item.get('key', '')
    if schema and key:
        # Convert schema.key to path format
        path = '/' + schema.replace('.', '/') + '/' + key
        print(path)
")

# Create associative array of allowed paths
declare -A allowed_paths
while IFS= read -r path; do
  [[ -n "$path" ]] && allowed_paths["$path"]=1
done <<< "$ALLOWED_KEYS"

echo "Found ${#allowed_paths[@]} allowed keybindings"

# Function to emit a keybinding entry
emit_kv() {
  local key_path="$1"
  local value="$2"
  # Escape double quotes inside value for YAML double-quoted string
  local esc
  esc=$(printf "%s" "$value" | sed 's/"/\\"/g')
  printf "  - { key: \"%s\", value: \"%s\" }\n" "$key_path" "$esc" >> "${TMP_FILE}"
}

# Process allowed keybindings first (with their actual values)
echo "Writing allowed keybindings..."
python3 - "${ALLOWED_FILE}" "${TMP_FILE}" <<'PYTHON_WRITE'
import yaml
import sys

with open(sys.argv[1], 'r') as f:
    data = yaml.safe_load(f)

allowed = data.get('allowed_keybindings', [])
with open(sys.argv[2], 'a') as out:
    for item in allowed:
        schema = item.get('schema', '')
        key = item.get('key', '')
        value = item.get('value', '')
        if schema and key and value:
            path = '/' + schema.replace('.', '/') + '/' + key
            # Escape quotes for YAML
            esc_value = value.replace('"', '\\"')
            out.write(f'  - {{ key: "{path}", value: "{esc_value}" }}\n')
PYTHON_WRITE

# Now process all schemas and disable keybindings not in allowed list
echo "Scanning schemas and disabling non-allowed keybindings..."
for schema in "${keybinding_schemas[@]}"; do
  if ! have_schema "${schema}"; then
    echo "  Schema ${schema} not found, skipping..."
    continue
  fi

  echo "  Processing schema: ${schema}"

  # Get all keys from the schema
  gsettings list-keys "${schema}" | while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    # Convert to path format
    path=$(schema_key_to_path "${schema}" "${key}")

    # Skip if this is in the allowed list
    if [[ -n "${allowed_paths[$path]:-}" ]]; then
      continue
    fi

    # Get the current value to check if it's a keybinding (array format)
    current_value=$(gsettings get "${schema}" "${key}" 2>/dev/null || echo "")

    # Only process if it looks like a keybinding (starts with [ or @as)
    if [[ "$current_value" == \[* ]] || [[ "$current_value" == "@as"* ]]; then
      # Disable this keybinding
      emit_kv "${path}" "['']"
    fi
  done
done

# Handle custom keybindings specially - we need to preserve the list structure
# The custom-keybindings key itself should be in allowed list if you have custom shortcuts
# But we need to make sure we don't disable the individual custom keybinding schemas

mv "${TMP_FILE}" "${OUT_FILE}"
echo
echo "✓ Comprehensive keybindings snapshot written to ${OUT_FILE}"
echo "  Total allowed keybindings: ${#allowed_paths[@]}"
echo "  All other keybindings have been disabled"

# Git status hint
if command -v git >/dev/null 2>&1; then
  (cd "${REPO_ROOT}" && git add "${OUT_FILE}" >/dev/null 2>&1 || true)
  echo "  Added to git index (if repository). Remember to commit."
fi

echo
read -r -p "Apply updated keybindings now via Ansible? (runs: ansible-playbook ansible/playbook.yml --tags gnome-settings) [y/N]: " reply
case "${reply}" in
  [yY][eE][sS]|[yY])
    # Resolve ansible-playbook: prefer PATH, then repo .venv, else abort.
    ANSIBLE_PLAYBOOK_BIN="ansible-playbook"
    if ! command -v ansible-playbook >/dev/null 2>&1; then
      if [ -x "${REPO_ROOT}/.venv/bin/ansible-playbook" ]; then
        ANSIBLE_PLAYBOOK_BIN="${REPO_ROOT}/.venv/bin/ansible-playbook"
        echo "Using virtualenv ansible-playbook at ${ANSIBLE_PLAYBOOK_BIN}"
      else
        echo "ansible-playbook not found in PATH or ${REPO_ROOT}/.venv/bin/. Run bootstrap.sh first. Skipping apply."
        echo "Done."
        exit 0
      fi
    fi
    (
      cd "${REPO_ROOT}" && \
      "${ANSIBLE_PLAYBOOK_BIN}" ansible/playbook.yml --tags gnome-settings
    )
    ;;
  *)
    echo "Skipped apply."
    ;;
esac

echo "Done."
