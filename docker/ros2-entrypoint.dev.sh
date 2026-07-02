#!/bin/bash
# EduBot ROS 2 core — developer entrypoint.
#
# Builds the bind-mounted workspace (./src) at container start with
# --symlink-install, then hands off to the SAME run.sh as the fleet image
# (camera/lidar auto-detect, rosbridge via bringup, /settings sourcing). So the
# dev container behaves exactly like a deployed one — just built from source.
set -Ee

source /opt/ros/humble/setup.bash

if [ ! -d /workspace/src ] || [ -z "$(ls -A /workspace/src 2>/dev/null)" ]; then
  echo "[edubot] /workspace/src is empty — did you run 'make src' on the host?" >&2
  exit 1
fi

echo "[edubot] building workspace (colcon, --symlink-install)..."
cd /workspace
# Don't let one optional third-party package (e.g. sllidar_ros2, only needed for
# ENABLE_LIDAR=true) abort the whole dev container: build best-effort and carry
# on as long as the core produced an install.
set +e
colcon build --symlink-install --continue-on-error --event-handlers console_direct+
build_rc=$?
set -e

if [ ! -f /workspace/install/setup.bash ]; then
  echo "[edubot] colcon produced no install — the build failed hard. Aborting." >&2
  exit 1
fi
if [ "$build_rc" -ne 0 ]; then
  echo "[edubot] WARNING: some packages failed to build (see the log above)." >&2
  echo "[edubot] Continuing with the packages that built. sllidar_ros2 is" >&2
  echo "[edubot] optional (only used when ENABLE_LIDAR=true)." >&2
fi

# Hand off to the full production launcher, pointed at the dev workspace.
export EDUBOT_WS=/workspace
exec /run.sh
