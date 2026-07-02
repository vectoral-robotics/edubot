# Releasing EduBot

EduBot uses a **GitOps** release model: the meta-repo is the single source of
truth, and it carries two long-lived **channel branches** — `dev` and `stable`.
A robot follows exactly one channel; updating just means advancing the checkout
to that branch's latest state.

```
Sub-repos:  feat branch → PR → main → (auto-bump tags vX.Y.Z)   ← per repo
                                  │
Meta main:  you edit compose/config/scripts → PR → main
                                  │  make release-dev
                                  ▼
   dev     ── release(dev): dev-N        images :dev,   pinned by digest
                                  │  make promote-stable
                                  ▼
   stable  ── release(stable): v1.4.2    images :stable + :v1.4.2 (same digests)
```

Three branches, three roles:

| Branch   | Who writes it            | What it is |
|----------|--------------------------|------------|
| `main`   | you (via PRs)            | where the meta-repo is developed (compose, config, scripts) |
| `dev`    | `make release-dev`       | the dev channel — a frozen, built dev release |
| `stable` | `make promote-stable`    | the stable channel — a promoted, blessed release |

`dev` and `stable` are **never hand-edited** — they are pipeline output.

## The key idea

Building images and moving the meta-repo forward are **the same action**: a
release. You never trigger them separately. A release is one pipeline that
(1) freezes the sub-repo commits, (2) builds/tags the images, and (3) writes a
commit on the channel branch pinning exactly those images
(`channels/<channel>.json` + the lockfiles). The channel commit is the *record*
of what the images are, so the two can never drift.

## Prerequisites

- `docker` + `buildx` (multi-arch build). A Mac with Docker Desktop is fine — no
  ROS/Pi needed.
- `docker login ghcr.io` with a token that has **`write:packages`** for the org.
- `vcstool` (`pip install vcstool`), `jq`.

## Cut a dev release

```bash
make release-dev
```

This runs, from the meta-repo root, in one shot:

1. `make pull-src` — fast-forward every sub-repo in `src/` and `dev/` to its
   latest `main`.
2. `freeze` — pin those exact commits into `edubot.lock.repos` /
   `edubot.dev.lock.repos`.
3. **build & push** all three images as `:dev` (multi-arch), capturing the
   pushed digests.
4. write `channels/dev.json` (version `dev-N`, the pinned image **digests**, and
   every component's version) and commit it to the `dev` branch (main's config
   is merged in first, so compose/config travel with the release).

A **config-only** change (you edited something under the meta-repo, no sub-repo
changed) still cuts a clean dev release — the images come out to identical
digests, only the config + version advance.

## Promote to stable

When a dev release has proven itself:

```bash
make promote-stable                 # auto: bump the patch from the last vX.Y.Z
make promote-stable VERSION=1.5.0   # or set the product version explicitly
```

Promotion **rebuilds nothing**. It takes the exact digests already on `dev`,
re-tags them `:stable` + `:vX.Y.Z` (a multi-arch manifest copy via
`docker buildx imagetools create`), writes `channels/stable.json`, and commits +
tags `vX.Y.Z` on the `stable` branch.

## Deploy / update / roll back on a robot

A delivered robot has this meta-repo checked out (bind-mounted at `/edubot`) and
tracks one channel via `EDUBOT_CHANNEL`:

```bash
make update                      # follow the current channel (stable by default)
EDUBOT_CHANNEL=dev    make update # follow dev
EDUBOT_CHANNEL=v1.4.2 make update # pin / roll back to an exact version tag
```

`make update` (see `scripts/update.sh`) fetches, checks out the channel's latest
commit — which **brings the new compose/config for free** — reads
`channels/<channel>.json` to pin the images by digest, then `docker compose up
-d --build --pull always` and a dashboard health check. This is what closes the
gap where meta-repo (compose/config) changes never reached robots.

## What "reproducible" means here

The channel branch commit pins **everything** for a release: the sub-repo
commits (lockfiles), the image **digests** (`channels/<channel>.json`), and the
config/compose (the tree at that commit). Checking out a channel commit — or a
`vX.Y.Z` tag — reproduces that exact robot state.

## Roadmap

- **CI builds** (later): move `make release-dev` into a GitHub Actions workflow
  on the meta-repo (`:dev` on merge to main; promotion on demand), so releases
  don't depend on a laptop.
- **Dashboard update UI** (later): the dashboard reads the remote
  `channels/<channel>.json`, compares it to the running release, and offers a
  one-click update per channel. The manifest is already shaped for this.
