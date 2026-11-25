#!/usr/bin/env bash
# Syncs staged personal coding-agent state (see the user-side staging script
# ~/.config/devcontainer/host-sync.sh, documented in the dcc-docker-images
# devcontainer README) from the read-only /mnt/agent-state mount into the
# container home.
#
# Invoked from setup-workspace.sh, postStartCommand, and /etc/zsh/zshenv (every
# shell). The shell hook is the one that matters in practice: DevPod's dotfiles
# linking re-applies user dotfiles after each `up`, so the staged state must be
# re-applied after that — the next shell start does it.
#
# Only config/auth files are ever staged (never sessions/history).
set -euo pipefail

[ -d /mnt/agent-state ] || exit 0

# Copy one staged path into the container home unless it is already identical.
sync_path() { # staging_dir target_dir relative_path
    local src="$1/$3" dst="$2/$3"
    [ -e "$src" ] || return 0
    if [ -d "$src" ]; then
        # -T: merge src's entries into dst instead of nesting src inside it.
        diff -r -q "$src" "$dst" >/dev/null 2>&1 || cp -aT "$src" "$dst"
    else
        cmp -s "$src" "$dst" 2>/dev/null || cp "$src" "$dst"
    fi
}

sync_agent() { # staging_dir target_dir relative_path...
    local staging_dir="$1" target_dir="$2"
    shift 2
    mkdir -p "$target_dir"
    local rel
    for rel in "$@"; do
        sync_path "$staging_dir" "$target_dir" "$rel"
    done
}

# omp (oh-my-pi): settings, model catalog, provider keys
if [ -d /mnt/agent-state/omp ]; then
    sync_agent /mnt/agent-state/omp "$HOME/.omp/agent" \
        config.yml models.db models.db-wal models.db-shm \
        agent.db agent.db-wal agent.db-shm
fi

# Claude Code: global memory, settings, keybindings, Linux credentials.
# .claude.json carries mcpServers + onboarding state (plus light per-project
# entries) and lives at $HOME, not inside ~/.claude.
if [ -d /mnt/agent-state/claude ]; then
    sync_agent /mnt/agent-state/claude "$HOME/.claude" \
        CLAUDE.md settings.json keybindings.json .credentials.json
    sync_agent /mnt/agent-state/claude "$HOME" .claude.json
fi

# OpenCode: config, credentials, user agents/commands.
if [ -d /mnt/agent-state/opencode ]; then
    sync_agent /mnt/agent-state/opencode "$HOME/.config/opencode" \
        opencode.json opencode.jsonc auth.json agent command
fi

# pi (coding agent): global settings + auth; sessions stay on the host.
if [ -d /mnt/agent-state/pi ]; then
    sync_agent /mnt/agent-state/pi "$HOME/.pi/agent" \
        settings.json auth.json
fi
