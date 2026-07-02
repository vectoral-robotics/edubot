#!/usr/bin/env bash
# release-dev.sh — cut a dev release.
#
# One pipeline: freeze the current sub-repo mains, build & push the three images
# as :dev, then write a commit on the `dev` channel branch that pins exactly
# those images (channels/dev.json) plus the lockfiles and the current meta-repo
# config (merged from main). Robots on the dev channel watch this branch.
#
#   make release-dev
#
# Requires: a clean meta-repo tree, buildx, and `docker login ghcr.io` with
# write:packages. Run from the meta-repo root.
set -euo pipefail
SCRIPT_NAME=release-dev
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

require_clean_tree
command -v vcs >/dev/null || die "vcstool not found (pip install vcstool)."

# A dev release freezes each sub-repo's main; refuse if a checkout sits on a
# different branch (e.g. a developer's feature branch) — run `make src` to reset.
off=""
for d in src/*/ dev/*/; do
  { [ -d "$d/.git" ] || [ -f "$d/.git" ]; } || continue
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$b" = "main" ] || off="$off $(basename "$d")($b)"
done
[ -z "$off" ] || die "sub-repos not on main:$off — run 'make src' to reset before a dev release."

info "refreshing sub-repos to their latest main (make pull-src)"
make pull-src

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Freeze: pin the exact sub-repo commits that will go into the images.
info "freezing lockfiles from src/ and dev/"
vcs export --exact src > "$tmp/edubot.lock.repos"
vcs export --exact dev > "$tmp/edubot.dev.lock.repos"

# 2. Build & push the three images from the frozen ros2 lockfile.
digests="$tmp/digests.txt"
PUSH="${PUSH:-true}" scripts/build-images.sh dev "$tmp/edubot.lock.repos" "$digests"

# 3. Resolve pushed digests into pinned image refs.
ref_of() { awk -v n="$1" '$1==n{print $2}' "$digests"; }
ros2_ref="${REGISTRY}/edubot-ros2@$(ref_of edubot-ros2)"
dash_ref="${REGISTRY}/edubot-dashboard@$(ref_of edubot-dashboard)"
flash_ref="${REGISTRY}/edubot-flasher@$(ref_of edubot-flasher)"

# 4. Compute the next dev build number + component versions (from the frozen
#    src/ + dev/ checkouts).
git fetch -q origin
# On the very first dev release origin/dev does not exist yet; keep git show's
# exit 128 from tripping `set -o pipefail` by capturing it separately.
prev_json=$(git show origin/dev:channels/dev.json 2>/dev/null || echo '{}')
prev=$(jq -r '.version // "dev-0"' <<<"$prev_json" | sed 's/^dev-//')
[[ "$prev" =~ ^[0-9]+$ ]] || prev=0
version="dev-$((prev + 1))"
components=$(components_json)
info "new dev version: $version"

# 5. Write the commit on the dev branch via a throwaway worktree so the
#    developer's main checkout (with src/, dev/) is left untouched.
wt="$tmp/dev-wt"
if git show-ref --verify -q refs/remotes/origin/dev; then
  git worktree add -q "$wt" -B dev origin/dev
else
  info "dev branch does not exist yet — creating it from origin/main"
  git worktree add -q "$wt" -b dev origin/main
fi
(
  cd "$wt"
  git merge --no-ff --no-edit origin/main -m "release(dev): merge main config into dev" >/dev/null 2>&1 || true
  cp "$tmp/edubot.lock.repos" "$tmp/edubot.dev.lock.repos" .
  write_manifest dev "$version" channels/dev.json "$ros2_ref" "$dash_ref" "$flash_ref" "$components"
  git add -A
  git commit -q -m "release(dev): $version"
  git push -q origin dev
)
git worktree remove --force "$wt"

info "dev release $version published → branch 'dev'. Robots on the dev channel will pick it up on 'make update'."
