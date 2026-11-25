# Shared dev container image

Pre-built dev container base for DCC-BS repos: **build once here, every repo
references it by name**. Published as
`ghcr.io/dcc-bs/dcc-docker-images/devcontainer:24.04` (plus rolling `latest`)
by `.github/workflows/docker-publish.yml` (manual `workflow_dispatch`).

The devcontainer spec has no include/extends, so repos cannot reference this
directory's files directly — they reference the *image* and copy the
*template*:

```
devcontainer/
├── Dockerfile            # the image source (context = this dir)
├── sync-agent.sh         # baked to /usr/local/bin/sync-agent
├── zshrc                 # baked to /root/.zshrc
├── template/devcontainer.json  # copy into <repo>/.devcontainer/, fill REPO-SPECIFIC fields
└── README.md
```

## What the image contains

- `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` (noble — repos' apt
  bootstrap packages use noble names) + `libatomic1` (needed by mise node ≥ 26)
- mise at `/usr/local/bin/mise` — tools themselves are NOT baked in; each repo
  installs them from its own `mise.toml` at create time
- zsh as root's login shell, oh-my-zsh (shipped by the base image) with the
  `mise` plugin, fish-style completion menu
- `/etc/zsh/zshenv`: mise shims on `PATH` + `HOME` fallback for
  non-interactive shells (`devpod ssh <ws> -- cmd`), and the agent-sync hook
- `/usr/local/bin/sync-agent`: copies staged personal coding-agent state from
  the read-only `/mnt/agent-state` mount into the container home
  (checksum-guarded, no-op when nothing is staged — safe for teammates who
  use no agent state)

## Adopting in a repo

1. Copy `template/devcontainer.json` to `<repo>/.devcontainer/devcontainer.json`
   and fill the `REPO-SPECIFIC` fields (name, forwardPorts, extensions; the
   `PROTON_PASS_KEY_PROVIDER` env only if the repo uses pass-cli).
2. Add `<repo>/.devcontainer/scripts/setup.sh` — repo-specific bootstrap
   (`mise trust`, `mise install`, `mise bootstrap packages apply`, GitHub host
   key, `bash /usr/local/bin/sync-agent`). Copy from an existing adopting repo
   (e.g. text-mate-frontend) and adjust.
3. Add `<repo>/.devcontainer/scripts/host-sync.sh` — the per-user opt-in list
   of agent state to stage on the host (omp by default; add blocks for other
   agents). No-op when empty: safe for teammates.
4. Done. Creating a workspace pulls the shared image; `mise install` pulls the
   repo's tools.

Why this split: the image carries what is identical for every repo; `mise.toml`
and `setup.sh` carry what is repo-specific (tool versions, OS packages); the
user's own agent state is opt-in per user and never shared by default.

## Publishing

Run the `Build and Publish Docker Image` workflow (`workflow_dispatch`). It
publishes both images (`mise` and `devcontainer`). Tags:

- `24.04` — the pinned tag repos reference; rolling (re-pushed on publish).
  Bump to `24.05` for breaking changes and let repos migrate deliberately.
- `latest` — rolling, for experimentation.

Build it locally with:

```sh
docker build -t ghcr.io/dcc-bs/dcc-docker-images/devcontainer:24.04 ./devcontainer
```
