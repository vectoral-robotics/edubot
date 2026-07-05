#!/bin/bash
# EduBot ROS 2 core — production entrypoint (baked into the fleet image).
#
# The workspace is already built into the image at /edubot_ws; this only sources
# it and launches the robot, with camera/lidar auto-detection and settings from
# the shared /settings volume. The developer counterpart that builds from source
# lives in ros2-entrypoint.dev.sh.
set -Ee

USE_SIM=${USE_SIM:-true}
USE_RVIZ=${USE_RVIZ:-false}
ENABLE_TELEOP=${ENABLE_TELEOP:-true}
ENABLE_LIDAR=${ENABLE_LIDAR:-false}
ENABLE_LEDS=${ENABLE_LEDS:-true}
ENABLE_CAMERA=${ENABLE_CAMERA:-auto}
CAMERA_DRIVER=${CAMERA_DRIVER:-v4l2_camera}
CAMERA_DEVICE=${CAMERA_DEVICE:-}
CAMERA_WIDTH=${CAMERA_WIDTH:-1280}
CAMERA_HEIGHT=${CAMERA_HEIGHT:-720}

mkdir -p /settings/edubot /settings/ros /state/edubot

if [ -f /settings/ros/ros.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /settings/ros/ros.env
  set +a
elif [ -f /settings/ros.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /settings/ros.env
  set +a
fi

ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
export ROS_DOMAIN_ID

shutdown() {
  echo "[EduBot] Shutting down ROS processes..."
  jobs -pr | xargs -r kill
  wait || true
}
trap shutdown EXIT
trap 'exit 0' INT TERM

find_camera_device() {
  local dev
  for dev in /dev/video*; do
    [ -e "${dev}" ] || continue
    if command -v v4l2-ctl >/dev/null 2>&1; then
      v4l2-ctl -d "${dev}" --list-formats-ext 2>/dev/null | grep -q "^[[:space:]]*\\[0\\]:" && {
        echo "${dev}"
        return 0
      }
    else
      echo "${dev}"
      return 0
    fi
  done
  return 1
}

# Workspace install to source. Fleet image builds into /edubot_ws; the dev
# container builds into /workspace and sets EDUBOT_WS accordingly.
source "${EDUBOT_WS:-/edubot_ws}/install/setup.bash"

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Main bringup. RViz defaults to false and runs in its own container.
ros2 launch edubot_bringup bringup.launch.py use_sim:="${USE_SIM}" use_rviz:="${USE_RVIZ}" use_leds:="${ENABLE_LEDS}" &

if [ "${ENABLE_TELEOP}" = "true" ]; then
  ros2 launch edubot_bringup teleop.launch.py &
fi

if [ "${ENABLE_LIDAR}" = "true" ]; then
  echo "LiDAR enabled. Starting LiDAR node and static transform..."
  ros2 run tf2_ros static_transform_publisher 0 0 0 1.54 0 0 base_link laser &
  ros2 launch sllidar_ros2 sllidar_c1_launch.py &
fi

if [ -z "${CAMERA_DEVICE}" ] && [ "${ENABLE_CAMERA}" != "false" ]; then
  CAMERA_DEVICE=$(find_camera_device || true)
fi

if [ "${ENABLE_CAMERA}" = "true" ] || { [ "${ENABLE_CAMERA}" = "auto" ] && [ -n "${CAMERA_DEVICE}" ] && [ -e "${CAMERA_DEVICE}" ]; }; then
  CAMERA_DEVICE_ID="${CAMERA_DEVICE#/dev/video}"
  echo "Camera enabled. Publishing ${CAMERA_DEVICE} to /image with ${CAMERA_DRIVER}..."
  if [ "${CAMERA_DRIVER}" = "cam2image" ]; then
    (
      set +e
      ros2 run image_tools cam2image --ros-args \
        -p device_id:="${CAMERA_DEVICE_ID}" \
        -p width:="${CAMERA_WIDTH}" \
        -p height:="${CAMERA_HEIGHT}"
      echo "[EduBot] cam2image exited with $?; keeping ROS core alive."
    ) &
  else
    (
      set +e
      ros2 run v4l2_camera v4l2_camera_node --ros-args \
        -p video_device:="${CAMERA_DEVICE}" \
        -p image_size:="[${CAMERA_WIDTH}, ${CAMERA_HEIGHT}]" \
        -r image_raw:=image
      echo "[EduBot] v4l2_camera exited with $?; keeping ROS core alive."
    ) &
  fi
else
  echo "Camera disabled or no capture device found; skipping camera."
fi

echo "ROS2 nodes are running. Press CTRL+C to stop."
wait
