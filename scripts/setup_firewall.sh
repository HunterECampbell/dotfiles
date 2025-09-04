#!/usr/bin/env bash
# Idempotent firewall setup for Pop!_OS (Ubuntu-based) using ufw.
# Actions:
# - Install baseline defaults (deny incoming, allow outgoing) if not already active.
# - Allow SSH (OpenSSH profile or 22/tcp) only if an SSH service appears installed.
# - Enable ufw if inactive.
# - Always output a machine-readable status block at the end (even if some steps fail).

set -u -o pipefail

overall_rc=0
run() {
  "$@"
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "WARN: rc=$rc cmd:$*" >&2
    overall_rc=1
  fi
}

if ! command -v ufw >/dev/null 2>&1; then
  echo "ERROR: ufw not installed" >&2
  overall_rc=1
else
  STATUS_LINE="$(ufw status 2>/dev/null | head -n1 || true)"

  if echo "$STATUS_LINE" | grep -qi "inactive"; then
    # Set baseline policies
    run ufw default deny incoming
    run ufw default allow outgoing
    # Allow SSH if service detected
    if systemctl list-unit-files 2>/dev/null | grep -Ei '(^|/)ssh\.service' >/dev/null 2>&1; then
      run ufw allow OpenSSH || run ufw allow 22/tcp
    fi
    run ufw --force enable
  fi

  run ufw status verbose
fi

# Gather final status (do not fail if parsing has issues)
UFW_VERBOSE="$(ufw status verbose 2>/dev/null || true)"

# Emit a simple key=value trailer for parsers
INCOMING_POLICY="$(printf '%s\n' "$UFW_VERBOSE" | grep -Ei '^Default:' | sed -E 's/.*Default: *([^,]+) \(incoming\).*/\1/i' || true)"
OUTGOING_POLICY="$(printf '%s\n' "$UFW_VERBOSE" | grep -Ei '^Default:' | sed -E 's/.*incoming\), *([^,]+) \(outgoing\).*/\1/i' || true)"
STATUS_ACTIVE="$(ufw status 2>/dev/null | grep -qi '^Status: active' && echo true || echo false)"

echo "FIREWALL_STATUS_ACTIVE=$STATUS_ACTIVE"
echo "FIREWALL_DEFAULT_INCOMING=${INCOMING_POLICY:-unknown}"
echo "FIREWALL_DEFAULT_OUTGOING=${OUTGOING_POLICY:-unknown}"

exit $overall_rc
