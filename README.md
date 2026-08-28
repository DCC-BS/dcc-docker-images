# DCC Docker Images

Shared Docker tooling for DCC-BS apps. The goal is to keep the Docker logic in
**one place** so apps don't duplicate it.

## Layout

```
dcc-docker-images/
├── mise/          # PRE-BUILT base image (dcc-mise:13-slim) — build once, share
├── fastapi/       # TEMPLATE — copy into FastAPI/uv apps, build in the app repo
├── nuxt/          # TEMPLATE — copy into Nuxt/node apps, build in the app repo
└── README.md
```

## How it works

Only the **mise base image** is pre-built and shared. The fastapi/nuxt
Dockerfiles are **templates**: they `COPY` app files, so they must be built
inside each app repo with the app as the build context.

The base image carries everything common:

- apt packages, mise env vars, and the mise binary
- `/usr/local/bin/assemble-runtime` — a shared script that strips the
  mise-managed python/node + varlock into a minimal `/runtime`, dropping
  headers, Tcl/Tk, terminfo, npm/corepack, man pages, and pip/idle launchers.

Each app's Dockerfile is then thin: it only holds the app-specific steps
(`COPY . .`, build commands, entrypoint). The runtime-assembly logic lives in
exactly one place — the base image — instead of being copy-pasted into every app.

## Build the base image

```sh
docker build -t ghcr.io/dcc-bs/dcc-docker-images/mise:13-slim ./mise
```

The base image is published to GHCR by the
`.github/workflows/docker-publish.yml` workflow (manual `workflow_dispatch`),
tagged `13-slim` and `latest`.

## Use a template in an app

1. Copy the template into the app repo:
   ```sh
   cp dcc-docker-images/fastapi/Dockerfile /path/to/app/Dockerfile
   ```
2. Build in the app repo (the app is the build context):
   ```sh
   cd /path/to/app
   docker build -t my-app .
   ```

The python/node version is **not** hardcoded anywhere in the templates — it
comes from the app's own `pyproject.toml` (`requires-python`) or `mise.toml`.
Change it there and both build and runtime follow automatically.

## Version pinning

The base image tag (`13-slim`) matches the Debian release. When you bump the
base image, rebuild it and re-tag so apps pick up the new `assemble-runtime`
script and toolchain.

## Publish

The `.github/workflows/docker-publish.yml` workflow builds and pushes the mise
base image to `ghcr.io/dcc-bs/dcc-docker-images/mise` on manual dispatch. The
fastapi/nuxt templates are not published — they are copied into each app and
built there.
