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
├── setup-workspace.sh    # baked to /usr/local/bin/setup-workspace
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
  use no agent state). Supported staging dirs: `omp`, `claude`, `opencode`, `pi`.
- `/usr/local/bin/setup-workspace`: create-time bootstrap run by
  `postCreateCommand` — `mise trust`, `mise install`,
  `mise bootstrap packages apply`, GitHub host key, agent sync. All steps key
  off the adopting repo's `mise.toml` in the workspace root, so the script
  itself has nothing repo-specific. A repo needing extra bootstrap steps
  points `postCreateCommand` at its own script that calls this one first.

## Personal agent state (opt-in, user-side)

The container is agent-neutral: nothing personal is staged unless the user
opts in. The opt-in script lives in the **user's home**, not the repo —
create `~/.config/devcontainer/host-sync.sh` (runs on the host before the
container starts, via `initializeCommand`). Example for omp (oh-my-pi):

```bash
#!/usr/bin/env bash
# Stage personal agent state for dev containers. Copy config files only,
# never sessions/history. Delete the blocks for agents you don't use.
set -euo pipefail
STAGING="${HOME}/.cache/devcontainer-agent-state"
mkdir -p "$STAGING"

# stage <agent> <source-dir> <relative-path>... — skip missing paths.
# <agent> must match the mapping in the image's sync-agent.sh.
stage() {
    local agent="$1" dir="$2"
    shift 2
    [ -d "$dir" ] || return 0
    local rel
    for rel in "$@"; do
        [ -e "$dir/$rel" ] || continue
        mkdir -p "$STAGING/$agent/$(dirname "$rel")"
        cp -a "$dir/$rel" "$STAGING/$agent/$rel"
    done
}

# omp (oh-my-pi): settings, model catalog, provider keys → ~/.omp/agent
stage omp "$HOME/.omp/agent" \
    config.yml models.db models.db-wal models.db-shm \
    agent.db agent.db-wal agent.db-shm

# Claude Code: memory, settings, keybindings, Linux credentials, mcp/onboarding
# (.claude.json carries mcpServers + onboarding; lives at $HOME)
stage claude "$HOME/.claude" \
    CLAUDE.md settings.json keybindings.json .credentials.json
stage claude "$HOME" .claude.json

# OpenCode: config, credentials, user agents/commands → ~/.config/opencode
stage opencode "$HOME/.config/opencode" \
    opencode.json opencode.jsonc auth.json agent command

# pi: global settings + auth → ~/.pi/agent (sessions stay on the host)
stage pi "$HOME/.pi/agent" settings.json auth.json
```

Without this file the staging dir is created empty and the container works
unchanged. For another agent, add a block that copies its config files into
`$STAGING/<agent>/`; the image's `/usr/local/bin/sync-agent` copies whatever
appears under `$STAGING` into the container home (checksum-guarded, re-runs on
every start and every shell start).

## Adopting in a repo

The devcontainer spec has no include/extends, so each repo carries its own
`.devcontainer/` — but it is a single file:

1. Copy `template/devcontainer.json` to `<repo>/.devcontainer/devcontainer.json`
   and fill the `REPO-SPECIFIC` fields (name, forwardPorts, extensions; the
   `PROTON_PASS_KEY_PROVIDER` env only if the repo uses pass-cli). Everything
   else — image, mounts, `initializeCommand`, `runArgs`, lifecycle commands —
   stays as-is.

Nothing else: no Dockerfile, no setup script, no host script. Creating the
workspace pulls the shared image; `postCreateCommand` runs the baked
`setup-workspace`, which installs the repo's tools from its `mise.toml`; each
user stages their own agent state from `~/.config/devcontainer/host-sync.sh`
if they have one.

Why this split: the image carries what is identical for every repo; `mise.toml`
carries what is repo-specific (tool versions, OS packages); the user's own
agent state is opt-in per user and never shared by default.

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
