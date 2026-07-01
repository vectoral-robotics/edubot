#!/usr/bin/env bash
set -euo pipefail

CERT_DIR=/state/codeserver/certs
CONFIG_DIR=/state/codeserver/code-server
WORKSPACE_FILE=/state/codeserver/edubot.code-workspace
CERT_FILE=${CERT_DIR}/code-server.crt
KEY_FILE=${CERT_DIR}/code-server.key
CONFIG_FILE=${CONFIG_DIR}/config.yaml
DEMO_SOURCE_DIR=/opt/edubot_demos
DEMO_TARGET_DIR=/workspace/src

mkdir -p /settings/dev /settings/ros

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
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}

mkdir -p "${CERT_DIR}" "${CONFIG_DIR}"

if [[ -d "${DEMO_SOURCE_DIR}" ]]; then
  mkdir -p "${DEMO_TARGET_DIR}"
  shopt -s nullglob
  for demo_item in "${DEMO_SOURCE_DIR}"/*; do
    demo_target="${DEMO_TARGET_DIR}/$(basename "${demo_item}")"
    if [[ ! -e "${demo_target}" ]]; then
      cp -a "${demo_item}" "${demo_target}"
    fi
  done
  shopt -u nullglob
fi

if [[ ! -f "${CERT_FILE}" || ! -f "${KEY_FILE}" ]]; then
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj "/CN=${CODE_SERVER_CN:-edubot-codeserver}" \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}"
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  cat > "${CONFIG_FILE}" <<EOF_CONF
bind-addr: 0.0.0.0:8443
auth: none
cert: ${CERT_FILE}
cert-key: ${KEY_FILE}
EOF_CONF
fi

cat > "${WORKSPACE_FILE}" <<EOF_WORKSPACE
{
  "folders": [
    { "name": "Workspace", "path": "/workspace" },
    { "name": "Edubot", "path": "/edubot" }
  ],
  "settings": {
    "terminal.integrated.cwd": "/workspace"
  }
}
EOF_WORKSPACE

exec code-server --config "${CONFIG_FILE}" "${WORKSPACE_FILE}"
