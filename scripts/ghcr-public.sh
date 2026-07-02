#!/usr/bin/env bash
# ghcr-public.sh — make the three EduBot fleet images publicly pullable.
#
# Freshly pushed GHCR packages are private; the fleet pulls without a login, so
# the images must be public. GitHub has NO REST endpoint to flip container
# package visibility — it is a one-time click in each package's settings (the
# setting is sticky, so later pushes stay public). This script just prints the
# links.
#
#   ./scripts/ghcr-public.sh
set -euo pipefail
OWNER="${GHCR_OWNER:-vectoral-robotics}"
IMAGES=(edubot-ros2 edubot-dashboard edubot-flasher)

echo "Make each image public once — open the settings page, then"
echo "  Danger Zone -> Change visibility -> Public:"
echo
for img in "${IMAGES[@]}"; do
  echo "  https://github.com/orgs/${OWNER}/packages/container/${img}/settings"
done
echo
echo "After that, robots pull these images without any login."
