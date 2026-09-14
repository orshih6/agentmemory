#!/bin/sh
# agentmemory entrypoint for Kubernetes (orshih6 fork). Based on deploy/coolify/entrypoint.sh.
#
# Runs as root so it can:
#   1. Overwrite the npm-bundled iii-config.yaml (binds 127.0.0.1, relative ./data paths)
#      with one that binds 0.0.0.0 and keeps all state under /data.
#   2. chown the mounted /data volume (hostPath/local-path volumes are root-owned).
#   3. Resolve the bearer secret:
#        - AGENTMEMORY_SECRET set in the environment -> used as-is, nothing written or printed.
#        - otherwise /data/.hmac, generated on first boot (printed once, as upstream does).
# Then execs the agentmemory CLI as the unprivileged `node` user.

set -eu

DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
HMAC_FILE="${AGENTMEMORY_HMAC_FILE:-/data/.hmac}"
RUN_AS="node:node"
III_CONFIG="/opt/agentmemory/node_modules/@agentmemory/agentmemory/dist/iii-config.yaml"

mkdir -p "$DATA_DIR"
chown -R "$RUN_AS" "$DATA_DIR"

cat > "$III_CONFIG" <<'CFG'
workers:
  - name: iii-http
    config:
      port: 3111
      host: 0.0.0.0
      default_timeout: 180000
      cors:
        allowed_origins:
          - "http://localhost:3111"
          - "http://localhost:3113"
          - "http://127.0.0.1:3111"
          - "http://127.0.0.1:3113"
        allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]
  - name: iii-state
    config:
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/state_store.db
  - name: iii-queue
    config:
      adapter:
        name: builtin
  - name: iii-pubsub
    config:
      adapter:
        name: local
  - name: iii-cron
    config:
      adapter:
        name: kv
  - name: iii-stream
    config:
      port: 3112
      host: 0.0.0.0
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/stream_store
  - name: iii-observability
    config:
      enabled: true
      service_name: agentmemory
      exporter: memory
      # Same as the repo-root iii-config.docker.yaml (see upstream #519).
      sampling_ratio: 0.1
      metrics_enabled: true
      logs_enabled: true
      logs_console_output: false
CFG
chown "$RUN_AS" "$III_CONFIG"

if [ -n "${AGENTMEMORY_SECRET:-}" ]; then
  echo "agentmemory: using AGENTMEMORY_SECRET from the environment"
else
  if [ ! -s "$HMAC_FILE" ]; then
    SECRET="$(openssl rand -hex 32)"
    umask 077
    printf '%s\n' "$SECRET" > "$HMAC_FILE"
    chmod 600 "$HMAC_FILE"
    chown "$RUN_AS" "$HMAC_FILE"
    echo "================================================================"
    echo "agentmemory: generated HMAC secret on first boot"
    echo "AGENTMEMORY_SECRET=$SECRET"
    echo "Copy this value now. It will not be printed again."
    echo "Stored at: $HMAC_FILE (chmod 600)"
    echo "================================================================"
  fi
  AGENTMEMORY_SECRET="$(cat "$HMAC_FILE")"
fi
export AGENTMEMORY_SECRET

exec gosu "$RUN_AS" agentmemory "$@"
