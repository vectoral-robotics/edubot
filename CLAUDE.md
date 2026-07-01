# edubot (meta-repo) — Claude guidelines

The single entry point for developing and deploying EduBot. It orchestrates the
separate package repos; it holds almost no code of its own.

## What lives here

- `edubot.repos` / `edubot.dev.repos` / `edubot.lock.repos` — vcstool manifests.
- `docker-compose.dev.yaml` (build from `./src`) and `docker-compose.yaml`
  (pre-built GHCR images). One robot runs one or the other.
- `Makefile` — the user-facing commands (`src`, `dev`, `up`, `pull`, `update`,
  `freeze`, `flash`).
- `docker/` — the ROS 2 developer image; `scripts/` — on-robot update.

`make src` imports the ROS core into `./src` and dev-only repos (firmware) into
`./dev`; both are git-ignored — never commit them. The repos under them are
independent checkouts; work happens inside them, not here. Firmware is kept out
of `./src` so it never enters the colcon workspace, the lockfile, or the fleet
image.

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
tag on this repo; `edubot.lock.repos` is the bill-of-materials). `make freeze`
records the current `src/` commits into the lockfile for a release.

## Firmware

`edubot_firmware` is private and NOT a colcon package. It is imported via
`edubot.dev.repos` for developers only. Delivery-standard sketch is
`EduBot_PI_Control_v2`. `make flash` wraps its `tools/flash.sh`. Fleet reflash
is done by a private `edubot-flasher` image (later phase), not by shipping
source.
