#!/usr/bin/env bash
set -Eeuo pipefail

RVIZ_IMAGE_SHARE=${RVIZ_IMAGE_SHARE:-/opt/edubot_rviz_ws/install/edubot_viz/share/edubot_viz}
RVIZ_DEFAULT_CONFIG=${RVIZ_DEFAULT_CONFIG:-/edubot/ROS2/edubot_ws/src/edubot_viz/rviz/bringup_view.rviz}
RVIZ_NAV_CONFIG=${RVIZ_NAV_CONFIG:-/edubot/ROS2/edubot_ws/src/edubot_viz/rviz/navigation_view.rviz}
RVIZ_STATE_DIR=${RVIZ_STATE_DIR:-/state/rviz}
RVIZ_SETTINGS_DIR=${RVIZ_SETTINGS_DIR:-/settings/rviz}
RVIZ_LOG_DIR=${RVIZ_LOG_DIR:-/tmp/rviz}
RVIZ_LOG_FILE=${RVIZ_LOG_FILE:-${RVIZ_LOG_DIR}/rviz.log}

mkdir -p \
  "${RVIZ_SETTINGS_DIR}" \
  "${RVIZ_STATE_DIR}/home" \
  "${RVIZ_STATE_DIR}/config" \
  "${RVIZ_STATE_DIR}/configs" \
  "${RVIZ_LOG_DIR}"
mkdir -p "${RVIZ_STATE_DIR}/runtime"
chmod 700 "${RVIZ_STATE_DIR}/runtime"

if [[ ! -f "${RVIZ_DEFAULT_CONFIG}" && -f "${RVIZ_IMAGE_SHARE}/rviz/bringup_view.rviz" ]]; then
  RVIZ_DEFAULT_CONFIG="${RVIZ_IMAGE_SHARE}/rviz/bringup_view.rviz"
fi

if [[ ! -f "${RVIZ_NAV_CONFIG}" && -f "${RVIZ_IMAGE_SHARE}/rviz/navigation_view.rviz" ]]; then
  RVIZ_NAV_CONFIG="${RVIZ_IMAGE_SHARE}/rviz/navigation_view.rviz"
fi

export HOME="${RVIZ_STATE_DIR}/home"
export XDG_CONFIG_HOME="${RVIZ_STATE_DIR}/config"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${RVIZ_STATE_DIR}/runtime}"
export QT_X11_NO_MITSHM=1

# Force RViz window to top-left corner so it stays within Xvfb bounds
# even when the browser client reports a larger virtual screen.
export QT_QPA_PLATFORM=xcb
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_SCALE_FACTOR=1

if [[ -f "${RVIZ_DEFAULT_CONFIG}" ]]; then
  ln -sf "${RVIZ_DEFAULT_CONFIG}" "${RVIZ_STATE_DIR}/configs/bringup_view.rviz"
fi

if [[ -f "${RVIZ_NAV_CONFIG}" ]]; then
  ln -sf "${RVIZ_NAV_CONFIG}" "${RVIZ_STATE_DIR}/configs/navigation_view.rviz"
fi

run_rviz_once() {
  local -a rviz_cmd=(rviz2)

  if [[ -f "${RVIZ_DEFAULT_CONFIG}" ]]; then
    rviz_cmd+=(-d "${RVIZ_DEFAULT_CONFIG}")
  fi

  : > "${RVIZ_LOG_FILE}"

  set +e
  "${rviz_cmd[@]}" 2>&1 | tee -a "${RVIZ_LOG_FILE}"
  local rviz_status=${PIPESTATUS[0]}
  set -e

  return "${rviz_status}"
}

if run_rviz_once; then
  exit 0
fi

if grep -Eq \
  'Unable to create a suitable GLXContext|Failed to create an OpenGL context|Unable to create the rendering window' \
  "${RVIZ_LOG_FILE}" && [[ "${RVIZ_RENDER_MODE:-software}" != "software" ]]; then
  echo "WARN: RViz OpenGL context creation failed; retrying with llvmpipe software rendering"
  export RVIZ_RENDER_MODE=software
  export LIBGL_ALWAYS_SOFTWARE=1
  export GALLIUM_DRIVER=llvmpipe
  export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
  export LIBGL_DRI3_DISABLE=1
  run_rviz_once
  exit $?
fi

exit 1
