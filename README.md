# edubot

The EduBot meta-repo — the single entry point for both **development** and
**deployment** of the [EduBot](https://github.com/vectoral-robotics) robot, by
Vectoral.

One clone, two modes:

- **Developers / dev robots** get the full source of every package repo and
  build from it, switching branches per repo.
- **Delivered robots (fleet)** pull pre-built, versioned container images and
  update over the air — no source, no build.

Both start from the same source of truth: the package repos, each with its own
semver tags.

## Developer quick start

```bash
git clone https://github.com/vectoral-robotics/edubot.git
cd edubot
make src        # ROS packages -> ./src, dev repos (firmware) -> ./dev
make dev        # builds the ROS 2 core live from ./src and runs it
```

Each repo under `src/` is a normal, independent git checkout — branch, commit
and push per repo exactly like a standalone clone:

```bash
cd src/edubot_hardware
git checkout -b feat/my-change
# ... hack ...  then  make dev  rebuilds from your working tree
```

Python changes (hardware, demos) are picked up live via `--symlink-install`;
C++/launch changes need a rebuild (`make dev` again).

### Flashing the firmware

The ESP32-S3 firmware is flashed from the machine the board is plugged into
(e.g. the robot's Raspberry Pi):

```bash
make flash-setup                        # once: installs arduino-cli + ESP32 core
make flash                              # flashes EduBot_PI_Control_v2 (default)
make flash SKETCH=EduBot_New_PCB        # or a specific sketch
```

## Fleet deployment

A delivered robot runs the image-based stack:

```bash
cp .env.example .env                    # set EDUBOT_CHANNEL, ROS_DOMAIN_ID, ...
make up                                 # pull + start (channel: stable)
make update                             # OTA update: pull + restart + health check
```

Images live on GHCR (`ghcr.io/vectoral-robotics/…`) with channel tags
`:stable`, `:dev` and immutable `:vX.Y.Z`. The images are **public**, so robots
pull them without any login — no token to provision.

If you ever keep an image private, log in once per robot with a **pull-only**
credential (fine-grained PAT, scope `read:packages`) before `make up`:

```bash
make login          # reads a token from /etc/edubot/ghcr-token (see .env.example)
```

See [RELEASING.md](RELEASING.md) for how versioned releases are cut.

## Versioning

Three layers, no overlap:

1. **Component** — each package repo carries its own semver (`package.xml` +
   commitizen) and is tagged `vX.Y.Z` on that repo. Firmware reports `FW_VERSION`
   over serial on boot.
2. **Image** — the ROS 2 core image is built from a specific `edubot.lock.repos`.
3. **Product** — a tag on this meta-repo; `edubot.lock.repos` at that tag is the
   bill-of-materials for that EduBot release. Generate it with `make freeze`.

## Layout

| Path | Purpose |
|---|---|
| `edubot.repos` | canonical public ROS package list (the colcon core) |
| `edubot.dev.repos` | developer-only extras (private firmware) |
| `edubot.lock.repos` | pinned commits for a release (`make freeze`) |
| `docker-compose.dev.yaml` | developer stack — build from `./src` |
| `docker-compose.yaml` | fleet stack — pre-built GHCR images |
| `docker/` | ROS 2 dev image + entrypoint |
| `scripts/update.sh` | on-robot OTA update |

Run `make` (no target) for the full command list.

## Status

This is a work-in-progress migration. See the root `CLAUDE.md` for the phased
plan; some fleet pieces (GHCR CI, images, the flasher image) land in later
phases and are marked as such in the compose files.
