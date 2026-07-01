#!/usr/bin/env bash
set -eo pipefail

mkdir -p /settings/web_video_server /settings/ros

if [[ -f /settings/ros/ros.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /settings/ros/ros.env
  set +a
elif [[ -f /settings/ros.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /settings/ros.env
  set +a
fi

ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
export ROS_DOMAIN_ID

source /opt/ros/humble/setup.bash
source /opt/ws/install/setup.bash

exec ros2 run web_video_server web_video_server --ros-args -p port:=8081
