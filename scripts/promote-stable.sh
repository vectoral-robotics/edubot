#!/usr/bin/env bash
# promote-stable.sh — promote the current dev release to stable.
#
# Promotion rebuilds NOTHING. It takes the exact image digests already published
# on the `dev` branch, re-tags them as :stable + :vX.Y.Z (multi-arch manifest
# copy), then writes a commit + tag on the `stable` channel branch pinning those
# same digests. Robots on the stable channel watch this branch.
#
#   make promote-stable                 # auto: bump patch from the last vX.Y.Z tag
#   make promote-stable VERSION=1.5.0   # explicit product version
#
# Requires: a clean tree and `docker login ghcr.io` with write:packages.
set -euo pipefail
SCRIPT_NAME=promote-stable
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

require_clean_tree
git fetch -q origin --tags

git show-ref --verify -q refs/remotes/origin/dev \
  || die "no dev branch — cut a dev release first (make release-dev)."
devman=$(git show origin/dev:channels/dev.json 2>/dev/null) \
  || die "origin/dev has no channels/dev.json — cut a dev release first."

# --- resolve the target product version ------------------------------------
if [ -n "${VERSION:-}" ]; then
  ver="${VERSION#v}"
else
  last=$(git tag --list 'v*' --sort=-v:refname | head -1)
  if [ -z "$last" ]; then
    ver="0.1.0"
  else
    IFS=. read -r a b c <<<"${last#v}"
    ver="${a}.${b}.$((c + 1))"
  fi
fi
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid VERSION '$ver' (want X.Y.Z)."
git rev-parse -q --verify "refs/tags/v$ver" >/dev/null && die "tag v$ver already exists."
info "promoting dev → stable as v$ver"

# --- re-tag the SAME digests as :stable + :vX.Y.Z (no rebuild) --------------
for image in "${IMAGE_NAMES[@]}"; do
  ref=$(jq -r --arg n "$image" '.images[$n]' <<<"$devman")   # name@sha256:…
  if [ -z "$ref" ] || [ "$ref" = "null" ]; then die "dev manifest missing image $image"; fi
  info "re-tagging $ref → :stable, :v$ver"
  docker buildx imagetools create \
    -t "${REGISTRY}/${image}:stable" \
    -t "${REGISTRY}/${image}:v${ver}" \
    "$ref"
done

# --- write the stable branch commit + tag via a throwaway worktree ----------
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
wt="$tmp/stable-wt"
if git show-ref --verify -q refs/remotes/origin/stable; then
  git worktree add -q "$wt" -B stable origin/stable
else
  info "stable branch does not exist yet — creating it from origin/main"
  git worktree add -q "$wt" -b stable origin/main
fi
(
  cd "$wt"
  # stable inherits dev's tree (config + lockfiles + component set).
  git merge --no-ff --no-edit origin/dev -m "release(stable): promote dev to v$ver" >/dev/null 2>&1 || true
  # The stable manifest carries the same digests but the stable version string.
  components=$(jq '.components' <<<"$devman")
  ros2_ref=$(jq -r '.images["edubot-ros2"]' <<<"$devman")
  dash_ref=$(jq -r '.images["edubot-dashboard"]' <<<"$devman")
  flash_ref=$(jq -r '.images["edubot-flasher"]' <<<"$devman")
  write_manifest stable "$ver" channels/stable.json "$ros2_ref" "$dash_ref" "$flash_ref" "$components"
  git add -A
  git commit -q -m "release(stable): v$ver"
  git tag -a "v$ver" -m "v$ver"
  git push -q --follow-tags origin stable
)
git worktree remove --force "$wt"

info "stable release v$ver published → branch 'stable', tag 'v$ver'. Robots on the stable channel will pick it up on 'make update'."
