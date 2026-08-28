FROM debian:13-slim

RUN apt-get update \
    && apt-get -y --no-install-recommends install sudo curl git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_STATE_DIR="/mise/state"
ENV MISE_INSTALL_PATH="/mise/bin/mise"
ENV PATH="/mise/bin:/mise/shims:$PATH"

# install mise (the installer honors MISE_INSTALL_PATH and installs to /mise/bin/mise)
RUN curl https://mise.run | sh

# Shared runtime-assembly helper: strips python/node + varlock into /runtime.
# Used by the fastapi/nuxt templates so the assembly logic lives in one place.
COPY assemble-runtime /usr/local/bin/assemble-runtime
RUN chmod +x /usr/local/bin/assemble-runtime
