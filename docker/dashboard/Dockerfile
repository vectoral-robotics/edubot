# edubot-dashboard — FLEET image (Node.js web UI).
#
# Build recipe lives in the meta-repo; the app source lives in edubot_dashboard
# (checked out into ./dev/edubot_dashboard by `make src`). Build context is the
# meta-repo root, so paths below are relative to it. Built via scripts/release.sh
# (channel dev/stable) — never from the app repo's own CI.
FROM node:20-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    docker.io \
    docker-compose \
    util-linux \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY dev/edubot_dashboard/package.json dev/edubot_dashboard/package-lock.json* ./
RUN npm install --omit=dev

COPY dev/edubot_dashboard/server.js ./
COPY dev/edubot_dashboard/public ./public

EXPOSE 8080

CMD ["node", "server.js"]
