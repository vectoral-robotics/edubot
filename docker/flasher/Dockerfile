# edubot-flasher — reflash the ESP32-S3 on a delivered robot without shipping
# firmware source. Two stages so the published image contains only the compiled
# binary (no .ino source), which keeps it safe to publish as a PUBLIC image.
#
# Build recipe lives in the meta-repo; the firmware source lives in
# edubot_firmware (checked out into ./dev/edubot_firmware by `make src`). Build
# context is the meta-repo root, so paths below are relative to it. Built via
# scripts/release.sh — never from the firmware repo's own CI.
#
# Run privileged with the board's serial device, e.g.:
#   docker run --rm --privileged -v /dev:/dev ghcr.io/vectoral-robotics/edubot-flasher
ARG SKETCH=EduBot_PI_Control_v2
ARG FQBN=esp32:esp32:esp32s3:CDCOnBoot=cdc
ARG ARDUINO_CLI_VERSION=1.5.1

# ---- Stage 1: compile the delivery sketch (source lives here only) ----------
FROM debian:bookworm-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG SKETCH
ARG FQBN
ARG ARDUINO_CLI_VERSION
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 \
 && rm -rf /var/lib/apt/lists/*

# Pinned arduino-cli via direct tarball — avoids the install.sh "latest" GitHub
# API lookup that flakes with 404s in CI. TARGETARCH is provided by buildx.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) asset=64bit ;; \
      arm64) asset=ARM64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/arduino/arduino-cli/releases/download/v${ARDUINO_CLI_VERSION}/arduino-cli_${ARDUINO_CLI_VERSION}_Linux_${asset}.tar.gz" \
      | tar -xz -C /usr/local/bin arduino-cli; \
    arduino-cli version

RUN arduino-cli config init \
 && arduino-cli config add board_manager.additional_urls \
      https://espressif.github.io/arduino-esp32/package_esp32_index.json \
 && arduino-cli core update-index \
 && arduino-cli core install esp32:esp32

WORKDIR /firmware
COPY dev/edubot_firmware/firmware/${SKETCH} ./firmware/${SKETCH}
RUN arduino-cli compile --fqbn "${FQBN}" --warnings all \
      --output-dir /opt/edubot/fw "firmware/${SKETCH}"

# ---- Stage 2: runtime — arduino-cli + core + the compiled binary only --------
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
ARG SKETCH
ARG FQBN
ARG ARDUINO_CLI_VERSION
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 \
 && rm -rf /var/lib/apt/lists/*

# arduino-cli + the ESP32 core provide esptool for the actual upload.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) asset=64bit ;; \
      arm64) asset=ARM64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/arduino/arduino-cli/releases/download/v${ARDUINO_CLI_VERSION}/arduino-cli_${ARDUINO_CLI_VERSION}_Linux_${asset}.tar.gz" \
      | tar -xz -C /usr/local/bin arduino-cli; \
    arduino-cli version

RUN arduino-cli config init \
 && arduino-cli config add board_manager.additional_urls \
      https://espressif.github.io/arduino-esp32/package_esp32_index.json \
 && arduino-cli core update-index \
 && arduino-cli core install esp32:esp32

WORKDIR /firmware
# Only the compiled artifacts and the version — no .ino source.
COPY --from=builder /opt/edubot/fw /opt/edubot/fw
COPY dev/edubot_firmware/VERSION ./VERSION

ENV EDUBOT_SKETCH=${SKETCH} EDUBOT_FQBN=${FQBN}
COPY docker/flasher/flash-entrypoint.sh /flash-entrypoint.sh
RUN chmod +x /flash-entrypoint.sh

ENTRYPOINT ["/flash-entrypoint.sh"]
