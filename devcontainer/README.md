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

### Machines without the agent installed (host-free workflow)

The staging flow assumes the agent's state originates on the host. On a machine
where the agent only lives inside dev containers, split the state by class —
the two classes have opposite sharing semantics and different homes:

| Class | Examples | Source of truth |
|---|---|---|
| Declarative config | omp `config.yml`, pi `settings.json`, OpenCode `opencode.json`, Claude `settings.json`/`CLAUDE.md` | **git — your dotfiles repo** |
| Mutable runtime state | omp `models.db`/`agent.db` (sqlite), credential caches | **per-machine named volume** |

- **Config → dotfiles repo.** DevPod clones your dotfiles *inside* every
  container on every `up`, on any machine — no host agent needed. This path
  already works today (it is how `dot_omp/config.yml` reaches the container).
  Never commit credentials: fetch `auth.json`/`.credentials.json` at first
  shell from a secret store instead (e.g. Proton Pass via pass-cli).
- **Mutable state → shared named volume.** Create a Podman/Docker named volume
  (e.g. `devpod-agent-state`) and mount it read-write into your workspaces; it
  survives workspace recreation and is shared by every container on that
  machine, with nothing stored on the host. First use seeds it.
- **Never sync the sqlite state between containers** (no container → host
  reverse-sync): sqlite/WAL snapshots traded between live writers are
  last-writer-wins with corruption risk. A volume mounted by one writer at a
  time is the safe shape.
- omp-specific: if `models.db`/`agent.db` turn out to be rebuildable from
  `config.yml` on first run, the volume shrinks to nothing and dotfiles +
  secret store cover the whole workflow.

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

## Creating workspaces — use the git URL

```sh
devpod up git@github.com:OWNER/REPO.git --ide vscode   # or: --ide zed
```

DevPod clones the repo into a container-managed volume; the host checkout is
never touched.

**Never create the workspace from the local folder** (`devpod up .`) with a
rootless Podman provider: DevPod bind-mounts the working tree and its
create-time sync writes through the mount as container-root, which maps to
your *subuid* — not your user. Every file it touches becomes unwritable on the
host, and every later `up` of that workspace re-syncs the mount. If it already
happened:

```sh
devpod delete <workspace>                          # remove the workspace
sudo chown -R $(id -un):$(id -gn) <repo>           # reclaim the host files
```

The IDE is independent of the content source and can be attached or changed
afterwards on an existing workspace (named after the repo folder):

```sh
devpod up <workspace> --ide zed      # reopen with Zed
devpod ide use zed <workspace>       # or make it the default, then `devpod up <workspace>`
```

Two naming/caching gotchas when creating from `URL@branch`:

- The workspace is named after the **branch** segment (`URL@features/foo` →
  workspace `foo`). If a workspace with that name already exists, DevPod does
  **not** create a new one — it re-targets the existing workspace's source and
  rebuilds in place. Deleting the workspace first avoids surprise takeovers.
- `devpod delete` does **not** purge DevPod's content cache under
  `~/.devpod/agent/contexts/default/workspaces/<name>/content`. Recreating a
  same-named workspace can then check out a **stale clone of a different repo**
  (branch names collide across repos, so the cache "fits"). Purge it manually
  before recreating for another repo:

  ```sh
  podman run --rm --security-opt label=disable \
      -v ~/.devpod/agent/contexts/default/workspaces/<name>:/c alpine:3 \
      sh -c 'rm -rf /c/* /c/.[!.]*'
  ```

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
