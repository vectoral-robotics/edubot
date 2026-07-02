# edubot (meta-repo) — Claude guidelines

The single entry point for developing and deploying EduBot. It orchestrates the
separate package repos; it holds almost no code of its own.

## What lives here

- `edubot.repos` / `edubot.dev.repos` — vcstool manifests (main); their frozen
  counterparts `edubot.lock.repos` / `edubot.dev.lock.repos` are the release BOM.
- `docker-compose.dev.yaml` (build from source) and `docker-compose.yaml`
  (pre-built GHCR images). One robot runs one or the other.
- `Makefile` — the user-facing commands (`src`, `dev`, `up`, `pull`, `update`,
  `freeze`, `release-dev`, `promote-stable`, `flash`).
- `channels/dev.json` / `channels/stable.json` — the per-channel release
  manifest (version + pinned image **digests** + component versions), written on
  the `dev`/`stable` branches. Robots watch their channel branch.
- `docker/` — the **build recipes for all three fleet images** (`ros2*.Dockerfile`,
  `dashboard/`, `flasher/`). `scripts/` — `release.sh` (image builds) + on-robot
  `update.sh`.

`make src` imports the ROS core into `./src` and the non-ROS source repos
(firmware, dashboard) into `./dev`; both are git-ignored — never commit them. The
repos under them are independent checkouts; app work happens inside them, not
here. `./dev` is kept out of `./src` so it never enters the colcon workspace.

## Image builds — centralized here, nowhere else

All three fleet images are built **only** from this repo (via
`scripts/build-images.sh`, driven by `make release-dev`) — the app repos do NOT
build images in their own CI.

- `edubot-ros2` ← `docker/ros2.Dockerfile` (imports its sources in-container).
- `edubot-dashboard` ← `docker/dashboard/Dockerfile` (source: `dev/edubot_dashboard`).
- `edubot-flasher` ← `docker/flasher/Dockerfile` (source: `dev/edubot_firmware`).

Build context is always the meta-repo root. `make release-dev` freezes the
sub-repo mains, builds all three multi-arch (amd64/arm64) via buildx, pushes
`:dev`, and records the pushed **digests** in `channels/dev.json`.
`make promote-stable` re-tags those same digests `:stable` + `:vX.Y.Z` with
`docker buildx imagetools create` (no rebuild). Runs on any machine with Docker
(a Mac is fine; no ROS/Pi needed). A push needs a GHCR login with
`write:packages`.

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

## Versioning (GitOps, two channel branches)

The meta-repo is the source of truth and carries two channel branches, `dev` and
`stable` (plus `main`, where the meta-repo is developed via PRs). A *release* is
one pipeline that builds/tags the images AND writes a commit on the channel
branch pinning them:

- `make release-dev` — freeze sub-repo mains, build+push `:dev`, write
  `channels/dev.json` (pinned digests) and commit to `dev`. Version `dev-N`.
- `make promote-stable [VERSION=X.Y.Z]` — re-tag the SAME dev digests as
  `:stable` + `:vX.Y.Z` (no rebuild), write `channels/stable.json`, commit +
  tag on `stable`.

`dev`/`stable` are never hand-edited — only the pipeline writes them. Robots
follow one channel (`EDUBOT_CHANNEL`); `make update` checks out the channel's
latest commit (bringing new compose/config) and pins images by digest. Component
tags (per-repo semver) still feed the lockfiles. See RELEASING.md.

## Firmware

`edubot_firmware` is private and NOT a colcon package. It is imported via
`edubot.dev.repos` into `./dev`. It holds **only firmware source** (sketches +
host tools); the flasher image's build recipe lives here in `docker/flasher/`.
Delivery-standard sketch is `EduBot_PI_Control_v2`. `make flash` wraps the
firmware's `tools/flash.sh` (dev, source flash); `make flash-fleet` runs the
`edubot-flasher` image (fleet reflash, binary only — no firmware source shipped).
