# mise base image

Pre-built base image (`ghcr.io/dcc-bs/dcc-docker-images/mise:13-slim`) that
carries everything common across DCC-BS app images. Build once, share.

## What it includes

- Debian 13 slim base
- apt packages: `sudo`, `curl`, `git`, `ca-certificates`, `build-essential`
- mise installed to `/mise/bin/mise`, with data/config/cache/state dirs under
  `/mise` and shims on `PATH`
- `/usr/local/bin/assemble-runtime` — a shared script that strips the
  mise-managed python/node + varlock into a minimal `/runtime`, dropping
  headers, Tcl/Tk, terminfo, npm/corepack, man pages, and pip/idle launchers.

## Environment

| Variable | Value |
| --- | --- |
| `MISE_DATA_DIR` | `/mise` |
| `MISE_CONFIG_DIR` | `/mise` |
| `MISE_CACHE_DIR` | `/mise/cache` |
| `MISE_STATE_DIR` | `/mise/state` |
| `MISE_INSTALL_PATH` | `/mise/bin/mise` |
| `PATH` | `/mise/bin:/mise/shims:$PATH` |

The installer honors `MISE_INSTALL_PATH` and installs to `/mise/bin/mise`.

## Build

```sh
docker build -t ghcr.io/dcc-bs/dcc-docker-images/mise:13-slim ./mise
```

The image is published to GHCR by the
`.github/workflows/docker-publish.yml` workflow (manual `workflow_dispatch`),
tagged `13-slim` and `latest`.

## Usage

App templates (`fastapi/`, `nuxt/`) `FROM` this image and add only their
app-specific steps. The runtime-assembly logic lives in exactly one place —
here — instead of being copy-pasted into every app.

## Version pinning

The tag (`13-slim`) matches the Debian release. When you bump it, rebuild and
re-tag so apps pick up the new `assemble-runtime` script and toolchain.
