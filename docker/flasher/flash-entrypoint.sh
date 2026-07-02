#!/usr/bin/env bash
# Upload the pre-compiled delivery firmware to the ESP32-S3.
#
# The sketch was compiled into /opt/edubot/fw at image build time; here we only
# upload it, mirroring tools/flash.sh (same FQBN, conservative 115200 upload).
#
# Env:
#   PORT           serial device (auto-detected if unset)
#   UPLOAD_SPEED   upload baud (default 115200 — reliable on the S3-Zero USB CDC)
#   EDUBOT_FQBN    board FQBN (baked from the image build)
set -euo pipefail

FQBN="${EDUBOT_FQBN:-esp32:esp32:esp32s3:CDCOnBoot=cdc}"
UPLOAD_SPEED="${UPLOAD_SPEED:-115200}"
BUILD_DIR="/opt/edubot/fw"
PORT="${PORT:-}"

info() { printf '\033[1;34m[flasher]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[flasher]\033[0m %s\n' "$*" >&2; exit 1; }

info "firmware version: $(cat /firmware/VERSION 2>/dev/null || echo unknown) (sketch ${EDUBOT_SKETCH:-?})"

detect_port() {
  for p in /dev/edubot_esp32 /dev/ttyACM0 /dev/ttyUSB0; do
    [ -e "$p" ] && { echo "$p"; return 0; }
  done
  arduino-cli board list 2>/dev/null | awk 'NR>1 && $1 ~ /^\/dev\// {print $1; exit}'
}

if [ -z "$PORT" ]; then
  PORT="$(detect_port || true)"
  [ -n "$PORT" ] || die "no serial port found — pass PORT=/dev/ttyACM0 (and mount /dev)."
  info "auto-detected port: $PORT"
fi
[ -e "$PORT" ] || die "serial port '$PORT' does not exist. Is the board connected? Is ROS holding it?"

info "uploading ${EDUBOT_SKETCH:-firmware} to ${PORT} (${UPLOAD_SPEED} baud)..."
arduino-cli upload --fqbn "$FQBN" -p "$PORT" \
  --input-dir "$BUILD_DIR" \
  --board-options "UploadSpeed=${UPLOAD_SPEED}"
info "done. Power-cycle the board if it does not reboot into the new firmware."
