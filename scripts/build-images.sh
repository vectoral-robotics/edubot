#!/usr/bin/env bash
# build-images.sh — build & push the three EduBot fleet images, capturing the
# pushed multi-arch digests. This is the build engine used by release-dev.sh;
# it is not called directly (use `make release-dev`).
#
# Args:
#   $1  TAG           channel tag to push (e.g. "dev")
#   $2  ROS_LOCKFILE  the .repos manifest the ros2 image imports (staged as
#                     .build.repos in the build context)
#   $3  DIGEST_OUT    file to write "<image-name> <digest>" lines to
#
# Env:
#   GHCR_OWNER  registry namespace  (default vectoral-robotics)
#   PLATFORMS   buildx platforms    (default linux/amd64,linux/arm64)
#   PUSH        true|false          (default true; false = local --load, single
#                                    arch, no registry push — for smoke tests)
set -euo pipefail
SCRIPT_NAME=build
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

TAG="${1:?usage: build-images.sh TAG ROS_LOCKFILE DIGEST_OUT}"
ROS_LOCKFILE="${2:?missing ROS_LOCKFILE}"
DIGEST_OUT="${3:?missing DIGEST_OUT}"
PUSH="${PUSH:-true}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

[ -f "$ROS_LOCKFILE" ] || die "ros2 manifest not found: $ROS_LOCKFILE"

# Dockerfile per image.
dockerfile_for() {
  case "$1" in
    edubot-ros2)      echo docker/ros2.Dockerfile ;;
    edubot-dashboard) echo docker/dashboard/Dockerfile ;;
    edubot-flasher)   echo docker/flasher/Dockerfile ;;
    *) die "unknown image $1" ;;
  esac
}

# The ros2 image imports its sources in-container from .build.repos.
info "staging $ROS_LOCKFILE as .build.repos for the ros2 core build"
cp "$ROS_LOCKFILE" .build.repos
trap 'rm -f .build.repos' EXIT

: > "$DIGEST_OUT"
metadir=$(mktemp -d)

for image in "${IMAGE_NAMES[@]}"; do
  df=$(dockerfile_for "$image")
  ref="${REGISTRY}/${image}"
  meta="${metadir}/${image}.json"

  out=(--push) ; plats=(--platform "$PLATFORMS")
  if [ "$PUSH" != "true" ]; then
    warn "PUSH=false → local single-arch --load build for ${image} (no push, no digest)"
    out=(--load) ; plats=()
  fi

  info "building ${ref}:${TAG} from ${df}"
  docker buildx build \
    "${plats[@]}" \
    -f "$df" \
    -t "${ref}:${TAG}" \
    "${out[@]}" \
    --provenance=false \
    --metadata-file "$meta" \
    --label "org.opencontainers.image.source=https://github.com/${OWNER}/edubot" \
    --label "ch.vectoral.edubot.channel=${TAG}" \
    .

  if [ "$PUSH" = "true" ]; then
    digest=$(jq -r '."containerimage.digest"' "$meta")
    if [ -z "$digest" ] || [ "$digest" = "null" ]; then die "no digest captured for ${image}"; fi
    echo "${image} ${digest}" >> "$DIGEST_OUT"
    info "${image} pushed → ${ref}@${digest}"
  fi
done

rm -rf "$metadir"
info "done — built ${IMAGE_NAMES[*]} :${TAG}${PUSH:+ (pushed)}"
