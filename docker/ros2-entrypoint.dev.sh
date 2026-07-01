#!/bin/bash
# EduBot ROS 2 core — developer entrypoint.
#
# Builds the bind-mounted workspace (./src on the host) at container start with
# --symlink-install, so Python changes are picked up live and only C++/launch
# changes need a rebuild (re-run `make dev`). Then launches the bringup stack.
#
# This is a trimmed dev launcher; the full production run.sh (camera/lidar auto-
# detect, settings.env sourcing) lands when the ROS2 assets migrate here in a
# later phase.
set -Ee

USE_SIM=${USE_SIM:-true}
USE_RVIZ=${USE_RVIZ:-false}
ENABLE_TELEOP=${ENABLE_TELEOP:-true}
ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
export ROS_DOMAIN_ID
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

shutdown() {
  echo "[edubot] shutting down ROS processes..."
  jobs -pr | xargs -r kill
  wait || true
}
trap shutdown EXIT
trap 'exit 0' INT TERM

source /opt/ros/humble/setup.bash

if [ ! -d /workspace/src ] || [ -z "$(ls -A /workspace/src 2>/dev/null)" ]; then
  echo "[edubot] /workspace/src is empty — did you run 'make src' on the host?" >&2
  exit 1
fi

echo "[edubot] building workspace (colcon, --symlink-install)..."
cd /workspace
colcon build --symlink-install --event-handlers console_direct+

source /workspace/install/setup.bash

echo "[edubot] launching bringup (use_sim=${USE_SIM}, use_rviz=${USE_RVIZ})..."
ros2 launch edubot_bringup bringup.launch.py use_sim:="${USE_SIM}" use_rviz:="${USE_RVIZ}" &

if [ "${ENABLE_TELEOP}" = "true" ]; then
  ros2 launch edubot_bringup teleop.launch.py &
fi

echo "[edubot] ROS 2 core is running. Ctrl-C to stop."
wait
