# EduBot meta-repo — single entry point for development and deployment.
#
#   make src        clone/refresh ROS packages into ./src and dev repos into ./dev
#   make dev        run the ROS 2 core built live from ./src (developer loop)
#   make login      log in to GHCR for private image pulls (once per robot)
#   make up         run the fleet stack from pre-built GHCR images
#   make pull       pull the latest images for the current channel
#   make update     pull + restart the fleet stack (on-robot OTA update)
#   make freeze     write current src commits to edubot.lock.repos (release)
#   make status     git status across all src repos
#   make flash      (re)flash the ESP32-S3 from source with SKETCH (dev)
#   make flash-fleet  reflash the ESP32-S3 from the edubot-flasher image (fleet)
#   make flash-setup  install arduino-cli + the ESP32 core (once per machine)

SHELL := /bin/bash
# Core ROS 2 workspace (colcon). Dev-only, non-ROS repos (firmware) go in DEV_DIR
# so they never leak into the reproducible lockfile or the fleet image.
SRC_DIR := src
DEV_DIR := dev

# Fleet stack channel: stable (default) | dev | vX.Y.Z
CHANNEL ?= stable
# Firmware sketch flashed by `make flash`.
SKETCH ?= EduBot_PI_Control_v2

DEV_COMPOSE := docker-compose.dev.yaml
FLEET_COMPOSE := docker-compose.yaml

.DEFAULT_GOAL := help

.PHONY: help
help:
	@grep -E '^#   make ' $(MAKEFILE_LIST) | sed 's/^#   /  /'

# ---- Source management (vcstool) ------------------------------------------
.PHONY: src
src: ## Import ROS packages into ./src and dev repos into ./dev
	@mkdir -p $(SRC_DIR) $(DEV_DIR)
	vcs import $(SRC_DIR) < edubot.repos
	vcs import $(DEV_DIR) < edubot.dev.repos
	@echo "[edubot] src/ (ROS core) + dev/ (firmware) ready — full git checkouts."

.PHONY: status
status: ## Show git status across all checked-out repos
	@vcs status $(SRC_DIR)
	@test -d $(DEV_DIR) && vcs status $(DEV_DIR) || true

.PHONY: pull-src
pull-src: ## git pull across all checked-out repos (fast-forward)
	@vcs pull $(SRC_DIR)
	@test -d $(DEV_DIR) && vcs pull $(DEV_DIR) || true

.PHONY: freeze
freeze: ## Freeze current src commits into edubot.lock.repos
	@test -d $(SRC_DIR) && [ -n "$$(ls -A $(SRC_DIR) 2>/dev/null)" ] \
		|| { echo "src/ is empty — run 'make src' first"; exit 1; }
	@# Only the ROS core (src/) is frozen — dev/ (firmware) is intentionally excluded.
	@vcs export --exact $(SRC_DIR) > edubot.lock.repos
	@echo "[edubot] wrote edubot.lock.repos (pinned commits)."

# ---- Development (build from source) --------------------------------------
.PHONY: dev
dev: ## Run the ROS 2 core built live from ./src
	@test -d $(SRC_DIR) || { echo "run 'make src' first"; exit 1; }
	docker compose -f $(DEV_COMPOSE) up --build

.PHONY: dev-down
dev-down:
	docker compose -f $(DEV_COMPOSE) down

# ---- Fleet (pre-built images) ---------------------------------------------
.PHONY: login
login: ## Log in to GHCR (once per robot; pull-only token)
	./scripts/ghcr-login.sh

.PHONY: up
up: ## Run the fleet stack from GHCR images
	EDUBOT_CHANNEL=$(CHANNEL) docker compose -f $(FLEET_COMPOSE) up -d

.PHONY: down
down:
	docker compose -f $(FLEET_COMPOSE) down

.PHONY: pull
pull: ## Pull latest images for the current channel
	EDUBOT_CHANNEL=$(CHANNEL) docker compose -f $(FLEET_COMPOSE) pull

.PHONY: update
update: ## OTA update: pull + restart the fleet stack
	EDUBOT_CHANNEL=$(CHANNEL) ./scripts/update.sh

.PHONY: flash-fleet
flash-fleet: ## Reflash the ESP32-S3 from the edubot-flasher image (no source)
	EDUBOT_CHANNEL=$(CHANNEL) docker compose -f $(FLEET_COMPOSE) \
		--profile flash run --rm flasher

# ---- Firmware -------------------------------------------------------------
.PHONY: flash
flash: ## Flash the ESP32-S3 with SKETCH (default EduBot_PI_Control_v2)
	@test -x $(DEV_DIR)/edubot_firmware/tools/flash.sh \
		|| { echo "firmware not found — run 'make src' first"; exit 1; }
	$(DEV_DIR)/edubot_firmware/tools/flash.sh $(SKETCH) $(FLASH_ARGS)

.PHONY: flash-setup
flash-setup: ## Install arduino-cli + the ESP32 core (once per machine)
	@command -v arduino-cli >/dev/null 2>&1 || { \
		echo "Installing arduino-cli..."; \
		curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh; }
	arduino-cli core update-index
	arduino-cli core install esp32:esp32
