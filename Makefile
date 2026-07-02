# EduBot meta-repo — single entry point for development and deployment.
#
#   make src        clone/refresh ROS packages into ./src and dev repos into ./dev
#   make dev        build and run the whole stack from local source
#   make login      log in to GHCR for private image pulls (once per robot)
#   make up         run the stack (pull the 3 images, build the rest locally)
#   make pull       pull the latest images for the current channel
#   make update     pull + restart the fleet stack (on-robot OTA update)
#   make freeze     pin current src + dev commits into the lockfiles (release)
#   make release-dev      cut a dev release (freeze + build/push :dev + commit to 'dev')
#   make promote-stable   promote dev -> stable (re-tag images, no rebuild; VERSION=X.Y.Z)
#   make status     git status across all src repos
#   make flash      (re)flash the ESP32-S3 from source with SKETCH (dev)
#   make flash-fleet  reflash the ESP32-S3 from the edubot-flasher image (fleet)
#   make flash-setup  install arduino-cli + the ESP32 core (once per machine)

SHELL := /bin/bash
# Core ROS 2 workspace (colcon) in SRC_DIR; non-ROS source repos (firmware,
# dashboard) in DEV_DIR so they stay out of the colcon workspace. Both are
# pinned by `make freeze` (into edubot.lock.repos / edubot.dev.lock.repos) and
# both feed the fleet images, which are built centrally by scripts/release.sh.
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
freeze: ## Pin current src + dev commits into the lockfiles (release BOM)
	@test -d $(SRC_DIR) && [ -n "$$(ls -A $(SRC_DIR) 2>/dev/null)" ] \
		|| { echo "src/ is empty — run 'make src' first"; exit 1; }
	@test -d $(DEV_DIR) && [ -n "$$(ls -A $(DEV_DIR) 2>/dev/null)" ] \
		|| { echo "dev/ is empty — run 'make src' first"; exit 1; }
	@# The bill-of-materials for a stable release: ROS core (src/) and the
	@# non-ROS source repos (dev/ — dashboard, firmware) that feed the images.
	@vcs export --exact $(SRC_DIR) > edubot.lock.repos
	@vcs export --exact $(DEV_DIR) > edubot.dev.lock.repos
	@echo "[edubot] wrote edubot.lock.repos + edubot.dev.lock.repos (pinned commits)."

# ---- Release (the ONLY place the fleet images are built) ------------------
# GitOps model: the meta-repo is the source of truth and carries two channel
# branches, 'dev' and 'stable'. A release is one pipeline that builds/tags the
# images AND writes a commit on the channel branch pinning them. See RELEASING.md.
.PHONY: release-dev
release-dev: ## Cut a dev release: freeze + build/push :dev + commit to 'dev'
	./scripts/release-dev.sh

.PHONY: promote-stable
promote-stable: ## Promote dev -> stable (re-tag images, no rebuild); VERSION=X.Y.Z optional
	./scripts/promote-stable.sh

# ---- Development (build everything from source) ---------------------------
.PHONY: dev
dev: ## Build and run the whole stack from local source (pulls nothing*)
	@test -d $(SRC_DIR) || { echo "run 'make src' first"; exit 1; }
	docker compose -f $(FLEET_COMPOSE) -f $(DEV_COMPOSE) up -d --build

.PHONY: dev-down
dev-down:
	docker compose -f $(FLEET_COMPOSE) -f $(DEV_COMPOSE) down

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
