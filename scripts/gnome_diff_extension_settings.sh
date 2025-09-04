#!/usr/bin/env bash
# scripts/gnome_diff_extension_settings.sh
#
# Parser v5 (pure bash, no awk dependency complexities).
# Extract all enforced /org/gnome/shell/extensions/* keys from:
#   ansible/roles/gnome-settings/tasks/main.yml
# Works with multi-line inline maps of form:
#   - {
#       key: "…",
#       value: "…",
#     }
# Also supports single-line:
#   - { key: "…", value: "…" }
#
# Logic:
#   1. Read file line-by-line.
#   2. Detect lines containing key: "/org/gnome/shell/extensions/..."
#   3. Capture key; search for value on same line or subsequent lines until found or a new key appears.
#   4. Store pairs; value empty => parse issue.
#   5. dconf read each key and compare.
#
# Output columns:
#   STATUS (OK|DIFF|MISSING|PARSE)
#
# Usage:
#   ./scripts/gnome_diff_extension_settings.sh
#
set -euo pipefail

ROLE_FILE="ansible/roles/gnome-settings/tasks/main.yml"

if [[ ! -f "$ROLE_FILE" ]]; then
  echo "ERROR: Cannot find $ROLE_FILE" >&2
  exit 1
fi

declare -a KEYS
declare -A ENFORCED

pending_key=""
pending_value=""

while IFS= read -r raw_line; do
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"   # ltrim
  [[ "$line" =~ ^# ]] && continue

  # Single-line item with both key and value
  if [[ "$line" =~ -[[:space:]]*\{.*key:[[:space:]]*\"(/org/gnome/shell/extensions/[^\"]+)\".*value:[[:space:]]*\"(.*)\".*\} ]]; then
    k="${BASH_REMATCH[1]}"
    v="${BASH_REMATCH[2]}"
    # Strip trailing comma if present
    v="${v%%\",}"
    v="${v%%\",*}"
    KEYS+=("$k")
    ENFORCED["$k"]="$v"
    continue
  fi

  # Key line (multi-line form)
  if [[ "$line" =~ key:[[:space:]]*\"(/org/gnome/shell/extensions/[^\"]+)\" ]]; then
    # If previous pending key existed without value, record parse issue
    if [[ -n "$pending_key" && -z "$pending_value" ]]; then
      KEYS+=("$pending_key")
      ENFORCED["$pending_key"]=""
    fi
    pending_key="${BASH_REMATCH[1]}"
    pending_value=""
    # Check if value also on same line
    if [[ "$line" =~ value:[[:space:]]*\"(.*)\" ]]; then
      pending_value="${BASH_REMATCH[1]}"
      pending_value="${pending_value%%\",}"
      KEYS+=("$pending_key")
      ENFORCED["$pending_key"]="$pending_value"
      pending_key=""
      pending_value=""
    fi
    continue
  fi

  # Value line following a pending key
  if [[ -n "$pending_key" && "$line" =~ value:[[:space:]]*\"(.*)\" ]]; then
    pending_value="${BASH_REMATCH[1]}"
    pending_value="${pending_value%%\",}"
    KEYS+=("$pending_key")
    ENFORCED["$pending_key"]="$pending_value"
    pending_key=""
    pending_value=""
    continue
  fi
done < "$ROLE_FILE"

# Flush dangling pending key
if [[ -n "$pending_key" && -z "${ENFORCED[$pending_key]:-}" ]]; then
  KEYS+=("$pending_key")
  ENFORCED["$pending_key"]=""
fi

if [[ ${#KEYS[@]} -eq 0 ]]; then
  echo "No extension keys found under /org/gnome/shell/extensions/ in $ROLE_FILE"
  exit 0
fi

printf '%-8s | %-70s | %s\n' 'STATUS' 'KEY' 'DETAIL'
printf '%-8s-+-%-70s-+-%s\n' '--------' '----------------------------------------------------------------------' '----------------------------------------'

OK_COUNT=0
DIFF_COUNT=0
MISS_COUNT=0
PARSE_COUNT=0

for key in "${KEYS[@]}"; do
  enforced="${ENFORCED[$key]}"
  if [[ -z "$enforced" ]]; then
    printf '%-8s | %-70s | %s\n' 'PARSE' "$key" 'No value captured (check YAML formatting)'
    ((PARSE_COUNT++))
    continue
  fi
  if current_raw=$(dconf read "$key" 2>/dev/null); then
    if [[ "$current_raw" == "$enforced" ]]; then
      printf '%-8s | %-70s | %s\n' 'OK' "$key" "$current_raw"
      ((OK_COUNT++))
    else
      printf '%-8s | %-70s | expected=%s current=%s\n' 'DIFF' "$key" "$enforced" "$current_raw"
      ((DIFF_COUNT++))
    fi
  else
    printf '%-8s | %-70s | expected=%s current=<unset>\n' 'MISSING' "$key" "$enforced"
    ((MISS_COUNT++))
  fi
done

echo
echo "Summary: OK=${OK_COUNT} DIFF=${DIFF_COUNT} MISSING=${MISS_COUNT} PARSE=${PARSE_COUNT}"
echo "Parsed keys: ${#KEYS[@]} (from $ROLE_FILE)"
echo "Interpretation:"
echo "  OK     => Live matches enforced."
echo "  DIFF   => Drift; adjust Ansible or system then re-export."
echo "  MISSING=> Key absent; extension not loaded / schema changed."
echo "  PARSE  => Script could not extract value."
