#!/usr/bin/env python3
"""
EduBot boot LED animation — runs on the Raspberry Pi 5 host, before Docker/ROS.

Pulses all four corner NeoPixels in a calm cool-white breathing pattern from
the moment the OS starts until the ROS container signals that it is about to
take ownership of the SPI bus (by creating /dev/edubot-leds-stop).

Managed by edubot-leds-boot.service. Provision once per robot:

    make install-boot-leds   (after make enable-spi + reboot)

Handoff sequence
    1. This script starts at boot, holds /dev/spidev0.0, breathes.
    2. The edubot_ros2 container's run.sh touches /dev/edubot-leds-stop.
    3. This script detects the flag, clears all pixels, releases SPI, exits.
    4. led_node starts and lights up the steady "ready" colour.

Environment variables (all optional):
    EDUBOT_LED_COUNT      number of pixels   (default 4)
    EDUBOT_LED_BRIGHTNESS hardware brightness, 0..1 (default 0.4)
    EDUBOT_LED_PERIOD     breath period in seconds  (default 4.0)
    EDUBOT_LED_BREATH_MIN dimmest level, 0..1       (default 0.08)
"""

import math
import os
import signal
import sys
import time

# ---------------------------------------------------------------------------
# Configuration (overridable via env for multi-robot fleets)
# ---------------------------------------------------------------------------
NUM_PIXELS = int(os.environ.get("EDUBOT_LED_COUNT", "4"))
BRIGHTNESS = float(os.environ.get("EDUBOT_LED_BRIGHTNESS", "0.4"))
PERIOD = float(os.environ.get("EDUBOT_LED_PERIOD", "4.0"))
BREATH_MIN = float(os.environ.get("EDUBOT_LED_BREATH_MIN", "0.08"))
COLOR = (200, 225, 255)  # cool white — same shade as led_node's startup_color
STOP_FLAG = "/dev/edubot-leds-stop"
TICK = 1.0 / 30.0  # 30 fps animation

# ---------------------------------------------------------------------------
_running = True


def _handle_signal(signum, frame):
    global _running
    _running = False


def _clamp8(v):
    return max(0, min(255, round(v)))


def _breathing_level(elapsed, period, gamma=2.2):
    """Gamma-eased raised-cosine: 0 at start/end, 1 at half-period."""
    if period <= 0:
        return 0.0
    raw = (1.0 - math.cos(2.0 * math.pi * (elapsed / period))) / 2.0
    return raw**gamma


def main():
    global _running
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    # Clean up any leftover stop-flag from a previous boot.
    try:
        os.remove(STOP_FLAG)
    except FileNotFoundError:
        pass

    try:
        import board
        import busio
        import neopixel_spi
    except Exception as exc:
        print(f"[boot-leds] library unavailable ({exc}); exiting.", file=sys.stderr)
        sys.exit(0)

    try:
        spi = busio.SPI(board.SCLK, MOSI=board.MOSI)
        pixels = neopixel_spi.NeoPixel_SPI(
            spi,
            NUM_PIXELS,
            brightness=BRIGHTNESS,
            auto_write=False,
            pixel_order=neopixel_spi.GRB,
        )
    except Exception as exc:
        print(f"[boot-leds] SPI init failed ({exc}); exiting.", file=sys.stderr)
        sys.exit(0)

    print(
        f"[boot-leds] breathing on {NUM_PIXELS} pixels, period={PERIOD}s "
        f"(stop flag: {STOP_FLAG})"
    )

    start = time.monotonic()
    try:
        while _running:
            if os.path.exists(STOP_FLAG):
                print("[boot-leds] stop flag received — handing off to led_node")
                break
            elapsed = time.monotonic() - start
            raw = _breathing_level(elapsed, PERIOD)
            level = BREATH_MIN + (1.0 - BREATH_MIN) * raw
            c = (_clamp8(COLOR[0] * level), _clamp8(COLOR[1] * level), _clamp8(COLOR[2] * level))
            pixels.fill(c)
            pixels.show()
            time.sleep(TICK)
    finally:
        # Clear pixels and release the SPI bus before led_node opens it.
        try:
            pixels.fill((0, 0, 0))
            pixels.show()
        except Exception:
            pass
        try:
            os.remove(STOP_FLAG)
        except FileNotFoundError:
            pass
        print("[boot-leds] SPI released — exiting")


if __name__ == "__main__":
    main()
