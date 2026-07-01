# Releasing EduBot

A release is a tag on this meta-repo. Its bill-of-materials is
`edubot.lock.repos` at that tag — the exact commit of every package that went
into the `:stable` / `:vX.Y.Z` images.

Three version layers are in play (see README): **component** (per-repo tags),
**image** (built from the lockfile), **product** (this repo's tag).

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
   make pull-src        # fast-forward every repo in ./src
   make freeze          # writes edubot.lock.repos with exact commits
   git add edubot.lock.repos
   git commit -m "build: freeze lockfile for the next release"
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

4. **CI builds the release.** The tag push triggers `release.yml` in this repo
   (and, once its workflow is committed, in `edubot_dashboard`). Both push
   `:stable` and `:vX.Y.Z` to GHCR, built multi-arch from the lockfile.

## Deploy / roll back on robots

```bash
make update                      # channel stable — pull + restart + health check
EDUBOT_CHANNEL=v1.4.2 make up    # pin an exact version (e.g. to roll back)
```

## What "reproducible" means here

`make freeze` records each package's exact commit SHA (`vcs export --exact`), so
rebuilding `edubot-ros2` from a given `edubot.lock.repos` yields the same
workspace. The image also carries a `ch.vectoral.edubot.manifest-sha256` label,
so `docker inspect` on a robot tells you exactly which manifest it was built
from.
