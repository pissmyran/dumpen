# Dumpen as a self-hosted container. Build from the repo root:
#   docker build -t dumpen .
# The Worker runs in workerd (the Cloudflare Workers runtime) through
# `wrangler dev --local`; the R2 buckets are files under /data, so keep that
# directory on a volume. The source has only placeholders; the entrypoint fills
# them in from the container environment with tools/render.mjs.
FROM node:24-trixie-slim

ENV NODE_ENV=production \
    WRANGLER_SEND_METRICS=false \
    PORT=8787

WORKDIR /opt/app
COPY package.json ./
RUN npm install --no-audit --no-fund --include=dev && npm cache clean --force
COPY tools ./tools
COPY src ./src
COPY public ./public
COPY cloudflare.example.env ./
COPY docker ./docker

RUN mkdir -p /data /srv && chown -R node:node /data /srv /opt/app/node_modules
USER node
VOLUME /data
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/bilder/x').then(r=>process.exit(r.status<500?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/opt/app/docker/entrypoint.sh"]
