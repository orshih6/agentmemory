# agentmemory on Kubernetes (orshih6 fork)

Image: `ghcr.io/orshih6/agentmemory`, built by `.github/workflows/selfhost-image.yml`
from `deploy/k8s/Dockerfile`. Upstream publishes no container image; its deploy templates
build from the npm package, and so does this one.

- Port `3111`: REST API (and the REST routes the `@agentmemory/mcp` shim proxies to).
- State: everything under `/data`. Mount a persistent volume there. Single replica only.
- Auth: set `AGENTMEMORY_SECRET` from a Secret. Clients send `Authorization: Bearer <secret>`.
  Without it, the entrypoint generates `/data/.hmac` on first boot like the other templates.
- `iii-console` is on the PATH, taken from the same iii release as the engine. Run it as a
  sidecar bound to 127.0.0.1 (it has no auth), e.g. `iii-console --host 127.0.0.1 --port 3114`,
  and reach it with `kubectl port-forward`.
- Bump `AGENTMEMORY_VERSION` / `III_VERSION` in the Dockerfile to upgrade.

The cluster manifests live in `~/myinternal/k0s/agentmemory/`.
