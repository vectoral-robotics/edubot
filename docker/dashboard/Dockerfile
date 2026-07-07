# edubot-dashboard — FLEET image (Node.js web UI).
#
# Build recipe lives in the meta-repo; the app source lives in edubot_dashboard
# (checked out into ./dev/edubot_dashboard by `make src`). Build context is the
# meta-repo root, so paths below are relative to it. Built via scripts/release.sh
# (channel dev/stable) — never from the app repo's own CI.
#
# The app is a pnpm workspace (hexagonal Fastify backend in TypeScript). The
# build stage bundles the server into a single self-contained ESM file; the
# runtime stage only needs that file plus the static UI in public/.

# ---- build stage: bundle the server ----------------------------------------
FROM node:20-bookworm AS build
ENV PNPM_HOME=/pnpm
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

WORKDIR /src
COPY dev/edubot_dashboard/ ./
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @edubot/dashboard-shared build \
 && pnpm --filter @edubot/dashboard-server build

# ---- runtime stage ---------------------------------------------------------
FROM node:20-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    docker.io \
    docker-compose \
    util-linux \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Serve the (currently still vanilla) UI shipped in public/. The React frontend
# replaces this once teleop/navigation are ported (dashboard migration M4).
ENV DASHBOARD_PUBLIC_DIR=/app/public

COPY --from=build /src/packages/server/dist/main.js ./main.js
COPY dev/edubot_dashboard/public ./public

EXPOSE 8080

CMD ["node", "main.js"]
