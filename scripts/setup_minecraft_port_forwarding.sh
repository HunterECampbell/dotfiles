#!/usr/bin/env bash
# Automate UPnP port forwarding for a Minecraft server (TCP 25565).
# Requirements: miniupnpc package (provides 'upnpc' binary) and a UPnP-enabled router.
# Behavior:
# 1. Detect primary local LAN IP.
# 2. Check existing mappings; if mapping for external TCP 25565 -> local 25565 already exists, leave unchanged.
# 3. Otherwise attempt to add the mapping.
# 4. Re-list mappings and emit a machine-readable key=value trailer plus JSON-ish summary for parsing.
#
# Exit codes:
#  0 success (mapping present or created)
#  1 failure (no upnpc, no local ip, or mapping still absent)

set -euo pipefail

PORT=25565
PROTO="TCP"
EXTERNAL_PORT="$PORT"
INTERNAL_PORT="$PORT"

result_error=""
action_taken="none"

json_escape() {
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

fail() {
  result_error="$1"
  echo "MC_PORTFWD_RESULT=error"
  echo "MC_PORTFWD_ERROR=$(json_escape "$result_error")"
  echo "MC_PORTFWD_ACTION=$action_taken"
  echo "MC_PORTFWD_ACTIVE=false"
  exit 1
}

if ! command -v upnpc >/dev/null 2>&1; then
  fail "upnpc_not_installed"
fi

# Obtain local IP (prefer first non-loopback IPv4)
LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${LOCAL_IP:-}" ]]; then
  # Fallback: parse ip route
  LOCAL_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){if($i=="src"){print $(i+1);exit}}}')"
fi
[[ -z "${LOCAL_IP:-}" ]] && fail "cannot_detect_local_ip"

# Fetch existing mappings
LIST_OUTPUT="$(upnpc -l 2>&1 || true)"

mapping_exists_exact() {
  # Exact mapping for this host IP
  echo "$LIST_OUTPUT" | grep -Eiq "^[[:space:]]*${PROTO}[[:space:]]+${EXTERNAL_PORT}->${LOCAL_IP}:${INTERNAL_PORT}"
}
mapping_exists_any() {
  # Any mapping on external port regardless of internal IP
  echo "$LIST_OUTPUT" | grep -Eiq "^[[:space:]]*${PROTO}[[:space:]]+${EXTERNAL_PORT}->"
}

if mapping_exists_exact; then
  action_taken="none_existing"
else
  # If port mapped to a different internal IP, attempt removal then re-add
  if mapping_exists_any; then
    if upnpc -d "$EXTERNAL_PORT" "$PROTO" 2>&1 | grep -Eqi "is removed|valid removal"; then
      action_taken="removed_old"
      # refresh list after removal
      LIST_OUTPUT="$(upnpc -l 2>&1 || true)"
    else
      # Could not remove existing conflicting mapping
      LIST_OUTPUT_POST="$(upnpc -l 2>&1 || true)"
      LIST_OUTPUT="$LIST_OUTPUT"$'\n'"$LIST_OUTPUT_POST"
      fail "conflicting_mapping_cannot_remove"
    fi
  fi

  # Attempt to add mapping (recognize multiple success phrasings)
  ADD_OUTPUT="$(upnpc -a "$LOCAL_IP" "$INTERNAL_PORT" "$EXTERNAL_PORT" "$PROTO" 2>&1 || true)"
  if echo "$ADD_OUTPUT" | grep -Eqi "is added|is redirected|external ${EXTERNAL_PORT} ${PROTO} .* to internal"; then
    action_taken="$([[ $action_taken == removed_old ]] && echo 'replaced' || echo 'added')"
  else
    # Re-check if mapping now present (race or ambiguous message)
    LIST_OUTPUT_POST="$(upnpc -l 2>&1 || true)"
    LIST_OUTPUT="$LIST_OUTPUT"$'\n'"$LIST_OUTPUT_POST"
    if echo "$LIST_OUTPUT_POST" | grep -Eiq "^[[:space:]]*${PROTO}[[:space:]]+${EXTERNAL_PORT}->${LOCAL_IP}:${INTERNAL_PORT}"; then
      action_taken="$([[ $action_taken == removed_old ]] && echo 'replaced' || echo 'added')"
    else
      # Provide specific failure reason if UPnP device missing
      if echo "$ADD_OUTPUT" | grep -qi "No IGD UPnP Device"; then
        fail "no_upnp_device_found"
      else
        fail "add_mapping_failed"
      fi
    fi
  fi
fi

# Re-list final state
FINAL_LIST="$(upnpc -l 2>&1 || true)"
if echo "$FINAL_LIST" | grep -Eiq "^[[:space:]]*${PROTO}[[:space:]]+${EXTERNAL_PORT}->${LOCAL_IP}:${INTERNAL_PORT}"; then
  active=true
else
  active=false
  [[ "$action_taken" == "added" ]] && result_error="mapping_missing_after_add"
fi

# Emit verbose info (optional for logs)
echo "---- upnpc final listing (truncated) ----"
echo "$FINAL_LIST" | sed -n '1,120p'

# Key=value trailer
echo "MC_PORTFWD_RESULT=$([[ -n "$result_error" ]] && echo error || echo ok)"
echo "MC_PORTFWD_ERROR=${result_error:-}"
echo "MC_PORTFWD_ACTION=$action_taken"
echo "MC_PORTFWD_ACTIVE=$active"
echo "MC_PORTFWD_EXTERNAL_PORT=$EXTERNAL_PORT"
echo "MC_PORTFWD_INTERNAL_IP=$LOCAL_IP"
echo "MC_PORTFWD_INTERNAL_PORT=$INTERNAL_PORT"
echo "MC_PORTFWD_PROTOCOL=$PROTO"

# Minimal JSON style summary (not strict JSON if errors contain newlines, kept simple)
printf 'MC_PORTFWD_SUMMARY={"result":"%s","error":"%s","action":"%s","active":%s,"external_port":%s,"internal_ip":"%s","internal_port":%s,"protocol":"%s"}\n' \
  "$([[ -n "$result_error" ]] && echo error || echo ok)" \
  "$(json_escape "${result_error:-}")" \
  "$action_taken" \
  "$active" \
  "$EXTERNAL_PORT" \
  "$(json_escape "$LOCAL_IP")" \
  "$INTERNAL_PORT" \
  "$PROTO"

# Exit with 0 if mapping active else 1
if [[ "$active" == "true" ]]; then
  exit 0
else
  exit 1
fi
