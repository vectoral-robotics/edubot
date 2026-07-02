# Releasing EduBot

A release is a tag on this meta-repo. Its bill-of-materials is
`edubot.lock.repos` + `edubot.dev.lock.repos` at that tag — the exact commit of
every source repo that went into the `:stable` / `:vX.Y.Z` images.

Three version layers are in play (see README): **component** (per-repo tags),
**image** (built from the lockfiles), **product** (this repo's tag).

All images are built **locally** from this repo with `make release` — nothing is
built in any app repo's CI.

## Cut a release

1. **Release the components first (recommended).** In each package repo that
   changed, bump and tag its own version so the lockfile pins released commits,
   not arbitrary work-in-progress:

   ```bash
   cd src/edubot_hardware
   uvx --from commitizen cz bump      # bumps package.xml + tags vX.Y.Z
   git push --follow-tags
   ```

2. **Refresh and pin the workspace.** From the meta-repo root:

   ```bash
   make pull-src        # fast-forward every repo in ./src and ./dev
   make freeze          # writes edubot.lock.repos + edubot.dev.lock.repos
   git add edubot.lock.repos edubot.dev.lock.repos
   git commit -m "build: freeze lockfiles for the next release"
   ```

3. **Bump the product version + tag.** commitizen reads `.cz.toml`, updates the
   version and CHANGELOG, and creates the `vX.Y.Z` tag from the conventional
   commits since the last tag:

   ```bash
   uvx --from commitizen cz bump          # first ever release: add --yes
   git push --follow-tags
   ```

   The very first release has no prior tag, so commitizen asks to confirm the
   initial tag — pass `--yes` (or answer the prompt) that one time.

4. **Build & push the images.** From the meta-repo root, with the workspace at
   the frozen commits and a GHCR login that has `write:packages`:

   ```bash
   make release CHANNEL=stable      # builds all 3 images from the lockfiles,
                                    # tags :stable + :v<product-version>, pushes
   ```

   Multi-arch (amd64/arm64) via buildx — runs on any machine with Docker, macOS
   included. Rolling `:dev` for the dev channel is the same command with
   `CHANNEL=dev` (builds from the main manifests instead of the lockfiles).

## Deploy / roll back on robots

```bash
make update                      # channel stable — pull + restart + health check
EDUBOT_CHANNEL=v1.4.2 make up    # pin an exact version (e.g. to roll back)
```

## What "reproducible" means here

`make freeze` records each source repo's exact commit SHA (`vcs export --exact`)
into `edubot.lock.repos` (ROS core) and `edubot.dev.lock.repos` (dashboard,
firmware). `make release CHANNEL=stable` builds every image from those pinned
commits, so a given release tag reproduces the same three images.
