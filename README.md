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
| `dev` (code-server), `web_video_server` | **built on the robot** | need only public ROS sources, whose contexts live here |
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
`dashboard` (from `./dev/edubot_dashboard`), plus `dev`/`web_video_server`
from this repo. Only `node_red`/`portainer` (third-party, optional) are images.

The **first** `make dev` runs a full colcon build (a few minutes). Watch it with
`docker logs -f edubot_ros2` until you see `ROS2 nodes are running` — the
dashboard and video connect once the ROS core is up. Then open the dashboard at
**`http://<robot-ip>:8080`**. Other services (started from the dashboard):

| Service | URL |
|---|---|
| Dashboard | `http://<robot-ip>:8080` |
| Code Server (`dev`) | `https://<robot-ip>:8443` |
| Foxglove | hosted app, connects to `ws://<robot-ip>:9090` (rosbridge) |
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

## Versioning & channels

GitOps: the meta-repo is the source of truth and carries two **channel
branches**, `dev` and `stable`. A robot follows one channel; `make update`
advances its checkout to that branch's latest state (bringing new compose/config
with it) and pins the images by digest from `channels/<channel>.json`.

Three layers, no overlap:

1. **Component** — each package repo carries its own semver (`package.xml` +
   commitizen), auto-tagged `vX.Y.Z` on merge. Firmware reports `FW_VERSION`
   over serial on boot.
2. **Image** — all three fleet images are built centrally by `make release-dev`
   (never in an app repo's CI) and pinned by digest on the channel branch.
3. **Product** — the channel branches: `dev` (rolling, `dev-N`) and `stable`
   (`vX.Y.Z` tag). `make promote-stable` blesses a dev release into stable
   without rebuilding.

See [RELEASING.md](RELEASING.md) for the full flow (`make release-dev` /
`make promote-stable`).

## Layout

| Path | Purpose |
|---|---|
| `edubot.repos` | public ROS package list (the colcon core, → `./src`) |
| `edubot.dev.repos` | non-ROS source: firmware + dashboard (→ `./dev`) |
| `channels/dev.json` / `channels/stable.json` | the per-channel release manifest (version, pinned image digests, component versions) — written on the `dev`/`stable` branches |
| `edubot.lock.repos` / `edubot.dev.lock.repos` | pinned commits for a release (on the channel branches; `make freeze`) |
| `docker-compose.yaml` | the stack (pulled images + on-robot builds) |
| `docker-compose.dev.yaml` | dev override — build everything from source |
| `docker/` | build recipes for the 3 fleet images (`ros2`, `dashboard/`, `flasher/`) + entrypoints |
| `containers/` | build contexts for the on-robot-built support containers (dev, web_video_server) |
| `deploy/` | dashboard config + helpers, mounted at runtime |
| `scripts/` | `release-dev.sh` / `promote-stable.sh` (releases), `build-images.sh` (build engine), `update.sh` (on-robot update), `lib.sh`, `ghcr-login.sh` |

Run `make` (no target) for the full command list.

## License

PolyForm Perimeter 1.0.0 (source-available) — see [LICENSE](LICENSE).
