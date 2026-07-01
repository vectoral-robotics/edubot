# EduBot meta-repo — single entry point for development and deployment.
#
#   make src        clone/refresh all package repos into ./src (incl. firmware)
#   make dev        run the ROS 2 core built live from ./src (developer loop)
#   make up         run the fleet stack from pre-built GHCR images
#   make pull       pull the latest images for the current channel
#   make update     pull + restart the fleet stack (on-robot OTA update)
#   make freeze     write current src commits to edubot.lock.repos (release)
#   make status     git status across all src repos
#   make flash      (re)flash the ESP32-S3 with SKETCH (default PI_Control_v2)
#   make flash-setup  install arduino-cli + the ESP32 core (once per machine)

SHELL := /bin/bash
SRC_DIR := src

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
src: ## Import/refresh all repos into ./src
	@mkdir -p $(SRC_DIR)
	vcs import $(SRC_DIR) < edubot.repos
	vcs import $(SRC_DIR) < edubot.dev.repos
	@echo "[edubot] src/ ready. Each repo is a full git checkout — branch/push freely."

.PHONY: status
status: ## Show git status across all src repos
	@vcs status $(SRC_DIR)

.PHONY: pull-src
pull-src: ## git pull across all src repos (fast-forward)
	@vcs pull $(SRC_DIR)

.PHONY: freeze
freeze: ## Freeze current src commits into edubot.lock.repos
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

# ---- Firmware -------------------------------------------------------------
.PHONY: flash
flash: ## Flash the ESP32-S3 with SKETCH (default EduBot_PI_Control_v2)
	@test -x $(SRC_DIR)/edubot_firmware/tools/flash.sh \
		|| { echo "firmware not found — run 'make src' first"; exit 1; }
	$(SRC_DIR)/edubot_firmware/tools/flash.sh $(SKETCH) $(FLASH_ARGS)

.PHONY: flash-setup
flash-setup: ## Install arduino-cli + the ESP32 core (once per machine)
	@command -v arduino-cli >/dev/null 2>&1 || { \
		echo "Installing arduino-cli..."; \
		curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh; }
	arduino-cli core update-index
	arduino-cli core install esp32:esp32
