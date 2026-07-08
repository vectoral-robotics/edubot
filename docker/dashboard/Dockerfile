# edubot-dashboard — FLEET image (Node.js web UI).
#
# Build recipe lives in the meta-repo; the app source lives in edubot_dashboard
# (checked out into ./dev/edubot_dashboard by `make src`). Build context is the
# meta-repo root, so paths below are relative to it. Built via scripts/release.sh
# (channel dev/stable) — never from the app repo's own CI.
#
# The app is a pnpm workspace (hexagonal Fastify backend + React/Vite SPA in
# TypeScript). The build stage bundles the server into a single self-contained
# ESM file and builds the web app; the runtime stage needs only that file plus
# the built SPA assets.

# ---- build stage: bundle the server + build the web SPA --------------------
FROM node:20-bookworm AS build
ENV PNPM_HOME=/pnpm
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

WORKDIR /src
COPY dev/edubot_dashboard/ ./
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @edubot/dashboard-shared build \
 && pnpm --filter @edubot/dashboard-server build \
 && pnpm --filter @edubot/dashboard-web build

# ---- runtime stage ---------------------------------------------------------
FROM node:20-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    docker.io \
    docker-compose \
    util-linux \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Serve the built React SPA (with a client-side-routing fallback in the server).
ENV DASHBOARD_PUBLIC_DIR=/app/public

COPY --from=build /src/packages/server/dist/main.js ./main.js
COPY --from=build /src/packages/web/dist ./public

EXPOSE 8080

CMD ["node", "main.js"]
