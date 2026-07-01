#!/usr/bin/env bash
# EduBot on-robot OTA update — pull the current channel and restart the stack.
#
# Usage:  EDUBOT_CHANNEL=stable ./scripts/update.sh
# Rollback: set EDUBOT_CHANNEL to a previous immutable tag (e.g. v1.4.2) and
#           re-run, or `docker compose up -d` with that channel.
set -euo pipefail

CHANNEL="${EDUBOT_CHANNEL:-stable}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yaml}"
cd "$(dirname "$0")/.."

echo "[update] channel: ${CHANNEL}"

# Record the currently running image ids so we can report/rollback.
before="$(docker compose -f "$COMPOSE_FILE" images -q 2>/dev/null || true)"

echo "[update] pulling images and rebuilding on-robot containers..."
# Hybrid stack: `--pull always` refreshes the pulled images (edubot/dashboard/
# flasher), `--build` rebuilds the on-robot ones (dev/rviz/web_video_server).
EDUBOT_CHANNEL="$CHANNEL" docker compose -f "$COMPOSE_FILE" up -d --build --pull always

# Give services a moment, then a shallow health check on the dashboard.
sleep 5
if curl -fsS --max-time 5 "http://localhost:${DASHBOARD_PORT:-8080}/" >/dev/null 2>&1; then
  echo "[update] OK — dashboard responding on :${DASHBOARD_PORT:-8080}."
else
  echo "[update] WARNING: dashboard did not respond. Check 'docker compose logs'." >&2
  echo "[update] to roll back: EDUBOT_CHANNEL=<previous-vX.Y.Z> $0" >&2
  exit 1
fi

after="$(docker compose -f "$COMPOSE_FILE" images -q 2>/dev/null || true)"
[ "$before" = "$after" ] && echo "[update] already up to date." || echo "[update] images updated."
