# edubot

The EduBot meta-repo — the single entry point for both **development** and
**deployment** of the [EduBot](https://github.com/vectoral-robotics) robot, by
Vectoral. You clone this one repo; it pulls in everything else and runs the
whole stack.

It is also the **deployment repo**: it holds the Docker Compose stack, all the
container build contexts, and the mounted config. The dashboard is just one
container here.

## How containers reach a robot (hybrid)

The rule: **a container is a pulled image only if its source is not on the
robot; otherwise it is built on the robot from this repo.**

| Container | Delivery | Why |
|---|---|---|
| `edubot` (ROS 2 core) | pulled image | reproducible from the lockfile; avoids recompiling all of ROS per robot |
| `dashboard` | pulled image | its source lives in `edubot_dashboard`, not on the robot |
| `flasher` | pulled image | firmware source is private, not on the robot |
| `rviz`, `dev` (code-server), `web_video_server` | **built on the robot** | need only public ROS sources, whose contexts live here |
| `node_red`, `portainer` | upstream image | third-party tools (optional, `autostart: false`) |

A **developer** overrides this and builds *everything* from source (below).

## Developer quick start

```bash
git clone https://github.com/vectoral-robotics/edubot.git
cd edubot
make src        # ROS packages -> ./src ; firmware + dashboard -> ./dev
make dev        # builds the WHOLE stack from local source and runs it
```

`make dev` pulls nothing EduBot-specific — it builds `edubot` (from `./src`),
`dashboard` (from `./dev/edubot_dashboard`), plus `rviz`/`dev`/`web_video_server`
from this repo. Only `node_red`/`portainer` (third-party, optional) are images.

Each repo under `src/` (and `dev/`) is a normal, independent git checkout —
branch, commit and push per repo exactly like a standalone clone:

```bash
cd src/edubot_hardware
git checkout -b feat/my-change
# ... hack ...  then  `make dev`  rebuilds from your working tree
```

Python changes (hardware, demos) are picked up live via `--symlink-install`;
C++/launch changes need a rebuild (`make dev` again). Stop with `make dev-down`.

### Flashing the firmware

Flashed from the machine the board is plugged into (e.g. the robot's Pi):

```bash
make flash-setup                        # once: installs arduino-cli + ESP32 core
make flash                              # flashes EduBot_PI_Control_v2 (default)
make flash SKETCH=EduBot_New_PCB        # or a specific sketch
```

## Fleet deployment

A delivered robot clones this repo and runs the stack — the three images are
pulled, the support containers are built locally on first start:

```bash
cp .env.example .env                    # set EDUBOT_CHANNEL, ROS_DOMAIN_ID, ...
make up                                 # start (channel: stable)
make update                             # update: pull images + rebuild locals + restart
```

Images live on GHCR (`ghcr.io/vectoral-robotics/…`) with channel tags
`:stable`, `:dev` and immutable `:vX.Y.Z`. They are **public**, so robots pull
without any login. (If you keep an image private, run `make login` once per
robot with a pull-only token — see `.env.example`.)

See [RELEASING.md](RELEASING.md) for how versioned releases are cut.

## Versioning

Three layers, no overlap:

1. **Component** — each package repo carries its own semver (`package.xml` +
   commitizen), tagged `vX.Y.Z` on that repo. Firmware reports `FW_VERSION`
   over serial on boot.
2. **Image** — `edubot-ros2` is built from a specific `edubot.lock.repos`.
3. **Product** — a tag on this meta-repo; `edubot.lock.repos` at that tag is the
   bill-of-materials for that EduBot release. Generate it with `make freeze`.

## Layout

| Path | Purpose |
|---|---|
| `edubot.repos` | public ROS package list (the colcon core, → `./src`) |
| `edubot.dev.repos` | dev-only source: firmware + dashboard (→ `./dev`) |
| `edubot.lock.repos` | pinned commits for a release (`make freeze`) |
| `docker-compose.yaml` | the stack (pulled images + on-robot builds) |
| `docker-compose.dev.yaml` | dev override — build everything from source |
| `containers/` | build contexts for the on-robot containers |
| `deploy/` | dashboard config + helpers, mounted at runtime |
| `docker/` | the ROS 2 core image (fleet + dev) + entrypoints |
| `scripts/` | `update.sh` (update), `ghcr-login.sh` (private images) |

Run `make` (no target) for the full command list.

## License

PolyForm Perimeter 1.0.0 (source-available) — see [LICENSE](LICENSE).
