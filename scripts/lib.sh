#!/usr/bin/env bash
# Shared helpers for the EduBot release/promote/update scripts.
#
# The release model is GitOps: the meta-repo is the source of truth and carries
# two channel branches, `dev` and `stable`. A release is a single pipeline run
# that builds/tags the images AND writes a commit on the channel branch pinning
# them (via channels/<channel>.json + the lockfiles). Robots only ever watch
# their channel branch. See RELEASING.md.

# These are consumed by the scripts that source this file (build-images.sh,
# release-dev.sh, promote-stable.sh), so shellcheck can't see the use here.
# shellcheck disable=SC2034
OWNER="${GHCR_OWNER:-vectoral-robotics}"
# shellcheck disable=SC2034
REGISTRY="ghcr.io/${OWNER}"
# The three fleet images (name -> Dockerfile is resolved in build-images.sh).
# shellcheck disable=SC2034
IMAGE_NAMES=(edubot-ros2 edubot-dashboard edubot-flasher)

: "${SCRIPT_NAME:=edubot}"
info() { printf '\033[1;34m[%s]\033[0m %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '\033[1;33m[%s]\033[0m %s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '\033[1;31m[%s]\033[0m %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

# Absolute meta-repo root (works regardless of the caller's CWD).
repo_root() { git rev-parse --show-toplevel; }

# Fail unless the meta-repo working tree is clean. src/, dev/ and .env are
# gitignored, so a populated developer workspace does not count as "dirty".
require_clean_tree() {
  if [ -n "$(git status --porcelain)" ]; then
    die "meta-repo has uncommitted changes — commit/stash them before releasing."
  fi
}

# Best-effort version of a checked-out sub-repo directory. Order:
# package.xml -> VERSION -> package.json -> pyproject.toml [tool.commitizen]
# -> first nested package.xml -> "unknown".
component_version() {
  local dir="$1" v=""
  if [ -f "$dir/package.xml" ]; then
    v=$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' "$dir/package.xml" | head -1)
  elif [ -f "$dir/VERSION" ]; then
    v=$(tr -d ' \n' < "$dir/VERSION")
  elif [ -f "$dir/package.json" ]; then
    v=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/package.json" | head -1)
  elif [ -f "$dir/pyproject.toml" ] && grep -q '\[tool.commitizen\]' "$dir/pyproject.toml"; then
    v=$(sed -n '/\[tool.commitizen\]/,/^\[/{s/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$dir/pyproject.toml" | head -1)
  else
    v=$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' "$dir"/*/package.xml 2>/dev/null | head -1)
  fi
  printf '%s' "${v:-unknown}"
}

# Emit a JSON object mapping every checked-out sub-repo (src/ + dev/) to its
# version. Run from the meta-repo root with src/ and dev/ populated.
components_json() {
  local acc dir name ver
  acc=$(jq -n '{}')
  for dir in src/*/ dev/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    ver=$(component_version "$dir")
    acc=$(jq --arg n "$name" --arg v "$ver" '. + {($n): $v}' <<<"$acc")
  done
  printf '%s' "$acc"
}

# Write channels/<channel>.json. Args:
#   1 channel  2 version  3 out-path
#   4 ros2 image ref (name@sha256:… or name:tag)  5 dashboard ref  6 flasher ref
#   7 components-json (from components_json)
write_manifest() {
  local channel="$1" version="$2" out="$3" ros2="$4" dash="$5" flash="$6" components="$7"
  mkdir -p "$(dirname "$out")"
  jq -n \
    --arg channel "$channel" \
    --arg version "$version" \
    --arg released_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg meta_main_sha "$(git rev-parse origin/main 2>/dev/null || git rev-parse HEAD)" \
    --arg ros2 "$ros2" --arg dash "$dash" --arg flash "$flash" \
    --argjson components "$components" \
    '{
       channel: $channel,
       version: $version,
       released_at: $released_at,
       meta_main_sha: $meta_main_sha,
       images: {
         "edubot-ros2": $ros2,
         "edubot-dashboard": $dash,
         "edubot-flasher": $flash
       },
       components: $components
     }' > "$out"
}
