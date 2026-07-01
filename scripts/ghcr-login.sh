#!/usr/bin/env bash
# Log in to GHCR so the robot can pull private EduBot images.
#
# Run once per robot (the login persists in ~/.docker/config.json). Use a
# pull-only credential — a fine-grained PAT or a GitHub App token with the
# single scope `read:packages`. Never put a push-capable token on a robot.
#
# The token is read from, in order:
#   1. $GHCR_TOKEN
#   2. the file in $GHCR_TOKEN_FILE
#   3. /etc/edubot/ghcr-token   (recommended: root-owned, chmod 600)
#
# Usage:
#   GHCR_TOKEN=ghp_xxx GHCR_USER=edubot-bot ./scripts/ghcr-login.sh
#   ./scripts/ghcr-login.sh              # reads /etc/edubot/ghcr-token
set -euo pipefail

REGISTRY="ghcr.io"
GHCR_USER="${GHCR_USER:-${GHCR_OWNER:-vectoral-robotics}}"
DEFAULT_TOKEN_FILE="/etc/edubot/ghcr-token"

read_token() {
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    printf '%s' "$GHCR_TOKEN"
    return 0
  fi
  local file="${GHCR_TOKEN_FILE:-$DEFAULT_TOKEN_FILE}"
  if [[ -r "$file" ]]; then
    tr -d '\r\n' < "$file"
    return 0
  fi
  return 1
}

if ! token="$(read_token)" || [[ -z "$token" ]]; then
  echo "[ghcr-login] no token found." >&2
  echo "  set GHCR_TOKEN, or GHCR_TOKEN_FILE, or place a token in $DEFAULT_TOKEN_FILE" >&2
  echo "  the token needs only the read:packages scope." >&2
  exit 1
fi

echo "[ghcr-login] logging in to ${REGISTRY} as ${GHCR_USER}..."
printf '%s' "$token" | docker login "$REGISTRY" -u "$GHCR_USER" --password-stdin
echo "[ghcr-login] done. 'make pull' / 'make update' can now fetch private images."
