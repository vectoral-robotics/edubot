#!/usr/bin/env bash
# install-boot-leds.sh — provision the EduBot boot LED animation on the Pi.
#
# Run once per robot, AFTER 'make enable-spi' and a reboot so /dev/spidev0.0
# exists. Idempotent: safe to re-run after updating boot-leds.py.
#
#   sudo ./scripts/install-boot-leds.sh     (or: make install-boot-leds)
#
# What this does:
#   1. Installs adafruit-circuitpython-neopixel-spi on the host (pip3).
#   2. Copies scripts/boot-leds.py to /opt/edubot/boot-leds.py.
#   3. Writes /etc/systemd/system/edubot-leds-boot.service.
#   4. Enables and starts the service so it survives reboots.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/edubot"
SCRIPT_SRC="${SCRIPT_DIR}/boot-leds.py"
SCRIPT_DEST="${INSTALL_DIR}/boot-leds.py"
UNIT_FILE="/etc/systemd/system/edubot-leds-boot.service"

# --- Require root -----------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "[install-boot-leds] re-running with sudo..."
    exec sudo "$0" "$@"
fi

# --- Check SPI is enabled ---------------------------------------------------
if [ ! -e /dev/spidev0.0 ]; then
    echo "[install-boot-leds] /dev/spidev0.0 not found." >&2
    echo "[install-boot-leds] Run 'make enable-spi' first, then reboot, then retry." >&2
    exit 1
fi

# --- Python dependency ------------------------------------------------------
if ! python3 -c "import neopixel_spi" 2>/dev/null; then
    echo "[install-boot-leds] installing adafruit-circuitpython-neopixel-spi..."
    pip3 install --break-system-packages adafruit-circuitpython-neopixel-spi
fi

# --- Install script ---------------------------------------------------------
mkdir -p "${INSTALL_DIR}"
cp "${SCRIPT_SRC}" "${SCRIPT_DEST}"
chmod +x "${SCRIPT_DEST}"
echo "[install-boot-leds] installed ${SCRIPT_DEST}"

# --- Write systemd unit -----------------------------------------------------
cat > "${UNIT_FILE}" << 'UNIT'
[Unit]
Description=EduBot corner LED boot animation
# Start as early as possible — well before Docker or network.
After=sysinit.target
DefaultDependencies=no

[Service]
Type=simple
ExecStart=/opt/edubot/boot-leds.py
# Clean exit (normal handoff to led_node) is not a failure.
Restart=on-failure
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable edubot-leds-boot.service

# Start now if not already running (first install).
if systemctl is-active --quiet edubot-leds-boot.service; then
    echo "[install-boot-leds] service already running — restarting to pick up changes"
    systemctl restart edubot-leds-boot.service
else
    systemctl start edubot-leds-boot.service
fi

echo "[install-boot-leds] edubot-leds-boot.service enabled and running."
echo "[install-boot-leds] Verify: systemctl status edubot-leds-boot"
