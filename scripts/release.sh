#!/usr/bin/env bash
# release.sh — build & push the three EduBot fleet images from local source.
#
# This is the ONE place images are built. Nothing is built in any repo's CI.
#   CHANNEL=dev     (default) build from the main manifests, tag :dev
#   CHANNEL=stable  build from the lockfiles, tag :stable + :v<product-version>
#
# The three images:
#   edubot-ros2       docker/ros2.Dockerfile     (imports sources in-container
#                                                  from .build.repos)
#   edubot-dashboard  docker/dashboard/Dockerfile (source: dev/edubot_dashboard)
#   edubot-flasher    docker/flasher/Dockerfile   (source: dev/edubot_firmware)
#
# Multi-arch (amd64 + arm64) via buildx; a multi-arch build must push, so a GHCR
# login with write:packages is required (`docker login ghcr.io`). Runs anywhere
# buildx is available (a Mac with Docker Desktop is fine — no ROS/Pi needed).
#
# Env knobs:
#   CHANNEL     dev | stable            (default dev)
#   GHCR_OWNER  registry namespace      (default vectoral-robotics)
#   PLATFORMS   buildx platforms        (default linux/amd64,linux/arm64)
#   PUSH        true | false            (default true; false = local single-arch
#                                        build for testing, no registry push)
set -euo pipefail

cd "$(dirname "$0")/.."  # meta-repo root = build context for all images

CHANNEL="${CHANNEL:-dev}"
OWNER="${GHCR_OWNER:-vectoral-robotics}"
REGISTRY="ghcr.io/${OWNER}"
PUSH="${PUSH:-true}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

info() { printf '\033[1;34m[release]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[release]\033[0m %s\n' "$*" >&2; exit 1; }

# --- resolve manifests + tag suffix per channel ----------------------------
case "$CHANNEL" in
  dev)
    ros_manifest="edubot.repos"
    dev_manifest="edubot.dev.repos"
    version_tag=""
    ;;
  stable)
    ros_manifest="edubot.lock.repos"
    dev_manifest="edubot.dev.lock.repos"
    [ -f "$ros_manifest" ] && [ -f "$dev_manifest" ] \
      || die "lockfiles missing — run 'make freeze' first ($ros_manifest / $dev_manifest)."
    # Product version comes from the meta-repo (.cz.toml) — the release identity.
    pv="$(grep -E '^version = ' .cz.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
    [ -n "$pv" ] || die "could not read product version from .cz.toml"
    version_tag="v${pv}"
    ;;
  *) die "CHANNEL must be 'dev' or 'stable' (got '$CHANNEL')." ;;
esac

# --- stage the dashboard/flasher sources at the manifest's commits ----------
# The ros2 image imports its own sources in-container; dashboard/flasher build
# from ./dev, so those must sit at the exact commits for this channel. Refuse to
# clobber uncommitted work — a release is never cut from a dirty tree.
for repo in dev/*/; do
  [ -d "${repo}.git" ] || continue
  if [ -n "$(git -C "$repo" status --porcelain)" ]; then
    die "${repo} has uncommitted changes — commit/stash them before releasing."
  fi
done
info "staging dev/ sources from ${dev_manifest}"
mkdir -p dev
vcs import dev < "$dev_manifest"

# --- build helper ----------------------------------------------------------
build_and_push() {
  local name="$1" dockerfile="$2"
  local image="${REGISTRY}/${name}"
  local tags=("-t" "${image}:${CHANNEL}")
  [ -n "$version_tag" ] && tags+=("-t" "${image}:${version_tag}")

  local out=("--push")
  local platforms=("--platform" "$PLATFORMS")
  if [ "$PUSH" != "true" ]; then
    info "PUSH=false → local single-arch build only (no registry push)"
    out=("--load")
    platforms=()  # --load cannot handle multi-arch
  fi

  info "building ${image} (${CHANNEL}${version_tag:+, $version_tag}) from ${dockerfile}"
  docker buildx build \
    "${platforms[@]}" \
    -f "$dockerfile" \
    "${tags[@]}" \
    "${out[@]}" \
    --provenance=false \
    --label "org.opencontainers.image.source=https://github.com/${OWNER}/edubot" \
    .
}

# --- ros2 core: stage the chosen manifest, build (imports in-container) ------
info "staging ${ros_manifest} as .build.repos for the ros2 core build"
cp "$ros_manifest" .build.repos

build_and_push "edubot-ros2"      "docker/ros2.Dockerfile"
build_and_push "edubot-dashboard" "docker/dashboard/Dockerfile"
build_and_push "edubot-flasher"   "docker/flasher/Dockerfile"

rm -f .build.repos
info "done — channel '${CHANNEL}'${version_tag:+ (${version_tag})} images built${PUSH:+ and pushed}."
