#!/usr/bin/env bash
# Create-time bootstrap, baked into the shared devcontainer image and run by
# postCreateCommand ("bash /usr/local/bin/setup-workspace"). The devcontainer
# lifecycle runs it with cwd = the workspace root, so every step keys off that
# repo's mise.toml: tool versions and OS packages are repo data, this script is
# shared. Repos needing extra bootstrap steps: give postCreateCommand your own
# script that calls this one, then your extra steps.
set -euo pipefail

# 1. mise refuses to evaluate an untrusted config in a fresh container.
mise trust

# 2. Install every tool pinned in mise.toml. The postinstall hook (mise.toml)
#    may chain further installs (e.g. package manager install, browser download).
mise install

# 3. OS libraries declared in [bootstrap.packages] (Ubuntu noble apt names).
#    Runs apt-get as root (devcontainer.json sets remoteUser: root).
mise bootstrap packages apply --update --yes

# 4. Pin GitHub's host key so the first `git fetch`/`git push` inside the
#    container is non-interactive. Authentication itself goes through the
#    forwarded host ssh-agent; no private key is ever stored here.
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts

# 5. Personal coding-agent state (opt-in staging, see the adopting repo's
#    .devcontainer/scripts/host-sync.sh). postStartCommand and /etc/zsh/zshenv
#    re-run the sync later; DevPod's dotfiles step re-links user dotfiles after
#    postCreate, so the staged copy must be re-applied after that.
bash /usr/local/bin/sync-agent
