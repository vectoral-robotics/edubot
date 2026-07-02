# edubot

The EduBot meta-repo — the single entry point for both **development** and
**deployment** of the [EduBot](https://github.com/vectoral-robotics) robot, by
Vectoral. You clone this one repo; it pulls in everything else and runs the
whole stack.

It is also the **deployment repo**: it holds the Docker Compose stack, all the
container build contexts, and the mounted config. The dashboard is just one
container here.

## Prerequisites

Running the **stack** needs the **robot (a Raspberry Pi) or any Linux box** — it
uses host networking and device access, so it does **not** run on macOS/Windows.
(Building the fleet images with `make release` is separate and runs anywhere with
Docker + buildx, macOS included — see [RELEASING.md](RELEASING.md).)

- **Docker** with the Compose plugin.
- **git** with access to the private `edubot_firmware` and `edubot_dashboard`
  repos (an SSH key or token on the machine).
- **vcstool** (`pip install vcstool`) — `make src` uses the `vcs` command.
- For flashing only: `arduino-cli` (installed by `make flash-setup`).

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

The **first** `make dev` runs a full colcon build (a few minutes). Watch it with
`docker logs -f edubot_ros2` until you see `ROS2 nodes are running` — the
dashboard and video connect once the ROS core is up. Then open the dashboard at
**`http://<robot-ip>:8080`**. Other services (started from the dashboard):

| Service | URL |
|---|---|
| Dashboard | `http://<robot-ip>:8080` |
| Code Server (`dev`) | `https://<robot-ip>:8443` |
| RViz (web) | `http://<robot-ip>:14500` |
| Web Video | `http://<robot-ip>:8081` |
| Node-RED | `http://<robot-ip>:1880` |
| Portainer | `http://<robot-ip>:9000` |

Each repo under `src/` (and `dev/`) is a normal, independent git checkout —
branch, commit and push per repo exactly like a standalone clone:

```bash
cd src/edubot_hardware
git checkout -b feat/my-change
# ... hack ...  then  `make dev`  rebuilds from your working tree
```

Python changes (hardware, demos) are picked up live via `--symlink-install`;
C++/launch changes need a rebuild (`make dev` again). Stop with `make dev-down`.

### Updating & testing on the robot

Each repo under `src/`/`dev/` is a normal git checkout, so you drive it with
plain git. To pull the latest and rebuild:

```bash
make pull-src                        # git pull (fast-forward) in every subrepo
# or just one:  cd src/edubot_hardware && git pull
make dev                             # incremental colcon rebuild + restart
```

To test an **un-merged branch**, check it out in that subrepo (it must be
pushed so the robot can fetch it), then rebuild:

```bash
cd src/edubot_hardware
git fetch && git checkout feat/my-branch
cd ../.. && make dev
```

Use `git pull` / `make pull-src` to update — **not** `make src`, which
re-imports the manifest versions (`main`) and would switch you off your branch.
`make src` is for the initial clone or resetting to the manifest.

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
2. **Image** — all three fleet images are built centrally with `make release`
   from the lockfiles (`edubot.lock.repos` + `edubot.dev.lock.repos`); no image
   is built in any app repo's CI.
3. **Product** — a tag on this meta-repo; the lockfiles at that tag are the
   bill-of-materials for that EduBot release. Generate them with `make freeze`.

## Layout

| Path | Purpose |
|---|---|
| `edubot.repos` | public ROS package list (the colcon core, → `./src`) |
| `edubot.dev.repos` | non-ROS source: firmware + dashboard (→ `./dev`) |
| `edubot.lock.repos` / `edubot.dev.lock.repos` | pinned commits for a release (`make freeze`) |
| `docker-compose.yaml` | the stack (pulled images + on-robot builds) |
| `docker-compose.dev.yaml` | dev override — build everything from source |
| `docker/` | build recipes for the 3 fleet images (`ros2`, `dashboard/`, `flasher/`) + entrypoints |
| `containers/` | build contexts for the on-robot-built support containers (rviz, dev, web_video_server) |
| `deploy/` | dashboard config + helpers, mounted at runtime |
| `scripts/` | `release.sh` (image builds), `update.sh` (update), `ghcr-login.sh` (private images) |

Run `make` (no target) for the full command list.

## License

PolyForm Perimeter 1.0.0 (source-available) — see [LICENSE](LICENSE).
