#!/usr/bin/env bash
# Export full GNOME keybindings snapshot into Ansible vars file.
# Hybrid workflow: committed snapshot + regeneration script.
#
# Regenerates: ansible/roles/gnome-settings/vars/keybindings.yml
#
# Notes:
# - Uses gsettings (must run inside a GNOME session / user bus).
# - Captures:
#   * custom keybindings (and their parent list)
#   * org.gnome.desktop.wm.keybindings (all array keys)
#   * org.gnome.settings-daemon.plugins.media-keys (array keys)
#   * org.gnome.shell.keybindings (if schema present)
#   * org.gnome.mutter.keybindings (if schema present)
# - Only array-valued keys (start with '[') are included for the non-custom schemas.
# - Keeps quoting in dconf format (so Ansible dconf module can apply verbatim).
#
# After generation you are prompted to optionally apply via Ansible.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="${REPO_ROOT}/ansible/roles/gnome-settings/vars/keybindings.yml"
TMP_FILE="${OUT_FILE}.tmp"

schemas_required=(
  "org.gnome.desktop.wm.keybindings"
  "org.gnome.settings-daemon.plugins.media-keys"
)

schemas_optional=(
  "org.gnome.shell.keybindings"
  "org.gnome.mutter.keybindings"
)

command -v gsettings >/dev/null 2>&1 || { echo "gsettings not found (run inside GNOME session)"; exit 1; }

echo "Generating GNOME keybindings snapshot -> ${OUT_FILE}"

echo "---" > "${TMP_FILE}"
echo "# Generated GNOME keybindings snapshot (regenerated $(date -Iseconds))." >> "${TMP_FILE}"
echo "# Regenerate with: scripts/export_gnome_keybindings.sh" >> "${TMP_FILE}"
echo "# This list is applied by the gnome-settings role." >> "${TMP_FILE}"
echo "gnome_keybindings:" >> "${TMP_FILE}"
echo >> "${TMP_FILE}"

have_schema () {
  gsettings list-schemas | grep -qx "$1"
}

emit_kv () {
  local key_path="$1"
  local value="$2"
  # Escape double quotes inside value for YAML double-quoted string
  local esc
  esc=$(printf "%s" "$value" | sed 's/"/\\"/g')
  printf "  - { key: \"%s\", value: \"%s\" }\n" "$key_path" "$esc" >> "${TMP_FILE}"
}

# 1. Custom keybindings (parent list + each entry)
custom_parent_schema="org.gnome.settings-daemon.plugins.media-keys"
parent_list=$(gsettings get "${custom_parent_schema}" custom-keybindings || true)

if [[ -n "${parent_list}" && "${parent_list}" != "@as []" ]]; then
  emit_kv "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings" "${parent_list}"

  # Strip brackets and split
  # parent_list looks like: ['path1/', 'path2/']
  cleaned=$(printf "%s" "${parent_list}" | sed "s/^\[//; s/\]$//")
  # Split by comma respecting quotes
  IFS=',' read -r -a paths <<< "${cleaned}"
  for raw in "${paths[@]}"; do
    p=$(printf "%s" "$raw" | sed "s/^ *'//; s/' *$//")
    [[ -z "$p" ]] && continue
    # Ensure trailing slash retained
    case "$p" in
      */) : ;;
      *) p="${p}/" ;;
    esac
    schema_rel="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    for field in binding command name; do
      val=$(gsettings get "${schema_rel}:${p}" "${field}" || true)
      [[ -z "$val" ]] && continue
      emit_kv "${p}${field}" "${val}"
    done
  done
fi

# 2. Function to dump array-valued keys from a schema
dump_array_keys () {
  local schema="$1"
  local prefix
  prefix="/$(echo "${schema}" | tr '.' '/')/"
  gsettings list-recursively "${schema}" | while IFS= read -r line; do
    # line format: schema key value...
    local s k rest
    s=$(printf "%s" "$line" | awk '{print $1}')
    k=$(printf "%s" "$line" | awk '{print $2}')
    rest=${line#"$s $k "}
    # Keep only array styled values (start with [)
    [[ "${rest}" == \[* ]] || continue
    emit_kv "${prefix}${k}" "${rest}"
  done
}

# 3. Required schemas
for sch in "${schemas_required[@]}"; do
  if have_schema "${sch}"; then
    dump_array_keys "${sch}"
  else
    echo "WARNING: required schema ${sch} not found (skipping)" >&2
  fi
done

# 4. Optional schemas
for sch in "${schemas_optional[@]}"; do
  if have_schema "${sch}"; then
    dump_array_keys "${sch}"
  fi
done

mv "${TMP_FILE}" "${OUT_FILE}"
echo "Snapshot written to ${OUT_FILE}"

# Git status hint
if command -v git >/dev/null 2>&1; then
  (cd "${REPO_ROOT}" && git add "${OUT_FILE}" >/dev/null 2>&1 || true)
  echo "Added to git index (if repository). Remember to commit."
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
