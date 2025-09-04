#!/usr/bin/env bash
# scripts/gnome_export_extensions_ansible.sh
#
# Purpose:
#   Export current GNOME Shell extension settings into an Ansible dconf task snippet
#   (compatible with the community.general.dconf module loop structure already used
#   in roles/gnome-settings/tasks/main.yml).
#
# What it does:
#   1. Lists enabled extensions (for reference).
#   2. Dumps current dconf subtree under /org/gnome/shell/extensions/
#   3. Converts that dump into YAML list items of the form:
#        - { key: "/org/gnome/shell/extensions/<section>/<key>", value: "<value>" }
#   4. Writes result to stdout (you can redirect into a temporary file, then manually
#      curate / prune keys you *actually* want to enforce).
#
# Notes / Caveats:
#   - This exports ALL currently set keys for all extensions; many are defaults.
#     You should *curate* the output to keep only opinionated deviations to avoid churn.
#   - Determining "non-default" requires comparison against schema defaults. This script
#     intentionally avoids complex schema diff logic and leaves human review in place.
#   - After curating, replace or update the loop in:
#       ansible/roles/gnome-settings/tasks/main.yml
#
# Usage:
#   ./scripts/gnome_export_extensions_ansible.sh > /tmp/gnome-extensions-ansible.yml
#   Review / prune / commit.
#
set -euo pipefail

echo "# Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "# Enabled extensions (reference):"
gnome-extensions list --enabled | sed 's/^/#   /'
echo "#"
echo "# Full dconf dump (raw) for reference was from: dconf dump /org/gnome/shell/extensions/"
echo "# Below is a YAML snippet suitable for inserting into the existing gnome-settings role."
echo

# Acquire dump
dump="$(dconf dump /org/gnome/shell/extensions/ || true)"

current_section=""
# Process line by line
# Rules:
#   [section] -> sets current section (maps to /org/gnome/shell/extensions/<section>/)
#   key=value -> output YAML line
#   blank/comment lines ignored
echo "$dump" | while IFS= read -r line; do
  # Strip CR
  line="${line%%$'\r'}"
  if [[ -z "$line" ]]; then
    continue
  fi
  if [[ "$line" =~ ^\[(.+)\]$ ]]; then
    current_section="${BASH_REMATCH[1]}"
    continue
  fi
  # key=value pair
  if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
    k="${BASH_REMATCH[1]}"
    v="${BASH_REMATCH[2]}"
    # Preserve original quoting of value; wrap entire value in double quotes unless it already starts with
    # a quote or bracket indicating non-scalar representation for dconf module.
    # The community.general.dconf module expects a GVariant string literal or other literal exactly.
    # We assume the right-hand side as-is is acceptable; just escape existing double quotes for YAML safety.
    yaml_value="$v"
    # Escape existing double quotes
    yaml_value="${yaml_value//\"/\\\"}"
    echo "- { key: \"/org/gnome/shell/extensions/${current_section}/${k}\", value: \"${yaml_value}\" }"
  fi
done

cat <<'EOF'

# Post-processing recommendations:
# 1. Remove keys you do not actively care about.
# 2. Group related extensions together.
# 3. Commit the curated subset only.
#
# To update later:
#   git checkout main
#   ./scripts/gnome_export_extensions_ansible.sh > /tmp/ext-new.yml
#   diff -u <(grep 'key:' ansible/roles/gnome-settings/tasks/main.yml) <(grep 'key:' /tmp/ext-new.yml)
#   Manually merge desired changes.
EOF
