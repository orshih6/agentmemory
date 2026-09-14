# agentmemory server image for Kubernetes (orshih6 fork, not upstream).
#
# Same build as deploy/coolify: installs the published npm package and copies the pinned
# iii engine binary from the official image. Differences are in entrypoint.sh:
#   - AGENTMEMORY_SECRET from the environment (a Kubernetes Secret) wins over /data/.hmac,
#     so the bearer secret is managed outside the pod and never printed to logs.
#   - Observability tuned like the repo-root iii-config.docker.yaml (10% sampling).
#   - Ships the iii console binary from the engine's own release, pinned and verified.
#
# Built by .github/workflows/selfhost-image.yml into ghcr.io/orshih6/agentmemory.
ARG III_VERSION=0.11.2

FROM iiidev/iii:${III_VERSION} AS iii-image

FROM node:22-slim

ARG AGENTMEMORY_VERSION=0.9.29
ARG III_VERSION=0.11.2
ARG III_SDK_VERSION=0.11.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates tini gosu curl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=iii-image /app/iii /usr/local/bin/iii

# iii console (developer web UI: traces, KV browser, functions, queues). `iii console` would
# download the newest console into $HOME at runtime; pin the build published in the SAME
# release as the engine instead, and verify its checksum.
RUN set -eu; \
    base="https://github.com/iii-hq/iii/releases/download/iii%2Fv${III_VERSION}"; \
    asset="iii-console-x86_64-unknown-linux-musl"; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSL -o console.tar.gz "$base/$asset.tar.gz"; \
    curl -fsSL -o console.sha256 "$base/$asset.sha256"; \
    [ "$(cut -d' ' -f1 console.sha256)" = "$(sha256sum console.tar.gz | cut -d' ' -f1)" ]; \
    tar xzf console.tar.gz; \
    install -m 0755 "$(find . -type f -name iii-console | head -1)" /usr/local/bin/iii-console; \
    cd /; rm -rf "$tmp"; \
    iii-console --version

WORKDIR /opt/agentmemory
RUN printf '{"name":"agentmemory-deploy","version":"1.0.0","private":true,"overrides":{"iii-sdk":"%s"}}\n' "${III_SDK_VERSION}" > package.json \
 && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" --omit=optional --no-fund --no-audit \
 && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory \
 && npm cache clean --force

ENV AGENTMEMORY_III_VERSION=${III_VERSION} \
    AGENTMEMORY_VERSION=${AGENTMEMORY_VERSION} \
    TINI_SUBREAPER=1

COPY --chmod=0755 entrypoint.sh /usr/local/bin/agentmemory-entrypoint.sh

EXPOSE 3111

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agentmemory-entrypoint.sh"]
