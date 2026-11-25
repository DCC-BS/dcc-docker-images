# Shared dev container base for DCC-BS repos: Ubuntu 24.04 + mise + zsh.
# Per-project tools (bun, node, varlock, usage, pass-cli) are NOT baked in —
# each repo installs them at container create time with `mise install` (its
# .devcontainer/scripts/setup.sh), so tool versions live only in that repo's
# mise.toml.
#
# Ubuntu 24.04 (noble) because repos' mise.toml [bootstrap.packages] use noble
# apt names (e.g. libasound2t64); Debian would not resolve them.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# mise's node >= 26 links against libatomic, which the slim base does not ship.
RUN apt-get update \
    && apt-get -y install --no-install-recommends libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# mise system-wide so every user and every shell (interactive or not) finds it.
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh -

# zsh as login shell for root (the remoteUser declared in each app's
# devcontainer.json). The base image ships oh-my-zsh at /root/.oh-my-zsh; its
# `mise` plugin runs `eval "$(mise activate zsh)"` for interactive shells.
RUN usermod -s /usr/bin/zsh root
COPY zshrc /root/.zshrc

# Non-interactive shells (`devpod ssh <ws> -- cmd`) never read .zshrc, so put
# mise on their PATH too and give them a usable HOME. The agent sync hook runs
# on every shell start: DevPod's dotfiles linking re-applies overrides from
# the user's dotfiles after each `up`, and the staged copy in /mnt/agent-state
# must win (see sync-agent.sh and the adopting repo's host-sync.sh).
COPY sync-agent.sh /usr/local/bin/sync-agent
COPY setup-workspace.sh /usr/local/bin/setup-workspace
RUN printf 'export HOME="${HOME:-/root}"\nexport PATH="/usr/local/bin:/root/.local/share/mise/shims:$PATH"\n' > /etc/zsh/zshenv \
    && printf 'test -d /mnt/agent-state && /usr/local/bin/sync-agent >/dev/null 2>&1 || true\n' >> /etc/zsh/zshenv
