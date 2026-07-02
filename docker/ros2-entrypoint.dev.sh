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
colcon build --symlink-install --event-handlers console_direct+

# Hand off to the full production launcher, pointed at the dev workspace.
export EDUBOT_WS=/workspace
exec /run.sh
