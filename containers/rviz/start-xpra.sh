#!/usr/bin/env bash
set -Ee
set -o pipefail
set -x

APP_ENTRYPOINT=${APP_ENTRYPOINT:-/usr/local/bin/start-rviz.sh}
WEB_PORT=${WEB_PORT:-14500}
XPRA_USER=${XPRA_USER:-root}
XPRA_DISPLAY=${XPRA_DISPLAY:-:100}
X_DISPLAY_RES=${SCREEN_GEOMETRY:-${X_DISPLAY_RES:-2560x1600}}
XPRA_LOG=${XPRA_LOG:-/tmp/xpra.log}
RVIZ_RENDER_MODE=${RVIZ_RENDER_MODE:-software}

mkdir -p /settings/rviz /settings/ros

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
export AMENT_TRACE_SETUP_FILES=""

ARCH=$(uname -m)
case "${RVIZ_RENDER_MODE}" in
  v3d)
    if [[ "$ARCH" == "aarch64" && -d /dev/dri ]]; then
      echo "INFO: RVIZ_RENDER_MODE=v3d; using V3D GPU rendering"
      unset LIBGL_ALWAYS_SOFTWARE
      unset MESA_LOADER_DRIVER_OVERRIDE
      unset LIBGL_DRI3_DISABLE
      export GALLIUM_DRIVER=v3d
    else
      echo "WARN: RVIZ_RENDER_MODE=v3d requested but /dev/dri or aarch64 support is unavailable; falling back to software"
      RVIZ_RENDER_MODE=software
    fi
    ;;
  auto)
    # Under Xpra + Xvfb, llvmpipe is the only consistently reliable path.
    RVIZ_RENDER_MODE=software
    ;;
esac

if [[ "${RVIZ_RENDER_MODE}" == "software" ]]; then
  echo "INFO: using llvmpipe software rendering (arch=$ARCH)"
  export LIBGL_ALWAYS_SOFTWARE=1
  export GALLIUM_DRIVER=llvmpipe
  export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
  export LIBGL_DRI3_DISABLE=1
fi

export RVIZ_RENDER_MODE

source /opt/ros/humble/setup.bash
if [[ -f /opt/edubot_rviz_ws/install/setup.bash ]]; then
  source /opt/edubot_rviz_ws/install/setup.bash
fi

if [[ -f /edubot_ws/install/setup.bash ]]; then
  source /edubot_ws/install/setup.bash
fi

rm -f /run/dbus/pid
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

display_num="${XPRA_DISPLAY#:}"
display_num="${display_num%%.*}"
rm -rf \
  "/tmp/${display_num}" \
  "/tmp/.X${display_num}-lock" \
  "/tmp/.X11-unix/X${display_num}"

: > "${XPRA_LOG}"

set +e
xpra start \
  ${XPRA_DISPLAY} \
  --bind-tcp=0.0.0.0:${WEB_PORT} \
  --html=on \
  --auth=none \
  --tcp-auth=none \
  --ws-auth=none \
  --username="${XPRA_USER}" \
  --env=DISPLAY=${XPRA_DISPLAY} \
  --mdns=no \
  --pulseaudio=no \
  --printing=no \
  --notifications=no \
  --bell=no \
  --webcam=no \
  --clipboard=no \
  --desktop-scaling=off \
  --resize-display=yes \
  --dpi=96 \
  --encoding=auto \
  --video-encoders=none \
  --min-quality=30 \
  --quality=50 \
  --min-speed=90 \
  --speed=100 \
  --auto-refresh-delay=0.4 \
  --refresh-rate=10 \
  --start-child="${APP_ENTRYPOINT}" \
  --exit-with-children=yes \
  --daemon=no \
  --log-file="${XPRA_LOG}" \
  2>&1 | tee -a "${XPRA_LOG}"
xpra_status=${PIPESTATUS[0]}
set -e

if [[ ${xpra_status} -ne 0 && -f "${XPRA_LOG}" ]]; then
  echo "xpra exited with ${xpra_status}, dumping log:"
  cat "${XPRA_LOG}"
fi

exit "${xpra_status}"
