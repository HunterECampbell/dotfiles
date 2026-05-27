#!/usr/bin/env bash
# Install system-level kill-discord timer (runs at midnight when logged off).
# Called automatically by ansible discord-settings; use this for a one-off install.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KILL_USER="${SUDO_USER:-${USER}}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

sed "s/{{ kill_discord_user }}/${KILL_USER}/" \
  "${REPO_ROOT}/ansible/roles/discord-settings/templates/kill-discord.service.j2" \
  > /etc/systemd/system/kill-discord.service
cp "${REPO_ROOT}/systemd/system/kill-discord.timer" /etc/systemd/system/kill-discord.timer
chmod 0644 /etc/systemd/system/kill-discord.service /etc/systemd/system/kill-discord.timer

systemctl daemon-reload
systemctl enable --now kill-discord.timer

# User-scoped timer only runs while logged in; remove if present.
if runuser -u "${KILL_USER}" -- systemctl --user is-active kill-discord.timer &>/dev/null; then
  runuser -u "${KILL_USER}" -- systemctl --user disable --now kill-discord.timer || true
fi

systemctl list-timers kill-discord.timer --no-pager
