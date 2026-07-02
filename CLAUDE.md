# edubot (meta-repo) — Claude guidelines

The single entry point for developing and deploying EduBot. It orchestrates the
separate package repos; it holds almost no code of its own.

## What lives here

- `edubot.repos` / `edubot.dev.repos` — vcstool manifests (main); their frozen
  counterparts `edubot.lock.repos` / `edubot.dev.lock.repos` are the release BOM.
- `docker-compose.dev.yaml` (build from source) and `docker-compose.yaml`
  (pre-built GHCR images). One robot runs one or the other.
- `Makefile` — the user-facing commands (`src`, `dev`, `up`, `pull`, `update`,
  `freeze`, `release`, `flash`).
- `docker/` — the **build recipes for all three fleet images** (`ros2*.Dockerfile`,
  `dashboard/`, `flasher/`). `scripts/` — `release.sh` (image builds) + on-robot
  `update.sh`.

`make src` imports the ROS core into `./src` and the non-ROS source repos
(firmware, dashboard) into `./dev`; both are git-ignored — never commit them. The
repos under them are independent checkouts; app work happens inside them, not
here. `./dev` is kept out of `./src` so it never enters the colcon workspace.

## Image builds — centralized here, nowhere else

All three fleet images are built **only** from this repo via `make release`
(`scripts/release.sh`) — the app repos do NOT build images in their own CI.

- `edubot-ros2` ← `docker/ros2.Dockerfile` (imports its sources in-container).
- `edubot-dashboard` ← `docker/dashboard/Dockerfile` (source: `dev/edubot_dashboard`).
- `edubot-flasher` ← `docker/flasher/Dockerfile` (source: `dev/edubot_firmware`).

Build context is always the meta-repo root. `CHANNEL=dev` builds from the main
manifests and tags `:dev`; `CHANNEL=stable` builds from the lockfiles and tags
`:stable` + `:v<product-version>`. Multi-arch (amd64/arm64) via buildx — runs on
any machine with Docker (a Mac is fine; no ROS/Pi needed). A push needs a GHCR
login with `write:packages`.

## Conventions

- **English everywhere** (code, comments, docs, commits).
- **Conventional Commits**, scope = area (e.g. `feat(compose): …`,
  `docs(readme): …`, `chore(makefile): …`).
- **Maintainer/contact:** Vectoral, info@vectoral.ch.
- **License:** PolyForm Perimeter 1.0.0 (this meta-repo is source-available; the
  firmware it references is private/proprietary).

## Two audiences, two mechanisms

- **Developers** build from source (`make dev`), switch branches per repo.
- **Fleet** pulls versioned images (`make up` / `make update`); channels
  `stable`/`dev`/`vX.Y.Z`. Images are public → no login needed. (`make login` /
  `scripts/ghcr-login.sh` stay available if an image is kept private.)

Never conflate the two — source-private repos still deploy fine, because the
robot only ever needs images + a tiny compose/env bundle, not source. The
flasher image ships a compiled binary only, so publishing it public leaks no
firmware source.

## Versioning

Component (per-repo semver tags) → image (built from a lockfile) → product (a
tag on this repo; the lockfiles are the bill-of-materials). `make freeze` records
the current `src/` **and** `dev/` commits into `edubot.lock.repos` /
`edubot.dev.lock.repos` for a reproducible stable release.

## Firmware

`edubot_firmware` is private and NOT a colcon package. It is imported via
`edubot.dev.repos` into `./dev`. It holds **only firmware source** (sketches +
host tools); the flasher image's build recipe lives here in `docker/flasher/`.
Delivery-standard sketch is `EduBot_PI_Control_v2`. `make flash` wraps the
firmware's `tools/flash.sh` (dev, source flash); `make flash-fleet` runs the
`edubot-flasher` image (fleet reflash, binary only — no firmware source shipped).
