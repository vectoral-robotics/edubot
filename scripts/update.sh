#!/usr/bin/env bash
# EduBot on-robot OTA update (GitOps pull).
#
# The meta-repo is the source of truth. An update = advance THIS checkout to the
# channel's latest state (which brings new compose/config for free), pin the
# images to the digests recorded in channels/<channel>.json, then pull + restart.
#
#   EDUBOT_CHANNEL=stable ./scripts/update.sh   # follow the stable branch
#   EDUBOT_CHANNEL=dev    ./scripts/update.sh   # follow the dev branch
#   EDUBOT_CHANNEL=v1.4.2 ./scripts/update.sh   # pin/roll back to a version tag
set -euo pipefail

CHANNEL="${EDUBOT_CHANNEL:-stable}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yaml}"
cd "$(dirname "$0")/.."

echo "[update] channel: ${CHANNEL}"

# A dirty tree would block the checkout. src/, dev/ and .env are gitignored, so
# a normal robot checkout is clean; refuse only on real local edits.
if [ -n "$(git status --porcelain)" ]; then
  echo "[update] ERROR: meta-repo has local changes — commit/stash or reset before updating." >&2
  git status --short >&2
  exit 1
fi

git fetch -q origin --tags

# Resolve the channel to a git ref and the manifest that pins the images.
case "$CHANNEL" in
  dev|stable)
    ref="origin/${CHANNEL}"
    git show-ref --verify -q "refs/remotes/origin/${CHANNEL}" \
      || { echo "[update] ERROR: no '${CHANNEL}' branch published yet." >&2; exit 1; }
    manifest="channels/${CHANNEL}.json"
    ;;
  v*)
    ref="refs/tags/${CHANNEL}"
    git rev-parse -q --verify "$ref" >/dev/null \
      || { echo "[update] ERROR: version tag '${CHANNEL}' not found." >&2; exit 1; }
    manifest="channels/stable.json"   # a version tag lives on the stable branch
    ;;
  *)
    echo "[update] ERROR: EDUBOT_CHANNEL must be dev|stable|vX.Y.Z (got '${CHANNEL}')." >&2
    exit 1 ;;
esac

before="$(git rev-parse HEAD)"
echo "[update] checking out ${ref}"
git checkout -q --force -B "edubot-${CHANNEL}" "$ref" 2>/dev/null \
  || git checkout -q --force --detach "$ref"

# Pin the images to the exact digests recorded for this release (if a manifest
# is present). Without it, compose falls back to the channel tag.
img_env=()
if [ -f "$manifest" ] && command -v jq >/dev/null; then
  ros2=$(jq -r '.images["edubot-ros2"] // empty' "$manifest")
  dash=$(jq -r '.images["edubot-dashboard"] // empty' "$manifest")
  flash=$(jq -r '.images["edubot-flasher"] // empty' "$manifest")
  ver=$(jq -r '.version // "?"' "$manifest")
  echo "[update] release: ${ver}"
  [ -n "$ros2" ]  && img_env+=("EDUBOT_ROS2_IMAGE=${ros2}")
  [ -n "$dash" ]  && img_env+=("EDUBOT_DASHBOARD_IMAGE=${dash}")
  [ -n "$flash" ] && img_env+=("EDUBOT_FLASHER_IMAGE=${flash}")
else
  echo "[update] no manifest — using the ':${CHANNEL}' channel tag."
fi

echo "[update] pulling images and (re)building on-robot containers..."
# Pulled images (edubot/dashboard/flasher) refresh; the on-robot-built ones
# (dev/web_video_server) rebuild.
env "${img_env[@]}" EDUBOT_CHANNEL="$CHANNEL" \
  docker compose -f "$COMPOSE_FILE" up -d --build --pull always

sleep 5
if curl -fsS --max-time 5 "http://localhost:${DASHBOARD_PORT:-8080}/" >/dev/null 2>&1; then
  echo "[update] OK — dashboard responding on :${DASHBOARD_PORT:-8080}."
else
  echo "[update] WARNING: dashboard did not respond. Check 'docker compose logs'." >&2
  echo "[update] to roll back: git checkout ${before} && EDUBOT_CHANNEL=<prev-vX.Y.Z> $0" >&2
  exit 1
fi

after="$(git rev-parse HEAD)"
[ "$before" = "$after" ] && echo "[update] already up to date." || echo "[update] updated ${before:0:7} → ${after:0:7}."
