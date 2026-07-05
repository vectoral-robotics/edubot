#!/usr/bin/env bash
# enable-spi.sh — one-time host provisioning for the EduBot corner LEDs.
#
# The WS2812B corner NeoPixels are driven over SPI (MOSI / GPIO10) on the
# Raspberry Pi 5, because the PIO path of adafruit-circuitpython-neopixel does
# not work on the Pi 5 / Ubuntu 24.04 ("Failed to open PIO device", no
# /dev/pio0). Driving them needs the SPI bus enabled so /dev/spidev0.0 exists.
#
# This is idempotent: run it once per robot during provisioning, then reboot.
# The ROS stack itself needs no extra device flags — the edubot container runs
# privileged with /dev bind-mounted, so it sees /dev/spidev0.0 directly.
#
# Wiring (per corner LED chain, single data line):
#   NeoPixel DIN -> GPIO10 / MOSI (pin 19)
#   NeoPixel 5V  -> pin 2
#   NeoPixel GND -> pin 6
set -euo pipefail

CONFIG="${SPI_CONFIG_TXT:-/boot/firmware/config.txt}"
PARAM="dtparam=spi=on"

if [ ! -f "$CONFIG" ]; then
  echo "[enable-spi] $CONFIG not found." >&2
  echo "[enable-spi] This script is for a Raspberry Pi with the Ubuntu/RPi firmware boot config." >&2
  exit 1
fi

if [ ! -w "$CONFIG" ]; then
  echo "[enable-spi] $CONFIG is not writable — re-run with sudo:" >&2
  echo "             sudo $0" >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*dtparam=spi=on[[:space:]]*$' "$CONFIG"; then
  echo "[enable-spi] SPI already enabled in $CONFIG."
else
  # Uncomment an existing '#dtparam=spi=...' line if present, else append.
  if grep -Eq '^[[:space:]]*#?[[:space:]]*dtparam=spi=' "$CONFIG"; then
    sed -i -E 's|^[[:space:]]*#?[[:space:]]*dtparam=spi=.*|'"$PARAM"'|' "$CONFIG"
  else
    printf '\n# Enable SPI for the EduBot corner NeoPixels (WS2812B over MOSI/GPIO10).\n%s\n' \
      "$PARAM" >> "$CONFIG"
  fi
  echo "[enable-spi] Enabled '$PARAM' in $CONFIG."
fi

if [ -e /dev/spidev0.0 ]; then
  echo "[enable-spi] /dev/spidev0.0 already present — SPI is active."
else
  echo "[enable-spi] Reboot required for /dev/spidev0.0 to appear:  sudo reboot"
fi
